import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:wanderlens/models/user.dart';

class UserService {
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return await getUserById(firebaseUser.uid);
  }

  static Future<User?> getUserById(String id) async {
    try {
      final doc = await _firestore.collection('users').doc(id).get();
      if (doc.exists) return User.fromJson(doc.data()!);
      return null;
    } catch (e) {
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
      if (query.docs.isNotEmpty) return User.fromJson(query.docs.first.data());
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> createUser(User user) async {
    await _firestore.collection('users').doc(user.id).set(user.toJson());
  }

  static Future<User?> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
    String? bio,
    String? location,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) throw Exception('Registration failed');

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
  }

  static Future<User?> login(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) return await getUserById(userCredential.user!.uid);
    return null;
  }

  static Future<void> logout() async => await _auth.signOut();

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to send reset email');
    }
  }

  // Mukammal Change Password Method
  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('User not logged in');

    try {
      // 1. Re-authenticate user
      auth.AuthCredential credential = auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // 2. Update password
      await user.updatePassword(newPassword);
    } on auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      }
      throw Exception(e.message ?? 'Failed to change password');
    }
  }

  static Future<User> updateUser(User user) async {
    final updatedUser = user.copyWith(updatedAt: DateTime.now());
    await _firestore.collection('users').doc(user.id).update(updatedUser.toJson());
    return updatedUser;
  }

  static Future<List<User>> searchUsers(String query, {String? excludeUserId}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    final snapshot = await _firestore.collection('users')
        .where('username', isGreaterThanOrEqualTo: trimmed)
        .where('username', isLessThanOrEqualTo: '$trimmed\uf8ff')
        .get();
    return snapshot.docs.map((doc) => User.fromJson(doc.data())).where((u) => u.id != excludeUserId).toList();
  }

  static Future<List<User>> getSuggestedUsers(String currentUserId, {int limit = 10}) async {
    final snapshot = await _firestore.collection('users').limit(limit).get();
    return snapshot.docs.map((doc) => User.fromJson(doc.data())).where((u) => u.id != currentUserId).toList();
  }
}
