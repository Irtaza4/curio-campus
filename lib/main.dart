import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curio_campus/screens/splash_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/providers/matchmaking_provider.dart';
import 'package:curio_campus/providers/emergency_provider.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Define a single global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Update the main function to handle notification clicks
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.setupBackgroundNotifications();

  // Handle notification click when app is terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      // Handle the notification click based on the data
      debugPrint('App opened from terminated state via notification: ${message.data}');

      // Store the notification data to handle it after app is initialized
      // This will be used in the first screen to navigate to the appropriate screen
      final prefs = SharedPreferences.getInstance();
      prefs.then((instance) {
        instance.setString('initial_notification', jsonEncode(message.data));
      });
    }
  });

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => MatchmakingProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // Add the navigator key
        title: 'CurioCampus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

