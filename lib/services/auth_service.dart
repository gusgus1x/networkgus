import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user stream
  Stream<firebase_auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final firebase_auth.UserCredential result = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        return await getUserData(result.user!.uid);
      }
      return null;
    } catch (e) {
      print('Sign in error: $e');
      throw _handleAuthException(e);
    }
  }

  // Create user with email and password
  Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    try {
      // Check if username is already taken
      final usernameExists = await _checkUsernameExists(username);
      if (usernameExists) {
        throw Exception('Username is already taken');
      }

      final firebase_auth.UserCredential result = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user document in Firestore
        final User newUser = User(
          id: result.user!.uid,
          username: username,
          email: email,
          displayName: displayName,
          profileImageUrl: null,
          bio: null,
          followersCount: 0,
          followingCount: 0,
          postsCount: 0,
          createdAt: DateTime.now(),
          isVerified: false,
        );

        await _firestore.collection('users').doc(result.user!.uid).set(newUser.toMap());
        return newUser;
      }
      return null;
    } catch (e) {
      print('Sign up error: $e');
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      throw Exception('Failed to sign out');
    }
  }

  // Get user data from Firestore
  Future<User?> getUserData(String uid) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Get user data error: $e');
      throw Exception('Failed to get user data');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? profileImageUrl,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      
      if (displayName != null) updateData['displayName'] = displayName;
      if (bio != null) updateData['bio'] = bio;
      if (profileImageUrl != null) updateData['profileImageUrl'] = profileImageUrl;

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updateData);
      }
    } catch (e) {
      print('Update profile error: $e');
      throw Exception('Failed to update profile');
    }
  }

  // Check if username exists
  Future<bool> _checkUsernameExists(String username) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      print('Check username error: $e');
      return false;
    }
  }

  // Handle authentication exceptions
  String _handleAuthException(dynamic e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email address.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email address.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many requests. Please try again later.';
        case 'operation-not-allowed':
          return 'Email/password sign in is not enabled.';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    return e.toString();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      throw _handleAuthException(e);
    }
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updateEmail(newEmail);
        await _firestore.collection('users').doc(user.uid).update({
          'email': newEmail,
        });
      }
    } catch (e) {
      print('Update email error: $e');
      throw _handleAuthException(e);
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } catch (e) {
      print('Update password error: $e');
      throw _handleAuthException(e);
    }
  }

  // Reauthenticate user
  Future<void> reauthenticate(String email, String password) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        final credential = firebase_auth.EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } catch (e) {
      print('Reauthenticate error: $e');
      throw _handleAuthException(e);
    }
  }
}