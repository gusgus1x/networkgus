import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'user_avatar.dart';
import 'fb_create_post_dialog.dart';

class PostComposer extends StatelessWidget {
  final String? groupId;
  const PostComposer({super.key, this.groupId});

  void _openDialog(BuildContext context, {ComposerAction initial = ComposerAction.none}) {
    showDialog(
      context: context,
      builder: (ctx) => FBCreatePostDialog(groupId: groupId, initialAction: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final theme = Theme.of(context);

    final displayName = user?.displayName ?? 'there';
    final avatarUrl = user?.profileImageUrl;

    final borderColor = theme.dividerColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: avatarUrl, displayName: displayName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor, width: 0.6),
                    ),
                    child: Text(
                      "What's on your mind, ${displayName.split(' ').first}?",
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Action buttons removed from UI for now (kept in code earlier). If you want them back,
          // re-introduce a Wrap row here with _ActionButton children.
        ],
      ),
    );
  }
}

// kept for future reuse; analyzer would otherwise warn it's unused
// ignore: unused_element
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade300),
            ),
          ],
        ),
      ),
    );
  }
}
