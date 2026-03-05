import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/comment.dart';

class CommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Comment>> getCommentsByPostId(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Comment.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Comment> createComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    final docRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    final now = DateTime.now();
    final comment = Comment(
      id: docRef.id,
      postId: postId,
      userId: userId,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(comment.toJson());

    // Update post comment count
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1)
    });

    return comment;
  }

  static Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Update post comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1)
      });
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  static Future<void> updateComment(String postId, String commentId, String content) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .update({
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }
}
