import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';

class GroupService {
  final CollectionReference groupsCollection = FirebaseFirestore.instance.collection('groups');

  Future<List<Group>> getGroups() async {
    final snapshot = await groupsCollection.get();
    return snapshot.docs.map((doc) => Group.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<void> createGroup(Group group) async {
    await groupsCollection.add(group.toMap());
  }

  Future<void> joinGroup(String groupId, String userId) async {
    await groupsCollection.doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await groupsCollection.doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> deleteGroup(String groupId) async {
    await groupsCollection.doc(groupId).delete();
  }

  Future<Group?> getGroupById(String groupId) async {
    final doc = await groupsCollection.doc(groupId).get();
    if (doc.exists) {
      return Group.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<void> updateGroupName(String groupId, String name) async {
    await groupsCollection.doc(groupId).update({'name': name});
  }

  Future<void> setGroupImageUrl(String groupId, String imageUrl) async {
    await groupsCollection.doc(groupId).update({'imageUrl': imageUrl});
  }
}
