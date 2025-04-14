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
import 'package:curio_campus/utils/navigator_key.dart'; // Import the navigator key

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Initialize notification channels and request permissions
  Future<void> initialize() async {
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
  }

  // Add this method after the initialize() method:
  Future<void> setupBackgroundNotifications() async {
    // Set up notification handling when app is in background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(emergencyChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(projectChannel);
  }

  // Update FCM token and save to Firestore
  Future<void> _updateFCMToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');

      // Save token to shared preferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('fcm_token', token);

      // Save token to Firestore if user is logged in
      final userId = prefs.getString(Constants.userIdKey);
      if (userId != null) {
        await _saveTokenToFirestore(userId, token);
      }
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(userId)
          .update({
        'fcmToken': token,
        'lastTokenUpdate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
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
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'curio_campus_channel',
      'Curio Campus Notifications',
      channelDescription: 'Notifications from Curio Campus',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final iOSPlatformChannelSpecifics = DarwinNotificationDetails();

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: message.data.toString(),
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
  }

  // Add a public method to show local notifications
  // Add this method after the _showLocalNotification method:

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
        // Navigate to chat screen
        break;
      case 'emergency':
        final requestId = data['requestId'];
        // Navigate to emergency request details
        break;
      case 'project':
        final projectId = data['projectId'];
        // Navigate to project details
        break;
    }
  }

  // Handle notification tap from local notification
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');

    // Parse payload and navigate accordingly
    if (response.payload != null) {
      // Handle navigation based on payload
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

  // Update the notification service to handle real notifications
  // Add this method to the NotificationService class

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
      default:
        break;
    }
  }

  // Handle notification clicks
  void _handleNotificationClick(String? payload) {
    if (payload == null) return;

    debugPrint('Notification payload: $payload');

    // Parse the payload and navigate to the appropriate screen
    // This will depend on your app's navigation structure
    // For example:
    // if (payload.contains('chat')) {
    //   Navigator.of(context).pushNamed('/chat', arguments: payload);
    // }
  }

  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
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
}

// Improve the _firebaseMessagingBackgroundHandler function at the bottom of the file
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
    message.hashCode,
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    platformChannelSpecifics,
  );
}
