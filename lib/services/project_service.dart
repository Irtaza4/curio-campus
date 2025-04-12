import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/models/project_model.dart';
import 'package:curio_campus/utils/constants.dart';

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
      print('Error fetching project: $e');
      return null;
    }
  }

  Future<List<ProjectModel>> fetchProjects(List<String> projectIds) async {
    List<ProjectModel> projects = [];

    for (final projectId in projectIds) {
      final project = await fetchProject(projectId);
      if (project != null) {
        projects.add(project);
      }
    }

    return projects;
  }
}
