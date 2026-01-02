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
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curio_campus/utils/navigator_key.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';
import 'package:curio_campus/services/app_initialization_service.dart'; // Assuming this new import is needed

// Global reference to services for easy access
late CallService callService;
late NotificationService notificationService;

void main() async {
  await AppInitializationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationHandling();
    _checkPendingNotifications();
  }

  Future<void> _checkPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check for initial notification
      final initialNotificationJson = prefs.getString('initial_notification');
      if (initialNotificationJson != null) {
        final initialNotification =
            json.decode(initialNotificationJson) as Map<String, dynamic>;

        // Clear the stored notification
        await prefs.remove('initial_notification');

        // Handle the notification after the app is fully initialized
        Future.delayed(const Duration(seconds: 2), () {
          _handleNotificationData(initialNotification);
        });
      }

      // Check for pending messages
      final pendingMessages = prefs.getStringList('pending_messages') ?? [];
      if (pendingMessages.isNotEmpty) {
        // Process messages that are less than 24 hours old
        final now = DateTime.now().millisecondsSinceEpoch;
        final recentMessages = <Map<String, dynamic>>[];

        for (final messageJson in pendingMessages) {
          try {
            final message = json.decode(messageJson) as Map<String, dynamic>;
            final timestamp = message['timestamp'] as int?;

            // Only process messages less than 24 hours old
            if (timestamp != null && now - timestamp < 24 * 60 * 60 * 1000) {
              recentMessages.add(message);
            }
          } catch (e) {
            debugPrint('Error parsing message: $e');
          }
        }

        // Clear pending messages
        await prefs.setStringList('pending_messages', []);

        // Process the most recent message after a delay
        if (recentMessages.isNotEmpty) {
          // Sort by timestamp (newest first)
          recentMessages.sort((a, b) => (b['timestamp'] as int? ?? 0)
              .compareTo(a['timestamp'] as int? ?? 0));

          // Process the most recent message
          Future.delayed(const Duration(seconds: 2), () {
            final mostRecent = recentMessages.first;
            final chatId = mostRecent['chatId'] as String?;
            final chatName = mostRecent['chatName'] as String?;

            if (chatId != null &&
                chatName != null &&
                navigatorKey.currentContext != null) {
              Navigator.push(
                navigatorKey.currentContext!,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatId: chatId,
                    chatName: chatName,
                  ),
                ),
              );
            }
          });
        }
      }

      // Check for pending calls
      final pendingCallJson = prefs.getString('pending_call');
      if (pendingCallJson != null) {
        try {
          final pendingCall =
              json.decode(pendingCallJson) as Map<String, dynamic>;
          final timestamp = pendingCall['timestamp'] as int?;

          // Only process calls that are less than 60 seconds old
          if (timestamp != null &&
              DateTime.now().millisecondsSinceEpoch - timestamp < 60000) {
            // Handle the pending call after the app is fully initialized
            Future.delayed(const Duration(seconds: 2), () {
              final callId = pendingCall['callId'] as String?;
              final callerId = pendingCall['callerId'] as String?;
              final callerName = pendingCall['callerName'] as String?;
              final callType = pendingCall['callType'] as String?;

              if (callId != null && callerId != null) {
                callService.handleIncomingCallFromNotification(
                  callId: callId,
                  callerId: callerId,
                  callerName: callerName ?? 'Unknown',
                  isVideoCall: callType == 'video',
                  callerProfileImage: null,
                );
              }
            });
          }

          // Clear the pending call data
          await prefs.remove('pending_call');
        } catch (e) {
          debugPrint('Error processing pending call: $e');
          await prefs.remove('pending_call');
        }
      }
    } catch (e) {
      debugPrint('Error checking pending notifications: $e');
    }
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
      _handleNotificationData(message.data);
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Handle navigation based on notification type
    final notificationType = data['type'];

    switch (notificationType) {
      case 'chat':
        final chatId = data['chatId'];
        final chatName = data['chatName'];
        if (chatId != null && navigatorKey.currentContext != null) {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                chatName: chatName ?? 'Chat',
              ),
            ),
          );
        }
        break;
      case 'call':
        final callId = data['callId'];
        final callerId = data['callerId'];
        final callerName = data['callerName'];
        final isVideoCall = data['callType'] == 'video';
        final callerImage = data['callerImage'];

        if (callId != null && callerId != null) {
          callService.handleIncomingCallFromNotification(
            callId: callId,
            callerId: callerId,
            callerName: callerName ?? 'Unknown',
            isVideoCall: isVideoCall,
            callerProfileImage: callerImage,
          );
        }
        break;
      case 'emergency':
        final requestId = data['requestId'];
        if (requestId != null && navigatorKey.currentContext != null) {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => EmergencyRequestDetailScreen(
                requestId: requestId,
                isOwnRequest: data['isOwnRequest'] == 'true',
              ),
            ),
          );
        }
        break;
      case 'project':
        final projectId = data['projectId'];
        if (projectId != null && navigatorKey.currentContext != null) {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(
                projectId: projectId,
              ),
            ),
          );
        }
        break;
    }
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
