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
      status: TaskStatus.values.firstWhere(
            (e) => e.toString() == 'TaskStatus.${json['status']}',
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
            (e) => e.toString() == 'TaskPriority.${json['priority']}',
        orElse: () => TaskPriority.medium,
      ),
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
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      teamMembers: List<String>.from(json['teamMembers']),
      createdBy: json['createdBy'] as String,
      deadline: DateTime.parse(json['deadline'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      progress: json['progress'] as int? ?? 0,
      tasks: (json['tasks'] as List?)
          ?.map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
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
      'tasks': tasks.map((e) => e.toJson()).toList(),
    };
  }
}

