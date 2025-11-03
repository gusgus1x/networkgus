import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'chat_screen.dart';
import '../widgets/user_avatar.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to see notifications.')),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final id = docs[index].id;
              final type = (data['type'] ?? '') as String; // follow | like | chat
              final senderName = data['senderName'] as String?;
              final senderId = data['userId'] as String?; // follower id for follow
              final postId = data['postId'] as String?;
              final conversationId = data['conversationId'] as String?;
              final conversationName = data['conversationName'] as String? ?? 'Chat';
              final createdAt = _parseDateTime(data['createdAt']);
              final read = (data['read'] ?? false) as bool;

              return _NotificationItem(
                type: type,
                senderName: senderName,
                senderId: senderId,
                title: _titleFor(type, senderName),
                subtitle: _subtitleFor(type),
                whenText: createdAt != null ? _timeAgo(createdAt) : null,
                read: read,
                onTap: () async {
                  // mark as read
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('notifications')
                      .doc(id)
                      .set({'read': true}, SetOptions(merge: true));

                  if (type == 'follow') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: senderId)),
                    );
                  } else if (type == 'like' && postId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
                    );
                  } else if (type == 'chat' && conversationId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(conversationId: conversationId, conversationName: conversationName),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  static String _titleFor(String type, String? senderName) {
    switch (type) {
      case 'follow':
        return senderName != null ? '$senderName started following you' : 'New follower';
      case 'like':
        return senderName != null ? '$senderName liked your post' : 'New like on your post';
      case 'chat':
        return 'New message';
      default:
        return 'Notification';
    }
  }

  static String _subtitleFor(String type) {
    switch (type) {
      case 'follow':
        return 'Follow';
      case 'like':
        return 'Like';
      case 'chat':
        return 'Chat';
      default:
        return '';
    }
  }

  static Widget _iconFor(String type, bool read, BuildContext context) {
    final color = _typeColor(context, type, read: read);
    final icon = () {
      switch (type) {
        case 'follow':
          return Icons.person_add_alt;
        case 'like':
          return Icons.favorite;
        case 'chat':
          return Icons.chat_bubble_outline;
        default:
          return Icons.notifications;
      }
    }();

    return _GradientIconBadge(icon: icon, color: color);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    if (value is int) {
      // milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  static String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

// --- Pretty notification list item ------------------------------------------------------------

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    Key? key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.read,
    this.senderName,
    this.senderId,
    this.whenText,
    this.onTap,
  }) : super(key: key);

  final String type;
  final String title;
  final String subtitle;
  final String? senderName;
  final String? senderId;
  final String? whenText;
  final bool read;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = read
        ? Theme.of(context).colorScheme.surface
        : Theme.of(context).colorScheme.primary.withOpacity(0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeading(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitle(context),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TypeChip(label: subtitle, type: type),
                        if (whenText != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            whenText!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!read)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge;
    if (senderName == null || senderName!.isEmpty) {
      return Text(title, style: base?.copyWith(fontWeight: read ? FontWeight.w500 : FontWeight.w700));
    }

    // Bold sender name for better readability
    if (title.toLowerCase().startsWith(senderName!.toLowerCase())) {
      final rest = title.substring(senderName!.length).trimLeft();
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: senderName!, style: base?.copyWith(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' '),
            TextSpan(text: rest, style: base),
          ],
        ),
      );
    }

    return Text(title, style: base?.copyWith(fontWeight: read ? FontWeight.w500 : FontWeight.w700));
  }

  Widget _buildLeading(BuildContext context) {
    // Show actor's avatar for follow/like when we have a senderId; otherwise fallback icon
    final canShowAvatar = (type == 'follow' || type == 'like') && (senderId != null && senderId!.isNotEmpty);
    if (!canShowAvatar) {
      return NotificationScreen._iconFor(type, read, context);
    }
    return _ActorAvatar(
      userId: senderId!,
      displayName: senderName ?? 'User',
      fallback: NotificationScreen._iconFor(type, read, context),
    );
  }
}

class _GradientIconBadge extends StatelessWidget {
  const _GradientIconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.type});
  final String label;
  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(context, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
      ),
    );
  }
}

Color _typeColor(BuildContext context, String type, {bool read = true}) {
  final scheme = Theme.of(context).colorScheme;
  switch (type) {
    case 'like':
      return Colors.orange;
    case 'follow':
      return Colors.blueGrey;
    case 'chat':
      return scheme.primary;
    default:
      return read ? (Theme.of(context).iconTheme.color ?? scheme.primary) : scheme.primary;
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({
    required this.userId,
    required this.displayName,
    required this.fallback,
  });

  final String userId;
  final String displayName;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snap) {
        if (snap.hasData && snap.data?.data() != null) {
          final data = snap.data!.data()!;
          final url = (data['profileImageUrl'] as String?);
          return UserAvatar(
            imageUrl: url,
            displayName: displayName,
            radius: 22,
            useThemePrimary: false,
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          // Show initials while loading; avoids layout shift
          return UserAvatar(
            imageUrl: null,
            displayName: displayName,
            radius: 22,
            useThemePrimary: false,
          );
        }
        // Fallback to existing icon badge if user doc missing
        return fallback;
      },
    );
  }
}
