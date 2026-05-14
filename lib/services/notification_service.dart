import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles Firebase Cloud Messaging (push notifications).
///
/// Call [NotificationService.initialize] once from main() after Firebase.initializeApp().
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'likealocal_channel',
    'LikeALocal Notifications',
    description: 'Place recommendations and chat messages',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    // ── 1. Local notifications plugin setup (for foreground messages) ──────
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // ── 2. Request permission ────────────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      print('Notification permission: ${settings.authorizationStatus}');
    }

    // ── 3. Save the FCM token to Firestore so the backend can target this device
    await _saveToken();

    // Refresh token when it rotates
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateToken);

    // ── 4. Handle messages ───────────────────────────────────────────────────

    // Foreground messages — show a local notification since FCM won't by default
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
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
    });

    // Background / terminated — message is available when the user taps the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) print('Notification tapped: ${message.data}');
      // TODO: Navigate to the relevant screen based on message.data['type']
      // e.g. if (message.data['type'] == 'chat') navigate to ChatScreen
    });
  }

  static Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
    });
    if (kDebugMode) print('FCM token saved: $token');
  }

  static Future<void> _updateToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
}

/// Top-level handler required by FCM for background/terminated messages.
/// Must be a top-level function (not inside a class).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) print('Background message: ${message.messageId}');
}