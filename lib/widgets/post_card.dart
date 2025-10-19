import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/cloudinary_service.dart';

import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../providers/posts_provider.dart';
import '../screens/post_detail_screen.dart';
import '../screens/user_profile_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/edit_post_dialog.dart';
import '../widgets/post_video.dart';

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  static const String dislikeEmoji = '\u{1F44E}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final borderColor = theme.dividerColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (post.content.isNotEmpty) _buildCaption(context),
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: PostVideo(url: post.videoUrl!, maxHeight: 320),
            ),
          if ((post.imageUrls ?? []).isNotEmpty) _PostImages(imageUrls: post.imageUrls!),
          _buildActions(context),
          if (post.reactionCounts.isNotEmpty) _buildReactionChips(),
          _buildTimestamp(context),
          _buildQuickComment(context),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: post.userId)));
            },
            child: UserAvatar(
              imageUrl: post.userProfileImageUrl,
              displayName: post.userDisplayName,
              radius: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: post.userId)));
                  },
                  child: Text(post.username, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Builder(builder: (ctx) {
            final currentUserId = Provider.of<AuthProvider>(ctx, listen: false).currentUser?.id;
            final isOwner = currentUserId != null && currentUserId == post.userId;
            return PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: Theme.of(ctx).colorScheme.onSurface),
              onSelected: (value) async {
                if (value == 'edit') {
                  final updated = await showDialog<bool>(
                    context: ctx,
                    builder: (_) => EditPostDialog(post: post),
                  );
                  if (updated == true && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Post updated')));
                  }
                } else if (value == 'delete') {
                  await _confirmDelete(ctx);
                }
              },
              itemBuilder: (_) {
                if (isOwner) {
                  return const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ];
                } else {
                  return const [
                    PopupMenuItem(value: 'hide', child: Text('Hide')),
                  ];
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCaption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(post.content, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.5)),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          
          IconButton(
            onPressed: () {
              final uid = context.read<AuthProvider>().currentUser?.id;
              if (uid != null) context.read<PostsProvider>().likePost(post.id, uid);
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                post.isLiked ? Icons.favorite : Icons.favorite_border,
                color: post.isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface,
                size: 24,
                key: ValueKey(post.isLiked),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)));
            },
            icon: Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.onSurface, size: 22),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final uid = context.read<AuthProvider>().currentUser?.id;
              if (uid == null) return;
              final next = post.userReaction == dislikeEmoji ? null : dislikeEmoji;
              await context.read<PostsProvider>().setReaction(postId: post.id, userId: uid, emoji: next);
            },
            icon: Icon(
              post.userReaction == dislikeEmoji ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
              color: post.userReaction == dislikeEmoji ? Colors.amber : Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showReactionPicker(context),
            icon: Icon(Icons.emoji_emotions_outlined, color: Theme.of(context).colorScheme.onSurface, size: 22),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              final uid = context.read<AuthProvider>().currentUser?.id;
              if (uid != null) context.read<PostsProvider>().bookmarkPost(post.id, uid);
            },
            icon: Icon(post.isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: post.isBookmarked ? const Color(0xFF6C5CE7) : Theme.of(context).colorScheme.onSurface, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: post.reactionCounts.entries
            .where((e) => (e.value) > 0)
            .map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(16)),
                  child: Text('${e.key} ${e.value}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 12, color: theme.hintColor),
          const SizedBox(width: 4),
          Text(_formatTimestamp(post.createdAt).toUpperCase(), style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _buildQuickComment(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final borderColor = Theme.of(context).dividerColor;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor, width: 1)),
      child: Row(
        children: [
          UserAvatar(imageUrl: user?.profileImageUrl, displayName: user?.displayName ?? 'User', radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor ?? Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor, width: 1)),
                child: Text('Add a comment...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    const emojis = ['\u{2764}\u{FE0F}', '\u{1F44D}', '\u{1F44E}', '\u{1F602}', '\u{1F62E}', '\u{1F622}', '\u{1F525}'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((e) {
            final selected = post.userReaction == e;
            return GestureDetector(
              onTap: () async {
                final uid = Provider.of<AuthProvider>(ctx, listen: false).currentUser?.id;
                if (uid == null) return;
                final next = selected ? null : e;
                await Provider.of<PostsProvider>(ctx, listen: false).setReaction(postId: post.id, userId: uid, emoji: next);
                if (!ctx.mounted) return;
                if (Navigator.canPop(ctx)) Navigator.pop(ctx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: selected ? const Color(0xFF6C5CE7).withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final uid = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await Provider.of<PostsProvider>(context, listen: false).deletePost(post.id, uid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: post.content);
    bool saving = false;
    bool uploading = false;
    final imagePicker = ImagePicker();
    List<String> imageUrls = List<String>.from(post.imageUrls ?? const []);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: StatefulBuilder(
            builder: (ctx, setState) {
              final theme = Theme.of(ctx);
              final changed = controller.text != post.content || !_listsEqual(imageUrls, post.imageUrls ?? const []);
              final count = controller.text.length;

              Future<void> pickAndUploadImages() async {
                try {
                  setState(() => uploading = true);
                  final cloudinary = CloudinaryService();
                  List<String> newUrls = [];
                  if (kIsWeb) {
                    final picked = await imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
                    for (final x in picked) {
                      final bytes = await x.readAsBytes();
                      final url = await cloudinary.uploadImageBytes(bytes, filename: 'edit_${DateTime.now().millisecondsSinceEpoch}.jpg');
                      newUrls.add(url);
                    }
                  } else if (Platform.isWindows || Platform.isLinux) {
                    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image);
                    if (res != null) {
                      for (final f in res.files) {
                        if (f.path == null) continue;
                        final url = await cloudinary.uploadImageFile(File(f.path!));
                        newUrls.add(url);
                      }
                    }
                  } else {
                    final picked = await imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
                    for (final x in picked) {
                      final url = await cloudinary.uploadImageFile(File(x.path));
                      newUrls.add(url);
                    }
                  }
                  if (newUrls.isNotEmpty) {
                    setState(() => imageUrls.addAll(newUrls));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Add images failed: $e')));
                  }
                } finally {
                  if (ctx.mounted) setState(() => uploading = false);
                }
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Edit Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Update your post...',
                        border: UnderlineInputBorder(),
                        counterText: '',
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    if (imageUrls.isNotEmpty) _EditImagesGrid(imageUrls: imageUrls, onRemove: (i) => setState(() => imageUrls.removeAt(i))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: uploading ? null : pickAndUploadImages,
                          icon: uploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.add_photo_alternate),
                          label: const Text('Add images'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '$count/500',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: saving || !changed
                              ? null
                              : () async {
                                  final newText = controller.text; // allow empty
                                  setState(() => saving = true);
                                  try {
                                    await Provider.of<PostsProvider>(ctx, listen: false).editPost(
                                      postId: post.id,
                                      newContent: newText,
                                      newImageUrls: imageUrls,
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  } finally {
                                    if (ctx.mounted) setState(() => saving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          child: saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post updated')));
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _EditImagesGrid extends StatelessWidget {
  final List<String> imageUrls;
  final void Function(int index) onRemove;
  const _EditImagesGrid({required this.imageUrls, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: imageUrls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (ctx, i) {
        final url = imageUrls[i];
        return Stack(children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: () => onRemove(i),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          )
        ]);
      },
    );
  }
}

class _PostImages extends StatefulWidget {
  final List<String> imageUrls;
  const _PostImages({required this.imageUrls});
  @override
  State<_PostImages> createState() => _PostImagesState();
}

class _PostImagesState extends State<_PostImages> {
  final PageController _controller = PageController();
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 360,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            urls.length == 1
                ? Image.network(urls.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                : PageView.builder(
                    controller: _controller,
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => Image.network(urls[i], fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback()),
                  ),
            if (urls.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_index + 1}/${urls.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(color: const Color(0xFF222222), child: const Center(child: Icon(Icons.image, size: 48, color: Colors.white24)));
}
