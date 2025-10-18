import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/group_service.dart';

class GroupProvider extends ChangeNotifier {
  List<Group> _groups = [];
  bool _isLoading = false;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;

  Future<void> fetchGroups() async {
    _isLoading = true;
    notifyListeners();
    _groups = await GroupService().getGroups();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> createGroup(Group group) async {
    await GroupService().createGroup(group);
    await fetchGroups();
  }

  Future<void> joinGroup(String groupId, String userId) async {
    await GroupService().joinGroup(groupId, userId);
    await fetchGroups();
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await GroupService().leaveGroup(groupId, userId);
    await fetchGroups();
  }

  Future<void> deleteGroup(String groupId) async {
    await GroupService().deleteGroup(groupId);
    await fetchGroups();
  }

  Future<Group?> getGroupById(String groupId) async {
    try {
      return await GroupService().getGroupById(groupId);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateGroupName(String groupId, String name) async {
    await GroupService().updateGroupName(groupId, name);
    // Optimistic local update
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final g = _groups[idx];
      _groups[idx] = Group(
        id: g.id,
        name: name,
        description: g.description,
        ownerId: g.ownerId,
        members: g.members,
        postIds: g.postIds,
        createdAt: g.createdAt,
        imageUrl: g.imageUrl,
      );
      notifyListeners();
    }
  }

  Future<void> updateGroupImageUrl(String groupId, String imageUrl) async {
    await GroupService().setGroupImageUrl(groupId, imageUrl);
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      final g = _groups[idx];
      _groups[idx] = Group(
        id: g.id,
        name: g.name,
        description: g.description,
        ownerId: g.ownerId,
        members: g.members,
        postIds: g.postIds,
        createdAt: g.createdAt,
        imageUrl: imageUrl,
      );
      notifyListeners();
    }
  }
}
