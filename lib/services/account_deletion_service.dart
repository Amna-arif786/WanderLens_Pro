import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:wanderlens/services/comment_service.dart';
import 'package:wanderlens/services/post_service.dart';

/// Removes all Firestore data for [uid] before Firebase Auth account deletion.
class AccountDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> purgeUserData(String uid) async {
    await _deleteCommentsByUser(uid);
    await _deleteLikesByUser(uid);

    final postsSnap = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in postsSnap.docs) {
      await PostService.deletePost(doc.id);
    }

    await _deleteWishlistSubcollection(uid);
    await _removeAllFriendshipsForUser(uid);
    await _deleteFriendRequestsForUser(uid);
    await _deleteNotificationsForUser(uid);

    await _firestore.collection('users').doc(uid).delete();
  }

  static Future<void> _deleteWishlistSubcollection(String uid) async {
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('wishlist')
        .get();
    await _batchDeleteRefs(snap.docs.map((d) => d.reference).toList());
  }

  static Future<void> _batchDeleteRefs(List<DocumentReference> refs) async {
    if (refs.isEmpty) return;
    const chunk = 400;
    for (var i = 0; i < refs.length; i += chunk) {
      final batch = _firestore.batch();
      final end = i + chunk > refs.length ? refs.length : i + chunk;
      for (final r in refs.sublist(i, end)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  static Future<void> _deleteCommentsByUser(String uid) async {
    try {
      final snap = await _firestore
          .collectionGroup('comments')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final postId = data['postId'] as String? ??
            doc.reference.parent.parent?.id;
        if (postId == null || postId.isEmpty) continue;
        try {
          await CommentService.deleteComment(postId, doc.id);
        } catch (e) {
          debugPrint('deleteAccount: skip comment ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('deleteAccount: comments collectionGroup failed: $e');
    }
  }

  static Future<void> _deleteLikesByUser(String uid) async {
    try {
      final snap = await _firestore
          .collectionGroup('likes')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final postRef = doc.reference.parent.parent;
        if (postRef == null) continue;
        try {
          await doc.reference.delete();
          await postRef.update({'likeCount': FieldValue.increment(-1)});
        } catch (e) {
          debugPrint('deleteAccount: skip like ${doc.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('deleteAccount: likes collectionGroup failed: $e');
    }
  }

  static Future<void> _removeAllFriendshipsForUser(String uid) async {
    final asUser = await _firestore
        .collection('user_friends')
        .where('userId', isEqualTo: uid)
        .get();
    final asFriend = await _firestore
        .collection('user_friends')
        .where('friendId', isEqualTo: uid)
        .get();

    final processedOthers = <String>{};
    Future<void> handle(QuerySnapshot<Map<String, dynamic>> snap) async {
      for (final doc in snap.docs) {
        final m = doc.data();
        final u1 = m['userId'] as String? ?? '';
        final u2 = m['friendId'] as String? ?? '';
        if (u1.isEmpty || u2.isEmpty) continue;
        final other = u1 == uid ? u2 : u1;
        if (!processedOthers.add(other)) continue;

        await _firestore.collection('user_friends').doc('${uid}_$other').delete();
        await _firestore.collection('user_friends').doc('${other}_$uid').delete();

        final otherRef = _firestore.collection('users').doc(other);
        final otherSnap = await otherRef.get();
        if (otherSnap.exists) {
          final m = otherSnap.data()!;
          final n = (m['friendCount'] as num?)?.toInt() ?? 0;
          if (n > 0) {
            await otherRef.update({
              'friendCount': n - 1,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
          }
        }
      }
    }

    await handle(asUser);
    await handle(asFriend);
  }

  static Future<void> _deleteFriendRequestsForUser(String uid) async {
    final s1 = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: uid)
        .get();
    final s2 = await _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: uid)
        .get();
    final refs = <DocumentReference>{};
    for (final d in s1.docs) {
      refs.add(d.reference);
    }
    for (final d in s2.docs) {
      refs.add(d.reference);
    }
    await _batchDeleteRefs(refs.toList());
  }

  static Future<void> _deleteNotificationsForUser(String uid) async {
    final r = await _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: uid)
        .get();
    final s = await _firestore
        .collection('notifications')
        .where('senderId', isEqualTo: uid)
        .get();
    final refs = <DocumentReference>{};
    for (final d in r.docs) {
      refs.add(d.reference);
    }
    for (final d in s.docs) {
      refs.add(d.reference);
    }
    await _batchDeleteRefs(refs.toList());
  }
}
