import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs.
  // No UI work here; the system tray notification is shown automatically by FCM.
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'wanderlens_notifications',
    'WanderLens Notifications',
    description: 'Notifications for likes, comments, friend requests and wishlists.',
    importance: Importance.high,
  );

  /// Call once after Firebase.initializeApp() in main().
  static Future<void> initialize() async {
    // 1. Register background handler before anything else.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission (Android 13+ / iOS).
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Create the Android notification channel for foreground messages.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Initialise flutter_local_notifications.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

    // 5. Save/refresh FCM token whenever it changes.
    await _saveToken();
    _messaging.onTokenRefresh.listen((_) => _saveToken());

    // 6. Show a local notification for messages that arrive while the app
    //    is in the foreground (FCM suppresses the system notification then).
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // 7. Handle notification tap when the app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 8. Handle notification tap that launched the app from terminated state.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // ── Token management ─────────────────────────────────────────────────────

  static Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    }
  }

  /// Call this after a user logs in to make sure their token is up-to-date.
  static Future<void> refreshTokenForCurrentUser() => _saveToken();

  // ── Foreground notification display ──────────────────────────────────────

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null || android == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── Notification tap handler ──────────────────────────────────────────────

  static void _handleNotificationTap(RemoteMessage message) {
    // Navigation from here requires a NavigatorKey. The app navigates to the
    // NotificationScreen on the next build cycle via the data payload if needed.
    // For now, the in-app StreamBuilder badge handles discoverability.
  }
}
