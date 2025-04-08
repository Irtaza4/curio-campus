import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/models/task_model.dart';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final List<String> teamMembers;
  final String createdBy;
  final DateTime deadline;
  final DateTime createdAt;
  final int progress;
  final List<TaskModel> tasks;
  final List<String> requiredSkills;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.teamMembers,
    required this.createdBy,
    required this.deadline,
    required this.createdAt,
    this.progress = 0,
    this.tasks = const [],
    this.requiredSkills = const [],
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      teamMembers: List<String>.from(json['teamMembers'] ?? []),
      createdBy: json['createdBy'] as String,
      deadline: json['deadline'] is Timestamp
          ? (json['deadline'] as Timestamp).toDate()
          : DateTime.parse(json['deadline'] as String),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      progress: json['progress'] as int? ?? 0,
      tasks: json['tasks'] != null
          ? List<TaskModel>.from(
        (json['tasks'] as List).map(
              (task) => TaskModel.fromJson(task as Map<String, dynamic>),
        ),
      )
          : [],
      requiredSkills: json['requiredSkills'] != null
          ? List<String>.from(json['requiredSkills'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'teamMembers': teamMembers,
      'createdBy': createdBy,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'progress': progress,
      'requiredSkills': requiredSkills,
      // Don't include tasks in the main project document
    };
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? teamMembers,
    String? createdBy,
    DateTime? deadline,
    DateTime? createdAt,
    int? progress,
    List<TaskModel>? tasks,
    List<String>? requiredSkills,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teamMembers: teamMembers ?? this.teamMembers,
      createdBy: createdBy ?? this.createdBy,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      progress: progress ?? this.progress,
      tasks: tasks ?? this.tasks,
      requiredSkills: requiredSkills ?? this.requiredSkills,
    );
  }
}
