import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');

  // Create mock users for testing
  Future<void> createMockUsers() async {
    try {
      final mockUsers = [
        {
          'username': 'johndoe',
          'usernameLower': 'johndoe',
          'email': 'john@example.com',
          'displayName': 'John Doe',
          'displayNameLower': 'john doe',
          'profileImageUrl': null,
          'bio': 'Software developer from Bangkok',
          'followersCount': 125,
          'followingCount': 89,
          'postsCount': 15,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
        },
        {
          'username': 'jansmith',
          'usernameLower': 'jansmith',
          'email': 'jane@example.com',
          'displayName': 'Jane Smith',
          'displayNameLower': 'jane smith',
          'profileImageUrl': null,
          'bio': 'UI/UX Designer who loves creating beautiful interfaces',
          'followersCount': 234,
          'followingCount': 156,
          'postsCount': 28,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': true,
        },
        {
          'username': 'alexcoder',
          'usernameLower': 'alexcoder',
          'email': 'alex@example.com',
          'displayName': 'Alex Johnson',
          'displayNameLower': 'alex johnson',
          'profileImageUrl': null,
          'bio': 'Full-stack developer and tech enthusiast',
          'followersCount': 89,
          'followingCount': 67,
          'postsCount': 12,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
        },
        {
          'username': 'sarahdev',
          'usernameLower': 'sarahdev',
          'email': 'sarah@example.com',
          'displayName': 'Sarah Wilson',
          'displayNameLower': 'sarah wilson',
          'profileImageUrl': null,
          'bio': 'Mobile app developer specializing in Flutter',
          'followersCount': 167,
          'followingCount': 98,
          'postsCount': 22,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
        },
      ];

      final batch = _firestore.batch();
      for (int i = 0; i < mockUsers.length; i++) {
        final docRef = _usersCollection.doc('user${i + 1}');
        mockUsers[i]['id'] = 'user${i + 1}';
        batch.set(docRef, mockUsers[i]);
      }
      
      await batch.commit();
      print('Mock users created successfully');
    } catch (e) {
      print('Error creating mock users: $e');
    }
  }

  // Add or update a recent search entry for current user
  Future<void> addRecentSearch(String currentUserId, String viewedUserId, {int keepLimit = 20}) async {
    try {
      if (currentUserId == viewedUserId) return;
      final CollectionReference recentsCol = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recent_searches');

      // Upsert viewed user with latest timestamp
      await recentsCol.doc(viewedUserId).set({
        'userId': viewedUserId,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trim to keep only the newest keepLimit items
      final QuerySnapshot q = await recentsCol
          .orderBy('viewedAt', descending: true)
          .get();
      if (q.docs.length > keepLimit) {
        final WriteBatch batch = _firestore.batch();
        for (final doc in q.docs.skip(keepLimit)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Add recent search error: $e');
    }
  }

  // Get recent searches as full User objects (most recent first)
  Future<List<User>> getRecentSearches(String currentUserId, {int limit = 20}) async {
    try {
      final recentsSnap = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recent_searches')
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get();

      final ids = recentsSnap.docs
          .map((d) => (d.data() as Map<String, dynamic>)['userId'] as String)
          .toList();

      if (ids.isEmpty) return [];

      final List<User> users = [];
      // Firestore whereIn supports up to 10 items; chunk if necessary
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final q = await _usersCollection.where(FieldPath.documentId, whereIn: chunk).get();
        for (var doc in q.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          users.add(User.fromMap(data));
        }
      }

      // Preserve order by ids sequence (most recent first)
      users.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
      return users;
    } catch (e) {
      print('Get recent searches error: $e');
      return [];
    }
  }

  // Clear all recent searches for current user
  Future<void> clearRecentSearches(String currentUserId) async {
    try {
      final col = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('recent_searches');
      final q = await col.get();
      if (q.docs.isEmpty) return;
      final WriteBatch batch = _firestore.batch();
      for (final d in q.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Clear recent searches error: $e');
    }
  }

  // Delete previously seeded mock users (safe to call multiple times)
  Future<int> deleteMockUsers() async {
    try {
      final mockIds = ['user1', 'user2', 'user3', 'user4'];
      final mockUsernames = ['johndoe', 'jansmith', 'alexcoder', 'sarahdev'];

      int deleted = 0;
      final WriteBatch batch = _firestore.batch();

      // Delete by known document IDs
      for (final id in mockIds) {
        final ref = _usersCollection.doc(id);
        final snap = await ref.get();
        if (snap.exists) {
          batch.delete(ref);
          deleted++;
        }
      }

      // Also delete by usernames in case they were imported with different IDs
      // Firestore whereIn max 10 items
      final q = await _usersCollection.where('username', whereIn: mockUsernames).get();
      for (final doc in q.docs) {
        batch.delete(doc.reference);
        deleted++;
      }

      if (deleted > 0) {
        await batch.commit();
      }
      return deleted;
    } catch (e) {
      print('Delete mock users error: $e');
      return 0;
    }
  }

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final DocumentSnapshot doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Ensure id is set from document ID
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Get user by ID error: $e');
      throw Exception('Failed to get user');
    }
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) async {
    try {
      // Prefer normalized lookup
      QuerySnapshot query = await _usersCollection
          .where('usernameLower', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      // Fallback to legacy field if needed
      if (query.docs.isEmpty) {
        query = await _usersCollection
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Get user by username error: $e');
      throw Exception('Failed to get user');
    }
  }

  // Search users
  Future<List<User>> searchUsers(String query) async {
    try {
      final List<User> users = [];
      
      // Search by username (normalized)
      QuerySnapshot usernameQuery = await _usersCollection
          .where('usernameLower', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('usernameLower', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      // Fallback to legacy field if index not present
      if (usernameQuery.docs.isEmpty) {
        usernameQuery = await _usersCollection
            .where('username', isGreaterThanOrEqualTo: query)
            .where('username', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(20)
            .get();
      }

      for (var doc in usernameQuery.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure id is set from document ID
          users.add(User.fromMap(data));
        } catch (e) {
          print('Error parsing user document ${doc.id}: $e');
          continue;
        }
      }

      // Search by display name (normalized)
      QuerySnapshot displayNameQuery = await _usersCollection
          .where('displayNameLower', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('displayNameLower', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      // Fallback to legacy field if needed
      if (displayNameQuery.docs.isEmpty) {
        displayNameQuery = await _usersCollection
            .where('displayName', isGreaterThanOrEqualTo: query)
            .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(20)
            .get();
      }

      for (var doc in displayNameQuery.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure id is set from document ID
          final user = User.fromMap(data);
          // Avoid duplicates
          if (!users.any((u) => u.id == user.id)) {
            users.add(user);
          }
        } catch (e) {
          print('Error parsing user document ${doc.id}: $e');
          continue;
        }
      }

      return users;
    } catch (e) {
      print('Search users error: $e');
      throw Exception('Failed to search users');
    }
  }

  // Follow user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Add to current user's following list
      final DocumentReference followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      batch.set(followingRef, {
        'userId': targetUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Add to target user's followers list
      final DocumentReference followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      batch.set(followerRef, {
        'userId': currentUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Update following count for current user
      final DocumentReference currentUserRef = _usersCollection.doc(currentUserId);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      // Update followers count for target user
      final DocumentReference targetUserRef = _usersCollection.doc(targetUserId);
      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      print('Follow user error: $e');
      throw Exception('Failed to follow user');
    }
  }

  // Unfollow user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Remove from current user's following list
      final DocumentReference followingRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId);
      batch.delete(followingRef);

      // Remove from target user's followers list
      final DocumentReference followerRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId);
      batch.delete(followerRef);

      // Update following count for current user
      final DocumentReference currentUserRef = _usersCollection.doc(currentUserId);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      // Update followers count for target user
      final DocumentReference targetUserRef = _usersCollection.doc(targetUserId);
      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e) {
      print('Unfollow user error: $e');
      throw Exception('Failed to unfollow user');
    }
  }

  // Check if user is following another user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Check following error: $e');
      return false;
    }
  }

  // Get user's followers
  Future<List<User>> getFollowers(String userId) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .orderBy('followedAt', descending: true)
          .get();

      final List<User> followers = [];
      for (var doc in query.docs) {
        final String followerId = (doc.data() as Map<String, dynamic>)['userId'];
        final User? follower = await getUserById(followerId);
        if (follower != null) {
          followers.add(follower);
        }
      }

      return followers;
    } catch (e) {
      print('Get followers error: $e');
      throw Exception('Failed to get followers');
    }
  }

  // Get user's following
  Future<List<User>> getFollowing(String userId) async {
    try {
      final QuerySnapshot query = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .orderBy('followedAt', descending: true)
          .get();

      final List<User> following = [];
      for (var doc in query.docs) {
        final String followingId = (doc.data() as Map<String, dynamic>)['userId'];
        final User? followingUser = await getUserById(followingId);
        if (followingUser != null) {
          following.add(followingUser);
        }
      }

      return following;
    } catch (e) {
      print('Get following error: $e');
      throw Exception('Failed to get following');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    String? website,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (displayName != null) updateData['displayName'] = displayName;
      if (displayName != null) updateData['displayNameLower'] = displayName.toLowerCase();
      if (bio != null) updateData['bio'] = bio;
      if (profileImageUrl != null) updateData['profileImageUrl'] = profileImageUrl;
      if (website != null) updateData['website'] = website;

      if (updateData.isNotEmpty) {
        await _usersCollection.doc(userId).update(updateData);
      }
    } catch (e) {
      print('Update user profile error: $e');
      throw Exception('Failed to update profile');
    }
  }

  // Propagate denormalized profile fields to posts, comments, and conversations
  Future<void> propagateUserProfileChanges({
    required String userId,
    String? displayName,
    String? profileImageUrl,
  }) async {
    try {
      // Update posts by this user
      final postsQuery = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in postsQuery.docs) {
        final Map<String, dynamic> update = {};
        if (displayName != null) update['userDisplayName'] = displayName;
        if (profileImageUrl != null) update['userProfileImageUrl'] = profileImageUrl;
        if (update.isNotEmpty) {
          await doc.reference.update(update);
        }
      }

      // Update comments by this user via collection group query
      final commentsQuery = await _firestore
          .collectionGroup('comments')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in commentsQuery.docs) {
        final Map<String, dynamic> update = {};
        if (displayName != null) update['userDisplayName'] = displayName;
        if (profileImageUrl != null) update['userProfileImageUrl'] = profileImageUrl;
        if (update.isNotEmpty) {
          await doc.reference.update(update);
        }
      }

      // Update conversations participant maps
      final conversationsQuery = await _firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .get();
      for (final doc in conversationsQuery.docs) {
        final Map<String, dynamic> update = {};
        if (displayName != null) update['participantNames.$userId'] = displayName;
        if (profileImageUrl != null) update['participantAvatars.$userId'] = profileImageUrl;
        if (update.isNotEmpty) {
          await doc.reference.update(update);
        }
      }
    } catch (e) {
      print('Propagate user profile changes error: $e');
      // Non-fatal
    }
  }

  // Get suggested users (users not followed by current user)
  Future<List<User>> getSuggestedUsers(String currentUserId, {int limit = 10}) async {
    try {
      // Get users with most followers (excluding current user)
      final QuerySnapshot query = await _usersCollection
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .orderBy('followersCount', descending: true)
          .limit(limit * 2) // Get more to filter out already followed users
          .get();

      final List<User> suggestedUsers = [];
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // ensure ID from document
        final user = User.fromMap(data);
        
        // Check if current user is already following this user
        final bool isAlreadyFollowing = await isFollowing(currentUserId, user.id);
        if (!isAlreadyFollowing && suggestedUsers.length < limit) {
          suggestedUsers.add(user);
        }
      }

      return suggestedUsers;
    } catch (e) {
      print('Get suggested users error: $e');
      throw Exception('Failed to get suggested users');
    }
  }

  // Block user
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .doc(targetUserId)
          .set({
        'userId': targetUserId,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      // Also unfollow if following
      final bool isCurrentlyFollowing = await isFollowing(currentUserId, targetUserId);
      if (isCurrentlyFollowing) {
        await unfollowUser(currentUserId, targetUserId);
      }
    } catch (e) {
      print('Block user error: $e');
      throw Exception('Failed to block user');
    }
  }

  // Unblock user
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .doc(targetUserId)
          .delete();
    } catch (e) {
      print('Unblock user error: $e');
      throw Exception('Failed to unblock user');
    }
  }

  // Check if user is blocked
  Future<bool> isBlocked(String currentUserId, String targetUserId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Check blocked error: $e');
      return false;
    }
  }

  // Get all users (for chat list)
  Future<List<User>> getAllUsers({int limit = 50}) async {
    try {
      final QuerySnapshot query = await _usersCollection
          .orderBy('displayName')
          .limit(limit)
          .get();

      final List<User> users = [];
      for (var doc in query.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure id is set from document ID
          users.add(User.fromMap(data));
        } catch (e) {
          print('Error parsing user document ${doc.id}: $e');
          continue;
        }
      }

      return users;
    } catch (e) {
      print('Get all users error: $e');
      throw Exception('Failed to get users');
    }
  }

  // Get users stream for real-time updates
  Stream<List<User>> getUsersStream({int limit = 50}) {
    try {
      return _usersCollection
          .orderBy('displayName')
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => User.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      print('Get users stream error: $e');
      throw Exception('Failed to get users stream');
    }
  }
}
