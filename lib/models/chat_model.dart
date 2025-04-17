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
  final String? creatorId; // Added field to track who created the group

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
    this.creatorId, // Added to constructor
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      participants: (json['participants'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          [],
      type: ChatType.values.firstWhere(
            (e) => e.toString() == 'ChatType.${json['type']}',
        orElse: () => ChatType.individual,
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMessageContent: json['lastMessageContent']?.toString(),
      lastMessageSenderId: json['lastMessageSenderId']?.toString(),
      groupImageUrl: json['groupImageUrl']?.toString(),
      creatorId: json['creatorId']?.toString(),
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
      'creatorId': creatorId, // Added to toJson
    };
  }
}
