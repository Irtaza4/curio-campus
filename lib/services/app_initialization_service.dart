import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../main.dart';
import '../utils/logger.dart';
import 'background_messaging_handler.dart';

class AppInitializationService {
  static Future<void> initialize() async {
    Logger.info('Initializing application services...');

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    Logger.info('Firebase Project ID: ${Firebase.app().options.projectId}');

    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize notification service
    await notificationService.initialize();
    await notificationService.setupBackgroundNotifications();

    // Ensure FCM token is updated on app start
    await notificationService.updateFCMToken();

    // Initialize call service with Agora App ID
    await callService.initialize('c4a1309f72be434592965a29b64c1fd4');

    // Handle notification click when app is terminated
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Logger.info(
          'App opened from terminated state via notification: ${initialMessage.data}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'initial_notification', jsonEncode(initialMessage.data));
    }

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    Logger.info('Application services initialized.');
  }
}
