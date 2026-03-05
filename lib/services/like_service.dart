import 'package:cloud_firestore/cloud_firestore.dart';

class LikeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> isPostLikedByUser(String postId, String userId) async {
    try {
      final doc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  static Future<void> toggleLike(String postId, String userId) async {
    try {
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(userId);

      final doc = await likeRef.get();
      final postRef = _firestore.collection('posts').doc(postId);

      if (doc.exists) {
        // Unlike
        await likeRef.delete();
        await postRef.update({'likeCount': FieldValue.increment(-1)});
      } else {
        // Like
        await likeRef.set({
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await postRef.update({'likeCount': FieldValue.increment(1)});
      }
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  static Future<int> getLikeCount(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
