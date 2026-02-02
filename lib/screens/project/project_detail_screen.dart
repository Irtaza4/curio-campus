import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/project_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:intl/intl.dart';

import 'package:curio_campus/screens/project/create_task_screen.dart';
import 'package:curio_campus/screens/project/edit_project_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/task_model.dart';
import '../../models/user_model.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _isLoading = false;
  Map<String, UserModel> _teamMemberDetails = {};

  @override
  void initState() {
    super.initState();
    // Schedule the fetch operation after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchProjectDetails();
      }
    });
  }

  Future<void> _fetchProjectDetails() async {
    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<ProjectProvider>(context, listen: false);
    await provider.fetchProjectDetails(widget.projectId);

    // Fetch team member details
    if (provider.currentProject != null && mounted) {
      final memberIds = provider.currentProject!.teamMembers;
      final futures = memberIds.map((id) => provider.fetchUserById(id));

      try {
        final results = await Future.wait(futures);
        final Map<String, UserModel> details = {};

        for (var user in results) {
          if (user != null) {
            details[user.id] = user;
          }
        }

        setState(() {
          _teamMemberDetails = details;
        });
      } catch (e) {
        debugPrint('Error fetching team members: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTaskStatus(String taskId, TaskStatus status) async {
    await Provider.of<ProjectProvider>(context, listen: false).updateTaskStatus(
      projectId: widget.projectId,
      taskId: taskId,
      status: status,
    );
  }

  Future<void> _addTask() async {
    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    final project = projectProvider.currentProject;

    if (project != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateTaskScreen(
            projectId: project.id,
            teamMembers: project.teamMembers,
          ),
        ),
      );

      // Refresh project details if a task was added
      if (result == true && mounted) {
        _fetchProjectDetails();
      }
    }
  }

  Future<void> _editProject() async {
    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    final project = projectProvider.currentProject;

    if (project != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProjectScreen(
            project: project,
          ),
        ),
      );

      // Refresh project details if the project was updated
      if (result == true && mounted) {
        _fetchProjectDetails();
      }
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final projectProvider =
            Provider.of<ProjectProvider>(context, listen: false);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: AppTheme.primaryColor),
                title: const Text('Share Project'),
                onTap: () {
                  Navigator.pop(context);
                  // Share functionality
                },
              ),
              if (projectProvider.currentProject?.createdBy ==
                  projectProvider.currentUserId)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Project',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    final project = projectProvider.currentProject;
                    if (project != null) {
                      _showDeleteProjectDialog(project);
                    }
                  },
                ),
              ListTile(
                leading:
                    const Icon(Icons.archive, color: AppTheme.primaryColor),
                title: const Text('Archive Project'),
                onTap: () {
                  Navigator.pop(context);
                  // Archive functionality
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline,
                    color: AppTheme.primaryColor),
                title: const Text('Project Help'),
                onTap: () {
                  Navigator.pop(context);
                  // Show help info
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteProjectDialog(ProjectModel project) async {
    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: SingleChildScrollView(
            child: ListBody(
              children: const <Widget>[
                Text('Are you sure you want to delete this project?'),
                Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await projectProvider.deleteProject(project.id);
                if (mounted) {
                  navigator.pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final project = projectProvider.currentProject;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? 'Project Details'),
        actions: [
          if (project?.createdBy == projectProvider.currentUserId)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editProject,
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : project == null
              ? const Center(child: Text('Project not found'))
              : RefreshIndicator(
                  onRefresh: _fetchProjectDetails,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project header
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        project.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            _getDeadlineColor(project.deadline),
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
                                ),
                                const SizedBox(height: 16),
                                if (project.requiredSkills.isNotEmpty) ...[
                                  const Text(
                                    'Required Skills',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        project.requiredSkills.map((skill) {
                                      return Chip(
                                        label: Text(
                                          skill,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor:
                                            AppTheme.lightGrayColor,
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                const Text(
                                  'Your Target',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'One step at a time. You\'ll get there.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: project.progress / 100,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor),
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
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Team members section
                        if (project.teamMembers.isNotEmpty) ...[
                          const Text(
                            'Team Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: project.teamMembers.length,
                              itemBuilder: (context, index) {
                                final memberId = project.teamMembers[index];
                                final user = _teamMemberDetails[memberId];

                                if (user == null) {
                                  // Show placeholder or loading if not found yet (though should be loaded by now)
                                  return const Padding(
                                    padding: EdgeInsets.only(right: 16),
                                    child: CircleAvatar(
                                      radius: 24,
                                      child: const Icon(Icons.person, size: 20),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    children: [
                                      user.profileImageBase64 != null &&
                                              user.profileImageBase64!
                                                  .isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  user.profileImageBase64!,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      CircleAvatar(
                                                radius: 24,
                                                backgroundImage: imageProvider,
                                                backgroundColor:
                                                    AppTheme.primaryColor,
                                              ),
                                              placeholder: (context, url) =>
                                                  CircleAvatar(
                                                radius: 24,
                                                backgroundColor:
                                                    AppTheme.primaryColor,
                                                child:
                                                    const CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      CircleAvatar(
                                                radius: 24,
                                                backgroundColor:
                                                    AppTheme.primaryColor,
                                                child: Text(
                                                  user.name.isNotEmpty
                                                      ? user.name[0]
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            )
                                          : CircleAvatar(
                                              radius: 24,
                                              backgroundColor:
                                                  AppTheme.primaryColor,
                                              child: Text(
                                                user.name.isNotEmpty
                                                    ? user.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.name.split(' ')[0],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Task list
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Task List',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.filter_list,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                // Show filter options
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Task priority section
                        const Text(
                          'Task Priority',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Task status
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TASK STATUS',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...project.tasks
                                    .map((task) => _buildTaskItem(task)),

                                const SizedBox(height: 16),

                                // Add new task button
                                InkWell(
                                  onTap: _addTask,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.add,
                                          size: 20,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Add new sub task',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTaskItem(TaskModel task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.status == TaskStatus.completed,
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (value) {
              _updateTaskStatus(
                task.id,
                value! ? TaskStatus.completed : TaskStatus.pending,
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: task.status == TaskStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.status == TaskStatus.completed
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due ${DateFormat('MMM d').format(task.dueDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
