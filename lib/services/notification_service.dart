import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initNotifications() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await messaging.requestPermission();

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _localNotifications.initialize(settings: initSettings);

      final token = await messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) async {
        await _saveFcmToken(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // ignore: avoid_print
        print('Notification received: ${message.notification?.title}');
        
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'vibzcheck_channel',
                'Vibzcheck Notifications',
                channelDescription: 'Important room events and updates',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // ignore: avoid_print
        print('Notification opened: ${message.data}');
      });
    } catch (e) {
      // Keep startup and hot restart alive even if FCM isn't ready.
      // ignore: avoid_print
      print('Notification init skipped: $e');
    }
  }

  Future<void> subscribeToRoomTopic(String roomId) async {
    try {
      await messaging.subscribeToTopic('room_$roomId');
    } catch (_) {
      // Keep room actions resilient even if topic subscription fails.
    }
  }

  Future<void> syncCurrentUserToken() async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }
    } catch (_) {
      // Ignore token sync errors to avoid blocking auth flow.
    }
  }

  Future<void> unsubscribeFromRoomTopic(String roomId) async {
    try {
      await messaging.unsubscribeFromTopic('room_$roomId');
    } catch (_) {
      // Ignore topic unsubscription failures.
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final user = auth.currentUser;
    if (user == null) return;

    await db.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await db.collection('users').doc(user.uid).collection('devices').doc(token).set({
      'token': token,
      'platform': 'flutter',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}