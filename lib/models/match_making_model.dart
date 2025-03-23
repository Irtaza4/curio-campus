class MatchmakingResultModel {
  final String userId;
  final String name;
  final String? avatarUrl;
  final List<String> skills;
  final double compatibilityScore;
  final DateTime lastActive;
  final String responseTime;

  MatchmakingResultModel({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.skills,
    required this.compatibilityScore,
    required this.lastActive,
    required this.responseTime,
  });

  factory MatchmakingResultModel.fromJson(Map<String, dynamic> json) {
    return MatchmakingResultModel(
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      skills: List<String>.from(json['skills'] ?? []),
      compatibilityScore: json['compatibilityScore'] as double? ?? 0.0,
      lastActive: DateTime.parse(json['lastActive'] as String),
      responseTime: json['responseTime'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'skills': skills,
      'compatibilityScore': compatibilityScore,
      'lastActive': lastActive.toIso8601String(),
      'responseTime': responseTime,
    };
  }
}

