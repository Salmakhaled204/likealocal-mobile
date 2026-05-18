import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place.dart';
import '../screens/chat_screen.dart';
import '../screens/place_details_screen.dart';

/// Handles Firebase Cloud Messaging (push notifications) and local notification
/// tap navigation.
///
/// Call [NotificationService.initialize] once from main() after Firebase.initializeApp().
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _fcmChannel =
      AndroidNotificationChannel(
        'likealocal_channel',
        'LikeALocal Notifications',
        description: 'Place recommendations and chat messages',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _proximityChannel =
      AndroidNotificationChannel(
        'likealocal_proximity',
        'Nearby Places',
        description: 'Notifications when you are near a saved place',
        importance: Importance.defaultImportance,
      );

  // Assigned from main.dart so we can navigate on notification tap
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> initialize() async {
    // ── 1. Create notification channels ──────────────────────────────────────
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_fcmChannel);
    await androidImpl?.createNotificationChannel(_proximityChannel);
    await androidImpl?.requestNotificationsPermission();

    // ── 2. Initialise plugin with local-notification tap handler ─────────────
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
=========
  static Future<void> initialize() async {
    // ── 1. Local notifications plugin setup (for foreground messages) ──────
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
>>>>>>>>> Temporary merge branch 2
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handleLocalTap(payload);
        }
      },
    );

    // Handle tap when the app was killed and the user tapped a local notification
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        // Delay slightly so the navigator is ready
        Future.delayed(const Duration(milliseconds: 600), () {
          _handleLocalTap(payload);
        });
      }
    }

    // ── 3. Request FCM permission ────────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      print('Notification permission: ${settings.authorizationStatus}');
    }

    // ── 4. Save / refresh FCM token ──────────────────────────────────────────
    await syncTokenForCurrentUser();
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateToken);

    // ── 5. Handle FCM messages ───────────────────────────────────────────────

    // Foreground: show banner + persist to history
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
              _fcmChannel.id,
              _fcmChannel.name,
              channelDescription: _fcmChannel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: _fcmPayload(message.data),
        );
      }

      _saveNotification(
        title: notification?.title ?? message.data['title'] ?? '',
        body: notification?.body ?? message.data['body'] ?? '',
        type: message.data['type'] as String?,
      );
    });

    // Background / terminated: navigate when user taps the FCM notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) print('FCM notification tapped: ${message.data}');
      _handleFcmTap(message.data);
    });

    // App launched from killed state via FCM tap
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleFcmTap(initial.data);
    }
  }

  // ── Tap handlers ───────────────────────────────────────────────────────────

  /// Handles taps on LOCAL notifications (proximity alerts shown by the device).
  /// Payload format: `proximity:<placeId>`
  static Future<void> _handleLocalTap(String payload) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    if (payload.startsWith('chat:')) {
      final parts = payload.split(':');
      if (parts.length >= 3) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: parts[1],
              otherUserId: parts[2],
              otherUserName: parts.length >= 4 && parts[3].isNotEmpty
                  ? parts.sublist(3).join(':')
                  : 'User',
            ),
          ),
        );
        return;
      }
    }

    if (payload.startsWith('proximity:')) {
      final placeId = payload.substring('proximity:'.length);
      try {
        final doc = await FirebaseFirestore.instance
            .collection('places')
            .doc(placeId)
            .get();
        if (doc.exists) {
          final place = Place.fromFirestore(doc);
          nav.push(
            MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
          );
          return;
        }
      } catch (_) {}
    }

    // Fallback: open notification history
    nav.pushNamed('/notifications');
  }

  /// Handles taps on FCM push notifications.
  /// Navigates to the exact chat or falls back to /notifications.
  static void _handleFcmTap(Map<String, dynamic> data) {
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    final type = data['type'] as String?;
    final chatId = data['chatId'] as String?;
    final otherUserId = data['otherUserId'] as String?;

    if (type == 'chat' && chatId != null && otherUserId != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserId: otherUserId,
            otherUserName: (data['otherUserName'] as String?) ?? 'User',
          ),
        ),
      );
    } else {
      nav.pushNamed('/notifications');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts FCM data map to a local-notification payload string so that
  /// if a foreground FCM notification is tapped it can also deep-link.
  static String? _fcmPayload(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'chat') {
      final chatId = data['chatId'] as String?;
      final otherId = data['otherUserId'] as String?;
      final otherName = data['otherUserName'] as String? ?? '';
      if (chatId != null && otherId != null) {
        return 'chat:$chatId:$otherId:$otherName';
      }
    }
    return null;
  }

  static Future<void> _saveNotification({
    required String title,
    required String body,
    String? type,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || (title.isEmpty && body.isEmpty)) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
          'type': type ?? 'general',
          'title': title,
          'body': body,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

<<<<<<<<< Temporary merge branch 1
  static Future<void> syncTokenForCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
=========
  static Future<void> _saveToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) print('FCM token saved: $token');
    } catch (e) {
      if (kDebugMode) print('Could not save FCM token: $e');
    }
  }

  static Future<void> _updateToken(String token) async {
<<<<<<<<< Temporary merge branch 1
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      if (kDebugMode) print('Could not refresh FCM token: $e');
=========
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('Could not update FCM token: $e');
>>>>>>>>> Temporary merge branch 2
    }
  }
}

/// Top-level handler required by FCM for background/terminated messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) print('Background message: ${message.messageId}');
}
