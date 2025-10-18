class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final bool isLiked;
  final String userDisplayName;
  final String username;
  final String? userProfileImageUrl;
  final bool isUserVerified;
  final String? replyToCommentId; // For nested comments
  final int repliesCount;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.isLiked = false,
    required this.userDisplayName,
    required this.username,
    this.userProfileImageUrl,
    this.isUserVerified = false,
    this.replyToCommentId,
    this.repliesCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['postId'],
      userId: json['userId'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : null,
      likesCount: json['likesCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      userDisplayName: json['userDisplayName'],
      username: json['username'],
      userProfileImageUrl: json['userProfileImageUrl'],
      isUserVerified: json['isUserVerified'] ?? false,
      replyToCommentId: json['replyToCommentId'],
      repliesCount: json['repliesCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'likesCount': likesCount,
      'isLiked': isLiked,
      'userDisplayName': userDisplayName,
      'username': username,
      'userProfileImageUrl': userProfileImageUrl,
      'isUserVerified': isUserVerified,
      'replyToCommentId': replyToCommentId,
      'repliesCount': repliesCount,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    bool? isLiked,
    String? userDisplayName,
    String? username,
    String? userProfileImageUrl,
    bool? isUserVerified,
    String? replyToCommentId,
    int? repliesCount,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      username: username ?? this.username,
      userProfileImageUrl: userProfileImageUrl ?? this.userProfileImageUrl,
      isUserVerified: isUserVerified ?? this.isUserVerified,
      replyToCommentId: replyToCommentId ?? this.replyToCommentId,
      repliesCount: repliesCount ?? this.repliesCount,
    );
  }
}