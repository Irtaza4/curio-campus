class Constants {
  // Firebase collections

  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String projectsCollection = 'projects';
  static const String tasksCollection = 'tasks';
  static const String emergencyRequestsCollection = 'emergencyRequests';
  static const String callsCollection = 'calls';

  // Navigation routes
  static const String splashRoute = '/splash';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String chatRoute = '/chat';
  static const String profileRoute = '/profile';
  static const String projectRoute = '/project';
  static const String matchmakingRoute = '/matchmaking';
  static const String emergencyRoute = '/emergency';

  // Shared preferences keys
  static const String userIdKey = 'userId';
  static const String userEmailKey = 'userEmail';
  static const String userNameKey = 'userName';
  static const String userSkillsKey = 'userSkills';

  // App constants
  static const int splashDuration = 3; // seconds
  static const int maxMessageLength = 500;
  static const int maxProjectNameLength = 50;
  static const int maxTaskNameLength = 100;
  static const int maxEmergencyTitleLength = 100;

  // image key
  static const String userImageKey = 'user_image_key';
}

