import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'services/notification_service.dart';

import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kReleaseMode) {
    // App Check can be enabled here later
  }

  await NotificationService().initNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const VibzcheckApp(),
    ),
  );
}

class VibzcheckApp extends StatelessWidget {
  const VibzcheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Vibzcheck',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const LoginScreen(),
        );
      },
    );
  }
}