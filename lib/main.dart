import 'package:curio_campus/utils/constants.dart';
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
import 'package:curio_campus/utils/navigator_key.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';

// Global reference to services for easy access
late CallService callService;
late NotificationService notificationService;

// This must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp();

  // Handle background notifications here
  if (message.data['type'] == 'call') {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Create notification channel for Android
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'call_channel',
            'Call Notifications',
            description: 'Notifications for incoming calls',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'call_channel',
        'Call Notifications',
        channelDescription: 'Notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        playSound: true,
        enableVibration: true,
        actions: [
          const AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
          const AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
        ],
      );

      final iOSPlatformChannelSpecifics = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
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
        notificationDetails,
        payload: 'call:$callId',
      );

      // Save call data to shared preferences for when app is opened
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_call', json.encode({
        'callId': callId.toString(),
        'callerId': message.data['callerId'],
        'callerName': callerName,
        'callType': callType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));
    } catch (e) {
      debugPrint('Error handling call notification in background: $e');
    }
  } else if (message.data['type'] == 'chat') {
    // Handle chat message notifications
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Create notification channel for Android
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'chat_channel',
            'Chat Notifications',
            description: 'Notifications for new messages',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      final senderName = message.data['senderName'] ?? 'Someone';
      final messageContent = message.notification?.body ?? message.data['content'] ?? 'New message';
      final chatId = message.data['chatId'];
      final chatName = message.data['chatName'] ?? 'Chat';

      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'chat_channel',
        'Chat Notifications',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        category: AndroidNotificationCategory.message,
      );

      final iOSPlatformChannelSpecifics = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Generate a unique notification ID
      final notificationId = chatId != null
          ? chatId.hashCode % 100000
          : DateTime.now().millisecondsSinceEpoch % 100000;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        senderName,
        messageContent,
        notificationDetails,
        payload: json.encode(message.data),
      );

      // Save message data to shared preferences for when app is opened
      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = prefs.getStringList('pending_messages') ?? [];
      pendingMessages.add(json.encode({
        'chatId': chatId,
        'chatName': chatName,
        'senderName': senderName,
        'content': messageContent,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      // Keep only the last 10 messages
      if (pendingMessages.length > 10) {
        pendingMessages.removeAt(0);
      }

      await prefs.setStringList('pending_messages', pendingMessages);
    } catch (e) {
      debugPrint('Error handling chat notification in background: $e');
    }
  } else {
    // For other notification types
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Create notification channel for Android
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            description: 'This channel is used for important notifications.',
            importance: Importance.max,
          ),
        );
      }

      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );print('Firebase Project ID: ${Firebase.app().options.projectId}');

      await flutterLocalNotificationsPlugin.show(
        message.hashCode % 100000, // Ensure ID is within 32-bit integer range
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        notificationDetails,
        payload: json.encode(message.data),
      );
    } catch (e) {
      debugPrint('Error handling notification in background: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  print('Firebase Project ID: ${Firebase.app().options.projectId}');
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notification service
  notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.setupBackgroundNotifications();

  // Ensure FCM token is updated on app start
  await notificationService.updateFCMToken();

  // Initialize call service with Agora App ID
  callService = CallService();
  await callService.initialize('c4a1309f72be434592965a29b64c1fd4');

  // Handle notification click when app is terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
    if (message != null) {
      // Handle the notification click based on the data
      debugPrint('App opened from terminated state via notification: ${message.data}');

      // Store the notification data to handle it after app is initialized
      // This will be used in the first screen to navigate to the appropriate screen
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('initial_notification', jsonEncode(message.data));
    }
  });

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
        final initialNotification = json.decode(initialNotificationJson) as Map<String, dynamic>;

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
          recentMessages.sort((a, b) =>
              (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));

          // Process the most recent message
          Future.delayed(const Duration(seconds: 2), () {
            final mostRecent = recentMessages.first;
            final chatId = mostRecent['chatId'] as String?;
            final chatName = mostRecent['chatName'] as String?;

            if (chatId != null && chatName != null && navigatorKey.currentContext != null) {
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
          final pendingCall = json.decode(pendingCallJson) as Map<String, dynamic>;
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
        debugPrint('Message also contained a notification: ${message.notification}');
        // Show local notification
        notificationService.handleForegroundMessage(message);
      }
    });

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A notification was clicked when the app was in the background!');
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
              '/emergency-detail': (context) => const EmergencyRequestDetailScreen(requestId: '', isOwnRequest: false),
              '/project-detail': (context) => const ProjectDetailScreen(projectId: ''),
            },
          );
        },
      ),
    );
  }
}
