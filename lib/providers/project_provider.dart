import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/project_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/task_model.dart';
import '../utils/navigator_key.dart';

class ProjectProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ProjectModel> _projects = [];
  ProjectModel? _currentProject;
  bool _isLoading = false;
  String? _errorMessage;

  List<ProjectModel> get projects => _projects;
  ProjectModel? get currentProject => _currentProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUserId => _auth.currentUser?.uid;

  // Initialize projects from shared preferences
  Future<void> initProjects() async {
    if (_auth.currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = prefs.getString('${_auth.currentUser!.uid}_projects');

      if (projectsJson != null) {
        final List<dynamic> projectsList = jsonDecode(projectsJson);
        _projects = projectsList.map((json) =>
            ProjectModel.fromJson(json as Map<String, dynamic>)
        ).toList();
        notifyListeners();
      }

      // Still fetch from Firestore to ensure data is up-to-date
      await fetchProjects();
    } catch (e) {
      debugPrint('Error initializing projects: $e');
      // Continue with fetching from Firestore
      await fetchProjects();
    }
  }

  // Save projects to shared preferences
  Future<void> _saveProjectsToPrefs() async {
    if (_auth.currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson = jsonEncode(_projects.map((p) => p.toJson()).toList());
      await prefs.setString('${_auth.currentUser!.uid}_projects', projectsJson);
    } catch (e) {
      debugPrint('Error saving projects to prefs: $e');
    }
  }

  // Fix the Firestore query to avoid the index error
  Future<void> fetchProjects() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Modified query to avoid the composite index error
      // Remove the orderBy clause temporarily until you create the index
      final querySnapshot = await _firestore
          .collection(Constants.projectsCollection)
          .where('teamMembers', arrayContains: userId)
          .get();

      _projects = querySnapshot.docs
          .map((doc) => ProjectModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Sort in memory instead of in the query
      _projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Save to shared preferences for offline access
      await _saveProjectsToPrefs();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Ensure the creator is always in the team members list when creating a project
  Future<String?> createProject({
    required String name,
    required String description,
    required List<String> teamMembers,
    required DateTime deadline,
    required List<String> requiredSkills,
  }) async {
    if (_auth.currentUser == null) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Get user data
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        _isLoading = false;
        _errorMessage = 'User profile not found';
        notifyListeners();
        return null;
      }

      final now = DateTime.now();
      final projectId = const Uuid().v4();

      // Make sure the creator is in the team members list
      if (!teamMembers.contains(userId)) {
        teamMembers.add(userId);
      }

      final project = ProjectModel(
        id: projectId,
        name: name,
        description: description,
        teamMembers: teamMembers,
        createdBy: userId,
        deadline: deadline,
        createdAt: now,
        requiredSkills: requiredSkills,
      );

      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .set(project.toJson());

      // Add project to local list
      _projects.insert(0, project);

      // Save to shared preferences
      await _saveProjectsToPrefs();

      _isLoading = false;
      notifyListeners();

      return projectId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Add the missing methods and properties
  Future<UserModel?> fetchUserById(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        return UserModel.fromJson({
          'id': docSnapshot.id,
          ...docSnapshot.data()!,
        });
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
  Future<List<UserModel>> fetchUsers(List<String> userIds) async {
    try {
      List<UserModel> users = [];

      // Fetch each user by ID
      for (String userId in userIds) {
        final user = await fetchUserById(userId);
        if (user != null) {
          users.add(user);
        }
      }

      return users;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<void> fetchProjectDetails(String projectId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final docSnapshot = await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .get();

      if (docSnapshot.exists) {
        _currentProject = ProjectModel.fromJson({
          'id': docSnapshot.id,
          ...docSnapshot.data()!,
        });

        // Fetch tasks for this project
        final tasksSnapshot = await _firestore
            .collection(Constants.projectsCollection)
            .doc(projectId)
            .collection(Constants.tasksCollection)
            .get();

        final tasks = tasksSnapshot.docs
            .map((doc) => TaskModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        }))
            .toList();

        _currentProject = _currentProject!.copyWith(tasks: tasks);
      } else {
        _errorMessage = 'Project not found';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> updateProject(ProjectModel updatedProject) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection(Constants.projectsCollection)
          .doc(updatedProject.id)
          .update(updatedProject.toJson());

      // Update local list
      final index = _projects.indexWhere((p) => p.id == updatedProject.id);
      if (index != -1) {
        _projects[index] = updatedProject;
      }

      // Update current project if it's the same
      if (_currentProject?.id == updatedProject.id) {
        _currentProject = updatedProject;
      }

      // Save to shared preferences
      await _saveProjectsToPrefs();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Delete all tasks in the project
      final tasksSnapshot = await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .get();

      final batch = _firestore.batch();

      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the project document
      batch.delete(_firestore.collection(Constants.projectsCollection).doc(projectId));

      await batch.commit();

      // Remove from local list
      _projects.removeWhere((p) => p.id == projectId);

      // Clear current project if it's the same
      if (_currentProject?.id == projectId) {
        _currentProject = null;
      }

      // Save to shared preferences
      await _saveProjectsToPrefs();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String?> addTask({
    required String projectId,
    required String title,
    required String description,
    required String assignedTo,
    required TaskPriority priority,
    required DateTime dueDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final taskId = const Uuid().v4();
      final now = DateTime.now();

      final task = TaskModel(
        id: taskId,
        title: title,
        description: description,
        status: TaskStatus.pending,
        priority: priority,
        assignedTo: assignedTo,
        dueDate: dueDate,
        createdAt: now,
        isCompleted: false,
      );

      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .doc(taskId)
          .set(task.toJson());

      // Update current project if it's the same
      if (_currentProject?.id == projectId) {
        final tasks = List<TaskModel>.from(_currentProject!.tasks);
        tasks.add(task);
        _currentProject = _currentProject!.copyWith(tasks: tasks);
      }

      _isLoading = false;
      notifyListeners();
      return taskId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTaskStatus({
    required String projectId,
    required String taskId,
    required TaskStatus status,
  }) async {
    try {
      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .doc(taskId)
          .update({'status': status.toString().split('.').last});

      // Update current project if it's the same
      if (_currentProject?.id == projectId) {
        final tasks = List<TaskModel>.from(_currentProject!.tasks);
        final index = tasks.indexWhere((t) => t.id == taskId);

        if (index != -1) {
          tasks[index] = tasks[index].copyWith(status: status);

          // Calculate new progress
          final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).length;
          final progress = tasks.isEmpty ? 0 : (completedTasks / tasks.length * 100).round();

          _currentProject = _currentProject!.copyWith(
            tasks: tasks,
            progress: progress,
          );

          // Update project progress in Firestore
          await _firestore
              .collection(Constants.projectsCollection)
              .doc(projectId)
              .update({'progress': progress});
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Add method to mark a task as completed and send a notification
  Future<bool> completeTask({
    required String projectId,
    required String taskId,
    required String completedById,
  }) async {
    if (_auth.currentUser == null) return false;

    try {
      final userId = _auth.currentUser!.uid;

      // Find the project
      final projectIndex = _projects.indexWhere((p) => p.id == projectId);
      if (projectIndex == -1) return false;

      final project = _projects[projectIndex];

      // Find the task
      final taskIndex = project.tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) return false;

      final task = project.tasks[taskIndex];

      // Update the task in Firestore
      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .doc(taskId)
          .update({
        'status': TaskStatus.completed.toString().split('.').last,
        'isCompleted': true,
        'completedAt': DateTime.now().toIso8601String(),
        'completedById': completedById,
      });

      // Update the task in local state
      final updatedTask = task.copyWith(
        status: TaskStatus.completed,
        isCompleted: true,
        completedAt: DateTime.now(),
        completedById: completedById,
      );

      final updatedTasks = List<TaskModel>.from(project.tasks);
      updatedTasks[taskIndex] = updatedTask;

      // Calculate new progress
      final completedTasks = updatedTasks.where((t) => t.isCompleted).length;
      final totalTasks = updatedTasks.length;
      final progress = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

      // Update the project in Firestore
      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .update({
        'progress': progress,
      });

      // Update the project in local state
      final updatedProject = project.copyWith(
        tasks: updatedTasks,
        progress: progress,
      );

      _projects[projectIndex] = updatedProject;

      // Send a notification to all team members except the one who completed the task
      for (final memberId in project.teamMembers) {
        if (memberId != completedById) {
          // Get the user who completed the task
          final completer = await fetchUserById(completedById);
          final completerName = completer?.name ?? 'A team member';

          // Create a notification
          if (navigatorKey.currentContext != null) {
            final notificationProvider = Provider.of<NotificationProvider>(
              navigatorKey.currentContext!,
              listen: false,
            );

            await notificationProvider.createTaskCompletionNotification(
              projectId: projectId,
              projectName: project.name,
              taskTitle: task.title,
              completedBy: completerName,
            );
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
