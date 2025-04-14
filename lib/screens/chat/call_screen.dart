import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:curio_campus/utils/image_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../services/call_service.dart';

enum CallType { voice, video }
enum CallState { ringing, connecting, connected, ended, failed, busy, noAnswer, networkError }
enum NetworkStatus { online, offline, unknown }

class CallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final CallType callType;
  final String? profileImageBase64;
  final bool autoConnect;
  final bool isOutgoing; // Whether this is an outgoing call or incoming call
  final String? callId;
  const CallScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.callType,
    this.profileImageBase64,
    this.autoConnect = false,
    this.isOutgoing = true,
    this.callId,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  CallState _callState = CallState.ringing;
  Duration _callDuration = Duration.zero;
  late DateTime _callStartTime;
  Timer? _callTimer;
  bool _isScreenSharing = false;
  bool _isScreenRecording = false;
  bool _permissionsGranted = false;
  bool _isCheckingPermissions = true;
  Timer? _ringTimer;
  bool _callAccepted = false;
  bool _isRecordingScreen = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  NetworkStatus _networkStatus = NetworkStatus.unknown;
  Timer? _networkCheckTimer;
  int _ringCount = 0;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final CallService _callService = CallService();
  String? _callId;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
    _checkPermissions();
    _startRealNetworkCheck();
    _callId = widget.callId;

    debugPrint('CallScreen initialized with callId: ${widget.callId}, isOutgoing: ${widget.isOutgoing}');
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  void _startRealNetworkCheck() {
    // Check connectivity using connectivity_plus package
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _networkStatus = result == ConnectivityResult.none
            ? NetworkStatus.offline
            : NetworkStatus.online;
      });

      debugPrint('Network status changed to: $_networkStatus');

      // If we're in ringing state and network goes offline, update UI
      if (_callState == CallState.ringing && _networkStatus == NetworkStatus.offline && widget.isOutgoing) {
        setState(() {
          _callState = CallState.networkError;
        });

        // Show network error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Please check your connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // Initial check
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _networkStatus = result == ConnectivityResult.none
            ? NetworkStatus.offline
            : NetworkStatus.online;
      });
      debugPrint('Initial network status: $_networkStatus');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app going to background/foreground
    if (state == AppLifecycleState.paused) {
      // App went to background
      if (_callState == CallState.ringing || _callState == CallState.connected) {
        _showCallNotification();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _cancelCallNotification();
    }
  }

  Future<void> _showCallNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Notifications for ongoing calls',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      _callState == CallState.ringing
          ? 'Calling ${widget.userName}...'
          : 'On call with ${widget.userName}',
      _callState == CallState.connected
          ? 'Tap to return to call'
          : 'Call in progress',
      platformChannelSpecifics,
    );
  }

  Future<void> _cancelCallNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isCheckingPermissions = true;
    });

    bool granted = false;

    if (widget.callType == CallType.video) {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      granted = cameraStatus.isGranted && micStatus.isGranted;
    } else {
      final micStatus = await Permission.microphone.request();
      granted = micStatus.isGranted;
    }

    setState(() {
      _permissionsGranted = granted;
      _isCheckingPermissions = false;
    });

    if (granted) {
      _initializeCall();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.callType == CallType.video
              ? 'Camera and microphone permissions are required for video calls'
              : 'Microphone permission is required for voice calls'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _recordingTimer?.cancel();
    _networkCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _stopScreenRecording();
    _cancelCallNotification();
    // End call if it's still active
    if (_callId != null && (_callState == CallState.ringing || _callState == CallState.connected)) {
      _callService.endCall(_callId!);
    }
    super.dispose();
  }

  void _initializeCall() {
    // Check if permissions are granted before proceeding
    if (!_permissionsGranted) {
      _checkPermissions().then((_) {
        if (_permissionsGranted) {
          _startCall();
        }
      });
      return;
    }

    _startCall();
  }

  void _startCall() async {
    // If this is an incoming call, show the incoming call UI
    if (!widget.isOutgoing) {
      debugPrint('Handling incoming call UI');
      setState(() {
        _callState = CallState.ringing;
      });

      // Play ringtone here in a real app
      _simulateRinging();
      return;
    }

    try {
      debugPrint('Making outgoing call to ${widget.userId}');
      final callId = await _callService.makeCall(
        receiverId: widget.userId,
        receiverName: widget.userName,
        receiverProfileImage: widget.profileImageBase64,
        isVideoCall: widget.callType == CallType.video,
        context: context,
      );

      // Save the call ID
      _callId = callId;
      debugPrint('Call ID generated: $callId');

      // Show ringing state
      setState(() {
        _callState = CallState.ringing;
      });

      // Simulate ringing sound and vibration
      _simulateRinging();

      // If autoConnect is true, automatically accept the call after 3 seconds
      if (widget.autoConnect) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _callState == CallState.ringing) {
            _acceptCall();
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to initiate call: $e');
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initiate call: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _simulateRinging() {
    // Simulate ringing sound and vibration
    // In a real app, you would play an actual ringtone

    // Update ring count every second to show "Ringing..." animation
    _ringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _callState == CallState.ringing) {
        setState(() {
          _ringCount++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _acceptCall() {
    debugPrint('Accepting call with ID: $_callId');
    _callAccepted = true;
    _ringTimer?.cancel();

    // If this is an incoming call, notify the call service
    if (!widget.isOutgoing && _callId != null) {
      _callService.acceptCall(_callId!);
    }

    setState(() {
      _callState = CallState.connecting;
    });

    // Simulate connection delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _callState = CallState.connected;
          _callStartTime = DateTime.now();
        });

        // Start call timer
        _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _callDuration = DateTime.now().difference(_callStartTime);
            });
          }
        });
      }
    });
  }

  void _endCall() {
    setState(() {
      _callState = CallState.ended;
    });

    _callTimer?.cancel();
    _stopScreenRecording();

    // If we have a call ID, end the call through the service
    if (_callId != null) {
      _callService.endCall(_callId!);
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _rejectCall() {
    setState(() {
      _callState = CallState.ended;
    });

    // If this is an incoming call, notify the call service
    if (!widget.isOutgoing && _callId != null) {
      _callService.rejectCall(_callId!);
    }

    // Close call screen
    Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'Microphone muted' : 'Microphone unmuted'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSpeakerOn ? 'Speaker on' : 'Speaker off'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isCameraOff ? 'Camera off' : 'Camera on'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleScreenShare() {
    setState(() {
      _isScreenSharing = !_isScreenSharing;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isScreenSharing ? 'Screen sharing started' : 'Screen sharing stopped'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleScreenRecording() async {
    if (_isRecordingScreen) {
      await _stopScreenRecording();
    } else {
      await _startScreenRecording();
    }
  }

  Future<void> _startScreenRecording() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required for screen recording'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create a unique filename
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/screen_recording_$timestamp.mp4';

      // In a real app, you would use a screen recording package here
      // For this demo, we'll just simulate recording
      setState(() {
        _isRecordingScreen = true;
        _recordingDuration = Duration.zero;
      });

      // Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screen recording started'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error starting screen recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopScreenRecording() async {
    if (!_isRecordingScreen) return;

    _recordingTimer?.cancel();

    // In a real app, you would stop the actual recording here
    setState(() {
      _isRecordingScreen = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Screen recording saved to: $_recordingPath'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _switchCamera() {
    // Implement camera switching logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera switched'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    if (_isCheckingPermissions) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Checking permissions...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.callType == CallType.video ? Icons.videocam_off : Icons.mic_off,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Permission denied',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - would be the video feed in a real implementation
          widget.callType == CallType.video
              ? Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black87,
            child: _isCameraOff
                ? Center(
              child: Icon(
                Icons.videocam_off,
                size: 80,
                color: Colors.white.withOpacity(0.5),
              ),
            )
                : _isScreenSharing
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.screen_share,
                    size: 80,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Screen Sharing Active',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
                : null,
          )
              : Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  Colors.black,
                ],
              ),
            ),
          ),

          // Network status indicator
          if (_networkStatus == NetworkStatus.offline)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.red,
                child: const Center(
                  child: Text(
                    'No network connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Call UI
          SafeArea(
            child: Column(
              children: [
                // Top bar with call info
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Column(
                        children: [
                          Text(
                            widget.userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCallStatusText(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          widget.callType == CallType.video
                              ? Icons.switch_camera
                              : Icons.info_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: widget.callType == CallType.video && _callState == CallState.connected
                            ? _switchCamera
                            : null,
                      ),
                    ],
                  ),
                ),

                // Screen recording indicator
                if (_isRecordingScreen)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recording: ${_formatDuration(_recordingDuration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                // User info (centered for voice calls, top for video)
                if (_callState == CallState.ringing && widget.isOutgoing)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Calling',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(width: 4),
                              _buildRingingDots(),
                            ],
                          ),
                          if (_networkStatus == NetworkStatus.offline)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                'Poor connection...',
                                style: TextStyle(
                                  color: Colors.red[300],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else if (_callState == CallState.ringing && !widget.isOutgoing)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(height: 24),
                          Text(
                            'Incoming call...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _rejectCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.all(16),
                                  shape: const CircleBorder(),
                                ),
                                child: const Icon(
                                  Icons.call_end,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 48),
                              ElevatedButton(
                                onPressed: _acceptCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.all(16),
                                  shape: const CircleBorder(),
                                ),
                                child: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_callState == CallState.connected && widget.callType == CallType.voice)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildProfileAvatar(),
                            const SizedBox(height: 24),
                            Text(
                              _formatDuration(_callDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_callState == CallState.ended || _callState == CallState.failed ||
                        _callState == CallState.noAnswer || _callState == CallState.networkError)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildProfileAvatar(),
                              const SizedBox(height: 24),
                              Text(
                                _getCallEndStatusText(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_callState == CallState.ended && _callDuration.inSeconds > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Duration: ${_formatDuration(_callDuration)}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(child: Container()),

                // Call controls
                if (_callState != CallState.ended && _callState != CallState.failed &&
                    _callState != CallState.noAnswer && _callState != CallState.networkError)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_callState == CallState.connected) ...[
                              _buildCallButton(
                                icon: _isMuted ? Icons.mic_off : Icons.mic,
                                label: _isMuted ? 'Unmute' : 'Mute',
                                onPressed: _toggleMute,
                                backgroundColor: Colors.white.withOpacity(0.2),
                              ),
                              _buildCallButton(
                                icon: Icons.call_end,
                                label: 'End',
                                onPressed: _endCall,
                                backgroundColor: Colors.red,
                                iconColor: Colors.white,
                              ),
                              if (widget.callType == CallType.video)
                                _buildCallButton(
                                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                                  label: _isCameraOff ? 'Camera On' : 'Camera Off',
                                  onPressed: _toggleCamera,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                )
                              else
                                _buildCallButton(
                                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                                  label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                                  onPressed: _toggleSpeaker,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                ),
                            ] else if (widget.isOutgoing && _callState == CallState.ringing)
                              _buildCallButton(
                                icon: Icons.call_end,
                                label: 'Cancel',
                                onPressed: _endCall,
                                backgroundColor: Colors.red,
                                iconColor: Colors.white,
                              ),
                          ],
                        ),

                        // Additional controls for connected calls
                        if (_callState == CallState.connected && widget.callType == CallType.video)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCallButton(
                                  icon: _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                                  label: _isScreenSharing ? 'Stop Share' : 'Share Screen',
                                  onPressed: _toggleScreenShare,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                ),
                                _buildCallButton(
                                  icon: _isRecordingScreen ? Icons.stop_circle : Icons.fiber_manual_record,
                                  label: _isRecordingScreen ? 'Stop Recording' : 'Record Screen',
                                  onPressed: _toggleScreenRecording,
                                  backgroundColor: _isRecordingScreen ? Colors.red.withOpacity(0.6) : Colors.white.withOpacity(0.2),
                                ),
                                _buildCallButton(
                                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                                  label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                                  onPressed: _toggleSpeaker,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingingDots() {
    // Animated dots to show ringing status
    final dotsCount = (_ringCount % 3) + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < dotsCount; i++)
          Text(
            '.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  String _getCallStatusText() {
    switch (_callState) {
      case CallState.ringing:
        return widget.isOutgoing ? 'Calling...' : 'Incoming call...';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return _formatDuration(_callDuration);
      case CallState.ended:
        return 'Call ended';
      case CallState.failed:
        return 'Call failed';
      case CallState.busy:
        return 'User is busy';
      case CallState.noAnswer:
        return 'No answer';
      case CallState.networkError:
        return 'Network error';
      default:
        return '';
    }
  }

  String _getCallEndStatusText() {
    switch (_callState) {
      case CallState.ended:
        return 'Call ended';
      case CallState.failed:
        return 'Call failed';
      case CallState.busy:
        return 'User is busy';
      case CallState.noAnswer:
        return 'No answer';
      case CallState.networkError:
        return 'Network error';
      default:
        return 'Call ended';
    }
  }

  Widget _buildProfileAvatar() {
    // Fixed the CircleAvatar issue by properly handling null backgroundImage
    if (widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty) {
      try {
        // Try to decode the base64 string using our improved utility
        final bytes = ImageUtils.safelyDecodeBase64(widget.profileImageBase64!);

        if (bytes != null) {
          return CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.primaryColor,
            child: ClipOval(
              child: Image.memory(
                bytes,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 40),
                  );
                },
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error decoding profile image: $e');
      }
    }

    return CircleAvatar(
      radius: 60,
      backgroundColor: AppTheme.primaryColor,
      child: Text(
        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 40),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color iconColor = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor, size: 28),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
