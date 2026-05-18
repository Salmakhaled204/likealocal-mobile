import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';

/// Unique WorkManager task identifiers.
const proximityTaskUniqueName = 'likealocal_proximity';
const proximityTaskName = 'proximity_check';

/// WorkManager callback — runs in a separate isolate, even when the app is
/// killed. Everything must be re-initialised from scratch here.
@pragma('vm:entry-point')
void proximityCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != proximityTaskName) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      await ProximityService._backgroundCheck();
    } catch (e) {
      if (kDebugMode) print('ProximityService background error: $e');
    }
    return true;
  });
}

/// Periodically checks whether the user is near any of their saved (favourite)
/// places and fires a local notification when within [_radiusMeters].
///
/// • Foreground: [start] sets up a [Timer.periodic] (every 5 min).
/// • Background / killed: WorkManager fires [_backgroundCheck] (every 15 min).
class ProximityService {
  ProximityService._();

  static const double _radiusMeters = 500.0;
  static const int _cooldownMinutes = 30;

  static const AndroidNotificationChannel proximityChannel =
      AndroidNotificationChannel(
    'likealocal_proximity',
    'Nearby Places',
    description: 'Notifications when you are near a saved place',
    importance: Importance.defaultImportance,
  );

  static Timer? _timer;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call when the user logs in. Starts the foreground timer and registers
  /// the WorkManager periodic task for true background execution.
  static Future<void> start() async {
    // Foreground: check every 5 min while app is open
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _foregroundCheck(),
    );
    _foregroundCheck();

    // Background: WorkManager fires every 15 min even when app is killed
    await Workmanager().initialize(proximityCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      proximityTaskUniqueName,
      proximityTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Call when the user logs out.
  static void stop() {
    _timer?.cancel();
    _timer = null;
    Workmanager().cancelByUniqueName(proximityTaskUniqueName);
  }

  // ── Foreground check (uses plugin already initialised by NotificationService)

  static Future<void> _foregroundCheck() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Reuse the plugin instance initialised (with tap handler) by
    // NotificationService so we don't overwrite onDidReceiveNotificationResponse.
    final plugin = FlutterLocalNotificationsPlugin();
    await _doCheck(uid, plugin);
  }

  // ── Background check (fresh isolate — everything re-initialised) ───────────

  static Future<void> _backgroundCheck() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(proximityChannel);
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _doCheck(uid, plugin);
  }

  // ── Core logic ─────────────────────────────────────────────────────────────

  static Future<void> _doCheck(
      String uid, FlutterLocalNotificationsPlugin plugin) async {
    // Location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (kDebugMode) print('ProximityService: location error: $e');
      return;
    }

    // Load user's saved places (favourites)
    final favSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .get();
    if (favSnap.docs.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    for (final favDoc in favSnap.docs) {
      final placeId = favDoc.id;

      // Per-place cooldown to avoid spam
      final cooldownKey = 'prox_$placeId';
      final lastMs = prefs.getInt(cooldownKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (elapsed < _cooldownMinutes * 60 * 1000) continue;

      // Fetch place details for coordinates
      DocumentSnapshot placeDoc;
      try {
        placeDoc = await FirebaseFirestore.instance
            .collection('places')
            .doc(placeId)
            .get();
      } catch (_) {
        continue;
      }
      if (!placeDoc.exists) continue;

      final data = placeDoc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final geoPoint = data['location'] as GeoPoint?;
      if (geoPoint == null) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        geoPoint.latitude,
        geoPoint.longitude,
      );

      if (distance <= _radiusMeters) {
        final name = (data['title'] as String?)?.isNotEmpty == true
            ? data['title'] as String
            : 'a saved place';
        await _fireNotification(plugin, uid, placeId, name, distance.round());
        await prefs.setInt(cooldownKey, DateTime.now().millisecondsSinceEpoch);
      }
    }
  }

  static Future<void> _fireNotification(
    FlutterLocalNotificationsPlugin plugin,
    String uid,
    String placeId,
    String placeName,
    int distanceM,
  ) async {
    await plugin.show(
      placeId.hashCode,
      "You're near $placeName!",
      "One of your saved places is ${distanceM}m away. Tap to view.",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'likealocal_proximity',
          'Nearby Places',
          channelDescription: 'Notifications when you are near a saved place',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      // Payload lets the tap handler navigate to the exact place
      payload: 'proximity:$placeId',
    );

    // Persist to Firestore notification history
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'type': 'proximity',
        'title': "You're near $placeName!",
        'body': "One of your saved places is ${distanceM}m away.",
        'placeId': placeId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
