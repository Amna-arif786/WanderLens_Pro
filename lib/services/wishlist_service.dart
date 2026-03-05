import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/post_service.dart';

class WishlistService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> isPostInWishlist(String postId, String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(postId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  static Future<void> toggleWishlist(String postId, String userId) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(postId);

      final doc = await docRef.get();
      final postRef = _firestore.collection('posts').doc(postId);

      if (doc.exists) {
        await docRef.delete();
        await postRef.update({'saveCount': FieldValue.increment(-1)});
      } else {
        await docRef.set({
          'postId': postId,
          'savedAt': FieldValue.serverTimestamp(),
        });
        await postRef.update({'saveCount': FieldValue.increment(1)});
      }
    } catch (e) {
      throw Exception('Failed to toggle wishlist: $e');
    }
  }

  // Real-time stream for wishlist updates
  static Stream<QuerySnapshot> getWishlistStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  static Future<List<Post>> getWishlistPosts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .orderBy('savedAt', descending: true)
          .get();

      List<Post> posts = [];
      for (var doc in snapshot.docs) {
        final post = await PostService.getPostById(doc.id);
        if (post != null) {
          posts.add(post);
        }
      }
      return posts;
    } catch (e) {
      return [];
    }
  }

  static Future<void> removeFromWishlist(String postId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(postId)
          .delete();

      await _firestore.collection('posts').doc(postId).update({
        'saveCount': FieldValue.increment(-1)
      });
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }
}
