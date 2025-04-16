import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:curio_campus/models/notification_model.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/utils/navigator_key.dart';
import 'package:curio_campus/services/call_service.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Track if we've already initialized
  bool _isInitialized = false;

  // Initialize notification channels and request permissions
  Future<void> initialize() async {
    // Prevent duplicate initialization
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return;
    }

    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Configure local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
        _handleNotificationClick(response.payload);
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint(
            'Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A notification was clicked when the app was in the background!');
      _handleNotificationTap(message);
    });

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle when user taps on notification from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get FCM token and save it
    await _updateFCMToken();

    // Start periodic updates
    await startPeriodicUpdates();

    _isInitialized = true;
  }

  // Add this public method to your NotificationService class, after the initialize() method:

// Public method to handle foreground messages
  Future<void> handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Handling foreground message');
    return _showLocalNotification(message);
  }

  // Add a public method to update FCM token that can be called from main.dart
  // Add this method after the initialize() method

  Future<void> updateFCMToken() async {
    return _updateFCMToken();
  }

  // Add this method after the initialize() method:
  // Enhance the setupBackgroundNotifications method
  Future<void> setupBackgroundNotifications() async {
    // Set up notification handling when app is in background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request notification permissions with high priority
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
      announcement: true,
    );

    // Set foreground notification presentation options
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle when user taps on notification from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Handle when user taps on notification from background state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Subscribe to topics based on user skills
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(Constants.userIdKey);
    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final majorSkills = List<String>.from(userData['majorSkills'] ?? []);
        final minorSkills = List<String>.from(userData['minorSkills'] ?? []);

        // Subscribe to topics for each skill
        for (final skill in [...majorSkills, ...minorSkills]) {
          final formattedSkill = _formatTopicName(skill);
          await FirebaseMessaging.instance.subscribeToTopic('skill_$formattedSkill');

          // Save subscribed topics for later unsubscribing
          final subscribedTopics = prefs.getStringList('subscribed_topics') ?? [];
          if (!subscribedTopics.contains('skill_$formattedSkill')) {
            subscribedTopics.add('skill_$formattedSkill');
            await prefs.setStringList('subscribed_topics', subscribedTopics);
          }
        }
      }
    }

    // Register for background fetch to keep notifications working
    await _registerBackgroundTasks();
  }

// Add this method to register background tasks
  Future<void> _registerBackgroundTasks() async {
    // This would typically use a package like workmanager or background_fetch
    // For this example, we'll just set up periodic FCM token refresh

    // Schedule periodic token refresh
    Timer.periodic(const Duration(hours: 12), (timer) async {
      await updateFCMToken();
    });
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Notifications for new messages',
      importance: Importance.high,
    );

    const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
      'emergency_channel',
      'Emergency Requests',
      description: 'Notifications for emergency requests',
      importance: Importance.high,
    );

    const AndroidNotificationChannel projectChannel = AndroidNotificationChannel(
      'project_channel',
      'Project Updates',
      description: 'Notifications for project updates',
      importance: Importance.high,
    );

    // 🔔 New missed call channel
    const AndroidNotificationChannel missedCallChannel = AndroidNotificationChannel(
      'missed_call_channel',
      'Missed Calls',
      description: 'Missed call alerts',
      importance: Importance.high,
    );

    // Create call channel with vibration
    final Int64List vibrationPattern = Int64List(8);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 1000;
    vibrationPattern[2] = 500;
    vibrationPattern[3] = 1000;
    vibrationPattern[4] = 500;
    vibrationPattern[5] = 1000;
    vibrationPattern[6] = 500;
    vibrationPattern[7] = 1000;

    final AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'call_channel',
      'Call Notifications',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      // Use default sound instead of custom ringtone
      // sound: const RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
    );

    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(chatChannel);
    await androidPlugin?.createNotificationChannel(emergencyChannel);
    await androidPlugin?.createNotificationChannel(projectChannel);
    await androidPlugin?.createNotificationChannel(callChannel);
    await androidPlugin?.createNotificationChannel(missedCallChannel); // ✅ Added
  }


  // Update FCM token and save to Firestore
  Future<void> _updateFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');

        // Save token to shared preferences
        final prefs = await SharedPreferences.getInstance();
        final oldToken = prefs.getString('fcm_token');

        // Only update if token has changed
        if (oldToken != token) {
          prefs.setString('fcm_token', token);

          // Save token to Firestore if user is logged in
          final userId = prefs.getString(Constants.userIdKey);
          if (userId != null) {
            await _saveTokenToFirestore(userId, token);
          }
        }
      } else {
        debugPrint('Failed to get FCM token');

        // Request permission again if token is null
        await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          criticalAlert: true,
        );
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      // First check if the user document exists
      final userDoc = await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (userDoc.exists) {
        // Update existing document
        await FirebaseFirestore.instance
            .collection(Constants.usersCollection)
            .doc(userId)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now().toIso8601String(),
          'lastSeen': FieldValue.serverTimestamp(),
        });

        debugPrint('FCM token updated in Firestore for user $userId');
      } else {
        // Create new document if it doesn't exist
        await FirebaseFirestore.instance
            .collection(Constants.usersCollection)
            .doc(userId)
            .set({
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now().toIso8601String(),
          'lastSeen': FieldValue.serverTimestamp(),
          'userId': userId,
        }, SetOptions(merge: true));

        debugPrint('New user document created with FCM token for user $userId');
      }
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  // Subscribe to topics based on user skills
  Future<void> subscribeToSkillTopics(UserModel user) async {
    // Unsubscribe from all skill topics first
    await unsubscribeFromAllSkillTopics();

    // Subscribe to topics based on major skills
    for (final skill in user.majorSkills) {
      final formattedSkill = _formatTopicName(skill);
      await _firebaseMessaging.subscribeToTopic('skill_$formattedSkill');
    }

    // Subscribe to topics based on minor skills
    for (final skill in user.minorSkills) {
      final formattedSkill = _formatTopicName(skill);
      await _firebaseMessaging.subscribeToTopic('skill_$formattedSkill');
    }
  }

  // Unsubscribe from all skill topics
  Future<void> unsubscribeFromAllSkillTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final subscribedTopics = prefs.getStringList('subscribed_topics') ?? [];

    for (final topic in subscribedTopics) {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
    }

    await prefs.setStringList('subscribed_topics', []);
  }

  // Format topic name (remove spaces, lowercase)
  String _formatTopicName(String name) {
    return name.toLowerCase().replaceAll(' ', '_');
  }

  // Enhance the _handleForegroundMessage method to show notifications when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.notification?.title}');

    // Always show local notification even when app is in foreground
    _showLocalNotification(message);
  }

  // Improve the _showLocalNotification method to handle different notification types
  // Improve the _showLocalNotification method
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      // Check if this is a call notification
      if (message.data['type'] == 'call') {
        // Handle call notifications separately
        final callId = message.data['callId'];
        final callerId = message.data['callerId'];
        final callerName = message.data['callerName'];
        final callerImage = message.data['callerImage'];
        final isVideoCall = message.data['callType'] == 'video';

        // Use the CallService to handle the incoming call
        final callService = CallService();
        callService.handleIncomingCallFromNotification(
          callId: callId ?? '0',
          callerId: callerId ?? '',
          callerName: callerName ?? 'Unknown',
          isVideoCall: isVideoCall,
          callerProfileImage: callerImage,
        );

        return;
      }

      // For other notification types
      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        _getChannelIdFromType(message.data['type']),
        _getChannelNameFromType(message.data['type']),
        channelDescription: 'Notifications from Curio Campus',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        fullScreenIntent: message.data['type'] == 'call',
        category: message.data['type'] == 'call'
            ? AndroidNotificationCategory.call
            : AndroidNotificationCategory.message,
      );

      final iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: message.data['type'] == 'call'
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      );

      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // Generate a unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        message.notification?.title ?? 'New Notification',
        message.notification?.body ?? '',
        platformChannelSpecifics,
        payload: json.encode(message.data),
      );

      // Add to local notifications if app is in foreground
      if (navigatorKey.currentContext != null) {
        final notificationProvider = Provider.of<NotificationProvider>(
          navigatorKey.currentContext!,
          listen: false,
        );

        // Add to local notifications with named parameters
        notificationProvider.addNotification(
          title: message.notification?.title ?? 'New Notification',
          message: message.notification?.body ?? '',
          type: _parseNotificationType(message.data['type'] as String? ?? 'system'),
          relatedId: message.data['relatedId'] as String?,
          additionalData: message.data,
        );
      }
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  // Public method to show local notifications
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    Color color = Colors.teal,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: color,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Add a method to get notification color based on type
  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'emergency':
        return Colors.red;
      case 'project':
        return Colors.blue;
      case 'chat':
        return Colors.green;
      case 'call':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  // Add a method to get notification actions based on type
  List<AndroidNotificationAction> _getNotificationActions(String? type) {
    switch (type) {
      case 'emergency':
        return [
          const AndroidNotificationAction('view', 'View'),
          const AndroidNotificationAction('respond', 'Respond'),
        ];
      case 'chat':
        return [
          const AndroidNotificationAction('reply', 'Reply'),
          const AndroidNotificationAction('view', 'View Chat'),
        ];
      case 'call':
        return [
          const AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
          const AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
        ];
      case 'project':
        return [
          const AndroidNotificationAction('view', 'View'),
        ];
      default:
        return [];
    }
  }

  // Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');

    // Handle navigation based on notification type
    final data = message.data;
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
          final callService = CallService();
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

  // Handle notification tap from local notification
  void _handleNotificationClick(String? payload) {
    if (payload == null) return;

    debugPrint('Local notification payload: $payload');

    try {
      // Check if this is a call payload with the format "call:callId"
      if (payload.startsWith('call:')) {
        final callId = payload.substring(5); // Extract callId after "call:"
        debugPrint('Extracted call ID: $callId');

        // Get call details from Firestore
        FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .get()
            .then((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final callerId = data['callerId'] as String?;
            final callerName = data['callerName'] as String?;
            final isVideoCall = data['callType'] == 'video';
            final callerImage = data['callerImage'] as String?;

            if (callerId != null) {
              final callService = CallService();
              callService.handleIncomingCallFromNotification(
                callId: callId,
                callerId: callerId,
                callerName: callerName ?? 'Unknown',
                isVideoCall: isVideoCall,
                callerProfileImage: callerImage,
              );
            }
          }
        }).catchError((e) {
          debugPrint('Error fetching call details: $e');
        });
        return;
      }

      // Try to parse the payload as a map for other notification types
      final payloadMap = Map<String, dynamic>.from(
          json.decode(payload.replaceAll('{', '{"').replaceAll(': ', '": "').replaceAll(', ', '", "').replaceAll('}', '"}'))
      );

      // Handle based on notification type
      final type = payloadMap['type'];

      if (type == 'chat' && payloadMap['chatId'] != null) {
        if (navigatorKey.currentContext != null) {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: payloadMap['chatId'],
                chatName: payloadMap['chatName'] ?? 'Chat',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }

  // Add a method to send chat notification that shows a local notification
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String chatId,
    required String chatName,
    required String message,
  }) async {
    try {
      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(recipientId)
          .get();

      if (recipientDoc.exists) {
        final recipientData = recipientDoc.data();
        final fcmToken = recipientData?['fcmToken'] as String?;

        if (fcmToken != null) {
          // Send notification via Cloud Functions (you'll need to implement this)
          debugPrint('Sending chat notification to $recipientId with token $fcmToken');

          // For local testing, show a notification directly
          await _flutterLocalNotificationsPlugin.show(
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
            'New message from $senderName',
            message,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'chat_channel',
                'Chat Notifications',
                channelDescription: 'Notifications for new messages',
                importance: Importance.high,
                priority: Priority.high,
                color: Colors.green,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending chat notification: $e');
    }
  }

  // Enhance the sendEmergencyRequestNotification method
  Future<void> sendEmergencyRequestNotification({
    required List<String> requiredSkills,
    required String requesterId,
    required String requesterName,
    required String requestId,
    required String title,
  }) async {
    try {
      // For each skill, send a notification to the corresponding topic
      for (final skill in requiredSkills) {
        final formattedSkill = _formatTopicName(skill);
        final topic = 'skill_$formattedSkill';

        // Create the message payload
        final message = {
          'notification': {
            'title': 'Emergency Request: $title',
            'body': '$requesterName needs help with $skill',
          },
          'data': {
            'type': 'emergency',
            'requestId': requestId,
            'requesterId': requesterId,
            'requesterName': requesterName,
            'skill': skill,
            'channel_id': 'emergency_channel',
            'channel_name': 'Emergency Requests',
            'channel_description': 'Notifications for emergency requests',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'topic': topic,
        };

        // In a real app, you would send this via Firebase Cloud Functions or a server
        debugPrint('Sending emergency notification to topic $topic: $message');

        // For local testing, show a notification directly
        await _flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          'Emergency Request: $title',
          '$requesterName needs help with $skill',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'emergency_channel',
              'Emergency Requests',
              channelDescription: 'Notifications for emergency requests',
              importance: Importance.high,
              priority: Priority.high,
              color: Colors.red,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending emergency notification: $e');
    }
  }

  // Add a method to send project notification
  Future<void> sendProjectNotification({
    required String recipientId,
    required String projectId,
    required String projectName,
    required String message,
    required String type, // 'task_assigned', 'deadline_updated', etc.
  }) async {
    try {
      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(recipientId)
          .get();

      if (recipientDoc.exists) {
        final recipientData = recipientDoc.data();
        final fcmToken = recipientData?['fcmToken'] as String?;

        if (fcmToken != null) {
          // For local testing, show a notification directly
          await _flutterLocalNotificationsPlugin.show(
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
            'Project Update: $projectName',
            message,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'project_channel',
                'Project Updates',
                channelDescription: 'Notifications for project updates',
                importance: Importance.high,
                priority: Priority.high,
                color: Colors.blue,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending project notification: $e');
    }
  }

  // Method to handle incoming FCM messages and create real notifications
  void setupNotificationHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');

        // Show local notification
        showLocalNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: message.notification!.title ?? 'New Notification',
          body: message.notification!.body ?? '',
          channelId: _getChannelIdFromType(message.data['type']),
          channelName: _getChannelNameFromType(message.data['type']),
          channelDescription: 'Notifications for ${message.data['type'] ?? 'app'} updates',
          color: _getColorFromType(message.data['type']),
        );

        // Add to notification provider
        if (navigatorKey.currentContext != null) {
          final notificationProvider = Provider.of<NotificationProvider>(
            navigatorKey.currentContext!,
            listen: false,
          );

          // Extract notification data
          final title = message.notification?.title ?? 'New Notification';
          final body = message.notification?.body ?? '';
          final type = _parseNotificationType(message.data['type'] as String? ?? 'system');
          final relatedId = message.data['relatedId'] as String?;

          // Add notification with named parameters
          notificationProvider.addNotification(
            title: title,
            message: body,
            type: type,
            relatedId: relatedId,
            additionalData: message.data,
          );
        }
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A notification was clicked when the app was in the background!');
      if (navigatorKey.currentContext != null && message.data['type'] != null) {
        final notificationProvider = Provider.of<NotificationProvider>(
          navigatorKey.currentContext!,
          listen: false,
        );

        // Create a notification model from the message data
        final notificationId = const Uuid().v4();
        final notification = NotificationModel(
          id: notificationId,
          title: message.notification?.title ?? 'New Notification',
          message: message.notification?.body ?? '',
          timestamp: DateTime.now(),
          type: _parseNotificationType(message.data['type'] as String? ?? 'system'),
          relatedId: message.data['relatedId'] as String?,
          isRead: false,
          additionalData: message.data,
        );

        // Navigate based on notification type
        _handleNotificationNavigation(notification);
      }
    });
  }

  // Helper method to get channel ID based on notification type
  String _getChannelIdFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'chat':
        return 'chat_channel';
      case 'emergency':
        return 'emergency_channel';
      case 'project':
        return 'project_channel';
      case 'call':
        return 'call_channel';
      case 'profile':
        return 'profile_channel';
      default:
        return 'general_channel';
    }
  }

  // Helper method to get channel name based on notification type
  String _getChannelNameFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'chat':
        return 'Chat Notifications';
      case 'emergency':
        return 'Emergency Requests';
      case 'project':
        return 'Project Updates';
      case 'call':
        return 'Call Notifications';
      case 'profile':
        return 'Profile Updates';
      default:
        return 'General Notifications';
    }
  }

  // Helper method to get color based on notification type
  Color _getColorFromType(String? type) {
    switch (type?.toLowerCase()) {
      case 'chat':
        return Colors.blue;
      case 'emergency':
        return Colors.orange;
      case 'project':
        return Colors.green;
      case 'call':
        return Colors.purple;
      case 'profile':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Helper method to parse notification type
  NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'chat':
        return NotificationType.chat;
      case 'emergency':
        return NotificationType.emergency;
      case 'project':
        return NotificationType.project;
      case 'call':
        return NotificationType.call;
      case 'profile':
        return NotificationType.profile;
      default:
        return NotificationType.system;
    }
  }

  // Helper method to handle navigation based on notification
  void _handleNotificationNavigation(NotificationModel notification) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (notification.type) {
      case NotificationType.chat:
        if (notification.relatedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: notification.relatedId!,
                chatName: notification.additionalData?['chatName'] ?? notification.title,
              ),
            ),
          );
        }
        break;
      case NotificationType.emergency:
        if (notification.relatedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmergencyRequestDetailScreen(
                requestId: notification.relatedId!,
                isOwnRequest: notification.additionalData?['isOwnRequest'] == true,
              ),
            ),
          );
        }
        break;
      case NotificationType.project:
        if (notification.relatedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(
                projectId: notification.relatedId!,
              ),
            ),
          );
        }
        break;
      case NotificationType.call:
        if (notification.relatedId != null && notification.additionalData != null) {
          final callService = CallService();
          callService.handleIncomingCallFromNotification(
            callId: notification.relatedId!,
            callerId: notification.additionalData!['callerId'] ?? '',
            callerName: notification.additionalData!['callerName'] ?? 'Unknown',
            isVideoCall: notification.additionalData!['callType'] == 'video',
            callerProfileImage: notification.additionalData!['callerImage'],
          );
        }
        break;
      default:
        break;
    }
  }

  Future<void> registerForBackgroundNotifications() async {
    // Request background notification permissions on iOS
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Enable background notifications
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // Update FCM token
    await _updateFCMToken();

    debugPrint('Registered for background notifications');
  }

  // Start periodic token refresh and online status update
  Future<void> startPeriodicUpdates() async {
    // Update FCM token and online status every 30 minutes
    Timer.periodic(const Duration(minutes: 30), (timer) async {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(Constants.userIdKey);

      if (userId != null) {
        // Update FCM token
        await _updateFCMToken();

        // Update online status
        try {
          await FirebaseFirestore.instance
              .collection(Constants.usersCollection)
              .doc(userId)
              .update({
            'lastSeen': FieldValue.serverTimestamp(),
            'isOnline': true,
          });
        } catch (e) {
          debugPrint('Error updating online status: $e');
        }
      } else {
        // User is not logged in, cancel the timer
        timer.cancel();
      }
    });
  }
}

// Background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  await Firebase.initializeApp();

  debugPrint('Background message received: ${message.notification?.title}');

  // Create a local notification to ensure it's displayed
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'This channel is used for important notifications.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode % 100000, // Ensure ID is within 32-bit integer range
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    platformChannelSpecifics,
  );

  // Special handling for call notifications
  if (message.data['type'] == 'call') {
    final callId = message.data['callId'] ?? '0';
    final callerName = message.data['callerName'] ?? 'Unknown';
    final callType = message.data['callType'] ?? 'voice';

    // Show a full-screen call notification
    final androidCallDetails = AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      // Use default sound instead of custom ringtone
      // sound: const RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
      actions: [
        const AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
        const AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
      ],
    );

    // Convert the call ID to a valid notification ID (within 32-bit integer range)
    // Use a hash code and modulo to ensure it's within range
    final notificationId = callId.hashCode % 100000;

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      callerName,
      NotificationDetails(android: androidCallDetails),
      payload: 'call:$callId',
    );
  }
}
