import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderlens/models/notification_model.dart';
import 'package:wanderlens/models/user.dart';
import 'package:uuid/uuid.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'notifications';

  // Create a new notification..
  static Future<void> createNotification({
    required String receiverId,
    required User sender,
    required NotificationType type,
    String? postId,
  }) async {
    // Don't notify if sender is receiver..
    if (receiverId == sender.id) return;

    final id = const Uuid().v4();
    final notification = NotificationModel(
      id: id,
      senderId: sender.id,
      receiverId: receiverId,
      senderName: sender.displayName,
      senderProfilePic: sender.profileImageUrl,
      type: type,
      postId: postId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    try {
      await _firestore.collection(_collection).doc(id).set(notification.toJson());
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Get real-time notifications stream for a user..
  static Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    // Removed .orderBy() from here to avoid the need for a composite index.
    // Sorting is now handled in memory below.
    return _firestore
        .collection(_collection)
        .where('receiverId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
            .map((doc) => NotificationModel.fromJson(doc.data()))
            .toList();
          
          // Sort in memory: newest first
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  // Get unread notifications count stream..
  static Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark a specific notification as read..
  static Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collection).doc(notificationId).update({'isRead': true});
  }

  // Mark all notifications for a user as read..
  static Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final unread = await _firestore
        .collection(_collection)
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
