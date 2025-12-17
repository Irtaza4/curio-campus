import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:curio_campus/models/emergency_request_model.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:curio_campus/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/cloud_functions_services.dart';


class EmergencyProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<EmergencyRequestModel> _emergencyRequests = [];
  List<EmergencyRequestModel> _myEmergencyRequests = [];
  List<EmergencyRequestModel> _ignoredRequests = []; // New list for ignored requests
  bool _isLoading = false;
  String? _errorMessage;

  List<EmergencyRequestModel> get emergencyRequests => _emergencyRequests;
  List<EmergencyRequestModel> get myEmergencyRequests => _myEmergencyRequests;
  List<EmergencyRequestModel> get ignoredRequests => _ignoredRequests; // Getter for ignored requests
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchEmergencyRequests() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Get user's ignored request IDs
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      List<String> ignoredRequestIds = [];
      if (userDoc.exists && userDoc.data()!.containsKey('ignoredEmergencyRequests')) {
        ignoredRequestIds = List<String>.from(userDoc.data()!['ignoredEmergencyRequests']);
      }

      // Create a composite index for this query
      final querySnapshot = await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .where('isResolved', isEqualTo: false)

      // Use orderBy with a field that has an index
          .get();

      final List<EmergencyRequestModel> loadedRequests = [];
      final List<EmergencyRequestModel> loadedIgnoredRequests = [];

      for (var doc in querySnapshot.docs) {
        final request = EmergencyRequestModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });

        // Skip requests created by the current user (they go in myEmergencyRequests)
        if (request.requesterId == userId) continue;

        // Check if this request is in the ignored list
        if (ignoredRequestIds.contains(request.id)) {
          loadedIgnoredRequests.add(request);
        } else {
          loadedRequests.add(request);
        }
      }

      // Sort the lists after fetching
      loadedRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      loadedIgnoredRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _emergencyRequests = loadedRequests;
      _ignoredRequests = loadedIgnoredRequests;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow; // Rethrow to handle in UI
    }
  }

  Future<void> fetchMyEmergencyRequests() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;
      final querySnapshot = await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .where('requesterId', isEqualTo: userId)
          .get();

      _myEmergencyRequests = querySnapshot.docs
          .map((doc) => EmergencyRequestModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Sort the list after fetching
      _myEmergencyRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow; // Rethrow to handle in UI
    }
  }

  // New method to ignore an emergency request
  Future<bool> ignoreEmergencyRequest(String requestId) async {
    if (_auth.currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Add to user's ignored requests in Firestore
      await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .update({
        'ignoredEmergencyRequests': FieldValue.arrayUnion([requestId])
      });

      // Move the request from regular list to ignored list
      final requestIndex = _emergencyRequests.indexWhere((req) => req.id == requestId);
      if (requestIndex >= 0) {
        final request = _emergencyRequests[requestIndex];
        _ignoredRequests.add(request);
        _emergencyRequests.removeAt(requestIndex);
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

  // New method to unignore an emergency request
  Future<bool> unignoreEmergencyRequest(String requestId) async {
    if (_auth.currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Remove from user's ignored requests in Firestore
      await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .update({
        'ignoredEmergencyRequests': FieldValue.arrayRemove([requestId])
      });

      // Move the request from ignored list to regular list
      final requestIndex = _ignoredRequests.indexWhere((req) => req.id == requestId);
      if (requestIndex >= 0) {
        final request = _ignoredRequests[requestIndex];
        _emergencyRequests.add(request);
        _ignoredRequests.removeAt(requestIndex);

        // Sort the list after adding the request back
        _emergencyRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  // Enhance the createEmergencyRequest method to trigger a notification
  Future<String?> createEmergencyRequest({
    required String title,
    required String description,
    required List<String> requiredSkills,
    required DateTime deadline,
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

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String;
      final userAvatar = userData['profileImageUrl'] as String?;

      final now = DateTime.now();
      final requestId = const Uuid().v4();

      final request = EmergencyRequestModel(
        id: requestId,
        title: title,
        description: description,
        requesterId: userId,
        requesterName: userName,
        requesterAvatar: userAvatar,
        requiredSkills: requiredSkills,
        deadline: deadline,
        createdAt: now,
        isResolved: false,
        responses: [],
      );

      print('🔥 About to save emergency request to Firestore:');
      print('  - Collection: ${Constants.emergencyRequestsCollection}');
      print('  - Document ID: $requestId');
      print('  - Required Skills: $requiredSkills');
      print('  - Requester: $userName');

      // Save to Firestore - this should trigger the Cloud Function
      await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .set(request.toJson());

      print('✅ Emergency request saved - Cloud Function will handle notifications');
      print('🔍 Check Firebase Functions logs to see if trigger fired');
      print('   Command: firebase functions:log --project curiocampus-c8f79');

      // Add request to local lists
      _myEmergencyRequests.insert(0, request);

      _isLoading = false;
      notifyListeners();

      return requestId;
    } catch (e) {
      print('❌ Error creating emergency request: $e');
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }


  // Add method to create an emergency request that matches user skills
  Future<String?> createEmergencyRequestWithSkillMatching({
    required String title,
    required String description,
    required List<String> requiredSkills,
    required DateTime deadline,
  }) async {
    if (_auth.currentUser == null) return null;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String;
      final userAvatar = userData['profileImageUrl'] as String?;

      final now = DateTime.now();
      final requestId = const Uuid().v4();

      final request = EmergencyRequestModel(
        id: requestId,
        title: title,
        description: description,
        requiredSkills: requiredSkills,
        deadline: deadline,
        requesterId: userId,
        requesterName: userName,
        requesterAvatar: userAvatar,
        createdAt: now,
        isResolved: false,
        responses: [],
      );

      await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .set(request.toJson());

      // Add to local list
      _myEmergencyRequests.add(request);
      _emergencyRequests.add(request);

      // Find users with matching skills and send notifications
      final usersSnapshot = await _firestore
          .collection(Constants.usersCollection)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Skip the requester
        if (userId == request.requesterId) continue;

        final majorSkills = List<String>.from(userData['majorSkills'] ?? []);
        final minorSkills = List<String>.from(userData['minorSkills'] ?? []);
        final allSkills = [...majorSkills, ...minorSkills];

        // Check if any required skill matches the user's skills
        final matchingSkills = requiredSkills.where((skill) => allSkills.contains(skill)).toList();

        if (matchingSkills.isNotEmpty) {
          // Create a notification for this user
          final notificationId = const Uuid().v4();

          await _firestore
              .collection(Constants.usersCollection)
              .doc(userId)
              .collection('notifications')
              .doc(notificationId)
              .set({
            'id': notificationId,
            'title': 'Emergency Request Matching Your Skills',
            'message': '$userName needs help with ${matchingSkills.first}: $title',
            'timestamp': now.toIso8601String(),
            'type': 'emergency',
            'relatedId': requestId,
            'isRead': false,
            'additionalData': {
              'requesterName': userName,
              'skill': matchingSkills.first,
              'isSkillMatch': true
            },
          });
        }
      }
      await NotificationService().showEmergencyRequestNotification(
        requestId: requestId,
        title: title,
        requesterName: userName,
      );

      notifyListeners();
      return requestId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEmergencyRequest({
    required String requestId,
    required String title,
    required String description,
    required List<String> requiredSkills,
    required DateTime deadline,
  }) async {
    if (_auth.currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Verify that the user is the owner of the request
      final requestDoc = await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        _isLoading = false;
        _errorMessage = 'Request not found';
        notifyListeners();
        return false;
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      if (requestData['requesterId'] != userId) {
        _isLoading = false;
        _errorMessage = 'You are not authorized to update this request';
        notifyListeners();
        return false;
      }

      // Update the request
      await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .update({
        'title': title,
        'description': description,
        'requiredSkills': requiredSkills,
        'deadline': deadline.toIso8601String(),
      });

      // Update local lists
      final myIndex = _myEmergencyRequests.indexWhere((r) => r.id == requestId);
      if (myIndex != -1) {
        final updatedRequest = EmergencyRequestModel.fromJson({
          ..._myEmergencyRequests[myIndex].toJson(),
          'title': title,
          'description': description,
          'requiredSkills': requiredSkills,
          'deadline': deadline.toIso8601String(),
        });
        _myEmergencyRequests[myIndex] = updatedRequest;
      }

      final allIndex = _emergencyRequests.indexWhere((r) => r.id == requestId);
      if (allIndex != -1) {
        final updatedRequest = EmergencyRequestModel.fromJson({
          ..._emergencyRequests[allIndex].toJson(),
          'title': title,
          'description': description,
          'requiredSkills': requiredSkills,
          'deadline': deadline.toIso8601String(),
        });
        _emergencyRequests[allIndex] = updatedRequest;
      }

      // Also update in ignored list if present
      final ignoredIndex = _ignoredRequests.indexWhere((r) => r.id == requestId);
      if (ignoredIndex != -1) {
        final updatedRequest = EmergencyRequestModel.fromJson({
          ..._ignoredRequests[ignoredIndex].toJson(),
          'title': title,
          'description': description,
          'requiredSkills': requiredSkills,
          'deadline': deadline.toIso8601String(),
        });
        _ignoredRequests[ignoredIndex] = updatedRequest;
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

  Future<bool> resolveEmergencyRequest(String requestId) async {
    if (_auth.currentUser == null) return false;

    try {
      final userId = _auth.currentUser!.uid;
      final now = DateTime.now();

      await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .update({
        'isResolved': true,
        'resolvedBy': userId,
        'resolvedAt': now.toIso8601String(),
      });

      // Update local lists
      final myIndex = _myEmergencyRequests.indexWhere((r) => r.id == requestId);
      if (myIndex != -1) {
        _myEmergencyRequests[myIndex] = EmergencyRequestModel.fromJson({
          ..._myEmergencyRequests[myIndex].toJson(),
          'isResolved': true,
          'resolvedBy': userId,
          'resolvedAt': now.toIso8601String(),
        });
      }

      final allIndex = _emergencyRequests.indexWhere((r) => r.id == requestId);
      if (allIndex != -1) {
        _emergencyRequests[allIndex] = EmergencyRequestModel.fromJson({
          ..._emergencyRequests[allIndex].toJson(),
          'isResolved': true,
          'resolvedBy': userId,
          'resolvedAt': now.toIso8601String(),
        });
      }

      // Also update in ignored list if present
      final ignoredIndex = _ignoredRequests.indexWhere((r) => r.id == requestId);
      if (ignoredIndex != -1) {
        _ignoredRequests[ignoredIndex] = EmergencyRequestModel.fromJson({
          ..._ignoredRequests[ignoredIndex].toJson(),
          'isResolved': true,
          'resolvedBy': userId,
          'resolvedAt': now.toIso8601String(),
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Add a method to fetch a single emergency request by ID
  Future<EmergencyRequestModel?> fetchEmergencyRequestById(String requestId) async {
    try {
      final docSnapshot = await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .get();

      if (docSnapshot.exists) {
        return EmergencyRequestModel.fromJson({
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

  Future<bool> deleteEmergencyRequest(String requestId) async {
    if (_auth.currentUser == null) return false;

    try {
      final userId = _auth.currentUser!.uid;

      // Verify that the user is the owner of the request
      final requestDoc = await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        _errorMessage = 'Request not found';
        notifyListeners();
        return false;
      }

      final requestData = requestDoc.data() as Map<String, dynamic>;
      if (requestData['requesterId'] != userId) {
        _errorMessage = 'You are not authorized to delete this request';
        notifyListeners();
        return false;
      }

      // Delete the request
      await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .delete();

      // Remove from local lists
      _myEmergencyRequests.removeWhere((r) => r.id == requestId);
      _emergencyRequests.removeWhere((r) => r.id == requestId);
      _ignoredRequests.removeWhere((r) => r.id == requestId);

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
