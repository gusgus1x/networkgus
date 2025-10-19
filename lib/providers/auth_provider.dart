import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class AuthProvider with ChangeNotifier {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  firebase_auth.User? get user => _firebaseAuth.currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  // Firebase login function
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Sign in with Firebase Auth
      final firebase_auth.UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Get user data from Firestore
        await _loadUserData(userCredential.user!.uid);
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isLoading = false;
      notifyListeners();
    }
    
    return false;
  }

  // Firebase signup function
  Future<bool> signUp(String email, String password, String displayName, String username) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Create user with Firebase Auth
      final firebase_auth.UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user document in Firestore
        final User newUser = User(
          id: userCredential.user!.uid,
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

        // Save to Firestore
        final data = newUser.toMap();
        data['usernameLower'] = username.toLowerCase();
        data['displayNameLower'] = displayName.toLowerCase();
        await _firestore.collection('users').doc(userCredential.user!.uid).set(data);
        
        _currentUser = newUser;
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint('Signup error: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isLoading = false;
      notifyListeners();
    }
    
    return false;
  }

  // Load user data from Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = User.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading user data: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // Firebase logout
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  // Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e, stackTrace) {
      debugPrint('Password reset error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? profileImageUrl,
  }) async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Update user data locally
      _currentUser = _currentUser!.copyWith(
        displayName: displayName,
        bio: bio,
        profileImageUrl: profileImageUrl,
      );

      // Update in Firestore
      await _firestore.collection('users').doc(_currentUser!.id).update({
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      });

      // Propagate denormalized fields to posts/comments/conversations
      if (displayName != null || profileImageUrl != null) {
        final userService = UserService();
        await userService.propagateUserProfileChanges(
          userId: _currentUser!.id,
          displayName: displayName,
          profileImageUrl: profileImageUrl,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error updating profile: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isLoading = false;
      notifyListeners();
    }
  }

  // Initialize auth state (check if user is already logged in)
  Future<void> initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    // Listen to auth state changes
    _firebaseAuth.authStateChanges().listen((firebase_auth.User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
        _isLoggedIn = true;
      } else {
        _currentUser = null;
        _isLoggedIn = false;
      }
      _isLoading = false;
      notifyListeners();
    });
  }
}
