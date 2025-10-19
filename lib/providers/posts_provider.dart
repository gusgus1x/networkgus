import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/post_service.dart';

class PostsProvider with ChangeNotifier {
  final PostService _postService = PostService();
  
  List<Post> _posts = [];
  List<Post> _groupPosts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  
  // Comments state
  Map<String, List<Comment>> _postComments = {};
  Map<String, bool> _commentsLoading = {};
  Map<String, StreamSubscription<List<Comment>>?> _commentSubscriptions = {};
  
  // Stream subscriptions
  StreamSubscription<List<Post>>? _postsSubscription;

  List<Post> get posts => _posts;
  List<Post> get groupPosts => _groupPosts;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  
  // Comment getters
  List<Comment> getCommentsForPost(String postId) => _postComments[postId] ?? [];
  bool isCommentsLoading(String postId) => _commentsLoading[postId] ?? false;

  // Start listening to posts stream for real-time updates
  void startListeningToPosts(String currentUserId) {
    print('PostsProvider: Starting posts stream for user: $currentUserId');
    
    _isLoading = true;
    notifyListeners();
    
    // Cancel existing subscription
    _postsSubscription?.cancel();
    
    try {
      _postsSubscription = _postService.getFeedPostsStream(currentUserId).listen(
        (posts) {
          print('PostsProvider: Received ${posts.length} posts from stream');
          
          // Only update if posts actually changed to prevent unnecessary UI updates
          if (!_arePostsEqual(_posts, posts)) {
            _posts = posts;
            _isLoading = false;
            _hasMore = posts.length >= 20; // Re-enable pagination if we have full limit
            notifyListeners();
          } else if (_isLoading) {
            // Just turn off loading if posts are the same
            _isLoading = false;
            notifyListeners();
          }
        },
        onError: (error) {
          print('PostsProvider: Error in posts stream: $error');
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      print('PostsProvider: Error starting posts stream: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to compare posts arrays - now handles different lengths properly
  bool _arePostsEqual(List<Post> oldPosts, List<Post> newPosts) {
    if (oldPosts.length != newPosts.length) {
      print('PostsProvider: Posts count changed: ${oldPosts.length} -> ${newPosts.length}');
      return false;
    }
    
    // Check if posts have same IDs in same order
    for (int i = 0; i < oldPosts.length; i++) {
      if (oldPosts[i].id != newPosts[i].id) {
        print('PostsProvider: Post order changed at index $i');
        return false;
      }
      
      // Check for important changes that should trigger UI update
      if (oldPosts[i].likesCount != newPosts[i].likesCount ||
          oldPosts[i].commentsCount != newPosts[i].commentsCount ||
          oldPosts[i].isLiked != newPosts[i].isLiked ||
          oldPosts[i].isBookmarked != newPosts[i].isBookmarked) {
        print('PostsProvider: Post ${oldPosts[i].id} stats changed');
        return false;
      }
    }
    
    return true;
  }

  // Stop listening to posts stream
  void stopListeningToPosts() {
    print('PostsProvider: Stopping posts stream');
    _postsSubscription?.cancel();
    _postsSubscription = null;
  }

  // Legacy method for backward compatibility - now prevents duplicates
  Future<void> fetchPosts({bool refresh = false, String? currentUserId}) async {
    print('PostsProvider: fetchPosts called with userId: $currentUserId'); // Debug
    
    if (refresh) {
      _posts.clear();
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      if (currentUserId != null) {
        print('PostsProvider: Fetching posts for user: $currentUserId'); // Debug
        // For now, try to get trending posts since feed might be empty
        List<Post> newPosts = [];
        
        try {
          // First try to get feed posts
          newPosts = await _postService.getFeedPosts(currentUserId, limit: 10);
        } catch (e) {
          print('Feed posts error: $e');
        }
        
        // If no feed posts, try trending posts
        if (newPosts.isEmpty) {
          try {
            newPosts = await _postService.getTrendingPosts(limit: 10);
          } catch (e) {
            print('Trending posts error: $e');
          }
        }
        
        print('PostsProvider: Got ${newPosts.length} posts'); // Debug
        
        if (newPosts.isEmpty) {
          _hasMore = false;
        } else {
          // Filter out duplicate posts by ID
          final existingIds = _posts.map((p) => p.id).toSet();
          final uniqueNewPosts = newPosts.where((post) => !existingIds.contains(post.id)).toList();
          
          if (uniqueNewPosts.isNotEmpty) {
            _posts.addAll(uniqueNewPosts);
            print('PostsProvider: Added ${uniqueNewPosts.length} unique posts');
          } else {
            print('PostsProvider: No new unique posts to add');
            _hasMore = false; // Stop trying if no new posts
          }
        }
      } else {
        print('PostsProvider: No user logged in'); // Debug
        // No user logged in, show empty
        _hasMore = false;
      }
    } catch (e) {
      print('Error fetching posts: $e');
      _hasMore = false;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchGroupPosts(String groupId, {String? currentUserId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _groupPosts = await _postService.getGroupPosts(groupId, currentUserId: currentUserId);
    } catch (e) {
      print('Error fetching group posts: $e');
      _groupPosts = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchGroupPostsByPostIds(List<String> postIds, {String? currentUserId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _groupPosts = await _postService.getPostsByIds(postIds, currentUserId: currentUserId);
    } catch (e) {
      print('Error fetching group posts by IDs: $e');
      _groupPosts = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createPost({
    required String content,
    required String userId,
    required String userDisplayName,
    required String username,
    String? userProfileImageUrl,
    bool isUserVerified = false,
    List<String>? imageUrls,
    List<File>? imageFiles,
    File? videoFile,
    String? videoUrl,
    String? groupId,
    bool refreshAfterCreate = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (groupId != null && groupId.isNotEmpty) {
        // Create post for group and then refresh that group's feed
        await _postService.createPostForGroup(
          userId: userId,
          content: content,
          userDisplayName: userDisplayName,
          username: username,
          userProfileImageUrl: userProfileImageUrl,
          isUserVerified: isUserVerified,
          imageUrls: imageUrls,
          imageFiles: imageFiles,
          videoFile: videoFile,
          videoUrl: videoUrl,
          groupId: groupId,
        );

        // Immediately refresh group posts so the new post appears without leaving the page
        await fetchGroupPosts(groupId);
      } else {
        await _postService.createPost(
          userId: userId,
          content: content,
          userDisplayName: userDisplayName,
          username: username,
          userProfileImageUrl: userProfileImageUrl,
          isUserVerified: isUserVerified,
          imageUrls: imageUrls,
          imageFiles: imageFiles,
          videoFile: videoFile,
          videoUrl: videoUrl,
          groupId: groupId,
        );
      }

      // Refresh posts to show the new post (optional)
      if (refreshAfterCreate && (groupId == null || groupId.isEmpty)) {
        await fetchPosts(refresh: true, currentUserId: userId);
      }
    } catch (e) {
      print('Error creating post: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> likePost(String postId, String userId) async {
    final pIdx = _posts.indexWhere((p) => p.id == postId);
    final gIdx = _groupPosts.indexWhere((p) => p.id == postId);
    if (pIdx == -1 && gIdx == -1) return;

    // Keep originals for revert
    final originalP = pIdx != -1 ? _posts[pIdx] : null;
    final originalG = gIdx != -1 ? _groupPosts[gIdx] : null;
    final wasLiked = (originalP ?? originalG)!.isLiked;

    // Optimistic updates for both lists
    void applyLike(List<Post> list, int idx) {
      list[idx] = list[idx].copyWith(
        isLiked: !list[idx].isLiked,
        likesCount: list[idx].isLiked ? list[idx].likesCount - 1 : list[idx].likesCount + 1,
      );
    }
    if (pIdx != -1) applyLike(_posts, pIdx);
    if (gIdx != -1) applyLike(_groupPosts, gIdx);
    notifyListeners();

    try {
      if (wasLiked) {
        await _postService.unlikePost(postId, userId);
      } else {
        await _postService.likePost(postId, userId);
      }
    } catch (e) {
      if (pIdx != -1 && originalP != null) _posts[pIdx] = originalP;
      if (gIdx != -1 && originalG != null) _groupPosts[gIdx] = originalG;
      notifyListeners();
      print('Error liking post: $e');
    }
  }

  Future<void> bookmarkPost(String postId, String userId) async {
    final pIdx = _posts.indexWhere((p) => p.id == postId);
    final gIdx = _groupPosts.indexWhere((p) => p.id == postId);
    if (pIdx == -1 && gIdx == -1) return;

    final originalP = pIdx != -1 ? _posts[pIdx] : null;
    final originalG = gIdx != -1 ? _groupPosts[gIdx] : null;
    final wasBookmarked = (originalP ?? originalG)!.isBookmarked;

    void applyBookmark(List<Post> list, int idx) {
      list[idx] = list[idx].copyWith(isBookmarked: !list[idx].isBookmarked);
    }
    if (pIdx != -1) applyBookmark(_posts, pIdx);
    if (gIdx != -1) applyBookmark(_groupPosts, gIdx);
    notifyListeners();

    try {
      if (wasBookmarked) {
        await _postService.removeBookmark(postId, userId);
      } else {
        await _postService.bookmarkPost(postId, userId);
      }
    } catch (e) {
      if (pIdx != -1 && originalP != null) _posts[pIdx] = originalP;
      if (gIdx != -1 && originalG != null) _groupPosts[gIdx] = originalG;
      notifyListeners();
      print('Error bookmarking post: $e');
    }
  }

  Future<void> deletePost(String postId, String userId) async {
    // Remove from UI immediately in both lists
    Post? removedFromPosts;
    Post? removedFromGroup;
    final pIdx = _posts.indexWhere((p) => p.id == postId);
    final gIdx = _groupPosts.indexWhere((p) => p.id == postId);
    if (pIdx != -1) {
      removedFromPosts = _posts[pIdx];
      _posts.removeAt(pIdx);
    }
    if (gIdx != -1) {
      removedFromGroup = _groupPosts[gIdx];
      _groupPosts.removeAt(gIdx);
    }
    notifyListeners();

    try {
      await _postService.deletePost(postId, userId);
    } catch (e) {
      // Revert on error to their respective lists
      if (removedFromPosts != null) _posts.add(removedFromPosts);
      if (removedFromGroup != null) _groupPosts.add(removedFromGroup);
      notifyListeners();
      print('Error deleting post: $e');
    }
  }

  Post? getPostById(String postId) {
    try {
      return _posts.firstWhere((post) => post.id == postId);
    } catch (e) {
      return null;
    }
  }

  // Set emoji reaction (null to remove). Also used for dislike via 'ðŸ‘Ž'
  Future<void> setReaction({
    required String postId,
    required String userId,
    String? emoji,
  }) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    final gIdx = _groupPosts.indexWhere((p) => p.id == postId);
    Post? original;
    Post? originalGroup;

    if (idx != -1) original = _posts[idx];
    if (gIdx != -1) originalGroup = _groupPosts[gIdx];

    void applyLocal(List<Post> list, int i) {
      if (i == -1) return;
      final prev = list[i].userReaction;
      final newMap = Map<String, int>.from(list[i].reactionCounts);
      if (prev != null && prev.isNotEmpty) {
        newMap[prev] = (newMap[prev] ?? 0) - 1;
        if ((newMap[prev] ?? 0) <= 0) newMap.remove(prev);
      }
      if (emoji != null && emoji!.isNotEmpty) {
        newMap[emoji!] = (newMap[emoji!] ?? 0) + 1;
      }
      list[i] = list[i].copyWith(reactionCounts: newMap, userReaction: emoji);
    }

    // optimistic update
    if (idx != -1) applyLocal(_posts, idx);
    if (gIdx != -1) applyLocal(_groupPosts, gIdx);
    notifyListeners();

    try {
      await _postService.setReaction(postId: postId, userId: userId, emoji: emoji);
    } catch (e) {
      if (idx != -1 && original != null) _posts[idx] = original;
      if (gIdx != -1 && originalGroup != null) _groupPosts[gIdx] = originalGroup;
      notifyListeners();
      rethrow;
    }
  }

  // Edit post content and optionally images/video
  Future<void> editPost({
    required String postId,
    String? newContent,
    List<String>? newImageUrls,
    String? newVideoUrl,
  }) async {
    // Find post index in main list
    final idx = _posts.indexWhere((p) => p.id == postId);
    Post? original;
    if (idx != -1) original = _posts[idx];

    // Optimistic UI update
    if (idx != -1) {
      _posts[idx] = _posts[idx].copyWith(
        content: newContent ?? _posts[idx].content,
        imageUrls: newImageUrls ?? _posts[idx].imageUrls,
        videoUrl: newVideoUrl ?? _posts[idx].videoUrl,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
    // Also update in groupPosts list if present
    final gIdx = _groupPosts.indexWhere((p) => p.id == postId);
    Post? originalGroup;
    if (gIdx != -1) {
      originalGroup = _groupPosts[gIdx];
      _groupPosts[gIdx] = _groupPosts[gIdx].copyWith(
        content: newContent ?? _groupPosts[gIdx].content,
        imageUrls: newImageUrls ?? _groupPosts[gIdx].imageUrls,
        videoUrl: newVideoUrl ?? _groupPosts[gIdx].videoUrl,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }

    try {
      await _postService.updatePost(
        postId: postId,
        content: newContent,
        imageUrls: newImageUrls,
        videoUrl: newVideoUrl,
      );
    } catch (e) {
      // Revert on error
      if (idx != -1 && original != null) _posts[idx] = original;
      if (gIdx != -1 && originalGroup != null) _groupPosts[gIdx] = originalGroup;
      notifyListeners();
      rethrow;
    }
  }

  // Start listening to comments stream for real-time updates
  void startListeningToComments(String postId) {
    print('PostsProvider: Starting comments stream for post: $postId');
    
    // Cancel existing subscription for this post
    _commentSubscriptions[postId]?.cancel();
    
    _commentsLoading[postId] = true;
    notifyListeners();
    
    try {
      _commentSubscriptions[postId] = _postService.getPostCommentsStream(postId).listen(
        (comments) {
          print('PostsProvider: Received ${comments.length} comments from stream for post: $postId');
          _postComments[postId] = comments;
          _commentsLoading[postId] = false;
          notifyListeners();
        },
        onError: (error) {
          print('PostsProvider: Error in comments stream for post $postId: $error');
          _commentsLoading[postId] = false;
          notifyListeners();
        },
      );
    } catch (e) {
      print('PostsProvider: Error starting comments stream for post $postId: $e');
      _commentsLoading[postId] = false;
      notifyListeners();
    }
  }

  // Stop listening to comments stream for a specific post
  void stopListeningToComments(String postId) {
    print('PostsProvider: Stopping comments stream for post: $postId');
    _commentSubscriptions[postId]?.cancel();
    _commentSubscriptions.remove(postId);
  }

  // Comment functionality (legacy method for compatibility)
  Future<void> loadCommentsForPost(String postId) async {
    print('PostsProvider: Loading comments for post: $postId');
    if (_commentsLoading[postId] == true) {
      print('PostsProvider: Already loading comments for post: $postId');
      return;
    }

    _commentsLoading[postId] = true;
    notifyListeners();

    try {
      final comments = await _postService.getPostComments(postId);
      print('PostsProvider: Loaded ${comments.length} comments for post: $postId');
      _postComments[postId] = comments;
    } catch (e) {
      print('Error loading comments: $e');
      _postComments[postId] = [];
    }

    _commentsLoading[postId] = false;
    notifyListeners();
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String content,
    required String userDisplayName,
    required String username,
    String? userProfileImageUrl,
    bool isUserVerified = false,
    String? replyToCommentId,
  }) async {
    try {
      final commentId = await _postService.addComment(
        postId: postId,
        userId: userId,
        content: content,
        userDisplayName: userDisplayName,
        username: username,
        userProfileImageUrl: userProfileImageUrl,
        isUserVerified: isUserVerified,
        replyToCommentId: replyToCommentId,
      );

      // If we are NOT listening via stream (e.g., in older screens),
      // optimistically append to local state; otherwise, the stream will update.
      final hasStream = _commentSubscriptions[postId] != null;
      if (!hasStream) {
        if (replyToCommentId == null || replyToCommentId.isEmpty) {
          final newComment = Comment(
            id: commentId,
            postId: postId,
            userId: userId,
            content: content,
            createdAt: DateTime.now(),
            userDisplayName: userDisplayName,
            username: username,
            userProfileImageUrl: userProfileImageUrl,
            isUserVerified: isUserVerified,
          );
          _postComments[postId] ??= [];
          _postComments[postId]!.add(newComment);
          notifyListeners();
        } else {
          final list = _postComments[postId];
          if (list != null) {
            final idx = list.indexWhere((c) => c.id == replyToCommentId);
            if (idx != -1) {
              final c = list[idx];
              list[idx] = c.copyWith(repliesCount: c.repliesCount + 1);
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      print('Error adding comment: $e');
      throw Exception('Failed to add comment');
    }
  }

  Future<void> likeComment(String commentId, String postId) async {
    // Find and update comment in local state
    final comments = _postComments[postId];
    if (comments != null) {
      final commentIndex = comments.indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        final comment = comments[commentIndex];
        comments[commentIndex] = comment.copyWith(
          isLiked: !comment.isLiked,
          likesCount: comment.isLiked ? comment.likesCount - 1 : comment.likesCount + 1,
        );
        notifyListeners();
      }
    }

    // TODO: Implement actual API call when comment liking is added to PostService
  }

  void clearCommentsForPost(String postId) {
    _postComments.remove(postId);
    _commentsLoading.remove(postId);
    stopListeningToComments(postId);
    notifyListeners();
  }

  // Get posts by user ID
  Future<List<Post>> getUserPosts(String userId) async {
    try {
      return await _postService.getUserPosts(userId);
    } catch (e) {
      print('PostsProvider: Error getting user posts: $e');
      throw Exception('Failed to get user posts');
    }
  }

  final Map<String, List<Comment>> _replies = {};
  List<Comment> getRepliesFor(String parentCommentId) => _replies[parentCommentId] ?? [];

  Future<void> loadReplies(String postId, String parentCommentId) async {
    try {
      final list = await _postService.getReplies(postId, parentCommentId);
      _replies[parentCommentId] = list;
      notifyListeners();
    } catch (e) {
      _replies[parentCommentId] = [];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    _postsSubscription?.cancel();
    for (var subscription in _commentSubscriptions.values) {
      subscription?.cancel();
    }
    _commentSubscriptions.clear();
    super.dispose();
  }

  Future<void> deleteEmojiComment({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final list = _postComments[postId];
      if (list != null) {
        final idx = list.lastIndexWhere((c) => c.userId == userId && c.content == emoji);
        if (idx != -1) {
          list.removeAt(idx);
        }
      }

      final pIdx = _posts.indexWhere((p) => p.id == postId);
      if (pIdx != -1) {
        final p = _posts[pIdx];
        if (p.commentsCount > 0) {
          _posts[pIdx] = p.copyWith(commentsCount: p.commentsCount - 1);
        }
      }
      notifyListeners();

      await _postService.deleteEmojiComment(postId: postId, userId: userId, emoji: emoji);
    } catch (e) {
      // Non-fatal
    }
  }
}
