enum MessageType { text, image, file, system }

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
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      chatId: json['chatId'] as String,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
            (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      fileUrl: json['fileUrl'] as String?,
      fileName: json['fileName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'chatId': chatId,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'fileUrl': fileUrl,
      'fileName': fileName,
    };
  }
}
