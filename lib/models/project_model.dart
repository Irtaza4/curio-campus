import 'package:curio_campus/models/user_model.dart';

enum TaskStatus { pending, inProgress, completed }

enum TaskPriority { low, medium, high }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final String assignedTo;
  final DateTime dueDate;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.dueDate,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: _parseTaskStatus(json['status'] as String),
      priority: _parseTaskPriority(json['priority'] as String),
      assignedTo: json['assignedTo'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'assignedTo': assignedTo,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static TaskStatus _parseTaskStatus(String status) {
    switch (status) {
      case 'pending':
        return TaskStatus.pending;
      case 'inProgress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.pending;
    }
  }

  static TaskPriority _parseTaskPriority(String priority) {
    switch (priority) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    String? assignedTo,
    DateTime? dueDate,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

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
  final List<String> requiredSkills; // Added required skills field

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
    this.requiredSkills = const [], // Default to empty list
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      teamMembers: List<String>.from(json['teamMembers'] ?? []),
      createdBy: json['createdBy'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
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

