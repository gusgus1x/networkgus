import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/posts_provider.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../widgets/user_avatar.dart';
import '../providers/user_provider.dart';
import '../widgets/post_video.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const String dislikeEmoji = '\u{1F44E}';

  String? _replyToCommentId;
  String? _replyToDisplay;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().startListeningToComments(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    context.read<PostsProvider>().stopListeningToComments(widget.postId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Post', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer2<PostsProvider, AuthProvider>(
        builder: (context, postsProvider, authProvider, _) {
          final post = postsProvider.getPostById(widget.postId);
          final comments = postsProvider.getCommentsForPost(widget.postId);
          final isCommentsLoading = postsProvider.isCommentsLoading(widget.postId);

          if (post == null) {
            return const Center(
              child: Text('Post not found', style: TextStyle(color: Colors.white)),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPostHeader(post),
                      _buildPostContent(post),
                      _buildPostActions(post),
                      const Divider(thickness: 8),

                      if (_replyToCommentId != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.reply, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Text('Replying to ${_replyToDisplay ?? ''}', style: const TextStyle(color: Colors.white70)),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _replyToCommentId = null;
                                        _replyToDisplay = null;
                                      }),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),

                      if (isCommentsLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else if (comments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (_, i) => _buildCommentTile(comments[i]),
                        ),
                    ],
                  ),
                ),
              ),
              _buildCommentInput(authProvider.currentUser),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostHeader(Post post) {
    return ListTile(
      leading: _PostAuthorAvatarDetail(
        userId: post.userId,
        fallbackImageUrl: post.userProfileImageUrl,
        displayName: post.userDisplayName,
        radius: 25,
      ),
      title: Row(
        children: [
          Text(post.userDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          if (post.isUserVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified, color: Colors.blue.shade600, size: 16),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('@${post.username}', style: const TextStyle(color: Colors.white70)),
          Text(_formatTimestamp(post.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPostContent(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(post.content, style: const TextStyle(fontSize: 18, height: 1.4, color: Colors.white)),
          ),
        if (post.videoUrl != null && post.videoUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: PostVideo(url: post.videoUrl!, maxHeight: 360),
          ),
        if ((post.imageUrls ?? []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: PageView.builder(
                  itemCount: post.imageUrls!.length,
                  itemBuilder: (context, index) {
                    final url = _transformCloudinary(
                      post.imageUrls![index],
                      width: MediaQuery.of(context).size.width.toInt(),
                      height: 300,
                    );
                    return Container(
                      color: const Color(0xFF1E1E1E),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade800,
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 48)),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _transformCloudinary(String url, {int? width, int? height}) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) return url;
    final marker = '/upload/';
    final i = url.indexOf(marker);
    if (i == -1) return url;
    final prefix = url.substring(0, i + marker.length);
    final suffix = url.substring(i + marker.length);
    final parts = <String>['f_auto', 'q_auto:good', 'c_fill', 'g_auto'];
    if (width != null) parts.add('w_$width');
    if (height != null) parts.add('h_$height');
    final trans = parts.join(',');
    return '$prefix$trans/$suffix';
  }

  Widget _buildPostActions(Post post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final uid = context.read<AuthProvider>().currentUser?.id;
              if (uid != null) context.read<PostsProvider>().likePost(post.id, uid);
            },
            icon: Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: post.isLiked ? Colors.red : Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              final uid = context.read<AuthProvider>().currentUser?.id;
              if (uid == null) return;
              final next = post.userReaction == dislikeEmoji ? null : dislikeEmoji;
              await context.read<PostsProvider>().setReaction(postId: post.id, userId: uid, emoji: next);
            },
            icon: Icon(post.userReaction == dislikeEmoji ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined, color: post.userReaction == dislikeEmoji ? Colors.amber : Colors.white, size: 22),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showReactionPicker(post),
            icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white, size: 22),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              final uid = context.read<AuthProvider>().currentUser?.id;
              if (uid != null) context.read<PostsProvider>().bookmarkPost(post.id, uid);
            },
            icon: Icon(post.isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: post.isBookmarked ? const Color(0xFF6C5CE7) : Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(Post post) {
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
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF6C5CE7).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentAuthorAvatar(
            userId: comment.userId,
            fallbackImageUrl: comment.userProfileImageUrl,
            displayName: comment.userDisplayName,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2C)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.userDisplayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (comment.isUserVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 14),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '@${comment.username}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTimestamp(comment.createdAt),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.content,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(user) {
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        // Removed top border line for a cleaner look
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: user.profileImageUrl,
            displayName: user.displayName,
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF333333)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.send,
              color: Colors.blue,
            ),
            onPressed: _postComment,
          ),
        ],
      ),
    );
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    try {
      await context.read<PostsProvider>().addComment(
        postId: widget.postId,
        userId: user.id,
        content: content,
        userDisplayName: user.displayName,
        username: user.username,
        userProfileImageUrl: user.profileImageUrl,
        isUserVerified: user.isVerified,
      );

      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted!'), duration: Duration(seconds: 1), backgroundColor: Colors.green),
        );
      }
    } catch (_) {}
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _PostAuthorAvatarDetail extends StatefulWidget {
  final String userId;
  final String? fallbackImageUrl;
  final String displayName;
  final double radius;

  const _PostAuthorAvatarDetail({
    required this.userId,
    required this.displayName,
    this.fallbackImageUrl,
    this.radius = 25,
  });

  @override
  State<_PostAuthorAvatarDetail> createState() => _PostAuthorAvatarDetailState();
}

class _PostAuthorAvatarDetailState extends State<_PostAuthorAvatarDetail> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.fallbackImageUrl;
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      _loadUserImage();
    }
  }

  Future<void> _loadUserImage() async {
    try {
      final user = await context.read<UserProvider>().getUserById(widget.userId);
      if (!mounted) return;
      setState(() {
        _imageUrl = user?.profileImageUrl;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: _imageUrl,
      displayName: widget.displayName,
      radius: widget.radius,
    );
  }
}

class _CommentAuthorAvatar extends StatefulWidget {
  final String userId;
  final String? fallbackImageUrl;
  final String displayName;
  final double radius;

  const _CommentAuthorAvatar({
    required this.userId,
    required this.displayName,
    this.fallbackImageUrl,
    this.radius = 16,
  });

  @override
  State<_CommentAuthorAvatar> createState() => _CommentAuthorAvatarState();
}

class _CommentAuthorAvatarState extends State<_CommentAuthorAvatar> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.fallbackImageUrl;
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      _loadUserImage();
    }
  }

  Future<void> _loadUserImage() async {
    try {
      final user = await context.read<UserProvider>().getUserById(widget.userId);
      if (!mounted) return;
      setState(() {
        _imageUrl = user?.profileImageUrl;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      imageUrl: _imageUrl,
      displayName: widget.displayName,
      radius: widget.radius,
    );
  }
}
