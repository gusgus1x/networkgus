import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String content;
  final List<String>? imageUrls;
  final String? videoUrl; // เพิ่ม field วิดีโอ
  final String? audioUrl; // เพิ่ม field เสียง (mp3)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLiked;
  final bool isBookmarked;
  final Map<String, int> reactionCounts; // emoji -> count
  final String? userReaction; // current user's reaction (client-only)
  final String userDisplayName;
  final String username;
  final String? userProfileImageUrl;
  final bool isUserVerified;
  final String? groupId;

  Post({
  required this.id,
  required this.userId,
  required this.content,
  this.imageUrls,
  this.videoUrl,
  this.audioUrl,
  required this.createdAt,
  this.updatedAt,
  this.likesCount = 0,
  this.commentsCount = 0,
  this.sharesCount = 0,
  this.isLiked = false,
  this.isBookmarked = false,
  this.reactionCounts = const {},
  this.userReaction,
  required this.userDisplayName,
  required this.username,
  this.userProfileImageUrl,
  this.isUserVerified = false,
  this.groupId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        try { return DateTime.parse(v); } catch (_) { return DateTime.now(); }
      }
      return DateTime.now();
    }
    return Post(
      id: json['id'],
      userId: json['userId'],
      content: json['content'],
    imageUrls: json['imageUrls'] != null 
      ? List<String>.from(json['imageUrls']) 
      : null,
    videoUrl: json['videoUrl'],
    audioUrl: json['audioUrl'],
      createdAt: parseDate(json['createdAt']),
      updatedAt: json['updatedAt'] != null 
          ? parseDate(json['updatedAt']) 
          : null,
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      sharesCount: json['sharesCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
      reactionCounts: json['reactionCounts'] != null
          ? Map<String, int>.from(json['reactionCounts'] as Map)
          : const {},
      userReaction: json['userReaction'],
      userDisplayName: json['userDisplayName'],
      username: json['username'],
      userProfileImageUrl: json['userProfileImageUrl'],
      isUserVerified: json['isUserVerified'] ?? false,
      groupId: json['groupId'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'imageUrls': imageUrls,
  'createdAt': createdAt.toIso8601String(),
  'updatedAt': updatedAt?.toIso8601String(),
  'likesCount': likesCount,
  'commentsCount': commentsCount,
  'sharesCount': sharesCount,
  'isLiked': isLiked,
  'isBookmarked': isBookmarked,
  'reactionCounts': reactionCounts,
  'userDisplayName': userDisplayName,
  'username': username,
  'userProfileImageUrl': userProfileImageUrl,
  'isUserVerified': isUserVerified,
  'groupId': groupId,
  'videoUrl': videoUrl,
  'audioUrl': audioUrl,
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? content,
    List<String>? imageUrls,
  DateTime? createdAt,
  DateTime? updatedAt,
  int? likesCount,
  int? commentsCount,
  int? sharesCount,
  bool? isLiked,
  bool? isBookmarked,
  String? userDisplayName,
  String? username,
  String? userProfileImageUrl,
  bool? isUserVerified,
  String? groupId,
  String? videoUrl,
  String? audioUrl,
  Map<String, int>? reactionCounts,
  String? userReaction,
  bool userReactionCleared = false,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
  createdAt: createdAt ?? this.createdAt,
  updatedAt: updatedAt ?? this.updatedAt,
  likesCount: likesCount ?? this.likesCount,
  commentsCount: commentsCount ?? this.commentsCount,
  sharesCount: sharesCount ?? this.sharesCount,
  isLiked: isLiked ?? this.isLiked,
  isBookmarked: isBookmarked ?? this.isBookmarked,
  userDisplayName: userDisplayName ?? this.userDisplayName,
  username: username ?? this.username,
  userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
  isUserVerified: isUserVerified ?? this.isUserVerified,
  groupId: groupId ?? this.groupId,
  videoUrl: videoUrl ?? this.videoUrl,
  audioUrl: audioUrl ?? this.audioUrl,
  reactionCounts: reactionCounts ?? this.reactionCounts,
  userReaction: userReactionCleared ? null : (userReaction ?? this.userReaction),
    );
  }
}
