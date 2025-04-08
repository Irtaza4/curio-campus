import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';

import '../models/match_making_model.dart';

class MatchmakingProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<MatchmakingResultModel> _matchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<MatchmakingResultModel> get matchResults => _matchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> findMatches({List<String>? requiredSkills}) async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Get current user's skills
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        _isLoading = false;
        _errorMessage = 'User profile not found';
        notifyListeners();
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final List<String> userMajorSkills = List<String>.from(userData['majorSkills'] ?? []);
      final List<String> userMinorSkills = List<String>.from(userData['minorSkills'] ?? []);

      // Use required skills if provided, otherwise use user's skills
      final skillsToMatch = requiredSkills ?? [...userMajorSkills, ...userMinorSkills];

      if (skillsToMatch.isEmpty) {
        _isLoading = false;
        _errorMessage = 'No skills available for matching';
        notifyListeners();
        return;
      }

      // Find users with matching skills
      final usersSnapshot = await _firestore
          .collection(Constants.usersCollection)
          .where('id', isNotEqualTo: userId)
          .get();

      final List<MatchmakingResultModel> results = [];

      for (final doc in usersSnapshot.docs) {
        final otherUser = UserModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });

        final List<String> otherUserSkills = [
          ...otherUser.majorSkills,
          ...otherUser.minorSkills,
        ];

        // Calculate compatibility score
        int matchingSkills = 0;
        for (final skill in skillsToMatch) {
          if (otherUserSkills.contains(skill)) {
            matchingSkills++;
          }
        }

        if (matchingSkills > 0) {
          final double compatibilityScore = matchingSkills / skillsToMatch.length;

          // Calculate response time (simplified for demo)
          final responseTime = _calculateResponseTime(otherUser.lastActive);

          results.add(MatchmakingResultModel(
            userId: otherUser.id,
            name: otherUser.name,
            avatarUrl: otherUser.profileImageBase64,
            skills: otherUserSkills,
            compatibilityScore: compatibilityScore,
            lastActive: otherUser.lastActive,
            responseTime: responseTime,
          ));
        }
      }

      // Sort by compatibility score (highest first)
      results.sort((a, b) => b.compatibilityScore.compareTo(a.compatibilityScore));

      _matchResults = results;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  String _calculateResponseTime(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 5) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} Min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} Hours';
    } else if (difference.inDays < 7) {
      return 'Yesterday';
    } else {
      return '${(difference.inDays / 7).round()} Weeks Ago';
    }
  }
}

