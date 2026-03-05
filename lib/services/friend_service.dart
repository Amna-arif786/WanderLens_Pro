import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/friend_request.dart';
import 'package:wanderlens/models/user_friend.dart';
import 'package:wanderlens/models/user.dart';
import 'package:wanderlens/services/user_service.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Friend Requests (Follow Requests)
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
      final snapshot = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: receiverId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return FriendRequest.fromJson(snapshot.docs.first.data());
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
      throw Exception('Already following this user');
    }

    final docRef = _firestore.collection('friend_requests').doc();
    final request = FriendRequest(
      id: docRef.id,
      senderId: senderId,
      receiverId: receiverId,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(request.toJson());
    return request;
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    try {
      final docRef = _firestore.collection('friend_requests').doc(requestId);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final request = FriendRequest.fromJson(doc.data()!);
        
        // Update request status
        await docRef.update({
          'status': FriendRequestStatus.accepted.name,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // Create friendship (Follow connection)
        await _createFriendship(request.senderId, request.receiverId);
      }
    } catch (e) {
      throw Exception('Failed to accept request: $e');
    }
  }

  static Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friend_requests').doc(requestId).update({
        'status': FriendRequestStatus.rejected.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to reject request: $e');
    }
  }

  // User Friends (Following/Followers)
  static Future<bool> areUsersFriends(String userId1, String userId2) async {
    try {
      final snapshot = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId1)
          .where('friendId', isEqualTo: userId2)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) return true;

      final reverseSnapshot = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId2)
          .where('friendId', isEqualTo: userId1)
          .limit(1)
          .get();
          
      return reverseSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get list of users that the given [userId] is following..
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

  /// Returns all friends (both directions: sent+accepted OR received+accepted)..
  static Future<List<User>> getFriends(String userId) async {
    try {
      final friends = <String, User>{};
      // People I sent request to and they accepted (userId = me, friendId = them)..
      final following = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in following.docs) {
        final data = UserFriend.fromJson(doc.data());
        final user = await UserService.getUserById(data.friendId);
        if (user != null) friends[user.id] = user;
      }
      // People who sent request to me and I accepted (friendId = me, userId = them)..
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

  /// Get list of users who are following the given [userId]..
  static Future<List<User>> getFollowers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('user_friends')
          .where('friendId', isEqualTo: userId)
          .get();
      
      List<User> followers = [];
      for (var doc in snapshot.docs) {
        final friendData = UserFriend.fromJson(doc.data());
        final user = await UserService.getUserById(friendData.userId);
        if (user != null) followers.add(user);
      }
      return followers;
    } catch (e) {
      return [];
    }
  }

  static Future<void> _createFriendship(String userId1, String userId2) async {
    final docRef = _firestore.collection('user_friends').doc();
    final friendship = UserFriend(
      id: docRef.id,
      userId: userId1,
      friendId: userId2,
      createdAt: DateTime.now(),
    );

    await docRef.set(friendship.toJson());

    // Update follow counts for both users..
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
      final snapshot = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId1)
          .where('friendId', isEqualTo: userId2)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      final reverseSnapshot = await _firestore
          .collection('user_friends')
          .where('userId', isEqualTo: userId2)
          .where('friendId', isEqualTo: userId1)
          .get();
          
      for (var doc in reverseSnapshot.docs) {
        await doc.reference.delete();
      }

      // Update follow counts..
      final user1 = await UserService.getUserById(userId1);
      final user2 = await UserService.getUserById(userId2);
      
      if (user1 != null && user1.friendCount > 0) {
        await UserService.updateUser(user1.copyWith(friendCount: user1.friendCount - 1));
      }
      if (user2 != null && user2.friendCount > 0) {
        await UserService.updateUser(user2.copyWith(friendCount: user2.friendCount - 1));
      }
      
      final reqSnapshot = await _firestore
          .collection('friend_requests')
          .where('senderId', whereIn: [userId1, userId2])
          .get();
      
      for (var doc in reqSnapshot.docs) {
        final data = doc.data();
        if ((data['senderId'] == userId1 && data['receiverId'] == userId2) ||
            (data['senderId'] == userId2 && data['receiverId'] == userId1)) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      throw Exception('Failed to unfollow: $e');
    }
  }

  static Future<void> firebase() async {}
}
