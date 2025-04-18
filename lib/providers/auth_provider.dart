import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _firebaseUser != null;

  AuthProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _firebaseUser = _auth.currentUser;
    if (_firebaseUser != null) {
      await _loadUserFromPrefs();
      await _fetchUserData();
    }
    notifyListeners();
  }

  Future<void> _loadUserFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('${_firebaseUser!.uid}_user_data');

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _userModel = UserModel.fromJson(userData);
      }
    } catch (e) {
      debugPrint('Error loading user from prefs: $e');
    }
  }

  Future<void> _saveUserToPrefs() async {
    if (_userModel == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(_userModel!.toJson());
      await prefs.setString('${_userModel!.id}_user_data', userJson);
    } catch (e) {
      debugPrint('Error saving user to prefs: $e');
    }
  }

  Future<void> _fetchUserData() async {
    if (_firebaseUser == null) return;

    try {
      final docSnapshot = await _firestore
          .collection(Constants.usersCollection)
          .doc(_firebaseUser!.uid)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        _userModel = UserModel.fromJson({
          'id': _firebaseUser!.uid,
          ...data,
        });

        await _saveUserToPrefs();
        await _firestore
            .collection(Constants.usersCollection)
            .doc(_firebaseUser!.uid)
            .update({'lastActive': DateTime.now().toIso8601String()});
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch user data: ${e.toString()}';
      debugPrint(_errorMessage);
    }
  }

  Future<void> _updateFCMToken() async {
    if (_firebaseUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');

      if (token != null) {
        await _firestore
            .collection(Constants.usersCollection)
            .doc(_firebaseUser!.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required List<String> majorSkills,
    required List<String> minorSkills,
    String? profileImageBase64,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        final now = DateTime.now();
        _userModel = UserModel(
          id: _firebaseUser!.uid,
          name: name,
          email: email,
          majorSkills: majorSkills,
          minorSkills: minorSkills,
          profileImageBase64: profileImageBase64,
          completedProjects: [],
          teamMembers: [],
          createdAt: now,
          lastActive: now,
        );

        await _firestore
            .collection(Constants.usersCollection)
            .doc(_firebaseUser!.uid)
            .set(_userModel!.toJson());

        await _saveUserToPrefs();
        await _updateFCMToken();

        final prefs = await SharedPreferences.getInstance();
        prefs.setString(Constants.userIdKey, _firebaseUser!.uid);
        prefs.setString(Constants.userEmailKey, email);
        prefs.setString(Constants.userNameKey, name);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = 'Registration failed';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('Registration error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        await _fetchUserData();
        await _updateFCMToken();

        final prefs = await SharedPreferences.getInstance();
        prefs.setString(Constants.userIdKey, _firebaseUser!.uid);
        prefs.setString(Constants.userEmailKey, email);
        if (_userModel != null) {
          prefs.setString(Constants.userNameKey, _userModel!.name);
        }
        await FirebaseMessaging.instance.subscribeToTopic('emergency_alerts');

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = 'Login failed';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('Login error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_firebaseUser != null) {
        await _firestore
            .collection(Constants.usersCollection)
            .doc(_firebaseUser!.uid)
            .update({
          'fcmToken': null,
        });
      }

      await _auth.signOut();
      _firebaseUser = null;
      _userModel = null;

      final prefs = await SharedPreferences.getInstance();
      prefs.remove(Constants.userIdKey);
      prefs.remove(Constants.userEmailKey);
      prefs.remove(Constants.userNameKey);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    String? name,
    List<String>? majorSkills,
    List<String>? minorSkills,
    String? profileImageBase64,
  }) async {
    if (_userModel == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedData = <String, dynamic>{};

      if (name != null) updatedData['name'] = name;
      if (majorSkills != null) updatedData['majorSkills'] = majorSkills;
      if (minorSkills != null) updatedData['minorSkills'] = minorSkills;
      if (profileImageBase64 != null) updatedData['profileImageBase64'] = profileImageBase64;

      await _firestore
          .collection(Constants.usersCollection)
          .doc(_userModel!.id)
          .update(updatedData);

      _userModel = _userModel!.copyWith(
        name: name,
        majorSkills: majorSkills,
        minorSkills: minorSkills,
        profileImageBase64: profileImageBase64,
      );

      await _saveUserToPrefs();

      if (name != null) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(Constants.userNameKey, name);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('Update profile error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<String?> convertImageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      return null;
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
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
