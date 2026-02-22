import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CallType { voice, video }

class CallScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final CallType callType;
  final String? profileImageBase64;
  final RtcEngine engine;
  final int callId;
  final bool isOutgoing;
  final VoidCallback onCallEnd;

  const CallScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.callType,
    this.profileImageBase64,
    required this.engine,
    required this.callId,
    required this.isOutgoing,
    required this.onCallEnd,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  bool _isCallConnected = false;
  bool _isCallRinging = true;
  Duration _callDuration = Duration.zero;
  late DateTime _callStartTime;
  Timer? _callTimer;
  int? _remoteUid;
  bool _localUserJoined = false;
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  bool _networkQualityPoor = false;
  String _callStatus = 'connecting';

  // Animation controller for the pulsing effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  // Add this flag to track if the call has already been ended
  bool _isCallEnding = false;
  // Add this flag to track if the controller has been disposed
  bool _isControllerDisposed = false;

  // For chat messages during call
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  final List<Map<String, dynamic>> _recentMessages = [];
  bool _showMessageBanner = false;
  Timer? _messageBannerTimer;
  final List<int> _remoteUids = [];
  @override
  void initState() {
    super.initState();

    _initializeCall();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenForChatMessages();
  }

  void _listenForChatMessages() async {
    // Get the current user ID
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');

    if (currentUserId == null) return;

    // Create a chat ID (combination of both user IDs, sorted alphabetically)
    final chatId = [currentUserId, widget.userId]..sort();
    final chatRoomId = chatId.join('_');

    // Listen for new messages
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final message = snapshot.docs.first.data();
        final senderId = message['senderId'];

        // Only show notifications for messages from the other user
        if (senderId != currentUserId) {
          setState(() {
            _recentMessages.add(message);
            _showMessageBanner = true;
          });

          // Hide the banner after 5 seconds
          _messageBannerTimer?.cancel();
          _messageBannerTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _showMessageBanner = false;
              });
            }
          });
        }
      }
    });
  }

  Future<void> _initializeCall() async {
    debugPrint('[Agora] Initializing call...');

    widget.engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint(
              '[Agora] Local user joined channel: \${connection.channelId}');
          setState(() {
            _localUserJoined = true;
            _isCallRinging = false;
            _isCallConnected = true;
            _callStartTime = DateTime.now();
          });
          _startCallTimer();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[Agora] Remote user joined: \$remoteUid');
          setState(() {
            _remoteUid = remoteUid;
            _isCallRinging = false;
            _isCallConnected = true;
            if (!_remoteUids.contains(remoteUid)) {
              _remoteUids.add(remoteUid);
            }
          });
        },
        onFirstRemoteVideoFrame:
            (connection, remoteUid, width, height, elapsed) {
          debugPrint(
              '[Agora] 📹 First remote video frame from \$remoteUid (\${width}x\$height)');
          if (!_remoteUids.contains(remoteUid)) {
            setState(() {
              _remoteUids.add(remoteUid);
            });
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[Agora] Remote user left: \$remoteUid, reason: \$reason');
          setState(() {
            _remoteUids.remove(remoteUid);
            if (_remoteUid == remoteUid) _remoteUid = null;
          });
          if (reason == UserOfflineReasonType.userOfflineQuit) {
            _endCall();
          }
        },
        onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
          final isPoor = txQuality.index >= 4 || rxQuality.index >= 4;
          if (_networkQualityPoor != isPoor) {
            setState(() {
              _networkQualityPoor = isPoor;
            });
          }
        },
        onConnectionStateChanged: (connection, state, reason) {
          debugPrint(
              '[Agora] Connection state changed: \$state, reason: \$reason');
          setState(() {
            _callStatus = state == ConnectionStateType.connectionStateConnected
                ? 'connected'
                : state == ConnectionStateType.connectionStateConnecting
                    ? 'connecting'
                    : 'disconnected';
          });
        },
        onError: (err, msg) {
          debugPrint('❌ Agora error: \$err, \$msg');
        },
      ),
    );

    _callSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId.toString())
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        if (status == 'ended' || status == 'declined') {
          debugPrint('[Call] Call ended remotely with status: \$status');
          _endCall();
        }
      }
    });

    if (widget.callType == CallType.video) {
      await widget.engine.enableVideo();
      await widget.engine.startPreview();
      debugPrint('[Agora] Video enabled and preview started');
    } else {
      await widget.engine.disableVideo();
      debugPrint('[Agora] Video disabled (voice call)');
    }

    await widget.engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    if (widget.isOutgoing) {
      setState(() {
        _isCallRinging = true;
        _callStatus = 'ringing';
      });
    }

    debugPrint('[Agora] Call setup complete');
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime);
        });
      }
    });
  }

  void _endCall() {
    // Prevent multiple calls to _endCall
    if (_isCallEnding) return;
    _isCallEnding = true;

    _callTimer?.cancel();
    _callSubscription?.cancel();
    _chatSubscription?.cancel();
    _messageBannerTimer?.cancel();

    // Don't dispose the controller here, it will be disposed in the dispose() method

    // Update call status in Firestore
    FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId.toString())
        .update({
      'status': 'ended',
      'endTime': FieldValue.serverTimestamp(),
      'duration': _callDuration.inSeconds,
    }).catchError((e) {
      debugPrint('Error updating call status: $e');
    });

    // Add call event to chat
    _addCallEventToChat('ended');

    // Call the onCallEnd callback
    widget.onCallEnd();

    // Close the call screen
    if (mounted) {
      Navigator.pop(context);
    }
  }

  // Add call event to chat
  Future<void> _addCallEventToChat(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('user_id');

      if (currentUserId == null) return;

      // Create a chat ID (combination of both user IDs, sorted alphabetically)
      final chatId = [currentUserId, widget.userId]..sort();
      final chatRoomId = chatId.join('_');

      // Create a message for the call event
      final callMessage = {
        'type': 'call_event',
        'callType': widget.callType == CallType.video ? 'video' : 'voice',
        'status': status,
        'duration': _isCallConnected ? _callDuration.inSeconds : 0,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': currentUserId,
        'callId': widget.callId,
        'isOutgoing': widget.isOutgoing,
      };

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add(callMessage);

      // Update last message in chat document
      await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).set({
        'lastMessage':
            '${widget.callType == CallType.video ? 'Video' : 'Voice'} call ${_getCallStatusText(status)}',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUserId, widget.userId],
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error adding call event to chat: $e');
    }
  }

  String _getCallStatusText(String status) {
    switch (status) {
      case 'ended':
        return _isCallConnected ? 'ended' : 'missed';
      case 'declined':
        return 'declined';
      case 'missed':
        return 'missed';
      default:
        return status;
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    widget.engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    widget.engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    widget.engine.muteLocalVideoStream(_isCameraOff);
  }

  void _switchCamera() {
    widget.engine.switchCamera();
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
  void dispose() {
    _callTimer?.cancel();
    _callSubscription?.cancel();
    _chatSubscription?.cancel();
    _messageBannerTimer?.cancel();

    // Only dispose the controller if it hasn't been disposed yet
    if (!_isControllerDisposed) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.dispose();
      _isControllerDisposed = true;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoingCall = widget.isOutgoing && !_isCallConnected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Show confirmation dialog before ending call
        final endCall = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Call'),
            content: const Text('Are you sure you want to end this call?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('End Call', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (endCall == true) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background - video feed for video calls, gradient for voice calls
            widget.callType == CallType.video
                ? _buildVideoView()
                : Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),

            // Call UI
            SafeArea(
              child: Column(
                children: [
                  // Top bar with call info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          widget.callType == CallType.video
                              ? 'Video Call'
                              : widget.isOutgoing
                                  ? 'Outgoing Voice Call'
                                  : 'Voice Call',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isCallConnected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _formatDuration(_callDuration),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // User info (centered for voice calls, top for video)
                  if (widget.callType == CallType.voice || !_isCallConnected)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Animated avatar for outgoing calls
                            if (isOutgoingCall)
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: CircleAvatar(
                                      radius: 60,
                                      backgroundColor: Colors.blue,
                                      backgroundImage:
                                          widget.profileImageBase64 != null &&
                                                  widget.profileImageBase64!
                                                      .isNotEmpty
                                              ? MemoryImage(base64Decode(
                                                  widget.profileImageBase64!))
                                              : null,
                                      onBackgroundImageError:
                                          widget.profileImageBase64 != null &&
                                                  widget.profileImageBase64!
                                                      .isNotEmpty
                                              ? (_, __) {
                                                  // Handle error silently
                                                }
                                              : null,
                                      child:
                                          (widget.profileImageBase64 == null ||
                                                  widget.profileImageBase64!
                                                      .isEmpty)
                                              ? Text(
                                                  widget.userName.isNotEmpty
                                                      ? widget.userName[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 40),
                                                )
                                              : null,
                                    ),
                                  );
                                },
                              )
                            else
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.blue,
                                backgroundImage: widget.profileImageBase64 !=
                                            null &&
                                        widget.profileImageBase64!.isNotEmpty
                                    ? MemoryImage(base64Decode(
                                        widget.profileImageBase64!))
                                    : null,
                                onBackgroundImageError:
                                    widget.profileImageBase64 != null &&
                                            widget
                                                .profileImageBase64!.isNotEmpty
                                        ? (_, __) {
                                            // Handle error silently
                                          }
                                        : null,
                                child: (widget.profileImageBase64 == null ||
                                        widget.profileImageBase64!.isEmpty)
                                    ? Text(
                                        widget.userName.isNotEmpty
                                            ? widget.userName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 40),
                                      )
                                    : null,
                              ),

                            const SizedBox(height: 24),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (_isCallRinging || !_isCallConnected)
                              Text(
                                isOutgoingCall
                                    ? 'Calling...'
                                    : _callStatus.capitalize(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (_isCallConnected &&
                                !_isCallRinging &&
                                widget.callType == CallType.voice)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _formatDuration(_callDuration),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            // Network quality indicator
                            if (_isCallConnected)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _networkQualityPoor
                                          ? Icons.signal_cellular_alt_1_bar
                                          : Icons.signal_cellular_alt,
                                      color: _networkQualityPoor
                                          ? Colors.orange
                                          : Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _networkQualityPoor
                                          ? 'Poor connection'
                                          : 'Good connection',
                                      style: TextStyle(
                                        color: _networkQualityPoor
                                            ? Colors.orange
                                            : Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Call controls
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: isOutgoingCall
                        ? _buildOutgoingCallControls()
                        : _buildActiveCallControls(),
                  ),
                ],
              ),
            ),

            // Message banner
            if (_showMessageBanner && _recentMessages.isNotEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    // Hide the banner
                    setState(() {
                      _showMessageBanner = false;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.message,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _recentMessages.last['text'] ?? 'New message',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.close,
                            color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    return Stack(
      children: [
        // Show all remote UIDs
        if (_remoteUids.isNotEmpty)
          ..._remoteUids.map((uid) => AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: widget.engine,
                  canvas: VideoCanvas(uid: uid),
                  connection:
                      RtcConnection(channelId: 'channel_${widget.callId}'),
                ),
              )),
        if (_remoteUids.isEmpty)
          Container(
            color: Colors.black,
            child: const Center(
              child: Text(
                'Waiting for remote user to join...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

        // Local PIP
        if (_localUserJoined &&
            widget.callType == CallType.video &&
            !_isCameraOff)
          Positioned(
            top: 80,
            right: 20,
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: widget.engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOutgoingCallControls() {
    return Align(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min, // ensures tight fit vertically
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
              onPressed: _endCall,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cancel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallControls() {
    return Column(
      children: [
        // First row of controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCallButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              onPressed: _toggleMute,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 16),
            _buildCallButton(
              icon: Icons.call_end,
              label: 'End',
              onPressed: _endCall,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
            ),
            const SizedBox(width: 16),
            if (widget.callType == CallType.video) ...[
              _buildCallButton(
                icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                label: _isCameraOff ? 'Camera On' : 'Camera Off',
                onPressed: _toggleCamera,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ] else
              _buildCallButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                onPressed: _toggleSpeaker,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
          ],
        ),

        // Second row of controls (additional features)
        if (_isCallConnected)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.callType == CallType.video)
                  _buildCallButton(
                    icon: Icons.flip_camera_ios,
                    label: 'Flip',
                    onPressed: _switchCamera,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    size: 50,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color iconColor = Colors.white,
    double size = 60,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor, size: size * 0.5),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? "${this[0].toUpperCase()}${substring(1)}" : this;
  }
}
