import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<String> members;
  final List<String> postIds;
  final DateTime createdAt;
  final String? imageUrl;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.members,
    required this.postIds,
    required this.createdAt,
    this.imageUrl,
  });

  factory Group.fromMap(Map<String, dynamic> map, String id) {
    return Group(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      postIds: List<String>.from(map['postIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'members': members,
      'postIds': postIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
    };
  }
}
