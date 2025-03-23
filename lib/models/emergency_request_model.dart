class EmergencyRequestModel {
  final String id;
  final String title;
  final String description;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final List<String> requiredSkills;
  final DateTime deadline;
  final DateTime createdAt;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  EmergencyRequestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatar,
    required this.requiredSkills,
    required this.deadline,
    required this.createdAt,
    this.isResolved = false,
    this.resolvedBy,
    this.resolvedAt,
  });

  factory EmergencyRequestModel.fromJson(Map<String, dynamic> json) {
    return EmergencyRequestModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String,
      requesterAvatar: json['requesterAvatar'] as String?,
      requiredSkills: List<String>.from(json['requiredSkills'] ?? []),
      deadline: DateTime.parse(json['deadline'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isResolved: json['isResolved'] as bool? ?? false,
      resolvedBy: json['resolvedBy'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterAvatar': requesterAvatar,
      'requiredSkills': requiredSkills,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isResolved': isResolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }
}

