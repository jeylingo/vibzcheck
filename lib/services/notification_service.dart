import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    await messaging.requestPermission();

    final token = await messaging.getToken();
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notification received: ${message.notification?.title}');
    });
  }
}