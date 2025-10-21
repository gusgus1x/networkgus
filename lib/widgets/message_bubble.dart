import 'package:flutter/material.dart';
import '../models/message_model.dart';
import 'user_avatar.dart';
import 'post_video.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showAvatar;
  // When true, renders sender name header above bubble (useful for groups)
  final bool showSenderName;
  final String senderName;
  final String? senderImageUrl;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.showSenderName = false,
    required this.senderName,
    this.senderImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final otherBubbleColor = theme.cardColor;
    final hint = theme.hintColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            UserAvatar(
              imageUrl: senderImageUrl,
              displayName: senderName,
              radius: 16,
            )
          else if (!isMe)
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? null : otherBubbleColor,
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF4F8EF7), Color(0xFF3B6FE0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show sender name for group chats when avatar boundary is shown
                  if (!isMe && showAvatar && showSenderName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                  child: Text(senderName, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  _buildMessageContent(context),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_formatTime(message.timestamp), style: TextStyle(color: isMe ? Colors.white70 : hint, fontSize: 11)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          color: message.isRead ? theme.colorScheme.onPrimary.withValues(alpha: 0.8) : Colors.white70,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isMe && showAvatar)
            UserAvatar(
              imageUrl: senderImageUrl,
              displayName: senderName,
              radius: 16,
            )
          else if (isMe)
            const SizedBox(width: 0),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = Theme.of(context);
    final otherTextColor = theme.textTheme.bodyLarge?.color ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87);
    final hint = theme.hintColor;
    switch (message.type) {
      case MessageType.text:
        return Text(message.content, style: TextStyle(color: isMe ? Colors.white : otherTextColor, fontSize: 16));
      case MessageType.image:
        final imageUrl = message.metadata != null ? message.metadata!['imageUrl'] as String? : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      child: const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
                    ),
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message.content, style: TextStyle(color: isMe ? Colors.white : otherTextColor, fontSize: 16)),
            ],
          ],
        );
      case MessageType.video:
        final videoUrl = message.metadata != null ? message.metadata!['videoUrl'] as String? : null;
        if (videoUrl == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PostVideo(url: videoUrl, maxHeight: 220),
            ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(message.content, style: TextStyle(color: isMe ? Colors.white : otherTextColor, fontSize: 16)),
            ],
          ],
        );
      case MessageType.file:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.2)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.attach_file,
                color: isMe ? Colors.white : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(message.content, style: TextStyle(color: isMe ? Colors.white : otherTextColor, fontSize: 16)),
              ),
            ],
          ),
        );
      case MessageType.emoji:
        return Text(
          message.content,
          style: const TextStyle(fontSize: 32),
        );
      case MessageType.system:
        return Text(message.content, style: TextStyle(color: hint, fontSize: 14, fontStyle: FontStyle.italic));
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}';
    } else {
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }
}
