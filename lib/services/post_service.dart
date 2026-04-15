import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:wanderlens/models/post.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/friend_service.dart';
import 'package:wanderlens/storage/cloudinary_service.dart';

class PostService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Feed / public queries (approved only) ─────────────────────────────────

  /// Returns all posts visible to [viewerId], **only approved posts**.
  static Future<List<Post>> getAllPosts({String? viewerId}) async {
    try {
      final snapshot = await _db
          .collection('posts')
          .where('status', isEqualTo: PostStatus.approved.name)
          .get();

      final allPosts =
          snapshot.docs.map((d) => Post.fromJson(d.data())).toList();

      if (viewerId == null) {
        return allPosts
            .where((p) => p.privacy == PostPrivacy.public)
            .toList();
      }

      final List<Post> filtered = [];
      for (final post in allPosts) {
        if (post.userId == viewerId || post.privacy == PostPrivacy.public) {
          filtered.add(post);
        } else if (post.privacy == PostPrivacy.friends) {
          if (await FriendService.areUsersFriends(viewerId, post.userId)) {
            filtered.add(post);
          }
        }
      }
      return filtered;
    } catch (_) {
      return [];
    }
  }

  static Future<Post?> getPostById(String id) async {
    try {
      final doc = await _db.collection('posts').doc(id).get();
      return doc.exists ? Post.fromJson(doc.data()!) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Post>> getPostsByUserId(
    String userId, {
    String? viewerId,
  }) async {
    try {
      // Removed status filter from query to allow owner to see pending posts
      final snapshot = await _db
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      final posts =
          snapshot.docs.map((d) => Post.fromJson(d.data())).toList();

      final isOwner = viewerId == userId;
      final areFriends = (!isOwner && viewerId != null)
          ? await FriendService.areUsersFriends(userId, viewerId)
          : false;

      final filtered = posts.where((post) {
        // Owner sees everything they uploaded
        if (isOwner) return post.status != PostStatus.rejected;
        
        // Others only see approved posts
        if (post.status != PostStatus.approved) return false;
        
        if (post.privacy == PostPrivacy.public) return true;
        if (post.privacy == PostPrivacy.friends && areFriends) return true;
        return false;
      }).toList();

      // Sort by creating a new mutable list to avoid "Unsupported operation: cannot modify an unmodifiable list"
      final List<Post> sortedList = List.from(filtered);
      sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return sortedList;
    } catch (_) {
      return [];
    }
  }

  static Stream<List<Post>> getPostsStreamByUserId(
    String userId, {
    String? viewerId,
  }) {
    // Removed status filter from query to allow real-time updates for owner
    return _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final posts =
          snapshot.docs.map((d) => Post.fromJson(d.data())).toList();

      final isOwner = viewerId == userId;
      final areFriends = (!isOwner && viewerId != null)
          ? await FriendService.areUsersFriends(userId, viewerId)
          : false;

      final filtered = posts.where((post) {
        // Owner sees everything except rejected
        if (isOwner) return post.status != PostStatus.rejected;

        // Others only see approved posts
        if (post.status != PostStatus.approved) return false;

        if (post.privacy == PostPrivacy.public) return true;
        if (post.privacy == PostPrivacy.friends && areFriends) return true;
        return false;
      }).toList();

      // Sort by creating a new mutable list to avoid sort errors
      final List<Post> sortedList = List.from(filtered);
      sortedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return sortedList;
    });
  }

  /// Main feed — only approved, ordered newest first.
  static Future<List<Post>> getFeedPosts(String currentUserId) async {
    try {
      final snapshot = await _db
          .collection('posts')
          .where('status', isEqualTo: PostStatus.approved.name)
          .orderBy('createdAt', descending: true)
          .get();

      final allPosts =
          snapshot.docs.map((d) => Post.fromJson(d.data())).toList();

      final following = await FriendService.getFollowing(currentUserId);
      final followingIds = following.map((u) => u.id).toSet();

      return allPosts.where((post) {
        if (post.userId == currentUserId) { return true; }
        if (post.privacy == PostPrivacy.public) { return true; }
        if (post.privacy == PostPrivacy.friends &&
            followingIds.contains(post.userId)) { return true; }
        return false;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  static Future<Post> createPost({
    required String userId,
    required String imageUrl,
    required String cloudinaryPublicId,
    required String caption,
    required String location,
    required String cityName,
    required PostStatus status,
    double? latitude,
    double? longitude,
    PostPrivacy privacy = PostPrivacy.public,
    double aiConfidenceScore = 0.0,
    List<String> aiDetectedLabels = const [],
    String aiVerificationSource = 'none',
  }) async {
    final user = await UserService.getUserById(userId);
    final docRef = _db.collection('posts').doc();

    final post = Post(
      id: docRef.id,
      userId: userId,
      username: user?.username ?? 'Unknown',
      userDisplayName: user?.displayName ?? 'Unknown',
      userProfileImage: user?.profileImageUrl,
      imageUrl: imageUrl,
      cloudinaryPublicId: cloudinaryPublicId,
      caption: caption,
      location: location,
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
      privacy: privacy,
      isVerified: status == PostStatus.approved,
      status: status,
      aiConfidenceScore: aiConfidenceScore,
      aiDetectedLabels: aiDetectedLabels,
      aiVerificationSource: aiVerificationSource,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(post.toJson());

    // Only count toward the user's total when approved
    if (status == PostStatus.approved && user != null) {
      await UserService.updateUser(
          user.copyWith(postCount: user.postCount + 1));
    }

    return post;
  }

  // ── Update / delete ───────────────────────────────────────────────────────

  static Future<Post> updatePost(Post post) async {
    final updated = post.copyWith(updatedAt: DateTime.now());
    await _db.collection('posts').doc(post.id).update(updated.toJson());
    return updated;
  }

  static Future<void> deletePost(String postId) async {
    final post = await getPostById(postId);
    if (post == null) return;

    final publicId = post.cloudinaryPublicId ??
        CloudinaryService.extractPublicId(post.imageUrl);
    if (publicId != null && publicId.isNotEmpty) {
      try {
        await CloudinaryService.deleteImage(publicId);
      } catch (e) {
        debugPrint('PostService.deletePost: Cloudinary delete failed: $e');
      }
    }

    // Delete subcollections
    for (final sub in ['comments', 'likes']) {
      final docs = await _db.collection('posts').doc(postId).collection(sub).get();
      for (final d in docs.docs) {
        await d.reference.delete();
      }
    }

    await _db
        .collection('users')
        .doc(post.userId)
        .collection('wishlist')
        .doc(postId)
        .delete();

    await _db.collection('posts').doc(postId).delete();

    if (post.status == PostStatus.approved) {
      final user = await UserService.getUserById(post.userId);
      if (user != null && user.postCount > 0) {
        await UserService.updateUser(
            user.copyWith(postCount: user.postCount - 1));
      }
    }
  }

  // ── Admin functions ───────────────────────────────────────────────────────

  /// Returns all posts with [status: pending] for admin review.
  static Future<List<Post>> getPendingPosts() async {
    try {
      final snapshot = await _db
          .collection('posts')
          .where('status', isEqualTo: PostStatus.pending.name)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((d) => Post.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Admin: approve a pending post.
  /// Sets status → approved and increments the author's post count.
  static Future<void> approvePost(String postId) async {
    final post = await getPostById(postId);
    if (post == null) return;

    await _db.collection('posts').doc(postId).update({
      'status': PostStatus.approved.name,
      'isVerified': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final user = await UserService.getUserById(post.userId);
    if (user != null) {
      await UserService.updateUser(
          user.copyWith(postCount: user.postCount + 1));
    }
  }

  /// Admin: reject a pending post.
  ///
  /// 1. Deletes the image from Cloudinary (using [cloudinaryPublicId]).
  /// 2. Sets status → rejected in Firestore (keeps audit trail).
  static Future<void> rejectPost(String postId) async {
    final post = await getPostById(postId);
    if (post == null) return;

    // Delete from Cloudinary
    final publicId = post.cloudinaryPublicId ??
        CloudinaryService.extractPublicId(post.imageUrl);
    if (publicId != null && publicId.isNotEmpty) {
      await CloudinaryService.deleteImage(publicId);
    }

    // Mark rejected in Firestore (tombstone for audit)
    await _db.collection('posts').doc(postId).update({
      'status': PostStatus.rejected.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ── Wishlist helpers (unchanged) ──────────────────────────────────────────

  static Future<void> toggleSavePost(String userId, String postId) async {
    final saveRef = _db
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(postId);

    final doc = await saveRef.get();
    final postRef = _db.collection('posts').doc(postId);

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
  }

  static Future<bool> isPostSaved(String userId, String postId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(postId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Post>> getWishlistPosts(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .orderBy('savedAt', descending: true)
          .get();

      final List<Post> wishlist = [];
      for (final doc in snapshot.docs) {
        final post = await getPostById(doc.id);
        if (post != null) {
          wishlist.add(post);
        } else {
          await doc.reference.delete();
        }
      }
      return wishlist;
    } catch (_) {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .get();

      final List<Post> wishlist = [];
      for (final doc in snapshot.docs) {
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
