import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/models/project_model.dart';
import 'package:curio_campus/utils/constants.dart';

import 'package:flutter/material.dart';

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ProjectModel?> fetchProject(String projectId) async {
    try {
      final docSnapshot = await _firestore
          .collection(Constants.projectsCollection)
          .doc(projectId)
          .get();

      if (docSnapshot.exists) {
        return ProjectModel.fromJson({
          'id': docSnapshot.id,
          ...docSnapshot.data()!,
        });
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching project: $e');
      return null;
    }
  }

  Future<List<ProjectModel>> fetchProjects(List<String> projectIds) async {
    try {
      final futures = projectIds.map((id) => fetchProject(id));
      final results = await Future.wait(futures);
      return results.whereType<ProjectModel>().toList();
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      return [];
    }
  }
}
