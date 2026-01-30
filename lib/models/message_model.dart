import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, file, system, audio, video, callEvent }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String chatId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  // fileUrl can store either a URL to an image or a base64-encoded string
  final String? fileUrl;
  final String? fileName;
  final int? duration; // For audio/video duration in seconds

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.chatId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.fileUrl,
    this.fileName,
    this.duration,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageType getType(String? typeStr) {
      if (typeStr == 'call_event') return MessageType.callEvent;
      return MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == typeStr,
        orElse: () => MessageType.text,
      );
    }

    return MessageModel(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      senderAvatar: json['senderAvatar']?.toString(),
      chatId: json['chatId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: getType(json['type']?.toString()),
      timestamp: _parseTimestamp(json['timestamp']),
      isRead: json['isRead'] as bool? ?? false,
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      duration: json['duration'] is int
          ? json['duration']
          : int.tryParse(json['duration']?.toString() ?? ''),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    } else {
      return DateTime.now(); // fallback
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'chatId': chatId,
      'content': content,
      'type': type == MessageType.callEvent
          ? 'call_event'
          : type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'duration': duration,
    };
  }
}
