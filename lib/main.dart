import 'package:curio_campus/services/app_initialization_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/providers/matchmaking_provider.dart';
import 'package:curio_campus/providers/emergency_provider.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/providers/theme_provider.dart';
import 'package:curio_campus/screens/splash_screen.dart';
import 'package:curio_campus/utils/navigator_key.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';
import 'package:curio_campus/services/notification_service.dart';
import 'package:curio_campus/services/call_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Global reference to services for easy access
final CallService callService = CallService();
final NotificationService notificationService = NotificationService();

void main() async {
  await AppInitializationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationHandling();
    notificationService.checkPendingNotifications();
  }

  void _setupNotificationHandling() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
            'Message also contained a notification: ${message.notification}');
        // Show local notification
        notificationService.handleForegroundMessage(message);
      }
    });

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          'A notification was clicked when the app was in the background!');
      notificationService.handleNotificationData(message.data);
    });
  }

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
            routes: {
              '/chat': (context) => const ChatScreen(chatId: '', chatName: ''),
              '/emergency-detail': (context) =>
                  const EmergencyRequestDetailScreen(
                      requestId: '', isOwnRequest: false),
              '/project-detail': (context) =>
                  const ProjectDetailScreen(projectId: ''),
            },
          );
        },
      ),
    );
  }
}
