import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.data['type'] == 'call') {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

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
          const AndroidNotificationAction('answer', 'Answer',
              showsUserInterface: true),
          const AndroidNotificationAction('decline', 'Decline',
              showsUserInterface: true),
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

      final notificationId = callId % 100000;

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
        callerName,
        notificationDetails,
        payload: 'call:$callId',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'pending_call',
          json.encode({
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
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

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
      final messageContent = message.notification?.body ??
          message.data['content'] ??
          'New message';
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

      final prefs = await SharedPreferences.getInstance();
      final pendingMessages = prefs.getStringList('pending_messages') ?? [];
      pendingMessages.add(json.encode({
        'chatId': chatId,
        'chatName': chatName,
        'senderName': senderName,
        'content': messageContent,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      if (pendingMessages.length > 10) {
        pendingMessages.removeAt(0);
      }

      await prefs.setStringList('pending_messages', pendingMessages);
    } catch (e) {
      debugPrint('Error handling chat notification in background: $e');
    }
  } else {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

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
      );

      await flutterLocalNotificationsPlugin.show(
        message.hashCode % 100000,
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
