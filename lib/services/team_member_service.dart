import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';

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
      print('Error fetching team member: $e');
      return null;
    }
  }

  Future<List<UserModel>> fetchTeamMembers(List<String> userIds) async {
    List<UserModel> members = [];

    for (final userId in userIds) {
      final member = await fetchTeamMember(userId);
      if (member != null) {
        members.add(member);
      }
    }

    return members;
  }
}
