import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/project_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';
import 'package:curio_campus/screens/project/create_project_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:curio_campus/widgets/notification_badge.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/widgets/notification_drawer.dart';
import 'package:curio_campus/models/notification_model.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({Key? key}) : super(key: key);

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to schedule the fetch after the build is complete
    Future.microtask(() => _fetchProjects());
  }

  // Update the _fetchProjects method to handle loading from shared preferences first
  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to load from shared preferences for immediate display
      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      await projectProvider.initProjects();

      // Then fetch from Firebase to ensure data is up-to-date
      await projectProvider.fetchProjects();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching projects: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToProjectDetail(String projectId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    ).then((_) {
      // Refresh projects when returning from detail screen
      _fetchProjects();
    });
  }

  void _navigateToCreateProject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateProjectScreen(),
      ),
    ).then((_) {
      // Refresh projects when returning from create screen
      _fetchProjects();
    });
  }

  void _showDeleteProjectDialog(ProjectModel project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() {
                _isLoading = true;
              });

              final success = await Provider.of<ProjectProvider>(context, listen: false)
                  .deleteProject(project.id);

              setState(() {
                _isLoading = false;
              });

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Project "${project.name}" deleted'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final allProjects = projectProvider.projects;
    final unreadCount = notificationProvider.unreadCount;

    // Separate projects into active and completed
    final activeProjects = allProjects.where((p) => p.progress < 100).toList();
    final completedProjects = allProjects.where((p) => p.progress == 100).toList();

    return Scaffold(
      // Remove the appBar here
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : allProjects.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No projects yet',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToCreateProject,
              child: const Text('Create Project'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchProjects,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (activeProjects.isNotEmpty) ...[
              const Text(
                'Active Projects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...activeProjects.map((project) => _buildProjectCard(project)),
            ],

            if (completedProjects.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Completed Projects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...completedProjects.map((project) => _buildProjectCard(project)),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'projects_fab',
        onPressed: _navigateToCreateProject,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToProjectDetail(project.id),
        onLongPress: () => _showDeleteProjectDialog(project),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getDeadlineColor(project.deadline),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatDeadline(project.deadline),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                project.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${project.teamMembers.length} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.task_alt,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${project.tasks.length} tasks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Your Target',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                project.progress == 100
                    ? 'Project completed!'
                    : 'One step at a time. You\'ll get there.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: project.progress == 100 ? Colors.green : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: project.progress / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  project.progress == 100 ? Colors.green : AppTheme.primaryColor,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${project.progress}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: project.progress == 100 ? Colors.green : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;

    if (difference < 0) {
      return Colors.red;
    } else if (difference < 3) {
      return Colors.orange;
    } else {
      return AppTheme.primaryColor;
    }
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Due today';
    } else if (difference == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due ${DateFormat('MMM d').format(deadline)}';
    }
  }
}
