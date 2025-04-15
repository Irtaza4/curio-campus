import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:curio_campus/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

// Global reference to services for easy access
late CallService callService;
late NotificationService notificationService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.setupBackgroundNotifications();

  // Ensure FCM token is updated on app start
  await notificationService.updateFCMToken();

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


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp();

  // Handle background notifications here
  if (message.data['type'] == 'call') {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      // Use default sound instead of custom ringtone
      // sound: RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
      actions: [
        AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
        AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
      ],
    );

    final callId = int.tryParse(message.data['callId'] ?? '0') ?? 0;
    final callerName = message.data['callerName'] ?? 'Unknown';
    final callType = message.data['callType'] ?? 'voice';

    // Convert the call ID to a valid notification ID (within 32-bit integer range)
    final notificationId = callId % 100000; // Use modulo to get a smaller number

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      callerName,
      NotificationDetails(android: androidPlatformChannelSpecifics),
      payload: 'call:$callId',
    );
  }
}
