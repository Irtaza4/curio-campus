import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:curio_campus/models/emergency_request_model.dart';
import 'package:curio_campus/utils/constants.dart';

class EmergencyProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<EmergencyRequestModel> _emergencyRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<EmergencyRequestModel> get emergencyRequests => _emergencyRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchEmergencyRequests() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Create a composite index for this query
      final querySnapshot = await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .where('isResolved', isEqualTo: false)
      // Use orderBy with a field that has an index
          .get();

      _emergencyRequests = querySnapshot.docs
          .map((doc) => EmergencyRequestModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Sort the list after fetching
      _emergencyRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

      _emergencyRequests = querySnapshot.docs
          .map((doc) => EmergencyRequestModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Sort the list after fetching
      _emergencyRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow; // Rethrow to handle in UI
    }
  }

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
      );

      await _firestore
          .collection(Constants.emergencyRequestsCollection)
          .doc(requestId)
          .set(request.toJson());

      // Add request to local list
      _emergencyRequests.insert(0, request);

      _isLoading = false;
      notifyListeners();

      return requestId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
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

      // Update local list
      final index = _emergencyRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _emergencyRequests[index] = EmergencyRequestModel.fromJson({
          ..._emergencyRequests[index].toJson(),
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
}

