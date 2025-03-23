enum ChatType { individual, group }

class ChatModel {
  final String id;
  final String name;
  final List<String> participants;
  final ChatType type;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? lastMessageContent;
  final String? lastMessageSenderId;
  final String? groupImageUrl;

  ChatModel({
    required this.id,
    required this.name,
    required this.participants,
    required this.type,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessageContent,
    this.lastMessageSenderId,
    this.groupImageUrl,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      participants: List<String>.from(json['participants']),
      type: ChatType.values.firstWhere(
            (e) => e.toString() == 'ChatType.${json['type']}',
        orElse: () => ChatType.individual,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      lastMessageContent: json['lastMessageContent'] as String?,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      groupImageUrl: json['groupImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'participants': participants,
      'type': type.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessageContent': lastMessageContent,
      'lastMessageSenderId': lastMessageSenderId,
      'groupImageUrl': groupImageUrl,
    };
  }
}

