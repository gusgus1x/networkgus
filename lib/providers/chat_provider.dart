import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  final Map<String, List<Message>> _messages = {};
  final Map<String, StreamSubscription<List<Message>>?> _messageSubscriptions = {};
  List<Conversation> _conversations = [];
  StreamSubscription<List<Conversation>>? _conversationsSubscription;
  bool _isLoading = false;
  String? _activeConversationId;
  String? _currentUserId;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoading => _isLoading;
  String? get activeConversationId => _activeConversationId;

  // Start listening to user conversations
  void startListeningToConversations(String userId) {
    print('ChatProvider: Starting conversations stream for user: $userId');
    
    _isLoading = true;
    _currentUserId = userId;
    notifyListeners();
    
    // Cancel existing subscription
    _conversationsSubscription?.cancel();
    
    try {
      _conversationsSubscription = _chatService.getUserConversations(userId).listen(
        (conversations) {
          print('ChatProvider: Received ${conversations.length} conversations');
          _conversations = conversations;
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          print('ChatProvider: Error in conversations stream: $error');
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      print('ChatProvider: Error starting conversations stream: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Stop listening to conversations
  void stopListeningToConversations() {
    print('ChatProvider: Stopping conversations stream');
    _conversationsSubscription?.cancel();
    _conversationsSubscription = null;
  }

  // Start listening to messages for a conversation
  void startListeningToMessages(String conversationId) {
    print('ChatProvider: Starting messages stream for conversation: $conversationId');
    
    // Cancel existing subscription for this conversation
    _messageSubscriptions[conversationId]?.cancel();
    
    try {
      _messageSubscriptions[conversationId] = _chatService.getMessages(conversationId).listen(
        (messages) {
          print('ChatProvider: Received ${messages.length} messages for conversation: $conversationId');
          
          // Get current messages and separate temporary ones (those with timestamp-based IDs)
          final currentMessages = _messages[conversationId] ?? [];
          final tempMessages = currentMessages.where((msg) => 
            msg.id.length > 10 && int.tryParse(msg.id) != null
          ).toList();
          
          // Combine Firebase messages with temporary messages
          final allMessages = [...messages.reversed.toList(), ...tempMessages];
          
          // Sort by timestamp to maintain order
          allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          
          _messages[conversationId] = allMessages;
          notifyListeners();
        },
        onError: (error) {
          print('ChatProvider: Error in messages stream for conversation $conversationId: $error');
          // Try one-shot fallback without orderBy to avoid index requirement
          _chatService.fetchMessagesNoOrder(conversationId).then((fallback) {
            if (fallback.isNotEmpty) {
              _messages[conversationId] = fallback;
              notifyListeners();
            }
          });
        },
      );
    } catch (e) {
      print('ChatProvider: Error starting messages stream for conversation $conversationId: $e');
    }
  }

  // Stop listening to messages for a conversation
  void stopListeningToMessages(String conversationId) {
    print('ChatProvider: Stopping messages stream for conversation: $conversationId');
    _messageSubscriptions[conversationId]?.cancel();
    _messageSubscriptions.remove(conversationId);
  }

  // Get messages for a conversation
  List<Message> getMessages(String conversationId) {
    return _messages[conversationId] ?? [];
  }

  // Preload messages once for instant UI when entering chat
  Future<void> preloadMessages(String conversationId, {int limit = 50}) async {
    try {
      // Avoid refetch if we already have messages cached
      if ((_messages[conversationId] ?? []).isNotEmpty) return;
      final messages = await _chatService.fetchLatestMessages(conversationId, limit: limit);
      // Ensure chronological order
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _messages[conversationId] = messages;
      notifyListeners();
    } catch (e) {
      // Non-fatal
    }
  }

  // Send message
  Future<void> sendMessage(
    String conversationId,
    String content,
    String senderId,
    String receiverId, {
    MessageType type = MessageType.text,
    String? imageUrl,
  }) async {
    // Only block empty text messages; allow non-text like images
    if (type == MessageType.text && content.trim().isEmpty) return;

    // Create a temporary message for immediate UI update
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: senderId,
      content: content.trim(),
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      metadata: imageUrl != null ? {'imageUrl': imageUrl} : null,
    );

    // Add to local messages immediately for instant UI update
    if (_messages[conversationId] == null) {
      _messages[conversationId] = [];
    }
    _messages[conversationId]!.add(tempMessage);
    notifyListeners();

    try {
      final messageId = await _chatService.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        content: content.trim(),
        type: type,
        imageUrl: imageUrl,
      );
      
      // Optimistically update conversations preview so Chat list updates immediately
      try {
        final idx = _conversations.indexWhere((c) => c.id == conversationId);
        if (idx != -1) {
          final preview = Message(
            id: messageId,
            conversationId: conversationId,
            senderId: senderId,
            content: content.trim(),
            type: type,
            timestamp: DateTime.now(),
            isRead: false,
            metadata: imageUrl != null ? {'imageUrl': imageUrl} : null,
          );
          _conversations[idx] = _conversations[idx].copyWith(
            lastMessage: preview,
            lastActivity: DateTime.now(),
          );
          notifyListeners();
        }
      } catch (_) {}

      // Remove the temporary message after successful send
      // The real message will come through the Firebase stream
      _messages[conversationId]?.removeWhere((msg) => msg.id == tempMessage.id);
      notifyListeners();
      
    } catch (e) {
      // Remove the temporary message if sending failed
      _messages[conversationId]?.remove(tempMessage);
      notifyListeners();
      print('ChatProvider: Error sending message: $e');
      throw Exception('Failed to send message');
    }
  }

  // Create or get conversation
  Future<String> createOrGetConversation(String userId1, String userId2) async {
    try {
      return await _chatService.createOrGetConversation(
        userId1: userId1,
        userId2: userId2,
      );
    } catch (e) {
      print('ChatProvider: Error creating conversation: $e');
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
      final id = await _chatService.createGroupConversation(
        name: name,
        participantIds: participantIds,
        imageUrl: imageUrl,
      );
      return id;
    } catch (e) {
      print('ChatProvider: Error creating group: $e');
      throw Exception('Failed to create group');
    }
  }

  // Update group name
  Future<void> updateGroupName(String conversationId, String name) async {
    try {
      await _chatService.updateGroupName(conversationId, name);
      // Optimistically update local state
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(name: name);
        notifyListeners();
      }
    } catch (e) {
      print('ChatProvider: Error updating group name: $e');
      rethrow;
    }
  }

  // Update group image from raw bytes (uploads then sets URL)
  Future<String> updateGroupImage(String conversationId, Uint8List bytes) async {
    try {
      final url = await _chatService.uploadGroupImage(
        conversationId: conversationId,
        bytes: bytes,
      );
      await _chatService.setGroupImageUrl(conversationId, url);
      // Optimistically update local state
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1) {
        _conversations[idx] = _conversations[idx].copyWith(imageUrl: url);
        notifyListeners();
      }
      return url;
    } catch (e) {
      print('ChatProvider: Error updating group image: $e');
      throw Exception('Failed to update group image');
    }
  }

  // Mark messages as read
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _chatService.markMessagesAsRead(conversationId, userId);
    } catch (e) {
      print('ChatProvider: Error marking messages as read: $e');
    }
  }

  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
    notifyListeners();

    if (conversationId != null) {
      startListeningToMessages(conversationId);
    }
  }

  Conversation? getConversationById(String conversationId) {
    try {
      return _conversations.firstWhere((c) => c.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  int get totalUnreadCount {
    return _conversations.fold(0, (total, conversation) {
      final lastSender = conversation.lastMessage?.senderId;
      final count = (lastSender != null && lastSender == _currentUserId)
          ? 0
          : conversation.unreadCount;
      return total + count;
    });
  }

  // Delete entire conversation and its messages
  Future<void> deleteConversation(String conversationId, String currentUserId) async {
    try {
      // Optimistically remove from UI
      _conversations.removeWhere((c) => c.id == conversationId);
      _messages.remove(conversationId);
      stopListeningToMessages(conversationId);
      notifyListeners();

      await _chatService.deleteConversation(conversationId, currentUserId);
    } catch (e) {
      // On failure, simply refresh conversations stream next tick
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _conversationsSubscription?.cancel();
    for (var subscription in _messageSubscriptions.values) {
      subscription?.cancel();
    }
    _messageSubscriptions.clear();
    super.dispose();
  }
}
