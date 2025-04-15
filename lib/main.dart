import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curio_campus/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/providers/matchmaking_provider.dart';
import 'package:curio_campus/providers/emergency_provider.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/providers/theme_provider.dart';
import 'package:curio_campus/services/notification_service.dart';
import 'package:curio_campus/services/call_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curio_campus/utils/navigator_key.dart'; // Import the navigator key

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.setupBackgroundNotifications();

  // Initialize call service with Agora App ID
  final callService = CallService();
  await callService.initialize('c4a1309f72be434592965a29b64c1fd4');

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey, // Use the navigator key from utils
            title: 'CurioCampus',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
