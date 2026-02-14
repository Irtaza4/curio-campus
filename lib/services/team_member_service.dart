import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';

import 'package:flutter/material.dart';

class TeamMemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel?> fetchTeamMember(String userId) async {
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
      debugPrint('Error fetching team member: $e');
      return null;
    }
  }

  Future<List<UserModel>> fetchTeamMembers(List<String> userIds) async {
    List<UserModel> members = [];

    final futures = userIds.map((userId) => fetchTeamMember(userId));
    final results = await Future.wait(futures);
    members = results.whereType<UserModel>().toList();

    return members;
  }
}
