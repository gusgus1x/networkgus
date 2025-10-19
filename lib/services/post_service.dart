import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'cloudinary_service.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CollectionReference _postsCollection = FirebaseFirestore.instance.collection('posts');
  final CloudinaryService _cloudinary = CloudinaryService();

  // Upload post video to Firebase Storage (รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยณรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฑรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รย 10 รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรยขรขโ€ยฌรยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยต)

  // Create a new post
  Future<String> createPost({
    required String userId,
    required String content,
    required String userDisplayName,
    required String username,
    String? userProfileImageUrl,
    bool isUserVerified = false,
    List<File>? imageFiles,
    List<String>? imageUrls,
    File? videoFile, // รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโ€ยฌร…ยกรโ€รยฌรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยฆรโ€รยพรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยก parameter รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยชรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยณรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยซรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฃรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฑรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยฆรโ€รยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยตรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€ฆรยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยญ
    String? videoUrl,
    String? groupId,
  }) async {
    try {
      List<String> uploadedImageUrls = [];

      // Upload images if provided
      if (imageFiles != null && imageFiles.isNotEmpty) {
        uploadedImageUrls = await _uploadPostImages(imageFiles);
      } else if (imageUrls != null) {
        uploadedImageUrls = imageUrls;
      }

      // Upload video if provided
      String? uploadedVideoUrl;
      if (videoFile != null) {
        uploadedVideoUrl = await _uploadPostVideo(videoFile);
      } else if (videoUrl != null) {
        uploadedVideoUrl = videoUrl;
      }

      // Create post document
      final DocumentReference postRef = _postsCollection.doc();
      final Post post = Post(
        id: postRef.id,
        userId: userId,
        content: content,
        imageUrls: uploadedImageUrls.isNotEmpty ? uploadedImageUrls : null,
        videoUrl: uploadedVideoUrl,
        createdAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        isLiked: false,
        isBookmarked: false,
        userDisplayName: userDisplayName,
        username: username,
        userProfileImageUrl: userProfileImageUrl,
        isUserVerified: isUserVerified,
        groupId: groupId,
      );

      await postRef.set(post.toJson());

      // Update user's posts count
      await _firestore.collection('users').doc(userId).update({
        'postsCount': FieldValue.increment(1),
      });
  // Upload post video to Firebase Storage (รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยณรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฑรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รย 10 รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรยขรขโ€ยฌรยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยต)

      // รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรยขรขโ€ยฌร…โ€รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€รยฐรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโ€ยฌร…ยกรโ€รยฌรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รยบรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€รยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€ฆรยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยฆรโ€รยพรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยชรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌยฆรยขรขโ€ยฌรขโ€ยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌย รยขรขโ€ยฌรขโ€ยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฅรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยธรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยก รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌย รยขรขโ€ยฌรขโ€ยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยซรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€รยฐรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโ€ยฌร…ยกรโ€รยฌรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยฆรโ€รยพรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยก postId รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโ€ยฌร…ยกรโ€รยฌรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€ฆรยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€รยฐรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒ group.postIds
      if (groupId != null && groupId.isNotEmpty) {
        await _firestore.collection('groups').doc(groupId).update({
          'postIds': FieldValue.arrayUnion([postRef.id]),
        });
      }

      return postRef.id;
    } catch (e, stackTrace) {
      debugPrint('Create post error: $e');
      debugPrintStack(stackTrace: stackTrace);
      throw Exception('Failed to create post');
    }
  }

  // Edit/update an existing post
  Future<void> updatePost({
    required String postId,
    String? content,
    List<String>? imageUrls,
    String? videoUrl,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (content != null) updates['content'] = content;
      if (imageUrls != null) updates['imageUrls'] = imageUrls;
      if (videoUrl != null) updates['videoUrl'] = videoUrl;

      await _postsCollection.doc(postId).update(updates);
    } catch (e) {
      debugPrint('Update post error: $e');
      throw Exception('Failed to update post');
    }
  }

  // Set or clear an emoji reaction for a user (including dislike via 'รฦ’รโ€รโ€รยฐรฦ’รขโฌยฆรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€นร…โ€รฦ’รขโฌยฆรโ€รยฝ')
  Future<void> setReaction({
    required String postId,
    required String userId,
    String? emoji, // null to remove reaction
  }) async {
    try {
      final postRef = _postsCollection.doc(postId);
      final reactionRef = postRef.collection('reactions').doc(userId);

      await _firestore.runTransaction((txn) async {
        final prevSnap = await txn.get(reactionRef);
        final prev = prevSnap.exists ? (prevSnap.data() as Map<String, dynamic>)['emoji'] as String? : null;

        // If nothing changes, skip
        if (prev == emoji) return;

        // Decrement previous count
        if (prev != null && prev.isNotEmpty) {
          txn.update(postRef, {'reactionCounts.$prev': FieldValue.increment(-1)});
        }

        // Update/remove user reaction doc
        if (emoji == null || emoji.isEmpty) {
          if (prevSnap.exists) txn.delete(reactionRef);
        } else {
          if (prevSnap.exists) {
            txn.update(reactionRef, {'emoji': emoji, 'updatedAt': FieldValue.serverTimestamp()});
          } else {
            txn.set(reactionRef, {
              'userId': userId,
              'emoji': emoji,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          // Increment new count
          txn.update(postRef, {'reactionCounts.$emoji': FieldValue.increment(1)});
        }
        // Ensure updatedAt on post
        txn.update(postRef, {'updatedAt': FieldValue.serverTimestamp()});
      });
    } catch (e) {
      debugPrint('Set reaction error: $e');
      throw Exception('Failed to set reaction');
    }
  }

  // Upload post video to Firebase Storage (รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยณรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฑรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รย 10 รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรยขรขโ€ยฌรยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยต)
  Future<String> _uploadPostVideo(File videoFile) async {
    try {
      // TODO: รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฃรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยชรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยญรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยฆรโ€รยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€ฆรยพรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยตรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€ฆรยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยญรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€ฆรยพรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยกรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌยนรยขรขโ€ยฌรย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโ€ยฌร…ยกรโ€รยฌรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยข 10 รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยงรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยดรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโ€ยฌร…ยพรโ€รยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฒรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รยขรยขรขโฌลกรยฌรยขรขโ€ยฌรยรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยต (รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รขโฌย รยขรขโ€ยฌรขโ€ยขรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌยฆรโ€รย รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยนรฦ’รยขรยขรขโฌลกรยฌรโ€รยฐ package video_player รฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยซรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยฃรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยทรฦ’รโ€รโ€รย รฦ’รขโฌลกรโ€รยธรฦ’รขโฌลกรโ€รยญ ffmpeg)
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_video.mp4';
      final Reference ref = _storage.ref().child('posts/videos').child(fileName);
      final UploadTask uploadTask = ref.putFile(videoFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload video error: $e');
      throw Exception('Failed to upload video');
    }
  }

  // Upload post images to Cloudinary
  Future<List<String>> _uploadPostImages(List<File> imageFiles) async {
    try {
      final uploads = <Future<String>>[];
      for (final file in imageFiles) {
        uploads.add(_cloudinary.uploadImageFile(file));
      }
      return await Future.wait(uploads);
    } catch (e) {
      debugPrint('Upload images error (Cloudinary): $e');
      throw Exception('Failed to upload images to Cloudinary');
    }
  }

  // Get posts feed stream (real-time posts from followed users)
  Stream<List<Post>> getFeedPostsStream(String currentUserId, {int limit = 20}) {
    try {
      // Get all posts with reasonable limit
      return _postsCollection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .asyncMap((snapshot) async {
  debugPrint('PostService: Stream received ${snapshot.docs.length} documents');
        final List<Post> posts = [];

        for (var doc in snapshot.docs) {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          
          // Check if current user liked/bookmarked this post
          final bool isLiked = await _isPostLikedByUser(post.id, currentUserId);
          final bool isBookmarked = await _isPostBookmarkedByUser(post.id, currentUserId);
          
          posts.add(post.copyWith(isLiked: isLiked, isBookmarked: isBookmarked));
        }

  debugPrint('PostService: Returning ${posts.length} posts from stream');
        return posts;
      });
    } catch (e) {
      debugPrint('Get feed posts stream error: $e');
      throw Exception('Failed to get feed posts stream');
    }
  }

  // Keep the original method for compatibility
  Future<List<Post>> getFeedPosts(String currentUserId, {DocumentSnapshot? lastDocument, int limit = 10}) async {
    try {
      // Get following list
      final QuerySnapshot followingQuery = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();

      final List<String> followingIds = followingQuery.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['userId'] as String)
          .toList();

      // Add current user to see their own posts
      followingIds.add(currentUserId);

      Query query;
      
      if (followingIds.length == 1) {
        // Only current user, get all posts
        query = _postsCollection
            .orderBy('createdAt', descending: true)
            .limit(limit);
      } else {
        // Query posts from followed users
        query = _postsCollection
            .where('userId', whereIn: followingIds)
            .orderBy('createdAt', descending: true)
            .limit(limit);
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final QuerySnapshot querySnapshot = await query.get();
      final List<Post> posts = [];

      for (var doc in querySnapshot.docs) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        
        // Check if current user liked this post
        final bool isLiked = await _isPostLikedByUser(post.id, currentUserId);
        final bool isBookmarked = await _isPostBookmarkedByUser(post.id, currentUserId);
        
        posts.add(post.copyWith(isLiked: isLiked, isBookmarked: isBookmarked));
      }

      return posts;
    } catch (e) {
      debugPrint('Get feed posts error: $e');
      throw Exception('Failed to get feed posts');
    }
  }

  // Get user's posts
  Future<List<Post>> getUserPosts(String userId, {DocumentSnapshot? lastDocument, int limit = 12}) async {
    try {
      Query query = _postsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final QuerySnapshot querySnapshot = await query.get();
      final List<Post> posts = [];

      for (var doc in querySnapshot.docs) {
        posts.add(Post.fromJson(doc.data() as Map<String, dynamic>));
      }

      return posts;
    } catch (e) {
      debugPrint('Get user posts error: $e');
      throw Exception('Failed to get user posts');
    }
  }

  // Stream user's posts (real-time) with like/bookmark flags
  Stream<List<Post>> getUserPostsStream(String userId, String currentUserId, {int limit = 50}) {
    try {
      return _postsCollection
          .where('userId', isEqualTo: userId)
          // Avoid orderBy to reduce index/type issues; sort locally
          .limit(limit)
          .snapshots()
          .asyncMap((snapshot) async {
        final List<Post> posts = [];
        for (var doc in snapshot.docs) {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          final bool isLiked = await _isPostLikedByUser(post.id, currentUserId);
          final bool isBookmarked = await _isPostBookmarkedByUser(post.id, currentUserId);
          posts.add(post.copyWith(isLiked: isLiked, isBookmarked: isBookmarked));
        }
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts;
      });
    } catch (e) {
      debugPrint('Get user posts stream error: $e');
      rethrow;
    }
  }

  // Get post by ID
  Future<Post?> getPostById(String postId) async {
    try {
      final DocumentSnapshot doc = await _postsCollection.doc(postId).get();
      if (doc.exists) {
        return Post.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Get post by ID error: $e');
      throw Exception('Failed to get post');
    }
  }

  // Like post
  Future<void> likePost(String postId, String userId) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Add like document
      final DocumentReference likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);
      batch.set(likeRef, {
        'userId': userId,
        'likedAt': FieldValue.serverTimestamp(),
      });

      // Update likes count
      final DocumentReference postRef = _postsCollection.doc(postId);
      batch.update(postRef, {'likesCount': FieldValue.increment(1)});

      await batch.commit();
    } catch (e) {
      debugPrint('Like post error: $e');
      throw Exception('Failed to like post');
    }
  }

  // Unlike post
  Future<void> unlikePost(String postId, String userId) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Remove like document
      final DocumentReference likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);
      batch.delete(likeRef);

      // Update likes count
      final DocumentReference postRef = _postsCollection.doc(postId);
      batch.update(postRef, {'likesCount': FieldValue.increment(-1)});

      await batch.commit();
    } catch (e) {
      debugPrint('Unlike post error: $e');
      throw Exception('Failed to unlike post');
    }
  }

  // Check if post is liked by user
  Future<bool> _isPostLikedByUser(String postId, String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Check like error: $e');
      return false;
    }
  }

  // Bookmark post
  Future<void> bookmarkPost(String postId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(postId)
          .set({
        'postId': postId,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Bookmark post error: $e');
      throw Exception('Failed to bookmark post');
    }
  }

  // Remove bookmark
  Future<void> removeBookmark(String postId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(postId)
          .delete();
    } catch (e) {
      debugPrint('Remove bookmark error: $e');
      throw Exception('Failed to remove bookmark');
    }
  }

  // Check if post is bookmarked by user
  Future<bool> _isPostBookmarkedByUser(String postId, String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .doc(postId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Check bookmark error: $e');
      return false;
    }
  }

  // Get bookmarked posts
  Future<List<Post>> getBookmarkedPosts(String userId) async {
    try {
      final QuerySnapshot bookmarksQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bookmarks')
          .orderBy('bookmarkedAt', descending: true)
          .get();

      final List<String> postIds = bookmarksQuery.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['postId'] as String)
          .toList();

      if (postIds.isEmpty) {
        return [];
      }

      final List<Post> posts = [];
      for (String postId in postIds) {
        final Post? post = await getPostById(postId);
        if (post != null) {
          posts.add(post.copyWith(isBookmarked: true));
        }
      }

      return posts;
    } catch (e) {
      debugPrint('Get bookmarked posts error: $e');
      throw Exception('Failed to get bookmarked posts');
    }
  }

  // Delete post
  Future<void> deletePost(String postId, String userId) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Delete post document
      final DocumentReference postRef = _postsCollection.doc(postId);
      batch.delete(postRef);

      // Update user's posts count
      final DocumentReference userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'postsCount': FieldValue.increment(-1),
      });

      await batch.commit();

      // Delete subcollections (likes, comments) - This would typically be done with Cloud Functions
      // For now, we'll leave them as they'll be cleaned up eventually
    } catch (e) {
      debugPrint('Delete post error: $e');
      throw Exception('Failed to delete post');
    }
  }

  // Add comment to post
  Future<String> addComment({
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
      final DocumentReference commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc();

      final Comment comment = Comment(
        id: commentRef.id,
        postId: postId,
        userId: userId,
        content: content,
        createdAt: DateTime.now(),
        likesCount: 0,
        userDisplayName: userDisplayName,
        username: username,
        userProfileImageUrl: userProfileImageUrl,
        isUserVerified: isUserVerified,
        replyToCommentId: replyToCommentId,
        isLiked: false,
      );

      final WriteBatch batch = _firestore.batch();

      // Add comment
      batch.set(commentRef, comment.toJson());

      // Update post's comments count
      final DocumentReference postRef = _postsCollection.doc(postId);
      batch.update(postRef, {'commentsCount': FieldValue.increment(1)}); if (replyToCommentId != null && replyToCommentId.isNotEmpty) { final parentRef = _firestore.collection('posts').doc(postId).collection('comments').doc(replyToCommentId); batch.update(parentRef, {'repliesCount': FieldValue.increment(1)}); }

      await batch.commit();
      return commentRef.id;
    } catch (e) {
      debugPrint('Add comment error: $e');
      throw Exception('Failed to add comment');
    }
  }

  // Delete the latest emoji comment of a user (e.g., for toggling dislike)
  Future<void> deleteEmojiComment({
    required String postId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final commentsCol = _firestore.collection('posts').doc(postId).collection('comments');
      final q = await commentsCol
          .where('userId', isEqualTo: userId)
          .where('content', isEqualTo: emoji)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return;
      final docRef = q.docs.first.reference;

      final WriteBatch batch = _firestore.batch();
      batch.delete(docRef);
      batch.update(_postsCollection.doc(postId), {
        'commentsCount': FieldValue.increment(-1),
      });
      await batch.commit();
    } catch (e) {
      debugPrint('Delete emoji comment error: $e');
      throw Exception('Failed to delete emoji comment');
    }
  }

  // Get post comments stream for real-time updates
  Stream<List<Comment>> getPostCommentsStream(String postId, {int limit = 50}) {
    try {
      debugPrint('PostService: Setting up comments stream for post $postId');
      
      return _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        debugPrint('PostService: Stream received ${snapshot.docs.length} comment documents');
        
        final List<Comment> comments = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          // Only include top-level comments (no replyToCommentId)
          if (data['replyToCommentId'] == null) {
            comments.add(Comment.fromJson(data));
          }
        }

        debugPrint('PostService: Stream returning ${comments.length} top-level comments');
        return comments;
      });
    } catch (e) {
      debugPrint('Get comments stream error: $e');
      throw Exception('Failed to get comments stream');
    }
  }

  // Get post comments
  Future<List<Comment>> getPostComments(String postId, {int limit = 20}) async {
    try {
      debugPrint('PostService: Loading comments for post: $postId');
      final QuerySnapshot query = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();

      debugPrint('PostService: Found ${query.docs.length} comment documents');
      
      final List<Comment> comments = [];
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('PostService: Comment data: $data');
        // Only include top-level comments (no replyToCommentId)
        if (data['replyToCommentId'] == null) {
          comments.add(Comment.fromJson(data));
        }
      }

      debugPrint('PostService: Returning ${comments.length} top-level comments');
      return comments;
    } catch (e) {
      debugPrint('Get comments error: $e');
      throw Exception('Failed to get comments');
    }
  }

  // Search posts
  Future<List<Post>> searchPosts(String query, {int limit = 20}) async {
    try {
      final QuerySnapshot querySnapshot = await _postsCollection
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThanOrEqualTo: '$query\uf8ff')
          .orderBy('content')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final List<Post> posts = [];
      for (var doc in querySnapshot.docs) {
        posts.add(Post.fromJson(doc.data() as Map<String, dynamic>));
      }

      return posts;
    } catch (e) {
      debugPrint('Search posts error: $e');
      throw Exception('Failed to search posts');
    }
  }

  // Get trending posts (most liked in last 24 hours)
  Future<List<Post>> getTrendingPosts({int limit = 20}) async {
    try {
      final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
      
      final QuerySnapshot querySnapshot = await _postsCollection
          .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
          .orderBy('createdAt')
          .orderBy('likesCount', descending: true)
          .limit(limit)
          .get();

      final List<Post> posts = [];
      for (var doc in querySnapshot.docs) {
        posts.add(Post.fromJson(doc.data() as Map<String, dynamic>));
      }

      return posts;
    } catch (e) {
      debugPrint('Get trending posts error: $e');
      throw Exception('Failed to get trending posts');
    }
  }

  // Get group posts
  Future<List<Post>> getGroupPosts(String groupId, {int limit = 20, String? currentUserId}) async {
    try {
      // Avoid requiring a composite index by not ordering in Firestore
      final querySnapshot = await _postsCollection
          .where('groupId', isEqualTo: groupId)
          .limit(limit)
          .get();

      final basePosts = querySnapshot.docs
          .map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // If we have a user, enrich with like/bookmark flags in parallel
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final enriched = await Future.wait(basePosts.map((p) async {
          final liked = await _isPostLikedByUser(p.id, currentUserId);
          final bookmarked = await _isPostBookmarkedByUser(p.id, currentUserId);
          return p.copyWith(isLiked: liked, isBookmarked: bookmarked);
        }));
        enriched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return enriched;
      }

      // Sort locally by createdAt desc to maintain expected order
      basePosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return basePosts;
    } catch (e) {
      debugPrint('Get group posts error: $e');
      return [];
    }
  }

  // Get posts by a list of IDs (chunks of 10 for whereIn)
  Future<List<Post>> getPostsByIds(List<String> postIds, {String? currentUserId}) async {
    try {
      if (postIds.isEmpty) return [];

      final List<Post> results = [];
      // Firestore whereIn supports up to 10 elements per query
      for (int i = 0; i < postIds.length; i += 10) {
        final chunk = postIds.sublist(i, i + 10 > postIds.length ? postIds.length : i + 10);
        final snapshot = await _postsCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        results.addAll(
          snapshot.docs.map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>)),
        );
      }

      if (currentUserId != null && currentUserId.isNotEmpty) {
        final enriched = await Future.wait(results.map((p) async {
          final liked = await _isPostLikedByUser(p.id, currentUserId);
          final bookmarked = await _isPostBookmarkedByUser(p.id, currentUserId);
          return p.copyWith(isLiked: liked, isBookmarked: bookmarked);
        }));
        enriched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return enriched;
      }

      // Sort by createdAt desc to ensure stable order
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    } catch (e) {
      debugPrint('Get posts by IDs error: $e');
      return [];
    }
  }

  // Create a new post for a group with atomic Firestore batch (more stable)
  Future<String> createPostForGroup({
    required String userId,
    required String content,
    required String userDisplayName,
    required String username,
    String? userProfileImageUrl,
    bool isUserVerified = false,
    List<File>? imageFiles,
    List<String>? imageUrls,
    File? videoFile,
    String? videoUrl,
    required String groupId,
  }) async {
    try {
      List<String> uploadedImageUrls = [];

      if (imageFiles != null && imageFiles.isNotEmpty) {
        uploadedImageUrls = await _uploadPostImages(imageFiles);
      } else if (imageUrls != null) {
        uploadedImageUrls = imageUrls;
      }

      String? uploadedVideoUrl;
      if (videoFile != null) {
        uploadedVideoUrl = await _uploadPostVideo(videoFile);
      } else if (videoUrl != null) {
        uploadedVideoUrl = videoUrl;
      }

      final DocumentReference postRef = _postsCollection.doc();
      final Post post = Post(
        id: postRef.id,
        userId: userId,
        content: content,
        imageUrls: uploadedImageUrls.isNotEmpty ? uploadedImageUrls : null,
        videoUrl: uploadedVideoUrl,
        createdAt: DateTime.now(),
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        isLiked: false,
        isBookmarked: false,
        userDisplayName: userDisplayName,
        username: username,
        userProfileImageUrl: userProfileImageUrl,
        isUserVerified: isUserVerified,
        groupId: groupId,
      );

      final WriteBatch batch = _firestore.batch();
      batch.set(postRef, post.toJson());
      batch.update(_firestore.collection('users').doc(userId), {
        'postsCount': FieldValue.increment(1),
      });
      batch.update(_firestore.collection('groups').doc(groupId), {
        'postIds': FieldValue.arrayUnion([postRef.id]),
      });

      await batch.commit();
      return postRef.id;
    } catch (e) {
      debugPrint('Create group post error: $e');
      throw Exception('Failed to create group post');
    }
  }


  // Get replies for a parent comment
  Future<List<Comment>> getReplies(String postId, String parentCommentId, {int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .where('replyToCommentId', isEqualTo: parentCommentId)
          .orderBy('createdAt', descending: false)
          .limit(limit)
          .get();
    return query.docs.map((d) => Comment.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('Get replies error: $e');
      return [];
    }
  }
}


