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

  // Call notification channel
  static final AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
    'call_channel',
    'Call Notifications',
    description: 'Notifications for incoming calls',
    importance: Importance.max,
    sound: const RawResourceAndroidNotificationSound('ringtone'),
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

    // Show a full-screen notification for the call
    await _flutterLocalNotificationsPlugin.show(
      callId,
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
          sound: 'ringtone.caf',
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
    _callTimeoutTimer = Timer(const Duration(seconds: 60), () {
      _cancelIncomingCall(callId);
    });
  }

  // Show incoming call screen
  void _showIncomingCallScreen({
    required int callId,
    required String callerId,
    required String callerName,
    String? callerImage,
    required CallType callType,
  }) {
    if (navigatorKey.currentContext != null) {
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
      );
    }
  }

  // Handle call notification tap
  void _handleCallNotificationTap(RemoteMessage message) async {
    final callData = message.data;
    final callerId = callData['callerId'];
    final callerName = callData['callerName'];
    final callerImage = callData['callerImage'];
    final callType = callData['callType'] == 'video' ? CallType.video : CallType.voice;
    final callId = int.tryParse(callData['callId'] ?? '0') ?? 0;

    // Show incoming call screen
    _showIncomingCallScreen(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerImage: callerImage,
      callType: callType,
    );
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

  // ✅ NEW METHOD
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

      // Create a call document in Firestore
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
      });

      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection(Constants.usersCollection)
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        debugPrint('Recipient not found');
        return false;
      }

      final recipientData = recipientDoc.data() as Map<String, dynamic>;
      final fcmToken = recipientData['fcmToken'] as String?;

      if (fcmToken == null) {
        debugPrint('Recipient FCM token not found');
        return false;
      }

      // Send a call notification to the recipient
      // In a real app, you would use Firebase Cloud Functions or a server for this
      // For now, we'll simulate it by updating the call document
      await FirebaseFirestore.instance.collection('calls').doc(callId.toString()).update({
        'notificationSent': true,
      });

      // Show the outgoing call screen
      if (navigatorKey.currentContext != null) {
        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (_) => OutgoingCallScreen(
              callId: callId,
              recipientId: recipientId,
              recipientName: recipientName,
              recipientImage: recipientImage,
              callType: callType,
              onCancel: () => _cancelOutgoingCall(callId),
            ),
          ),
        );
      }

      // Set a timeout for the outgoing call (60 seconds)
      _callTimeoutTimer = Timer(const Duration(seconds: 60), () {
        _cancelOutgoingCall(callId);
      });

      _isCallActive = true;
      return true;
    } catch (e) {
      debugPrint('Error making call: $e');
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

      // Join the call channel
      await _joinChannel(callId.toString());

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
        );
      }

      // Cancel the notification
      await _flutterLocalNotificationsPlugin.cancel(callId);

      _isCallActive = true;
      _currentCallId = callId;
      return true;
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

      // Cancel the notification
      await _flutterLocalNotificationsPlugin.cancel(callId);

      // Close the incoming call screen if it's open
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
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
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }

      _isCallActive = false;
      _currentCallId = null;
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

      // Cancel the notification
      await _flutterLocalNotificationsPlugin.cancel(callId);
    } catch (e) {
      debugPrint('Error cancelling incoming call: $e');
    }
  }
  void listenForIncomingCalls(String currentUserId, BuildContext context) {
    FirebaseFirestore.instance
        .collection('calls')
        .where('recipientId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();

        final callId = int.tryParse(data['callId'].toString()) ?? 0;
        final callerId = data['callerId'];
        final callerName = data['callerName'];
        final callerImage = data['callerImage'];
        final callType = data['callType'] == 'video' ? CallType.video : CallType.voice;

        debugPrint("📞 Incoming call from $callerName");

        _showIncomingCallScreen(
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callerImage: callerImage,
          callType: callType,
        );
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

    // In a real app, you would get a token from your server
    // For testing, we'll use a temporary token or no token
    const String token = ''; // Replace with your token generation logic

    await _engine!.joinChannel(
      token: token,
      channelId: 'channel_$channelName',
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
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
                  backgroundImage: widget.callerImage != null
                      ? MemoryImage(base64Decode(widget.callerImage!))
                      : null,
                  child: widget.callerImage == null
                      ? Text(
                    widget.callerName[0].toUpperCase(),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 60),
            Column(
              children: [
                Text(
                  'Outgoing ${widget.callType == CallType.video ? 'Video' : 'Voice'} Call',
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
                  backgroundImage: widget.recipientImage != null
                      ? MemoryImage(base64Decode(widget.recipientImage!))
                      : null,
                  child: widget.recipientImage == null
                      ? Text(
                    widget.recipientName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                    ),
                  )
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.recipientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _getStatusText(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: _buildCallButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: 'Cancel',
                onPressed: widget.onCancel,
              ),
            ),
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
      sound: const RawResourceAndroidNotificationSound('ringtone'),
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

    await flutterLocalNotificationsPlugin.show(
      callId,
      'Incoming ${callType == 'video' ? 'Video' : 'Voice'} Call',
      callerName,
      platformChannelSpecifics,
      payload: 'call:$callId',
    );
  }
}