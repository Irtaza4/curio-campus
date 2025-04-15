import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    Key? key,
    required this.userId,
    required this.userName,
    required this.callType,
    this.profileImageBase64,
    required this.engine,
    required this.callId,
    required this.isOutgoing,
    required this.onCallEnd,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  bool _isCallConnected = false;
  bool _isCallRinging = true;
  Duration _callDuration = Duration.zero;
  late DateTime _callStartTime;
  Timer? _callTimer;
  bool _isScreenSharing = false;
  int? _remoteUid;
  bool _localUserJoined = false;
  StreamSubscription<DocumentSnapshot>? _callSubscription;
  bool _networkQualityPoor = false;
  String _callStatus = 'connecting';

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    // Set up event handlers for the Agora engine
    widget.engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Local user joined channel: ${connection.channelId}');
          setState(() {
            _localUserJoined = true;
            _isCallRinging = false;
            _isCallConnected = true;
            _callStartTime = DateTime.now();
          });
          _startCallTimer();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('Remote user joined: $remoteUid');
          setState(() {
            _remoteUid = remoteUid;
            _isCallRinging = false;
            _isCallConnected = true;
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('Remote user left: $remoteUid, reason: $reason');
          setState(() {
            _remoteUid = null;
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
          debugPrint('Connection state changed: $state, reason: $reason');
          setState(() {
            _callStatus = state == ConnectionStateType.connectionStateConnected
                ? 'connected'
                : state == ConnectionStateType.connectionStateConnecting
                ? 'connecting'
                : 'disconnected';
          });
        },
        onError: (err, msg) {
          debugPrint('Agora error: $err, $msg');
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
          _endCall();
        }
      }
    });

    if (widget.callType == CallType.video) {
      await widget.engine.enableVideo();
      await widget.engine.startPreview();
    } else {
      await widget.engine.disableVideo();
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
  }

  // Future<void> _initializeCall() async {
  //   // Set up event handlers for the Agora engine
  //   widget.engine.registerEventHandler(
  //     RtcEngineEventHandler(
  //       onJoinChannelSuccess: (connection, elapsed) {
  //         debugPrint('Local user joined channel: ${connection.channelId}');
  //         setState(() {
  //           _localUserJoined = true;
  //           _isCallRinging = false;
  //           _isCallConnected = true;
  //           _callStartTime = DateTime.now();
  //         });
  //         _startCallTimer();
  //       },
  //       onUserJoined: (connection, remoteUid, elapsed) {
  //         debugPrint('Remote user joined: $remoteUid');
  //         setState(() {
  //           _remoteUid = remoteUid;
  //           _isCallRinging = false;
  //           _isCallConnected = true;
  //         });
  //       },
  //       onUserOffline: (connection, remoteUid, reason) {
  //         debugPrint('Remote user left: $remoteUid, reason: $reason');
  //         setState(() {
  //           _remoteUid = null;
  //         });
  //         // End the call if the remote user left
  //         if (reason == UserOfflineReasonType.userOfflineQuit) {
  //           _endCall();
  //         }
  //       },
  //       onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
  //         // Update network quality indicator - fixed comparison
  //         final isPoor = txQuality.index >= 4 || rxQuality.index >= 4; // 4 or higher means poor quality
  //         if (_networkQualityPoor != isPoor) {
  //           setState(() {
  //             _networkQualityPoor = isPoor;
  //           });
  //         }
  //       },
  //       onConnectionStateChanged: (connection, state, reason) {
  //         debugPrint('Connection state changed: $state, reason: $reason');
  //         if (state == ConnectionStateType.connectionStateConnected) {
  //           setState(() {
  //             _callStatus = 'connected';
  //           });
  //         } else if (state == ConnectionStateType.connectionStateConnecting) {
  //           setState(() {
  //             _callStatus = 'connecting';
  //           });
  //         } else if (state == ConnectionStateType.connectionStateDisconnected) {
  //           setState(() {
  //             _callStatus = 'disconnected';
  //           });
  //         }
  //       },
  //       onError: (err, msg) {
  //         debugPrint('Agora error: $err, $msg');
  //       },
  //     ),
  //   );
  //
  //   // Listen for call updates from Firestore
  //   _callSubscription = FirebaseFirestore.instance
  //       .collection('calls')
  //       .doc(widget.callId.toString())
  //       .snapshots()
  //       .listen((snapshot) {
  //     if (snapshot.exists) {
  //       final data = snapshot.data() as Map<String, dynamic>;
  //       final status = data['status'] as String;
  //
  //       if (status == 'ended' || status == 'declined') {
  //         // Call was ended by the other party
  //         _endCall();
  //       }
  //     }
  //   });
  //
  //   // Enable video for video calls
  //   if (widget.callType == CallType.video) {
  //     await widget.engine.enableVideo();
  //     await widget.engine.startPreview();
  //   } else {
  //     await widget.engine.disableVideo();
  //   }
  //
  //   // Set audio profile for better voice quality
  //   await widget.engine.setAudioProfile(
  //     profile: AudioProfileType.audioProfileDefault,
  //     scenario: AudioScenarioType.audioScenarioChatroom,
  //   );
  //
  //   // Join the channel - fixed token parameter
  //   // await widget.engine.joinChannel(
  //   //   token: '', // Empty string instead of null
  //   //   channelId: 'channel_${widget.callId}',
  //   //   uid: 0,
  //   //   options: const ChannelMediaOptions(
  //   //     clientRoleType: ClientRoleType.clientRoleBroadcaster,
  //   //     channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
  //   //   ),
  //   // );
  //
  //   // Simulate call connection after a short delay
  //   if (widget.isOutgoing) {
  //     setState(() {
  //       _isCallRinging = true;
  //       _callStatus = 'ringing';
  //     });
  //   }
  // }

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
    _callTimer?.cancel();
    _callSubscription?.cancel();

    // Update call status in Firestore
    FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId.toString())
        .update({
      'status': 'ended',
      'endTime': FieldValue.serverTimestamp(),
    }).catchError((e) {
      debugPrint('Error updating call status: $e');
    });

    // Leave the channel
    widget.engine.leaveChannel();

    // Call the onCallEnd callback
    widget.onCallEnd();

    // Close the call screen
    if (mounted) {
      Navigator.pop(context);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog before ending call
        final result = await showDialog<bool>(
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
                child: const Text('End Call', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (result == true) {
          _endCall();
        }
        return false;
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
                    AppTheme.primaryColor.withOpacity(0.8),
                    Colors.black,
                  ],
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
                            // Show confirmation dialog before minimizing call
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('End Call'),
                                content: const Text('Are you sure you want to end this call?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _endCall();
                                    },
                                    child: const Text('End Call', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
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
                            Row(
                              children: [
                                if (_networkQualityPoor)
                                  const Icon(
                                    Icons.signal_cellular_connected_no_internet_4_bar,
                                    color: Colors.orange,
                                    size: 14,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  _isCallRinging
                                      ? _callStatus.capitalize()
                                      : _formatDuration(_callDuration),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
                          onPressed: widget.callType == CallType.video
                              ? _switchCamera
                              : null,
                        ),
                      ],
                    ),
                  ),

                  // User info (centered for voice calls, top for video)
                  if (widget.callType == CallType.voice || !_isCallConnected)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: AppTheme.primaryColor,
                              backgroundImage: widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty
                                  ? MemoryImage(base64Decode(widget.profileImageBase64!))
                                  : null,
                              onBackgroundImageError: widget.profileImageBase64 != null && widget.profileImageBase64!.isNotEmpty
                                  ? (_, __) {
                                // Handle error silently
                              }
                                  : null,
                              child: (widget.profileImageBase64 == null || widget.profileImageBase64!.isEmpty)
                                  ? Text(
                                widget.userName.isNotEmpty
                                    ? widget.userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 40),
                              )
                                  : null,
                            ),

                            const SizedBox(height: 24),
                            if (_isCallRinging)
                              Text(
                                _callStatus.capitalize(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Call controls
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
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
                        if (widget.callType == CallType.video) ...[
                          _buildCallButton(
                            icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                            label: _isCameraOff ? 'Camera On' : 'Camera Off',
                            onPressed: _toggleCamera,
                            backgroundColor: Colors.white.withOpacity(0.2),
                          ),
                        ] else
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
    );
  }

  Widget _buildVideoView() {
    return Stack(
      children: [
        // Remote video (full screen)
        _remoteUid != null
            ? AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: widget.engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: 'channel_${widget.callId}'),
          ),
        )
            : Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              'Waiting for remote user to join...',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),

        // Local video (picture-in-picture)
        if (_localUserJoined && widget.callType == CallType.video && !_isCameraOff)
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

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? "${this[0].toUpperCase()}${substring(1)}" : this;
  }
}
