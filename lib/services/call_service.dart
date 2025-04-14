import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import 'notification_service.dart';

class CallData {
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final bool isVideoCall;

  CallData({
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.isVideoCall,
  });
}

class CallService {
  static final CallService _instance = CallService._internal();

  factory CallService() {
    return _instance;
  }

  CallService._internal();

  final _uuid = const Uuid();

  Future<void> startCall(CallData callData) async {
    var uuid = const Uuid().v4();

    // Create a CallKitParams object with the correct parameter names
    final params = CallKitParams(
        id: uuid,
        nameCaller: callData.callerName,
        appName: 'My App',
        avatar: callData.callerAvatar,
        handle: callData.callerId,
        type: callData.isVideoCall ? 1 : 0,
        duration: 30000,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          id: 1,
          subtitle: 'Missed call',
          callbackText: 'Call back',
          isShowCallback: true,
          count: 1,
        ),
        extra: <String, dynamic>{'userId': callData.callerId},
        android: const AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            isShowCallID: false,  // Changed from isShowCallback to isShowCallID
            ringtonePath: 'system_ring',
            backgroundColor: '#0955fa',
            actionColor: '#4CAF50'
        ),
        ios: const IOSParams(
            iconName: 'CallKitLogo',
            handleType: 'generic',
            supportsVideo: true,
            maximumCallGroups: 2,
            maximumCallsPerCallGroup: 1,
            audioSessionMode: 'default',
            audioSessionActive: true,
            supportsDTMF: true,
            supportsHolding: true,
            supportsGrouping: false,
            supportsUngrouping: false,
            ringtonePath: 'system_ring'
        )
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    _showLocalNotification(callData);
  }

  void endCall(String callId) {
    FlutterCallkitIncoming.endAllCalls();
  }

  Future<void> handleIncomingCallFromNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required bool isVideoCall,
    String? callerProfileImage,
  }) async {
    debugPrint('Handling incoming call from notification: $callId');

    // Create call data
    final callData = CallData(
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerProfileImage ?? '',
      isVideoCall: isVideoCall,
    );

    // Show notification using your existing notification service
    _showLocalNotification(callData);

    // Create a CallKitParams object with the correct parameter names
    final params = CallKitParams(
        id: callId,
        nameCaller: callerName,
        appName: 'My App',
        avatar: callerProfileImage,
        handle: callerId,
        type: isVideoCall ? 1 : 0,
        duration: 30000,
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: const NotificationParams(
          id: 1,
          subtitle: 'Missed call',
          callbackText: 'Call back',
          isShowCallback: true,
          count: 1,
        ),
        extra: <String, dynamic>{'userId': callerId},
        android: const AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            isShowCallID: false,  // Changed from isShowCallback to isShowCallID
            ringtonePath: 'system_ring',
            backgroundColor: '#0955fa',
            actionColor: '#4CAF50'
        ),
        ios: const IOSParams(
            iconName: 'CallKitLogo',
            handleType: 'generic',
            supportsVideo: true,
            maximumCallGroups: 2,
            maximumCallsPerCallGroup: 1,
            audioSessionMode: 'default',
            audioSessionActive: true,
            supportsDTMF: true,
            supportsHolding: true,
            supportsGrouping: false,
            supportsUngrouping: false,
            ringtonePath: 'system_ring'
        )
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> _showLocalNotification(CallData callData) async {
    debugPrint('Showing incoming call notification');

    // Use your existing notification service method
    final _notificationService = NotificationService();
    await _notificationService.showLocalNotification(
      id: 0,
      title: 'Incoming ${callData.isVideoCall ? 'Video' : 'Voice'} Call',
      body: 'From ${callData.callerName}',
      channelId: 'call_channel',
      channelName: 'Call Notifications',
      channelDescription: 'Notifications for incoming calls',
      color: Colors.blue,
    );
  }
}
