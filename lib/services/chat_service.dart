import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import 'cloudinary_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _conversationsCollection = FirebaseFirestore.instance.collection('conversations');
  final CollectionReference _messagesCollection = FirebaseFirestore.instance.collection('messages');
  final CloudinaryService _cloudinary = CloudinaryService();

  // Create or get existing conversation
  Future<String> createOrGetConversation({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Create conversation ID based on user IDs (sorted to ensure consistency)
      final List<String> sortedUserIds = [userId1, userId2]..sort();
      final String conversationId = '${sortedUserIds[0]}_${sortedUserIds[1]}';

      // Check if conversation already exists
      final DocumentSnapshot conversationDoc = await _conversationsCollection.doc(conversationId).get();
      
      if (!conversationDoc.exists) {
        // Get participant display names
        final user1Doc = await _firestore.collection('users').doc(userId1).get();
        final user2Doc = await _firestore.collection('users').doc(userId2).get();
        
        final user1Name = user1Doc.exists 
            ? (user1Doc.data() as Map<String, dynamic>)['displayName'] ?? 'Unknown User'
            : 'Unknown User';
        final user2Name = user2Doc.exists 
            ? (user2Doc.data() as Map<String, dynamic>)['displayName'] ?? 'Unknown User' 
            : 'Unknown User';

        // Create new conversation
        final conversationData = {
          'id': conversationId,
          'participantIds': [userId1, userId2],
          'lastMessage': '',
          'lastActivity': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
          'unreadCount': 0,
          'unreadBy': {
            userId1: 0,
            userId2: 0,
          },
          'isActive': true,
          'participantNames': {
            userId1: user1Name,
            userId2: user2Name,
          },
          'participantAvatars': {
            userId1: user1Doc.exists 
                ? (user1Doc.data() as Map<String, dynamic>)['profileImageUrl'] 
                : null,
            userId2: user2Doc.exists 
                ? (user2Doc.data() as Map<String, dynamic>)['profileImageUrl'] 
                : null,
          },
        };

        await _conversationsCollection.doc(conversationId).set(conversationData);
      }

      return conversationId;
    } catch (e, stackTrace) {
      debugPrint('Create conversation error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to create conversation');
    }
  }

  // Create a new group conversation
  Future<String> createGroupConversation({
    required String name,
    required List<String> participantIds,
    String? imageUrl,
  }) async {
    try {
      if (participantIds.isEmpty) throw Exception('No participants');

      final DocumentReference convoRef = _conversationsCollection.doc();

      // Fetch participant display names and avatars
      final Map<String, String> participantNames = {};
      final Map<String, String?> participantAvatars = {};
      for (final uid in participantIds) {
        try {
          final u = await _firestore.collection('users').doc(uid).get();
          if (u.exists) {
            final d = u.data() as Map<String, dynamic>;
            participantNames[uid] = (d['displayName'] as String?) ?? 'User';
            participantAvatars[uid] = d['profileImageUrl'] as String?;
          } else {
            participantNames[uid] = 'User';
            participantAvatars[uid] = null;
          }
        } catch (_) {
          participantNames[uid] = 'User';
          participantAvatars[uid] = null;
        }
      }

      final data = {
        'id': convoRef.id,
        'participantIds': participantIds,
        'name': name,
        'imageUrl': imageUrl,
        'type': 'group',
        'participantNames': participantNames,
        'participantAvatars': participantAvatars,
        'lastMessage': '',
        'lastActivity': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unreadCount': 0,
        'unreadBy': {
          for (final uid in participantIds) uid: 0,
        },
        'isActive': true,
      };

      await convoRef.set(data);
      return convoRef.id;
    } catch (e, stackTrace) {
      debugPrint('Create group conversation error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to create group');
    }
  }

  // Update group name
  Future<void> updateGroupName(String conversationId, String name) async {
    try {
      await _conversationsCollection.doc(conversationId).update({'name': name});
    } catch (e, stackTrace) {
      debugPrint('Update group name error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to update group name');
    }
  }

  // Upload group image and return URL
  Future<String> uploadGroupImage({
    required String conversationId,
    required Uint8List bytes,
  }) async {
    try {
      final filename = 'group_${conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _cloudinary.uploadImageBytes(bytes, filename: filename);
      return url;
    } catch (e, stackTrace) {
      debugPrint('Upload group image error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to upload group image');
    }
  }

  // Set group image URL on conversation
  Future<void> setGroupImageUrl(String conversationId, String imageUrl) async {
    try {
      await _conversationsCollection.doc(conversationId).update({'imageUrl': imageUrl});
    } catch (e, stackTrace) {
      debugPrint('Set group image URL error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to set group image');
    }
  }

  // Send message
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? imageUrl,
  }) async {
    try {
      final DocumentReference messageRef = _messagesCollection.doc();

      final messageData = {
        'id': messageRef.id,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
        'type': type.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'replyToMessageId': null,
        'metadata': imageUrl != null ? {'imageUrl': imageUrl} : null,
      };

      final WriteBatch batch = _firestore.batch();

      // Add message
      batch.set(messageRef, messageData);

      // Update conversation (store a lightweight lastMessage object for previews)
      final DocumentReference conversationRef = _conversationsCollection.doc(conversationId);
      batch.update(conversationRef, {
        'lastMessage': {
          'id': messageRef.id,
          'conversationId': conversationId,
          'senderId': senderId,
          'content': content,
          'type': type.toString().split('.').last,
          // Use server time surrogate; UI falls back gracefully
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        },
        'lastActivity': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        // Keep a global counter for backward compatibility
        'unreadCount': FieldValue.increment(1),
        // Per-user unread counter: increment for receiver only
        'unreadBy.$receiverId': FieldValue.increment(1),
        'isActive': true,
      });

      await batch.commit();
      return messageRef.id;
    } catch (e, stackTrace) {
      debugPrint('Send message error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to send message');
    }
  }

  // Upload chat image to Cloudinary - returns secure_url
  Future<String> uploadChatImage({
    required String conversationId,
    required Uint8List? bytes,
  }) async {
    try {
      if (bytes == null) {
        throw Exception('No image data provided');
      }
      final filename = 'chat_${conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _cloudinary.uploadImageBytes(bytes, filename: filename);
      return url;
    } catch (e, stackTrace) {
      debugPrint('Upload chat image error (Cloudinary): $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to upload image to Cloudinary');
    }
  }

  // One-shot fetch of latest messages for a conversation
  Future<List<Message>> fetchLatestMessages(String conversationId, {int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _messagesCollection
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false)
          .limit(limit)
          .get();

      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] != null) {
          if (data['timestamp'] is Timestamp) {
            data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
          }
        } else {
          data['timestamp'] = DateTime.now().toIso8601String();
        }
        return Message.fromJson(data);
      }).toList();

      return messages;
    } catch (e, stackTrace) {
      debugPrint('Fetch latest messages error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return [];
    }
  }

  // Fallback: fetch messages without orderBy (avoids composite index), sort client-side
  Future<List<Message>> fetchMessagesNoOrder(String conversationId, {int limit = 50}) async {
    try {
      final QuerySnapshot snapshot = await _messagesCollection
          .where('conversationId', isEqualTo: conversationId)
          .limit(limit)
          .get();

      final messages = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] != null) {
          if (data['timestamp'] is Timestamp) {
            data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
          }
        } else {
          data['timestamp'] = DateTime.now().toIso8601String();
        }
        return Message.fromJson(data);
      }).toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e, stackTrace) {
      debugPrint('Fetch messages (no order) error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return [];
    }
  }
  // Get messages for a conversation
  Stream<List<Message>> getMessages(String conversationId, {int limit = 50}) {
    return _messagesCollection
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Handle server timestamp conversion
            if (data['timestamp'] != null) {
              if (data['timestamp'] is Timestamp) {
                data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
              }
            } else {
              data['timestamp'] = DateTime.now().toIso8601String();
            }
            return Message.fromJson(data);
          })
          .toList();
      return messages;
    });
  }

  // Get conversations for a user
  Stream<List<Conversation>> getUserConversations(String userId) {
    return _conversationsCollection
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final conversations = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            // Handle server timestamp conversion
            if (data['lastActivity'] != null && data['lastActivity'] is Timestamp) {
              data['lastActivity'] = (data['lastActivity'] as Timestamp).toDate().toIso8601String();
            } else if (data['lastActivity'] == null) {
              data['lastActivity'] = DateTime.now().toIso8601String();
            }

            // Build Message model for lastMessage if available
            Message? lastMsg;
            final lm = data['lastMessage'];
            if (lm is Map<String, dynamic>) {
              final lmMap = Map<String, dynamic>.from(lm);
              final ts = lmMap['timestamp'];
              if (ts is Timestamp) {
                lmMap['timestamp'] = ts.toDate().toIso8601String();
              } else if (ts is! String) {
                lmMap['timestamp'] = DateTime.now().toIso8601String();
              }
              lastMsg = Message.fromJson(lmMap);
            }
            
            // Coerce conversation type/name/image
            final String name = (data['name'] as String?) ?? '';
            final String? imageUrl = data['imageUrl'] as String?;
            final String typeRaw = (data['type'] as String?) ?? 'direct';
            final ConversationType type = typeRaw == 'group'
                ? ConversationType.group
                : ConversationType.direct;

            // Create a conversation model with participant names
            return Conversation(
              id: data['id'] ?? '',
              participantIds: List<String>.from(data['participantIds'] ?? []),
              name: name,
              imageUrl: imageUrl,
              type: type,
              lastActivity: data['lastActivity'] is String 
                ? DateTime.parse(data['lastActivity'])
                : DateTime.now(),
              // Use per-user unread if available; fallback to global int
              unreadCount: (() {
                final u = data['unreadBy'];
                if (u is Map<String, dynamic>) {
                  final v = u[userId];
                  if (v is int) return v;
                }
                return data['unreadCount'] is int ? data['unreadCount'] as int : 0;
              })(),
              participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
              participantAvatars: Map<String, String?>.from(data['participantAvatars'] ?? {}),
              lastMessage: lastMsg,
            );
          })
          .toList();
      
      // Sort by last activity manually
      conversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
      
      return conversations;
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Get unread messages
      final QuerySnapshot unreadMessages = await _messagesCollection
          .where('conversationId', isEqualTo: conversationId)
          .where('isRead', isEqualTo: false)
          .get();

      // Mark messages as read
      for (var doc in unreadMessages.docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Only mark as read if this user is the receiver (for 1:1 chats)
        if (data['receiverId'] == userId) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      // Set this user's unread counter to 0 (per-user)
      final DocumentReference conversationRef = _conversationsCollection.doc(conversationId);
      batch.update(conversationRef, {
        'unreadBy.$userId': 0,
      });

      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('Mark messages as read error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to mark messages as read');
    }
  }

  // Delete message
  Future<void> deleteMessage(String messageId, String conversationId) async {
    try {
      await _messagesCollection.doc(messageId).delete();

      // Update last message if this was the last message
      final QuerySnapshot lastMessageQuery = await _messagesCollection
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (lastMessageQuery.docs.isNotEmpty) {
        final Map<String, dynamic> data = lastMessageQuery.docs.first.data() as Map<String, dynamic>;
        // Normalize timestamp to string for Message model
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        } else if (data['timestamp'] == null) {
          data['timestamp'] = DateTime.now().toIso8601String();
        }
        final Message lastMessage = Message.fromJson(data);

        await _conversationsCollection.doc(conversationId).update({
          'lastMessage': lastMessage.toJson(),
          'lastActivity': Timestamp.fromDate(lastMessage.timestamp),
          'lastMessageSenderId': lastMessage.senderId,
        });
      } else {
        // No messages left, set empty values
        await _conversationsCollection.doc(conversationId).update({
          'lastMessage': null,
          'lastActivity': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Delete message error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to delete message');
    }
  }

  // Delete conversation (hard delete: messages + conversation doc)
  Future<void> deleteConversation(String conversationId, String userId) async {
    try {
      // Fetch messages to delete
      final QuerySnapshot messages = await _messagesCollection
          .where('conversationId', isEqualTo: conversationId)
          .get();

      final WriteBatch batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      // Remove the conversation document itself
      batch.delete(_conversationsCollection.doc(conversationId));
      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('Delete conversation error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to delete conversation');
    }
  }

  // Search conversations
  Future<List<Conversation>> searchConversations(String userId, String query) async {
    try {
      // Get user's conversations using correct field name
      final QuerySnapshot conversationsQuery = await _conversationsCollection
          .where('participantIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final List<Conversation> conversations = conversationsQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Normalize lastActivity
        if (data['lastActivity'] is Timestamp) {
          data['lastActivity'] = (data['lastActivity'] as Timestamp).toDate().toIso8601String();
        } else if (data['lastActivity'] == null) {
          data['lastActivity'] = DateTime.now().toIso8601String();
        }

        // Normalize lastMessage timestamp if map
        Message? lastMsg;
        final lm = data['lastMessage'];
        if (lm is Map<String, dynamic>) {
          final lmMap = Map<String, dynamic>.from(lm);
          final ts = lmMap['timestamp'];
          if (ts is Timestamp) {
            lmMap['timestamp'] = ts.toDate().toIso8601String();
          } else if (ts is! String) {
            lmMap['timestamp'] = DateTime.now().toIso8601String();
          }
          lastMsg = Message.fromJson(lmMap);
        }

        return Conversation(
          id: data['id'] ?? doc.id,
          participantIds: List<String>.from(data['participantIds'] ?? []),
          name: (data['name'] as String?) ?? '',
          imageUrl: data['imageUrl'] as String?,
          type: ((data['type'] as String?) ?? 'direct') == 'group'
              ? ConversationType.group
              : ConversationType.direct,
          lastMessage: lastMsg,
          lastActivity: DateTime.parse(data['lastActivity'] as String),
          unreadCount: data['unreadCount'] is int ? data['unreadCount'] as int : 0,
          participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
          participantAvatars: Map<String, String?>.from(data['participantAvatars'] ?? {}),
        );
      }).toList();

      // Filter by query against name or last message content
      final q = query.toLowerCase();
      return conversations.where((c) {
        final name = c.name.toLowerCase();
        final last = c.lastMessage?.content.toLowerCase() ?? '';
        return name.contains(q) || last.contains(q);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Search conversations error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to search conversations');
    }
  }

  // Get unread messages count for user
  Future<int> getUnreadMessagesCount(String userId) async {
    try {
      final QuerySnapshot conversationsQuery = await _conversationsCollection
          .where('participantIds', arrayContains: userId)
          .where('isActive', isEqualTo: true)
          .get();

      int totalUnreadCount = 0;
      for (var doc in conversationsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final u = data['unreadBy'];
        if (u is Map<String, dynamic>) {
          final v = u[userId];
          if (v is int) {
            totalUnreadCount += v;
            continue;
          }
        }
        // Fallback to global int if per-user map is absent
        final int unread = (data['unreadCount'] is int) ? data['unreadCount'] as int : 0;
        totalUnreadCount += unread;
      }

      return totalUnreadCount;
    } catch (e, stackTrace) {
      debugPrint('Get unread count error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return 0;
    }
  }

  // Get online status (this would typically be implemented with presence system)
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return data['isOnline'] ?? false;
      }
      return false;
    });
  }

  // Update user online status
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      debugPrint('Update online status error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to update online status');
    }
  }

  // Get conversation info with user details
  Future<Map<String, dynamic>> getConversationInfo(String conversationId, String currentUserId) async {
    try {
      final DocumentSnapshot conversationDoc = await _conversationsCollection.doc(conversationId).get();
      
      if (!conversationDoc.exists) {
        throw Exception('Conversation not found');
      }

      final Conversation conversation = Conversation.fromJson(
        conversationDoc.data() as Map<String, dynamic>
      );

      // Get other participant's info
      final String otherUserId = conversation.participantIds
          .firstWhere((id) => id != currentUserId);

      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get();

      Map<String, dynamic> otherUserInfo = {};
      if (userDoc.exists) {
        otherUserInfo = userDoc.data() as Map<String, dynamic>;
      }

      return {
        'conversation': conversation,
        'otherUser': otherUserInfo,
      };
    } catch (e, stackTrace) {
      debugPrint('Get conversation info error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to get conversation info');
    }
  }
}
