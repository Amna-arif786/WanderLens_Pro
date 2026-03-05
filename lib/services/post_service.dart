import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/user_service.dart';

class PostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Post>> getAllPosts() async {
    try {
      final snapshot = await _firestore.collection('posts').get();
      return snapshot.docs.map((doc) => Post.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Post?> getPostById(String id) async {
    try {
      final doc = await _firestore.collection('posts').doc(id).get();
      if (doc.exists) {
        return Post.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Post>> getPostsByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => Post.fromJson(doc.data())).toList();
    } catch (e) {
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => Post.fromJson(doc.data())).toList();
    }
  }

  static Stream<List<Post>> getPostsStreamByUserId(String userId) {
    // Simple stream without orderBy to avoid index issues for now
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs.map((doc) => Post.fromJson(doc.data())).toList();
          // Sort in memory to avoid needing a Firestore index
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  static Future<List<Post>> getFeedPosts(String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();
      
      final posts = snapshot.docs.map((doc) => Post.fromJson(doc.data())).toList();
      
      return posts.where((post) => 
        post.privacy == PostPrivacy.public || post.userId == currentUserId
      ).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Post> createPost({
    required String userId,
    required String imageUrl,
    required String caption,
    required String location,
    required String cityName,
    double? latitude,
    double? longitude,
    PostPrivacy privacy = PostPrivacy.public,
  }) async {
    final user = await UserService.getUserById(userId);
    final docRef = _firestore.collection('posts').doc();
    
    final post = Post(
      id: docRef.id,
      userId: userId,
      username: user?.username ?? 'Unknown User',
      userDisplayName: user?.displayName ?? 'Unknown User',
      userProfileImage: user?.profileImageUrl,
      imageUrl: imageUrl,
      caption: caption,
      location: location,
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
      privacy: privacy,
      isVerified: true, 
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(post.toJson());

    if (user != null) {
      await UserService.updateUser(user.copyWith(postCount: user.postCount + 1));
    }

    return post;
  }

  static Future<Post> updatePost(Post post) async {
    try {
      final updatedPost = post.copyWith(updatedAt: DateTime.now());
      await _firestore.collection('posts').doc(post.id).update(updatedPost.toJson());
      return updatedPost;
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  static Future<void> deletePost(String postId) async {
    try {
      final post = await getPostById(postId);
      if (post != null) {
        // 1. Delete comments
        final comments = await _firestore.collection('posts').doc(postId).collection('comments').get();
        for (var doc in comments.docs) {
          await doc.reference.delete();
        }

        // 2. Delete likes
        final likes = await _firestore.collection('posts').doc(postId).collection('likes').get();
        for (var doc in likes.docs) {
          await doc.reference.delete();
        }

        // 3. Remove from author's wishlist (optional but good)
        await _firestore.collection('users').doc(post.userId).collection('wishlist').doc(postId).delete();

        // 4. Delete the post itself
        await _firestore.collection('posts').doc(postId).delete();

        // 5. Decrement user's post count
        final user = await UserService.getUserById(post.userId);
        if (user != null && user.postCount > 0) {
          await UserService.updateUser(user.copyWith(postCount: user.postCount - 1));
        }
      }
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  static Future<void> toggleSavePost(String userId, String postId) async {
    try {
      final saveRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(postId);

      final doc = await saveRef.get();
      final postRef = _firestore.collection('posts').doc(postId);

      if (doc.exists) {
        await saveRef.delete();
        await postRef.update({'saveCount': FieldValue.increment(-1)});
      } else {
        await saveRef.set({
          'postId': postId,
          'savedAt': FieldValue.serverTimestamp(),
        });
        await postRef.update({'saveCount': FieldValue.increment(1)});
      }
    } catch (e) {
      throw Exception('Failed to toggle save: $e');
    }
  }

  static Future<bool> isPostSaved(String userId, String postId) async {
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

  static Future<List<Post>> getWishlistPosts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .orderBy('savedAt', descending: true)
          .get();

      List<Post> wishlist = [];
      for (var doc in snapshot.docs) {
        final post = await getPostById(doc.id);
        if (post != null) {
          wishlist.add(post);
        } else {
          // Cleanup dead links
          await doc.reference.delete();
        }
      }
      return wishlist;
    } catch (e) {
      // Fallback if index not ready
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .get();
      
      List<Post> wishlist = [];
      for (var doc in snapshot.docs) {
        final post = await getPostById(doc.id);
        if (post != null) {
          wishlist.add(post);
        } else {
          await doc.reference.delete();
        }
      }
      return wishlist;
    }
  }
}
