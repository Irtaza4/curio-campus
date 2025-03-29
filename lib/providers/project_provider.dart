import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:curio_campus/models/project_model.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';

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

  Future<void> fetchProjects() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Simplified query without orderBy to avoid index requirement
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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchProjectDetails(String projectId) async {
    if (_auth.currentUser == null) return;

    // Set loading state
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

        // Fetch tasks
        final tasksSnapshot = await _firestore
            .collection(Constants.projectsCollection)
            .doc(projectId)
            .collection(Constants.tasksCollection)
            .orderBy('createdAt', descending: true)
            .get();

        final tasks = tasksSnapshot.docs
            .map((doc) => TaskModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        }))
            .toList();

        // Update current project with tasks
        _currentProject = ProjectModel.fromJson({
          ..._currentProject!.toJson(),
          'tasks': tasks.map((task) => task.toJson()).toList(),
        });
      }

      // Update state after fetch is complete
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

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

  Future<bool> updateProject(ProjectModel project) async {
    if (_auth.currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestore
          .collection(Constants.projectsCollection)
          .doc(project.id)
          .update(project.toJson());

      // Update local project
      _currentProject = project;

      // Update project in projects list
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
      }

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

  Future<String?> createProject({
    required String name,
    required String description,
    required List<String> teamMembers,
    required DateTime deadline,
  }) async {
    if (_auth.currentUser == null) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Ensure current user is in team members
      if (!teamMembers.contains(userId)) {
        teamMembers.add(userId);
      }

      final now = DateTime.now();
      final projectId = const Uuid().v4();

      final project = ProjectModel(
        id: projectId,
        name: name,
        description: description,
        teamMembers: teamMembers,
        createdBy: userId,
        deadline: deadline,
        createdAt: now,
        progress: 0,
        tasks: [],
      );

      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .set(project.toJson());

      // Add project to local list
      _projects.insert(0, project);
      _currentProject = project;

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

  Future<String?> addTask({
    required String projectId,
    required String title,
    required String description,
    required String assignedTo,
    required TaskPriority priority,
    required DateTime dueDate,
  }) async {
    if (_auth.currentUser == null) return null;

    try {
      final now = DateTime.now();
      final taskId = const Uuid().v4();

      final task = TaskModel(
        id: taskId,
        title: title,
        description: description,
        status: TaskStatus.pending,
        priority: priority,
        assignedTo: assignedTo,
        dueDate: dueDate,
        createdAt: now,
      );

      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .doc(taskId)
          .set(task.toJson());

      // Update current project if it's the same project
      if (_currentProject != null && _currentProject!.id == projectId) {
        final updatedTasks = [..._currentProject!.tasks, task];
        _currentProject = ProjectModel.fromJson({
          ..._currentProject!.toJson(),
          'tasks': updatedTasks.map((t) => t.toJson()).toList(),
        });

        // Update progress
        _updateProjectProgress(projectId);
      }

      notifyListeners();
      return taskId;
    } catch (e) {
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
    if (_auth.currentUser == null) return false;

    try {
      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .doc(taskId)
          .update({'status': status.toString().split('.').last});

      // Update current project if it's the same project
      if (_currentProject != null && _currentProject!.id == projectId) {
        final updatedTasks = _currentProject!.tasks.map((task) {
          if (task.id == taskId) {
            return TaskModel.fromJson({
              ...task.toJson(),
              'status': status.toString().split('.').last,
            });
          }
          return task;
        }).toList();

        _currentProject = ProjectModel.fromJson({
          ..._currentProject!.toJson(),
          'tasks': updatedTasks.map((t) => t.toJson()).toList(),
        });

        // Update progress
        _updateProjectProgress(projectId);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _updateProjectProgress(String projectId) async {
    if (_currentProject == null || _currentProject!.id != projectId) return;

    try {
      final totalTasks = _currentProject!.tasks.length;
      if (totalTasks == 0) return;

      final completedTasks = _currentProject!.tasks
          .where((task) => task.status == TaskStatus.completed)
          .length;

      final progress = (completedTasks / totalTasks * 100).round();

      await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .update({'progress': progress});

      // Update local project
      _currentProject = ProjectModel.fromJson({
        ..._currentProject!.toJson(),
        'progress': progress,
      });

      // Update project in projects list
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = ProjectModel.fromJson({
          ..._projects[index].toJson(),
          'progress': progress,
        });
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deleteProject(String projectId) async {
    if (_auth.currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Delete all tasks
      final tasksSnapshot = await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .collection(Constants.tasksCollection)
          .get();

      final batch = _firestore.batch();

      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete project document
      batch.delete(_firestore.collection(Constants.projectsCollection).doc(projectId));

      await batch.commit();

      // Remove project from local list
      _projects.removeWhere((project) => project.id == projectId);

      if (_currentProject != null && _currentProject!.id == projectId) {
        _currentProject = null;
      }

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
}

