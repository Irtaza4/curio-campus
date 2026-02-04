import 'package:flutter/material.dart';

enum NotificationType {
  chat,
  emergency,
  project,
  profile,
  call, // ✅ Added missing type
  system,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final String? relatedId; // ID of related item (chat, emergency request, etc.)
  final bool isRead;
  final Map<String, dynamic>? additionalData;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.relatedId,
    this.isRead = false,
    this.additionalData,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: _parseNotificationType(json['type'] as String),
      relatedId: json['relatedId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'relatedId': relatedId,
      'isRead': isRead,
      'additionalData': additionalData,
    };
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type) {
      case 'chat':
        return NotificationType.chat;
      case 'emergency':
        return NotificationType.emergency;
      case 'project':
        return NotificationType.project;
      case 'profile':
        return NotificationType.profile;
      case 'call': // ✅ Added to match enum
        return NotificationType.call;
      default:
        return NotificationType.system;
    }
  }

  IconData getIcon() {
    switch (type) {
      case NotificationType.chat:
        return Icons.chat_bubble_outline;
      case NotificationType.emergency:
        return Icons.warning_amber_rounded;
      case NotificationType.project:
        return Icons.assignment_outlined;
      case NotificationType.profile:
        return Icons.person_outline;
      case NotificationType.call: // ✅ Added icon
        return Icons.call_outlined;
      case NotificationType.system:
        return Icons.notifications_none;
    }
  }

  Color getColor() {
    switch (type) {
      case NotificationType.chat:
        return Colors.blue;
      case NotificationType.emergency:
        return Colors.orange;
      case NotificationType.project:
        return Colors.green;
      case NotificationType.profile:
        return Colors.purple;
      case NotificationType.call: // ✅ Added color
        return Colors.purple;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${(difference.inDays / 7).floor()} ${(difference.inDays / 7).floor() == 1 ? 'week' : 'weeks'} ago';
    }
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    String? relatedId,
    bool? isRead,
    Map<String, dynamic>? additionalData,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}
