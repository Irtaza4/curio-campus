import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<Map<String, dynamic>> responses; // Added this field

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
    required this.isResolved,
    this.resolvedBy,
    this.resolvedAt,
    this.responses = const [], // Initialize with empty list
  });

  factory EmergencyRequestModel.fromJson(Map<String, dynamic> json) {
    return EmergencyRequestModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String,
      requesterAvatar: json['requesterAvatar'] as String?,
      requiredSkills: List<String>.from(json['requiredSkills'] as List),
      deadline: json['deadline'] is Timestamp
          ? (json['deadline'] as Timestamp).toDate()
          : DateTime.parse(json['deadline'] as String),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      isResolved: json['isResolved'] as bool,
      resolvedBy: json['resolvedBy'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? json['resolvedAt'] is Timestamp
          ? (json['resolvedAt'] as Timestamp).toDate()
          : DateTime.parse(json['resolvedAt'] as String)
          : null,
      responses: json['responses'] != null
          ? List<Map<String, dynamic>>.from(json['responses'] as List)
          : [],
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
      'responses': responses,
    };
  }

  EmergencyRequestModel copyWith({
    String? id,
    String? title,
    String? description,
    String? requesterId,
    String? requesterName,
    String? requesterAvatar,
    List<String>? requiredSkills,
    DateTime? deadline,
    DateTime? createdAt,
    bool? isResolved,
    String? resolvedBy,
    DateTime? resolvedAt,
    List<Map<String, dynamic>>? responses,
  }) {
    return EmergencyRequestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterAvatar: requesterAvatar ?? this.requesterAvatar,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      responses: responses ?? this.responses,
    );
  }
}
