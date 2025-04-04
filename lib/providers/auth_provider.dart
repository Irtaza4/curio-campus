import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
      // Try to load from shared preferences first for faster startup
      await _loadUserFromPrefs();
      // Then fetch from Firestore to ensure data is up-to-date
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

        // Save to shared preferences for offline access
        await _saveUserToPrefs();

        // Update last active timestamp
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

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required List<String> majorSkills,
    required List<String> minorSkills,
    String? profileImageUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _firebaseUser = userCredential.user;

      if (_firebaseUser != null) {
        // Create user model
        final now = DateTime.now();
        _userModel = UserModel(
          id: _firebaseUser!.uid,
          name: name,
          email: email,
          majorSkills: majorSkills,
          minorSkills: minorSkills,
          profileImageUrl: profileImageUrl,
          completedProjects: [],
          teamMembers: [],
          createdAt: now,
          lastActive: now,
        );

        // Save user data to Firestore
        await _firestore
            .collection(Constants.usersCollection)
            .doc(_firebaseUser!.uid)
            .set(_userModel!.toJson());

        // Save user data to shared preferences
        await _saveUserToPrefs();

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

        // Save user data to shared preferences
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(Constants.userIdKey, _firebaseUser!.uid);
        prefs.setString(Constants.userEmailKey, email);
        if (_userModel != null) {
          prefs.setString(Constants.userNameKey, _userModel!.name);
        }

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
      await _auth.signOut();
      _firebaseUser = null;
      _userModel = null;

      // Clear shared preferences
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
    String? profileImageUrl,
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
      if (profileImageUrl != null) updatedData['profileImageUrl'] = profileImageUrl;

      await _firestore
          .collection(Constants.usersCollection)
          .doc(_userModel!.id)
          .update(updatedData);

      // Update local user model
      _userModel = _userModel!.copyWith(
        name: name,
        majorSkills: majorSkills,
        minorSkills: minorSkills,
        profileImageUrl: profileImageUrl,
      );

      // Save updated user to shared preferences
      await _saveUserToPrefs();

      // Update shared preferences if name changed
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

  Future<String?> uploadProfileImage(File imageFile) async {
    if (_firebaseUser == null) return null;

    try {
      final userId = _firebaseUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'profile_images/$userId/$timestamp.jpg';

      // Create the storage reference
      final storageRef = _storage.ref().child(path);

      // Upload the file with metadata to ensure proper content type
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      // Show upload progress (optional)
      final uploadTask = storageRef.putFile(imageFile, metadata);

      // Add better error handling and progress tracking
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');

        // Check for error states
        if (snapshot.state == TaskState.error) {
          // Use snapshot.state instead of trying to access snapshot.error
          debugPrint('Upload error: Task is in error state');
        }
      });

      // Wait for the upload to complete
      try {
        final snapshot = await uploadTask.whenComplete(() => null);

        // Get the download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();

        debugPrint('Profile image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } catch (storageError) {
        _errorMessage = 'Failed to upload image: ${storageError.toString()}';
        debugPrint(_errorMessage);
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Failed to upload image: ${e.toString()}';
      debugPrint(_errorMessage);
      notifyListeners();
      return null;
    }
  }
}

