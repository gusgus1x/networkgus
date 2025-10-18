import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime createdAt;
  final bool isVerified;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    required this.createdAt,
    this.isVerified = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      displayName: json['displayName'],
      profileImageUrl: json['profileImageUrl'],
      bio: json['bio'],
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
      postsCount: json['postsCount'] ?? 0,
      createdAt: _parseDateTime(json['createdAt']),
      isVerified: json['isVerified'] ?? false,
    );
  }

  static DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    if (dateTime is String) {
      try {
        return DateTime.parse(dateTime);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (dateTime is Timestamp) {
      // Handle Firebase Timestamp
      return dateTime.toDate();
    }
    if (dateTime.runtimeType.toString().contains('Timestamp')) {
      // Handle Firebase Timestamp (fallback)
      return (dateTime as dynamic).toDate();
    }
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
    };
  }

  // For Firestore compatibility
  Map<String, dynamic> toMap() => toJson();
  
  factory User.fromMap(Map<String, dynamic> map) => User.fromJson(map);

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    DateTime? createdAt,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}