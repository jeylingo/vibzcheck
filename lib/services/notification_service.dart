import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initNotifications() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await messaging.requestPermission();

      final token = await messaging.getToken();
      // ignore: avoid_print
      print('FCM Token: $token');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // ignore: avoid_print
        print('Notification received: ${message.notification?.title}');
      });
    } catch (e) {
      // Keep startup and hot restart alive even if FCM isn't ready.
      // ignore: avoid_print
      print('Notification init skipped: $e');
    }
  }
}