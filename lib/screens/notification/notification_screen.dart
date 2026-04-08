import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wanderlens/models/notification_model.dart';
import 'package:wanderlens/services/notification_service.dart';
import 'package:wanderlens/widgets/user_avatar.dart';
import 'package:intl/intl.dart';
import '../../responsive/constrained_scaffold.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // Mark notifications as read only after a short delay or when screen is built
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        NotificationService.markAllAsRead(_currentUserId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedScaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () => NotificationService.markAllAsRead(_currentUserId),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService.getNotificationsStream(_currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: colorScheme.primary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: notification.isRead ? Colors.transparent : colorScheme.primaryContainer.withOpacity(0.05),
      child: ListTile(
        onTap: () {
          NotificationService.markAsRead(notification.id);
          // Navigate to post or profile if needed
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatar(imageUrl: notification.senderProfilePic, size: 48),
        title: RichText(
          text: TextSpan(
            style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
            children: [
              TextSpan(text: '${notification.senderName} ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: _getNotificationText(notification.type)),
            ],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatTimestamp(notification.createdAt),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
        trailing: notification.isRead 
            ? null 
            : Container(width: 8, height: 8, decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle)),
      ),
    );
  }

  String _getNotificationText(NotificationType type) {
    switch (type) {
      case NotificationType.like: return 'liked your post.';
      case NotificationType.comment: return 'commented on your post.';
      case NotificationType.friendRequest: return 'sent you a friend request.';
      case NotificationType.wishlist: return 'added your post to their wishlist.';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return DateFormat('MMM d').format(timestamp);
  }
}
