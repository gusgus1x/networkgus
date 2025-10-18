import 'message_model.dart';

class Conversation {
  final String id;
  final List<String> participantIds;
  final String name; // Group name or empty for direct messages
  final String? imageUrl;
  final ConversationType type;
  final Message? lastMessage;
  final DateTime lastActivity;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final Map<String, String> participantNames; // userId -> displayName
  final Map<String, String?> participantAvatars; // userId -> imageUrl

  Conversation({
    required this.id,
    required this.participantIds,
    this.name = '',
    this.imageUrl,
    this.type = ConversationType.direct,
    this.lastMessage,
    required this.lastActivity,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.participantNames = const {},
    this.participantAvatars = const {},
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      participantIds: List<String>.from(json['participantIds']),
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'],
      type: ConversationType.values.firstWhere(
        (e) => e.toString() == 'ConversationType.${json['type']}',
        orElse: () => ConversationType.direct,
      ),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      lastActivity: DateTime.parse(json['lastActivity']),
      unreadCount: json['unreadCount'] ?? 0,
      isPinned: json['isPinned'] ?? false,
      isMuted: json['isMuted'] ?? false,
      participantNames: Map<String, String>.from(json['participantNames'] ?? {}),
      participantAvatars: Map<String, String?>.from(json['participantAvatars'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantIds': participantIds,
      'name': name,
      'imageUrl': imageUrl,
      'type': type.toString().split('.').last,
      'lastMessage': lastMessage?.toJson(),
      'lastActivity': lastActivity.toIso8601String(),
      'unreadCount': unreadCount,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'participantNames': participantNames,
      'participantAvatars': participantAvatars,
    };
  }

  String getDisplayName(String currentUserId) {
    if (type == ConversationType.group) {
      return name.isNotEmpty ? name : 'Group Chat';
    }
    
    // For direct messages, show the other participant's name
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    
    // Return participant name if available, otherwise try to create a fallback
    final displayName = participantNames[otherParticipantId];
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    
    // Fallback: Use user ID as display name (better than "Unknown User")
    return 'User ${otherParticipantId.substring(0, 8)}...';
  }

  String? getTargetUserId(String currentUserId) {
    if (type == ConversationType.group) {
      return null; // No single target for group chats
    }
    
    // For direct messages, return the other participant's ID
    try {
      return participantIds.firstWhere((id) => id != currentUserId);
    } catch (e) {
      return null;
    }
  }

  String? getDisplayImage(String currentUserId) {
    if (type == ConversationType.group) {
      return imageUrl;
    }
    
    // For direct messages, show the other participant's avatar
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    
    return participantAvatars[otherParticipantId];
  }

  Conversation copyWith({
    String? id,
    List<String>? participantIds,
    String? name,
    String? imageUrl,
    ConversationType? type,
    Message? lastMessage,
    DateTime? lastActivity,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    Map<String, String>? participantNames,
    Map<String, String?>? participantAvatars,
  }) {
    return Conversation(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      participantNames: participantNames ?? this.participantNames,
      participantAvatars: participantAvatars ?? this.participantAvatars,
    );
  }
}

enum ConversationType {
  direct,
  group,
}