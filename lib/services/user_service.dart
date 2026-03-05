import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderlens/models/user.dart';

class UserService {
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      debugPrint('No user currently logged in to Firebase Auth.');
      return null;
    }
    return await getUserById(firebaseUser.uid);
  }

  static Future<User?> getUserById(String id) async {
    try {
      debugPrint('Fetching user document for ID: $id');
      final doc = await _firestore.collection('users').doc(id).get();
      
      if (doc.exists) {
        debugPrint('User document found in Firestore.');
        return User.fromJson(doc.data()!);
      } else {
        debugPrint('CRITICAL: User document NOT found in Firestore for ID: $id');
        return null;
      }
    } catch (e) {
      debugPrint('[Firestore Error] getUserById failed: $e');
      // Rethrow to let the UI know an actual error occurred vs just "not found"
      rethrow; 
    }
  }

  static Future<User?> getUserByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return User.fromJson(query.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('[Firestore Error] getUserByUsername failed: $e');
      return null;
    }
  }

  static Future<void> createUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toJson());
      debugPrint('Successfully saved user profile to Firestore.');
    } catch (e) {
      debugPrint('[Firestore Error] createUser failed: $e');
      rethrow;
    }
  }

  static Future<User?> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
    String? bio,
    String? location,
  }) async {
    try {
      final existingUser = await getUserByUsername(username);
      if (existingUser != null) {
        throw Exception('Username already taken');
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception('Registration failed');

      try {
        final user = User(
          id: firebaseUser.uid,
          username: username.toLowerCase(),
          email: email,
          displayName: displayName,
          bio: bio,
          location: location,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await createUser(user);
        return user;
      } catch (e) {
        debugPrint('[Firestore Error] Saving user profile failed: $e');
        await firebaseUser.delete();
        throw Exception('Database Error: Profile could not be saved. Check Firestore rules in Console.');
      }
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('User with this email already exists');
      }
      throw Exception(e.message ?? 'Registration failed');
    } catch (e) {
      rethrow;
    }
  }

  static Future<User?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user != null) {
        return await getUserById(userCredential.user!.uid);
      }
      return null;
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to send reset email');
    }
  }

  static Future<User> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await _firestore.collection('users').doc(user.id).update(updatedUser.toJson());
      return updatedUser;
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  static Future<List<User>> searchUsers(String query, {String? excludeUserId}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final String queryLower = trimmed.toLowerCase();
      final List<User> results = [];
      final Set<String> seenUserIds = {};

      // Helper to add users while avoiding duplicates and excluded IDs..
      void addUsersFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final map = Map<String, dynamic>.from(data);
          if ((map['id'] ?? '').toString().isEmpty) map['id'] = doc.id;
          final user = User.fromJson(map);
          if (user.id == excludeUserId) continue;
          if (seenUserIds.contains(user.id)) continue;
          seenUserIds.add(user.id);
          results.add(user);
        }
      }

      // 1) Search by username (case-insensitive prefix using stored lowercase usernames)
      final usernameSnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: queryLower)
          .where('username', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .get();
      addUsersFromSnapshot(usernameSnapshot);

      // 2) Search by display name (prefix match, case-sensitive since displayName is stored as-is)
      final displayNameSnapshot = await _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: trimmed)
          .where('displayName', isLessThanOrEqualTo: '$trimmed\uf8ff')
          .get();
      addUsersFromSnapshot(displayNameSnapshot);

      // 3) Search by exact user ID (document ID)
      final userIdSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isEqualTo: trimmed)
          .get();
      addUsersFromSnapshot(userIdSnapshot);
      
      // Final in-memory filter so partial name also works (case-insensitive)..
      final filtered = results.where((user) {
        final display = user.displayName.toLowerCase();
        final username = user.username.toLowerCase();
        return display.contains(queryLower) ||
            username.contains(queryLower) ||
            user.id.contains(trimmed);
      }).toList();

      return filtered;
    } catch (e) {
      debugPrint('[Firestore Error] searchUsers failed: $e');
      return [];
    }
  }

  static Future<List<User>> getSuggestedUsers(String currentUserId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .limit(limit)
          .get();

      final users = <User>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final map = Map<String, dynamic>.from(data);
        if ((map['id'] ?? '').toString().isEmpty) map['id'] = doc.id;
        users.add(User.fromJson(map));
      }
      return users;
    } catch (e) {
      return [];
    }
  }
}
