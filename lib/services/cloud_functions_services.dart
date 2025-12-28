import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class CloudFunctionsService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Add debug mode for testing
  static const bool _debugMode = true;

  static Future<bool> sendEmergencyNotification({
    required List<String> requiredSkills,
    required String requesterId,
    required String requesterName,
    required String requestId,
    required String title,
  }) async {
    try {
      if (_debugMode) {
        debugPrint('🔥 Calling sendEmergencyNotification with:');
        debugPrint('  - Skills: $requiredSkills');
        debugPrint('  - Requester: $requesterName');
        debugPrint('  - Request ID: $requestId');
        debugPrint('  - Title: $title');
      }

      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ User not authenticated');
        return false;
      }

      final callable = _functions.httpsCallable('sendEmergencyNotification');

      final result = await callable.call({
        'requiredSkills': requiredSkills,
        'requesterId': requesterId,
        'requesterName': requesterName,
        'requestId': requestId,
        'title': title,
      });

      if (_debugMode) {
        debugPrint('✅ Function result: ${result.data}');
      }

      return result.data['success'] == true;
    } catch (e) {
      debugPrint('❌ Error calling sendEmergencyNotification: $e');

      // If function not found, fall back to Firestore trigger
      if (e.toString().contains('NOT_FOUND')) {
        debugPrint('🔄 Function not found, relying on Firestore trigger...');
        return true; // Let the Firestore trigger handle it
      }

      return false;
    }
  }

  // Send chat notification
  static Future<bool> sendChatNotification({
    required String recipientToken,
    required String senderName,
    required String chatId,
    required String chatName,
    required String message,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendChatNotification');

      final result = await callable.call({
        'recipientToken': recipientToken,
        'senderName': senderName,
        'chatId': chatId,
        'chatName': chatName,
        'message': message,
      });

      return result.data['success'] == true;
    } catch (e) {
      debugPrint('Error calling sendChatNotification: $e');
      return false;
    }
  }

  // Send call notification
  static Future<bool> sendCallNotification({
    required String recipientToken,
    required String callId,
    required String callerId,
    required String callerName,
    required String callType,
    String? callerImage,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendCallNotification');

      final result = await callable.call({
        'recipientToken': recipientToken,
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callType': callType,
        'callerImage': callerImage,
      });

      return result.data['success'] == true;
    } catch (e) {
      debugPrint('Error calling sendCallNotification: $e');
      return false;
    }
  }

  // Send topic notification
  static Future<bool> sendTopicNotification({
    required String topic,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendTopicNotification');

      final result = await callable.call({
        'topic': topic,
        'title': title,
        'body': body,
        'data': data,
      });

      return result.data['success'] == true;
    } catch (e) {
      debugPrint('Error calling sendTopicNotification: $e');
      return false;
    }
  }

  // Test function to verify connection
  static Future<bool> testConnection() async {
    try {
      final callable = _functions.httpsCallable('sendEmergencyNotification');

      // Try to call with minimal data to test connection
      await callable.call({
        'requiredSkills': ['test'],
        'requesterId': 'test',
        'requesterName': 'test',
        'requestId': 'test',
        'title': 'test',
      });

      return true;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }
}
