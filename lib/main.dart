import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Keep App Check out of debug builds so local auth works even when the
  // Firebase App Check API is not enabled for this project.
  if (kReleaseMode) {
    // App Check can be enabled here later with production providers.
  }

  await NotificationService().initNotifications();

  runApp(const VibzcheckApp());
}

class VibzcheckApp extends StatelessWidget {
  const VibzcheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibzcheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LoginScreen(),
    );
  }
}