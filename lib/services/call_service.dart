import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:curio_campus/screens/chat/call_screen.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:uuid/uuid.dart';

enum CallStatus {
  idle,
  outgoing,
  incoming,
  connecting,
  connected,
  ended,
  missed,
  rejected,
  busy,
  failed
}

class CallData {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerProfileImage;
  final String receiverId;
  final String receiverName;
  final String receiverProfileImage;
  final bool isVideoCall;
  final DateTime timestamp;
  final CallStatus status;

  CallData({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerProfileImage,
    required this.receiverId,
    required this.receiverName,
    required this.receiverProfileImage,
    required this.isVideoCall,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerProfileImage': callerProfileImage,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverProfileImage': receiverProfileImage,
      'isVideoCall': isVideoCall,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString(),
    };
  }

  factory CallData.fromMap(Map<String, dynamic> map) {
    return CallData(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerProfileImage: map['callerProfileImage'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverProfileImage: map['receiverProfileImage'] ?? '',
      isVideoCall: map['isVideoCall'] ?? false,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      status: _parseCallStatus(map['status']),
    );
  }

  static CallStatus _parseCallStatus(String? status) {
    if (status == null) return CallStatus.idle;

    switch (status) {
      case 'CallStatus.outgoing':
        return CallStatus.outgoing;
      case 'CallStatus.incoming':
        return CallStatus.incoming;
      case 'CallStatus.connecting':
        return CallStatus.connecting;
      case 'CallStatus.connected':
        return CallStatus.connected;
      case 'CallStatus.ended':
        return CallStatus.ended;
      case 'CallStatus.missed':
        return CallStatus.missed;
      case 'CallStatus.rejected':
        return CallStatus.rejected;
      case 'CallStatus.busy':
        return CallStatus.busy;
      case 'CallStatus.failed':
        return CallStatus.failed;
      default:
        return CallStatus.idle;
    }
  }
}

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<DocumentSnapshot>? _callSubscription;
  CallData? _currentCall;
  Timer? _callTimeoutTimer;

  // Initialize the call service
  Future<void> initialize() async {
    // Initialize notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        _handleNotificationTap(response.payload);
      },
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    // Listen for incoming calls
    _listenForIncomingCalls();
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'call_channel',
      'Call Notifications',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Listen for incoming calls
  void _listenForIncomingCalls() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Create a document for this user if it doesn't exist
    _firestore.collection('calls').doc(userId).set({
      'userId': userId,
      'hasActiveCall': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((error) {
      debugPrint('Error creating call document: $error');
    });

    // Listen for changes to the user's call document
    _callSubscription = _firestore
        .collection('calls')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['hasActiveCall'] == true && data['callData'] != null) {
          // There's an active call
          final callData = CallData.fromMap(data['callData']);

          debugPrint('Call data received: ${callData.status}');

          // Only handle incoming calls here
          if (callData.receiverId == userId && callData.status == CallStatus.outgoing) {
            // This is an incoming call
            _handleIncomingCall(callData);
          } else if (_currentCall != null && _currentCall!.callId == callData.callId) {
            // Update current call status if it's the same call
            _currentCall = callData;

            // Handle status changes
            if (callData.status == CallStatus.rejected || callData.status == CallStatus.ended) {
              _notificationsPlugin.cancel(0);
            }
          }
        }
      }
    }, onError: (error) {
      debugPrint('Error listening for calls: $error');
    });
  }

  // Handle incoming call
  void _handleIncomingCall(CallData callData) {
    debugPrint('Handling incoming call from ${callData.callerName}');
    _currentCall = callData;

    // Show notification for incoming call
    _showIncomingCallNotification(callData);

    // Update call status to incoming
    _updateCallStatus(callData.callId, CallStatus.incoming);

    // Open call screen directly
    _openIncomingCallScreen(callData);
  }

  // Open incoming call screen
  void _openIncomingCallScreen(CallData callData) {
    debugPrint('Opening incoming call screen');

    // Use a delay to ensure the app has time to initialize if needed
    Future.delayed(Duration(milliseconds: 500), () {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            userId: callData.callerId,
            userName: callData.callerName,
            callType: callData.isVideoCall ? CallType.video : CallType.voice,
            profileImageBase64: callData.callerProfileImage,
            autoConnect: false,
            isOutgoing: false,
            callId: callData.callId,
          ),
        ),
      );
    });
  }

  // Show notification for incoming call
  Future<void> _showIncomingCallNotification(CallData callData) async {
    debugPrint('Showing incoming call notification');

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      // Fix: Use AndroidNotificationCategory enum instead of string
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
      // Fix: Use Int64List for vibration pattern
      vibrationPattern: Int64List.fromList([0, 500, 500, 500, 500, 500]),
    );

    NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      'Incoming ${callData.isVideoCall ? 'Video' : 'Voice'} Call',
      'From ${callData.callerName}',
      platformChannelSpecifics,
      payload: callData.callId,
    );
  }

  // Handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload == null || _currentCall == null) return;

    debugPrint('Notification tapped with payload: $payload');

    // Open call screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          userId: _currentCall!.callerId,
          userName: _currentCall!.callerName,
          callType: _currentCall!.isVideoCall ? CallType.video : CallType.voice,
          profileImageBase64: _currentCall!.callerProfileImage,
          autoConnect: false,
          isOutgoing: false,
          callId: payload,
        ),
      ),
    );
  }

  // Make a call
  Future<String> makeCall({
    required String receiverId,
    required String receiverName,
    String? receiverProfileImage,
    required bool isVideoCall,
    required BuildContext context,
  }) async {
    final callerId = _auth.currentUser?.uid;
    if (callerId == null) {
      throw Exception('User not logged in');
    }

    // Get caller info
    final callerDoc = await _firestore.collection('users').doc(callerId).get();
    if (!callerDoc.exists) {
      throw Exception('Caller profile not found');
    }

    final callerData = callerDoc.data()!;
    final callerName = callerData['name'] ?? 'Unknown';
    final callerProfileImage = callerData['profileImageBase64'] ?? '';

    // Create call ID
    final callId = const Uuid().v4();

    // Create call data
    final callData = CallData(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerProfileImage: callerProfileImage,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverProfileImage: receiverProfileImage ?? '',
      isVideoCall: isVideoCall,
      timestamp: DateTime.now(),
      status: CallStatus.outgoing,
    );

    // Save current call
    _currentCall = callData;

    try {
      // First check if receiver document exists
      final receiverDoc = await _firestore.collection('calls').doc(receiverId).get();

      if (!receiverDoc.exists) {
        // Create receiver document if it doesn't exist
        await _firestore.collection('calls').doc(receiverId).set({
          'userId': receiverId,
          'hasActiveCall': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Update caller's document
      await _firestore.collection('calls').doc(callerId).set({
        'hasActiveCall': true,
        'callData': callData.toMap(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update receiver's document
      await _firestore.collection('calls').doc(receiverId).set({
        'hasActiveCall': true,
        'callData': callData.toMap(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Call documents updated successfully');

      // Start call timeout timer (30 seconds)
      _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
        // If call is still outgoing after 30 seconds, mark as missed
        if (_currentCall?.status == CallStatus.outgoing || _currentCall?.status == CallStatus.incoming) {
          _updateCallStatus(callId, CallStatus.missed);

          // Show missed call notification to receiver
          _showMissedCallNotification(receiverId, callerName);

          // Navigate back if still on call screen
          Navigator.of(context).pop();
        }
      });

      return callId;
    } catch (e) {
      debugPrint('Error making call: $e');
      throw Exception('Failed to make call: $e');
    }
  }

  // Update call status
  Future<void> _updateCallStatus(String callId, CallStatus status) async {
    if (_currentCall == null) return;

    debugPrint('Updating call status to: $status');

    // Update current call status
    _currentCall = CallData(
      callId: _currentCall!.callId,
      callerId: _currentCall!.callerId,
      callerName: _currentCall!.callerName,
      callerProfileImage: _currentCall!.callerProfileImage,
      receiverId: _currentCall!.receiverId,
      receiverName: _currentCall!.receiverName,
      receiverProfileImage: _currentCall!.receiverProfileImage,
      isVideoCall: _currentCall!.isVideoCall,
      timestamp: _currentCall!.timestamp,
      status: status,
    );

    try {
      // Update caller's document
      await _firestore.collection('calls').doc(_currentCall!.callerId).update({
        'callData': _currentCall!.toMap(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update receiver's document
      await _firestore.collection('calls').doc(_currentCall!.receiverId).update({
        'callData': _currentCall!.toMap(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('Call status updated successfully');
    } catch (e) {
      debugPrint('Error updating call status: $e');
    }
  }

  // Accept call
  Future<void> acceptCall(String callId) async {
    if (_currentCall == null || _currentCall!.callId != callId) {
      debugPrint('No current call or call ID mismatch');
      return;
    }

    debugPrint('Accepting call: $callId');

    // Update call status to connecting
    await _updateCallStatus(callId, CallStatus.connecting);

    // Cancel notification
    await _notificationsPlugin.cancel(0);

    // After a short delay, update to connected
    Future.delayed(const Duration(seconds: 1), () {
      _updateCallStatus(callId, CallStatus.connected);
    });
  }

  // Reject call
  Future<void> rejectCall(String callId) async {
    if (_currentCall == null || _currentCall!.callId != callId) {
      debugPrint('No current call or call ID mismatch');
      return;
    }

    debugPrint('Rejecting call: $callId');

    // Update call status to rejected
    await _updateCallStatus(callId, CallStatus.rejected);

    // Cancel notification
    await _notificationsPlugin.cancel(0);

    // End call
    await _endCall(callId);
  }

  // End call
  Future<void> endCall(String callId) async {
    if (_currentCall == null || _currentCall!.callId != callId) {
      debugPrint('No current call or call ID mismatch');
      return;
    }

    debugPrint('Ending call: $callId');

    // Update call status to ended
    await _updateCallStatus(callId, CallStatus.ended);

    // End call
    await _endCall(callId);
  }

  // End call (internal)
  Future<void> _endCall(String callId) async {
    // Cancel timeout timer
    _callTimeoutTimer?.cancel();

    // Cancel notification
    await _notificationsPlugin.cancel(0);

    if (_currentCall == null) return;

    try {
      // Update caller's document
      await _firestore.collection('calls').doc(_currentCall!.callerId).update({
        'hasActiveCall': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update receiver's document
      await _firestore.collection('calls').doc(_currentCall!.receiverId).update({
        'hasActiveCall': false,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Save call to history
      await _firestore.collection('callHistory').add({
        'callId': _currentCall!.callId,
        'callerId': _currentCall!.callerId,
        'callerName': _currentCall!.callerName,
        'receiverId': _currentCall!.receiverId,
        'receiverName': _currentCall!.receiverName,
        'isVideoCall': _currentCall!.isVideoCall,
        'timestamp': _currentCall!.timestamp.toIso8601String(),
        'status': _currentCall!.status.toString(),
        'duration': DateTime.now().difference(_currentCall!.timestamp).inSeconds,
      });

      debugPrint('Call ended successfully and saved to history');

      // Clear current call
      _currentCall = null;
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  // Show missed call notification
  Future<void> _showMissedCallNotification(String userId, String callerName) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for missed calls',
      importance: Importance.high,
      priority: Priority.high,
    );

    NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      1, // Different ID from incoming call
      'Missed Call',
      'From $callerName',
      platformChannelSpecifics,
    );
  }

  // Dispose
  void dispose() {
    _callSubscription?.cancel();
    _callTimeoutTimer?.cancel();
  }
}

// Global navigator key for accessing navigator from service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();