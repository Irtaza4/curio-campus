class UserModel {
  final String id;
  final String name;
  final String email;
  final List<String> majorSkills;
  final List<String> minorSkills;
  final String? profileImageUrl;
  final List<String> completedProjects;
  final List<String> teamMembers;
  final DateTime createdAt;
  final DateTime lastActive;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.majorSkills,
    required this.minorSkills,
    this.profileImageUrl,
    this.completedProjects = const [],
    this.teamMembers = const [],
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      majorSkills: List<String>.from(json['majorSkills'] ?? []),
      minorSkills: List<String>.from(json['minorSkills'] ?? []),
      profileImageUrl: json['profileImageUrl'] as String? ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(json['name'] as String)}&background=00A0B0&color=fff',
      completedProjects: List<String>.from(json['completedProjects'] ?? []),
      teamMembers: List<String>.from(json['teamMembers'] ?? []),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActive: DateTime.parse(json['lastActive'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'majorSkills': majorSkills,
      'minorSkills': minorSkills,
      'profileImageUrl': profileImageUrl,
      'completedProjects': completedProjects,
      'teamMembers': teamMembers,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    List<String>? majorSkills,
    List<String>? minorSkills,
    String? profileImageUrl,
    List<String>? completedProjects,
    List<String>? teamMembers,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      majorSkills: majorSkills ?? this.majorSkills,
      minorSkills: minorSkills ?? this.minorSkills,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      completedProjects: completedProjects ?? this.completedProjects,
      teamMembers: teamMembers ?? this.teamMembers,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}

