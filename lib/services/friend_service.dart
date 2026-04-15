import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/friend_request.dart';
import 'package:wanderlens/models/user_friend.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/models/notification_model.dart';
import 'package:wanderlens/services/user_service.dart';
import 'package:wanderlens/services/notification_service.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<FriendRequest>> getPendingRequestsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('receiverId', isEqualTo: userId)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .get();
      return snapshot.docs.map((doc) => FriendRequest.fromJson(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<FriendRequest?> getFriendRequest(String senderId, String receiverId) async {
    try {
      final docId = '${senderId}_$receiverId';
      final doc = await _firestore.collection('friend_requests').doc(docId).get();
      if (doc.exists) {
        return FriendRequest.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<FriendRequest> sendFriendRequest(String senderId, String receiverId) async {
    if (senderId == receiverId) {
      throw Exception('Cannot follow yourself');
    }

    final areFriends = await areUsersFriends(senderId, receiverId);
    if (areFriends) {
      throw Exception('Already friends');
    }

    final docId = '${senderId}_$receiverId';
    final docRef = _firestore.collection('friend_requests').doc(docId);

    final doc = await docRef.get();
    if (doc.exists) {
      final existing = FriendRequest.fromJson(doc.data()!);
      if (existing.status == FriendRequestStatus.pending) {
        return existing;
      }
    }

    final request = FriendRequest(
      id: docId,
      senderId: senderId,
      receiverId: receiverId,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(request.toJson());

    final sender = await UserService.getUserById(senderId);
    if (sender != null) {
      await NotificationService.createNotification(
        receiverId: receiverId,
        sender: sender,
        type: NotificationType.friendRequest,
      );
    }

    return request;
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    try {
      final docRef = _firestore.collection('friend_requests').doc(requestId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final request = FriendRequest.fromJson(doc.data()!);
        
        await docRef.update({
          'status': FriendRequestStatus.accepted.name,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        await _createFriendship(request.senderId, request.receiverId);
      }
    } catch (e) {
      throw Exception('Failed to accept request: $e');
    }
  }

  static Future<void> rejectFriendRequest(String requestId) async {
    try {
      final docRef = _firestore.collection('friend_requests').doc(requestId);
      await docRef.update({
        'status': FriendRequestStatus.rejected.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  static Future<bool> areUsersFriends(String userId1, String userId2) async {
    try {
      final doc1 = await _firestore.collection('user_friends').doc('${userId1}_$userId2').get();
      if (doc1.exists) return true;
      
      final doc2 = await _firestore.collection('user_friends').doc('${userId2}_$userId1').get();
      return doc2.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get list of users who follow the given [userId].
  static Future<List<User>> getFollowers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_friends')
          .where('friendId', isEqualTo: userId)
          .get();

      final followers = <User>[];
      for (final doc in snapshot.docs) {
        final data = UserFriend.fromJson(doc.data());
        final user = await UserService.getUserById(data.userId);
        if (user != null) followers.add(user);
      }
      return followers;
    } catch (e) {
      return [];
    }
  }

  /// Get list of users that the given [userId] is following.
  static Future<List<User>> getFollowing(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId)
          .get();
      
      List<User> following = [];
      for (var doc in snapshot.docs) {
        final friendData = UserFriend.fromJson(doc.data());
        final user = await UserService.getUserById(friendData.friendId);
        if (user != null) following.add(user);
      }
      return following;
    } catch (e) {
      return [];
    }
  }

  static Future<List<User>> getFriends(String userId) async {
    try {
      final friends = <String, User>{};
      final following = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in following.docs) {
        final data = UserFriend.fromJson(doc.data());
        final user = await UserService.getUserById(data.friendId);
        if (user != null) friends[user.id] = user;
      }
      final followers = await _firestore
          .collection('user_friends')
          .where('friendId', isEqualTo: userId)
          .get();
      for (final doc in followers.docs) {
        final data = UserFriend.fromJson(doc.data());
        final user = await UserService.getUserById(data.userId);
        if (user != null) friends[user.id] = user;
      }
      return friends.values.toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _createFriendship(String userId1, String userId2) async {
    final docId = '${userId1}_$userId2';
    final docRef = _firestore.collection('user_friends').doc(docId);
    
    final doc = await docRef.get();
    if (doc.exists) return;

    final friendship = UserFriend(
      id: docId,
      userId: userId1,
      friendId: userId2,
      createdAt: DateTime.now(),
    );

    await docRef.set(friendship.toJson());

    final user1 = await UserService.getUserById(userId1);
    final user2 = await UserService.getUserById(userId2);
    
    if (user1 != null) {
      await UserService.updateUser(user1.copyWith(friendCount: user1.friendCount + 1));
    }
    if (user2 != null) {
      await UserService.updateUser(user2.copyWith(friendCount: user2.friendCount + 1));
    }
  }

  static Future<void> removeFriend(String userId1, String userId2) async {
    try {
      await _firestore.collection('user_friends').doc('${userId1}_$userId2').delete();
      await _firestore.collection('user_friends').doc('${userId2}_$userId1').delete();

      final user1 = await UserService.getUserById(userId1);
      final user2 = await UserService.getUserById(userId2);
      
      if (user1 != null && user1.friendCount > 0) {
        await UserService.updateUser(user1.copyWith(friendCount: user1.friendCount - 1));
      }
      if (user2 != null && user2.friendCount > 0) {
        await UserService.updateUser(user2.copyWith(friendCount: user2.friendCount - 1));
      }
      
      final doc1 = '${userId1}_$userId2';
      final doc2 = '${userId2}_$userId1';
      await _firestore.collection('friend_requests').doc(doc1).delete();
      await _firestore.collection('friend_requests').doc(doc2).delete();
      
    } catch (e) {
      throw Exception('Failed to unfriend: $e');
    }
  }
}
