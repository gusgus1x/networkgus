import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final Map<String, User> _users = {};
  bool _isLoading = false;

  Map<String, User> get users => _users;
  bool get isLoading => _isLoading;

  Future<User?> getUserById(String userId) async {
    if (_users.containsKey(userId)) {
      return _users[userId];
    }

    _isLoading = true;
    notifyListeners();

    try {
      final user = await _userService.getUserById(userId);
      if (user != null) {
        _users[userId] = user;
      }
      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      print('UserProvider: Error getting user by ID: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<List<User>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    _isLoading = true;
    notifyListeners();

    try {
      final results = await _userService.searchUsers(query.trim());
      _isLoading = false;
      notifyListeners();
      return results;
    } catch (e) {
      print('UserProvider: Error searching users: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<List<User>> getSuggestedUsers(String currentUserId, {int limit = 10}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Only use real users from Firestore and exclude current user + already-following
      final suggestions = await _userService.getSuggestedUsers(currentUserId, limit: limit);
      _isLoading = false;
      notifyListeners();
      return suggestions;
    } catch (e) {
      print('UserProvider: Error getting suggested users: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<int> deleteMockUsers() async {
    final n = await _userService.deleteMockUsers();
    return n;
  }

  Future<bool> followUser(String currentUserId, String targetUserId) async {
    try {
      await _userService.followUser(currentUserId, targetUserId);
      
      // Update local cache if user exists
      final user = _users[targetUserId];
      if (user != null) {
        _users[targetUserId] = user.copyWith(
          followersCount: user.followersCount + 1,
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('UserProvider: Error following user: $e');
      return false;
    }
  }

  Future<bool> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      await _userService.unfollowUser(currentUserId, targetUserId);
      
      // Update local cache if user exists
      final user = _users[targetUserId];
      if (user != null) {
        _users[targetUserId] = user.copyWith(
          followersCount: user.followersCount - 1,
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('UserProvider: Error unfollowing user: $e');
      return false;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      return await _userService.getAllUsers();
    } catch (e) {
      print('UserProvider: Error getting all users: $e');
      return [];
    }
  }

  // Recent searches APIs
  Future<void> addRecentSearch(String currentUserId, String viewedUserId) async {
    try {
      await _userService.addRecentSearch(currentUserId, viewedUserId);
    } catch (e) {
      print('UserProvider: Error adding recent search: $e');
    }
  }

  Future<List<User>> getRecentSearches(String currentUserId, {int limit = 20}) async {
    try {
      return await _userService.getRecentSearches(currentUserId, limit: limit);
    } catch (e) {
      print('UserProvider: Error getting recent searches: $e');
      return [];
    }
  }

  Future<void> clearRecentSearches(String currentUserId) async {
    try {
      await _userService.clearRecentSearches(currentUserId);
    } catch (e) {
      print('UserProvider: Error clearing recent searches: $e');
    }
  }

  // Check if current user is following target user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      return await _userService.isFollowing(currentUserId, targetUserId);
    } catch (e) {
      print('UserProvider: Error checking follow status: $e');
      return false;
    }
  }

  void clearUsers() {
    _users.clear();
    notifyListeners();
  }
}
