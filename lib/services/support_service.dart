import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:wanderlens/services/user_service.dart';

class SupportService {
  SupportService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String ticketsCollection = 'supportTickets';
  static const String messagesSubcollection = 'messages';

  static String? get _uid => auth.FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>> ticketRef(String userId) =>
      _db.collection(ticketsCollection).doc(userId);

  static CollectionReference<Map<String, dynamic>> messagesRef(String userId) =>
      ticketRef(userId).collection(messagesSubcollection);

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream() {
    final uid = _uid;
    if (uid == null) {
      return const Stream.empty();
    }
    // Do NOT orderBy('createdAtMs') here: admin tools often omit this field or use
    // Timestamp-only fields, which breaks the query or excludes those messages.
    return messagesRef(uid).snapshots();
  }

  /// Best-effort chronological sort for mixed message shapes (app + admin panel).
  static int compareMessages(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final ta = _messageSortKey(a.data());
    final tb = _messageSortKey(b.data());
    final c = ta.compareTo(tb);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  static int _messageSortKey(Map<String, dynamic> data) {
    final ms = data['createdAtMs'];
    if (ms is int) return ms;

    final server = data['createdAtServer'];
    if (server is Timestamp) return server.millisecondsSinceEpoch;

    final createdAt = data['createdAt'];
    if (createdAt is String) {
      try {
        return DateTime.parse(createdAt).millisecondsSinceEpoch;
      } catch (_) {}
    }

    return 0;
  }

  // User k pas unread messages check krny k liye stream
  static Stream<bool> hasUnreadSupportStream() {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return ticketRef(uid).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      return data['unreadByUser'] ?? false;
    });
  }

  // Jab user chat kholy to unread flag khatam krna
  static Future<void> markAsRead() async {
    final uid = _uid;
    if (uid == null) return;
    await ticketRef(uid).update({'unreadByUser': false});
  }

  static Future<void> sendUserMessage(String text) async {
    final uid = _uid;
    if (uid == null) throw Exception('You must be signed in.');

    final user = await UserService.getCurrentUser();
    final displayName = user?.displayName ?? user?.username ?? 'User';
    final profileImage = user?.profileImageUrl ?? '';

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = _db.batch();
    final now = DateTime.now();
    final ticket = ticketRef(uid);

    batch.set(
      ticket,
      {
        'userId': uid,
        'username': displayName,
        'userProfileImage': profileImage,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': trimmed.length > 120 ? '${trimmed.substring(0, 120)}…' : trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'status': 'open',
        'unreadByAdmin': true,
        'unreadByUser': false, // User ny khud bheja hai to user k liye read hai
      },
      SetOptions(merge: true),
    );

    final msgRef = messagesRef(uid).doc();
    batch.set(msgRef, {
      'id': msgRef.id,
      'senderId': uid,
      'senderName': displayName,
      'senderRole': 'user',
      'text': trimmed,
      'createdAt': now.toIso8601String(),
      'createdAtMs': now.millisecondsSinceEpoch,
      'createdAtServer': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('SupportService.sendUserMessage: $e');
      rethrow;
    }
  }
}
