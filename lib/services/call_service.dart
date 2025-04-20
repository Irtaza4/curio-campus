import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:curio_campus/utils/navigator_key.dart';
import 'package:curio_campus/screens/chat/call_screen.dart';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // Agora SDK variables
  RtcEngine? _engine;
  String? _agoraAppId;
  int? _currentCallId;
  Timer? _callTimeoutTimer;
  bool _isCallActive = false;

  // Track if an incoming call screen is already showing
  bool _isIncomingCallScreenShowing = false;

  // Track if an outgoing call screen is already showing
  bool _isOutgoingCallScreenShowing = false;

  // Call notification channel
  static final AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
    'call_channel',
    'Call Notifications',
    description: 'Notifications for incoming calls',
    importance: Importance.max,
    // Use default sound instead of custom ringtone
    // sound: const RawResourceAndroidNotificationSound('ringtone'),
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
  );

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Initialize the call service
  Future<void> initialize(String agoraAppId) async {
    _agoraAppId = agoraAppId;

    // Create the call notification channel
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_callChannel);

    // Set up notification handlers for calls
    _setupCallNotificationHandlers();

    debugPrint('Call service initialized with Agora App ID: $_agoraAppId');
  }

  // Set up notification handlers for calls
  void _setupCallNotificationHandlers() {
    // Handle foreground messages for calls
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        _handleIncomingCallNotification(message);
      }
    });

    // Handle when app is opened from a call notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        _handleCallNotificationTap(message);
      }
    });
  }

  // Handle incoming call notification
  Future<void> _handleIncomingCallNotification(RemoteMessage message) async {
    // Prevent duplicate call screens
    if (_isIncomingCallScreenShowing) {
      debugPrint('Incoming call screen already showing, ignoring duplicate notification');
      return;
    }

    final callData = message.data;
    final callerId = callData['callerId'];
    final callerName = callData['callerName'];
    final callerImage = callData['callerImage'];
    final callType = callData['callType'] == 'video' ? CallType.video : CallType.voice;
    final callId = int.tryParse(callData['callId'] ?? '0') ?? 0;

    // Show full-screen incoming call UI
    _showIncomingCallNotification(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerImage: callerImage,
      callType: callType,
    );
  }

  // Handle incoming call from notification (public method for notification service)
  Future<void> handleIncomingCallFromNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required bool isVideoCall,
    String? callerProfileImage,
  }) async {
    // Prevent duplicate call screens
    if (_isIncomingCallScreenShowing) {
      debugPrint('Incoming call screen already showing, ignoring duplicate notification');
      return;
    }

    final callIdInt = int.tryParse(callId) ?? 0;
    final callType = isVideoCall ? CallType.video : CallType.voice;

    _showIncomingCallNotification(
      callId: callIdInt,
      callerId: callerId,
      callerName: callerName,
      callerImage: callerProfileImage,
      callType: callType,
    );
  }

  // Show incoming call notification
  Future<void> _showIncomingCallNotification({
    required int callId,
    required String callerId,
    required String callerName,
    String? callerImage,
    required CallType callType,
  }) async {
    try {
      // Save call details for when the notification is tapped
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('incoming_call', json.encode({
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerImage': callerImage,
        'callType': callType == CallType.video ? 'video' : 'voice',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }));

      // Convert the call ID to a valid notification ID (within 32-bit integer range)
      final notificationId = callId.hashCode % 100000; // Use hashCode and modulo to get a smaller number

      // Show a full-screen notification for the call
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        'Incoming ${callType == CallType.video ? 'Video' : 'Voice'} Call',
        callerName,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _callChannel.id,
            _callChannel.name,
            channelDescription: _callChannel.description,
            importance: _callChannel.importance,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.call,
            sound: _callChannel.sound,
            playSound: _callChannel.playSound,
            enableVibration: _callChannel.enableVibration,
            vibrationPattern: _callChannel.vibrationPattern,
            actions: [
              const AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
              const AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // Remove custom sound reference
            // sound: 'ringtone.caf',
            interruptionLevel: InterruptionLevel.timeSensitive,
            categoryIdentifier: 'call',
          ),
        ),
        payload: 'call:$callId',
      );

      // If the app is in foreground, show the incoming call screen
      if (navigatorKey.currentContext != null) {
        _showIncomingCallScreen(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerImage: callerImage,
          callType: callType,
        );
      }

      // Set a timeout for the call (60 seconds)
      _callTimeoutTimer?.cancel(); // Cancel any existing timer
      _callTimeoutTimer = Timer(const Duration(seconds: 60), () {
        _cancelIncomingCall(callId);
      });
    } catch (e) {
      debugPrint('Error showing incoming call notification: $e');
    }
  }

  // Show incoming call screen
  void _showIncomingCallScreen({
    required int callId,
    required String callerId,
    required String callerName,
    String? callerImage,
    required CallType callType,
  }) {
    if (_isIncomingCallScreenShowing) {
      debugPrint('Incoming call screen already showing, ignoring duplicate call');
      return;
    }

    if (navigatorKey.currentContext != null) {
      _isIncomingCallScreenShowing = true;

      Navigator.push(
        navigatorKey.currentContext!,
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerImage: callerImage,
            callType: callType,
            onAccept: () => _acceptCall(callId, callerId, callerName, callerImage, callType),
            onDecline: () => _declineCall(callId),
          ),
        ),
      ).then((_) {
        // Reset flag when screen is closed
        _isIncomingCallScreenShowing = false;
      });
    }
  }

  // Handle call notification tap
  void _handleCallNotificationTap(RemoteMessage message) async {
    if (_isIncomingCallScreenShowing) {
      debugPrint('Incoming call screen already showing, ignoring notification tap');
      return;
    }

    final callData = message.data;
    final callerId = callData['callerId'];
    final callerName = callData['callerName'];
    final callerImage = callData['callerImage'];
    final callType = callData['callType'] == 'video' ? CallType.video : CallType.voice;
    final callId = int.tryParse(callData['callId'] ?? '0') ?? 0;

    // Check if the call is still active in Firestore
    final callDoc = await FirebaseFirestore.instance
        .collection('calls')
        .doc(callId.toString())
        .get();

    if (callDoc.exists) {
      final data = callDoc.data() as Map<String, dynamic>;
      final status = data['status'] as String;

      // Only show the incoming call screen if the call is still ringing
      if (status == 'ringing') {
        // Show incoming call screen
        _showIncomingCallScreen(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerImage: callerImage,
          callType: callType,
        );
      } else {
        debugPrint('Call is no longer active, status: $status');
      }
    }
  }

  Future<RtcEngine?> setupCall({
    required String callerId,
    required String calleeId,
    required bool isVideoCall,
    required int callId,
  }) async {
    try {
      final callType = isVideoCall ? CallType.video : CallType.voice;

      if (!await _checkCallPermissions(callType)) {
        debugPrint('Permissions not granted');
        return null;
      }

      await _initializeAgoraEngine();
      await _joinChannel(callId.toString());

      _isCallActive = true;
      _currentCallId = callId;

      return _engine;
    } catch (e) {
      debugPrint('Error setting up call: $e');
      return null;
    }
  }

  Future<void> disposeEngine() async {
    try {
      await _leaveChannel();
      await _engine?.release();
      _engine = null;
      _isCallActive = false;
    } catch (e) {
      debugPrint('Error disposing engine: $e');
    }
  }

  // Make a call
  Future<bool> makeCall({
    required String recipientId,
    required String recipientName,
    String? recipientImage,
    required CallType callType,
  }) async {
    try {
      // Prevent duplicate outgoing calls
      if (_isOutgoingCallScreenShowing || _isCallActive) {
        debugPrint('Call already in progress, ignoring duplicate call attempt');
        return false;
      }

      // Check if call permissions are granted
      if (!await _checkCallPermissions(callType)) {
        return false;
      }

      // Generate a unique call ID
      final callId = DateTime.now().millisecondsSinceEpoch;
      _currentCallId = callId;

      // Get the current user details
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString(Constants.userIdKey);
      final currentUserName = prefs.getString(Constants.userNameKey) ?? 'User';
      final currentUserImage = prefs.getString(Constants.userImageKey);

      if (currentUserId == null) {
        debugPrint('Cannot make call: User not logged in');
        return false;
      }

      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        debugPrint('Recipient not found');

        // Show error message to the user
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Recipient user not found'),
              backgroundColor: Colors.red,
            ),
          );
        }

        return false;
      }

      final recipientData = recipientDoc.data() as Map<String, dynamic>;
      final fcmToken = recipientData['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('Recipient FCM token not found');

        // Create the call document anyway - we'll rely on Firestore listener
        await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).set({
          'callId': callId,
          'callerId': currentUserId,
          'callerName': currentUserName,
          'callerImage': currentUserImage,
          'recipientId': recipientId,
          'recipientName': recipientName,
          'recipientImage': recipientImage,
          'callType': callType == CallType.video ? 'video' : 'voice',
          'status': 'ringing',
          'startTime': FieldValue.serverTimestamp(),
          'endTime': null,
          'channel': 'channel_$callId',
          'token': '', // Will be generated by your server
          'fcmNotificationSent': false, // Mark that FCM notification wasn't sent
        });

        // Show a warning to the user
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Recipient may not receive notification. They need to be online to receive the call.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Create a call document in Firestore with FCM token
        await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).set({
          'callId': callId,
          'callerId': currentUserId,
          'callerName': currentUserName,
          'callerImage': currentUserImage,
          'recipientId': recipientId,
          'recipientName': recipientName,
          'recipientImage': recipientImage,
          'callType': callType == CallType.video ? 'video' : 'voice',
          'status': 'ringing',
          'startTime': FieldValue.serverTimestamp(),
          'endTime': null,
          'channel': 'channel_$callId',
          'token': '', // Will be generated by your server
          'recipientFcmToken': fcmToken, // Store the FCM token
          'fcmNotificationSent': true, // Mark that FCM notification was sent
        });
      }

      // Show the outgoing call screen
      if (navigatorKey.currentContext != null) {
        _isOutgoingCallScreenShowing = true;

        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 120),
              child: OutgoingCallScreen(
                callId: callId,
                recipientId: recipientId,
                recipientName: recipientName,
                recipientImage: recipientImage,
                callType: callType,
                onCancel: () => _cancelOutgoingCall(callId),
              ),
            ),
          ),
        ).then((_) {
          // Reset flag when screen is closed
          _isOutgoingCallScreenShowing = false;
        });
      }

      // Set a timeout for the outgoing call (60 seconds)
      _callTimeoutTimer?.cancel(); // Cancel any existing timer
      _callTimeoutTimer = Timer(const Duration(seconds: 60), () {
        _cancelOutgoingCall(callId);
      });

      _isCallActive = true;
      return true;
    } catch (e) {
      debugPrint('Error making call: $e');

      // Show error to the user
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Error making call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  // Accept a call
  Future<bool> _acceptCall(
      int callId,
      String callerId,
      String callerName,
      String? callerImage,
      CallType callType,
      ) async {
    try {
      // Cancel the timeout timer
      _callTimeoutTimer?.cancel();

      // Check if call permissions are granted
      if (!await _checkCallPermissions(callType)) {
        return false;
      }

      // Update the call status in Firestore
      await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
        'status': 'connected',
        'connectedAt': FieldValue.serverTimestamp(),
      });

      // Initialize the Agora engine
      await _initializeAgoraEngine();

      try {
        // Join the call channel with retry mechanism
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            await _joinChannel(callId.toString());
            break; // Success, exit the loop
          } catch (e) {
            retryCount++;
            debugPrint('Join channel attempt $retryCount failed: $e');

            if (retryCount >= maxRetries) {
              throw e; // Rethrow after max retries
            }

            // Wait before retrying
            await Future.delayed(const Duration(seconds: 1));
          }
        }

        // Show the call screen
        if (navigatorKey.currentContext != null) {
          Navigator.pushReplacement(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                userId: callerId,
                userName: callerName,
                callType: callType,
                profileImageBase64: callerImage,
                engine: _engine!,
                callId: callId,
                isOutgoing: false,
                onCallEnd: () => _endCall(callId),
              ),
            ),
          ).then((_) {
            // Reset incoming call screen flag
            _isIncomingCallScreenShowing = false;
          });
        }

        // Cancel the notification using the same ID conversion
        final notificationId = callId.hashCode % 100000;
        await _flutterLocalNotificationsPlugin.cancel(notificationId);

        _isCallActive = true;
        _currentCallId = callId;
        return true;
      } catch (e) {
        debugPrint('Error accepting call: $e');

        // Show error to user
        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Text('Error connecting to call: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Update call status to failed
        await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
          'status': 'failed',
          'endTime': FieldValue.serverTimestamp(),
          'errorMessage': e.toString(),
        });

        return false;
      }
    } catch (e) {
      debugPrint('Error accepting call: $e');
      return false;
    }
  }

  // Decline a call
  Future<void> _declineCall(int callId) async {
    try {
      // Cancel the timeout timer
      _callTimeoutTimer?.cancel();

      // Update the call status in Firestore
      await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
        'status': 'declined',
        'endTime': FieldValue.serverTimestamp(),
      });

      // Cancel the notification using the same ID conversion
      final notificationId = callId.hashCode % 100000;
      await _flutterLocalNotificationsPlugin.cancel(notificationId);

      // Close the incoming call screen if it's open
      if (navigatorKey.currentContext != null && Navigator.canPop(navigatorKey.currentContext!)) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      // Reset flag
      _isIncomingCallScreenShowing = false;
    } catch (e) {
      debugPrint('Error declining call: $e');
    }
  }

  // Cancel an outgoing call
  Future<void> _cancelOutgoingCall(int callId) async {
    try {
      // Cancel the timeout timer
      _callTimeoutTimer?.cancel();

      // Update the call status in Firestore
      await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
        'status': 'cancelled',
        'endTime': FieldValue.serverTimestamp(),
      });

      // Close the outgoing call screen if it's open
      if (navigatorKey.currentContext != null && Navigator.canPop(navigatorKey.currentContext!)) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      _isCallActive = false;
      _currentCallId = null;
      _isOutgoingCallScreenShowing = false;
    } catch (e) {
      debugPrint('Error cancelling outgoing call: $e');
    }
  }

  // Cancel an incoming call (timeout or missed)
  Future<void> _cancelIncomingCall(int callId) async {
    try {
      // Update the call status in Firestore
      await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
        'status': 'missed',
        'endTime': FieldValue.serverTimestamp(),
      });

      // Cancel the notification using the same ID conversion
      final notificationId = callId.hashCode % 100000;
      await _flutterLocalNotificationsPlugin.cancel(notificationId);

      // Close the incoming call screen if it's open
      if (_isIncomingCallScreenShowing && navigatorKey.currentContext != null && Navigator.canPop(navigatorKey.currentContext!)) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      // Reset flag
      _isIncomingCallScreenShowing = false;

      // Handle missed call (add to chat)
      await _handleMissedCall(callId);
    } catch (e) {
      debugPrint('Error cancelling incoming call: $e');
    }
  }

// Fix the _handleMissedCall method
  Future<void> _handleMissedCall(int callId) async {
    try {
      // Get call details
      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId.toString())
          .get();

      if (!callDoc.exists) return;

      final callData = callDoc.data() as Map<String, dynamic>;
      final callerId = callData['callerId'] as String?;
      final recipientId = callData['recipientId'] as String?;
      final callTypeStr = callData['callType'] as String?;
      final callType = (callTypeStr == 'video') ? 'video' : 'voice';

      if (callerId == null || recipientId == null) return;

      // Update call status to missed
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId.toString())
          .update({
        'status': 'missed',
        'endTime': FieldValue.serverTimestamp(),
      });

      // Add call event to chat
      // Create a chat ID (combination of both user IDs, sorted alphabetically)
      final chatId = [callerId, recipientId]..sort();
      final chatRoomId = chatId.join('_');

      // Create a message for the call event
      final callMessage = {
        'id': const Uuid().v4(),
        'type': 'call_event',
        'callType': callType,
        'status': 'missed',
        'duration': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': callerId,
        'senderName': callData['callerName'] ?? 'Unknown',
        'senderAvatar': callData['callerImage'],
        'chatId': chatRoomId,
        'content': '${callType == 'video' ? 'Video' : 'Voice'} call missed',
        'isRead': false,
        'callId': callId,
        'isOutgoing': false,
      };

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .doc(callMessage['id'] as String)
          .set(callMessage);

      // Update last message in chat document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .set({
        'lastMessageContent': '${callType == 'video' ? 'Video' : 'Voice'} call missed',
        'lastMessageSenderId': callerId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'participants': [callerId, recipientId],
      }, SetOptions(merge: true));

      // Show a missed call notification
      final notificationId = callId.hashCode % 100000;

      final androidDetails = AndroidNotificationDetails(
        'missed_call_channel',
        'Missed Calls',
        channelDescription: 'Notifications for missed calls',
        importance: Importance.high,
        priority: Priority.high,
        color: Colors.red,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      );

      // Get caller name
      final callerName = callData['callerName'] as String? ?? 'Unknown';

      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        'Missed ${callType == 'video' ? 'Video' : 'Voice'} Call',
        'You missed a call from $callerName',
        notificationDetails,
      );

    } catch (e) {
      debugPrint('Error handling missed call: $e');
    }
  }

  void listenForIncomingCalls(String currentUserId, BuildContext context) {
    // Prevent duplicate listeners
    if (_isCallActive || _isIncomingCallScreenShowing) {
      debugPrint('Call already active or incoming call screen showing, not setting up listener');
      return;
    }

    FirebaseFirestore.instance
        .collection('calls')
        .where('recipientId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Only process the most recent call if there are multiple
        final sortedDocs = snapshot.docs.toList()
          ..sort((a, b) {
            final aTime = a.data()['startTime'] as Timestamp?;
            final bTime = b.data()['startTime'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Most recent first
          });

        final data = sortedDocs.first.data();

        final callId = int.tryParse(data['callId'].toString()) ?? 0;
        final callerId = data['callerId'];
        final callerName = data['callerName'];
        final callerImage = data['callerImage'];
        final callType = data['callType'] == 'video' ? CallType.video : CallType.voice;

        debugPrint("📞 Incoming call from $callerName");

        // Only show if no call screen is currently showing
        if (!_isIncomingCallScreenShowing && !_isOutgoingCallScreenShowing) {
          _showIncomingCallNotification(
            callId: callId,
            callerId: callerId,
            callerName: callerName,
            callerImage: callerImage,
            callType: callType,
          );
        }
      }
    });
  }

  // End an active call
  Future<void> _endCall(int callId) async {
    try {
      // Leave the Agora channel
      await _leaveChannel();

      // Update the call status in Firestore
      await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
        'status': 'ended',
        'endTime': FieldValue.serverTimestamp(),
      });

      _isCallActive = false;
      _currentCallId = null;
      _isIncomingCallScreenShowing = false;
      _isOutgoingCallScreenShowing = false;
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  // Initialize the Agora engine
  Future<void> _initializeAgoraEngine() async {
    if (_engine != null) return;

    if (_agoraAppId == null || _agoraAppId!.isEmpty) {
      throw Exception('Agora App ID not set');
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: _agoraAppId!,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    await _engine!.enableAudio();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // Set up event handlers
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Local user joined channel: ${connection.channelId}');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('Remote user joined: $remoteUid');
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('Remote user left: $remoteUid, reason: $reason');
          // If the remote user left, end the call
          if (_currentCallId != null) {
            _endCall(_currentCallId!);
          }
        },
        onError: (err, msg) {
          debugPrint('Agora error: $err, $msg');
        },
      ),
    );
  }

  // Join an Agora channel
  Future<void> _joinChannel(String channelName) async {
    if (_engine == null) {
      await _initializeAgoraEngine();
    }

    try {
      // In a real app, you would get a token from your server
      // For testing, we'll use a temporary token or no token
      const String token = ''; // Replace with your token generation logic

      // Set channel options with proper error handling
      final options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      );

      // Join the channel with proper error handling
      await _engine!.joinChannel(
        token: token,
        channelId: 'channel_$channelName',
        uid: 0,
        options: options,
      );

      debugPrint('Successfully joined channel: channel_$channelName');
    } catch (e) {
      debugPrint('Error joining channel: $e');
      // Rethrow to allow caller to handle the error
      rethrow;
    }
  }

  // Leave an Agora channel
  Future<void> _leaveChannel() async {
    if (_engine != null) {
      await _engine!.leaveChannel();
    }
  }

  // Check if call permissions are granted
  Future<bool> _checkCallPermissions(CallType callType) async {
    // Check microphone permission for all calls
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      debugPrint('Microphone permission denied');
      return false;
    }

    // Check camera permission for video calls
    if (callType == CallType.video) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        debugPrint('Camera permission denied');
        return false;
      }
    }

    return true;
  }

  // Dispose the call service
  void dispose() {
    _callTimeoutTimer?.cancel();
    _leaveChannel();
    _engine?.release();
    _engine = null;
    _isCallActive = false;
    _isIncomingCallScreenShowing = false;
    _isOutgoingCallScreenShowing = false;
  }

  // Check if a call is active
  bool get isCallActive => _isCallActive;
}

// Incoming call screen widget
class IncomingCallScreen extends StatefulWidget {
  final int callId;
  final String callerId;
  final String callerName;
  final String? callerImage;
  final CallType callType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    Key? key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerImage,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                Text(
                  'Incoming ${widget.callType == CallType.video ? 'Video' : 'Voice'} Call',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.blue,
                  backgroundImage: widget.callerImage != null && widget.callerImage!.isNotEmpty
                      ? MemoryImage(base64Decode(widget.callerImage!))
                      : null,
                  child: widget.callerImage == null || widget.callerImage!.isEmpty
                      ? Text(
                    widget.callerName.isNotEmpty
                        ? widget.callerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  )
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'is calling you...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Decline',
                    onPressed: widget.onDecline,
                  ),
                  _buildCallButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: 'Accept',
                    onPressed: widget.onAccept,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// Outgoing call screen widget
class OutgoingCallScreen extends StatefulWidget {
  final int callId;
  final String recipientId;
  final String recipientName;
  final String? recipientImage;
  final CallType callType;
  final VoidCallback onCancel;

  const OutgoingCallScreen({
    Key? key,
    required this.callId,
    required this.recipientId,
    required this.recipientName,
    this.recipientImage,
    required this.callType,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  late StreamSubscription<DocumentSnapshot> _callSubscription;
  String _callStatus = 'ringing';

  @override
  void initState() {
    super.initState();
    _listenForCallUpdates();
  }

  void _listenForCallUpdates() {
    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId.toString())
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        setState(() {
          _callStatus = status;
        });

        if (status == 'connected') {
          // Call was accepted, show the call screen
          _showCallScreen();
        } else if (status == 'declined' || status == 'missed') {
          // Call was declined or missed, close the screen
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _showCallScreen() {
    // Initialize Agora and show the call screen
    final callService = CallService();
    callService._initializeAgoraEngine().then((_) {
      callService._joinChannel(widget.callId.toString()).then((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              userId: widget.recipientId,
              userName: widget.recipientName,
              callType: widget.callType,
              profileImageBase64: widget.recipientImage,
              engine: callService._engine!,
              callId: widget.callId,
              isOutgoing: true,
              onCallEnd: () => callService._endCall(widget.callId),
            ),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _callSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Outgoing ${widget.callType == CallType.video ? 'Video' : 'Voice'} Call',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue,
              backgroundImage: widget.recipientImage != null && widget.recipientImage!.isNotEmpty
                  ? MemoryImage(base64Decode(widget.recipientImage!))
                  : null,
              child: widget.recipientImage == null || widget.recipientImage!.isEmpty
                  ? Text(
                widget.recipientName.isNotEmpty
                    ? widget.recipientName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                ),
              )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              widget.recipientName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusText(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            _buildCallButton(
              icon: Icons.call_end,
              color: Colors.red,
              label: 'Cancel',
              onPressed: widget.onCancel,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );


  }

  String _getStatusText() {
    switch (_callStatus) {
      case 'ringing':
        return 'Calling...';
      case 'connected':
        return 'Connected';
      case 'declined':
        return 'Call declined';
      case 'missed':
        return 'No answer';
      default:
        return 'Calling...';
    }
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 30),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// Background message handler for calls
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // await Firebase.initializeApp();

  if (message.data['type'] == 'call') {
    // Show a notification for the incoming call
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
      // sound: const RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
      actions: [
        const AndroidNotificationAction('answer', 'Answer', showsUserInterface: true),
        const AndroidNotificationAction('decline', 'Decline', showsUserInterface: true),
      ],
    );

    NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    final callId = int.tryParse(message.data['callId'] ?? '0') ?? 0;
    final callerName = message.data['callerName'] ?? 'Unknown';
    final callType = message.data['callType'] ?? 'voice';

    // Convert the call ID to a valid notification ID (within 32-bit integer range)
    final notificationId = callId.hashCode % 100000; // Use hashCode and modulo to get a smaller number

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      callerName,
      platformChannelSpecifics,
      payload: 'call:$callId',
    );
  }
}
