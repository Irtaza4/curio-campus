import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';

import '../../models/task_model.dart';
import '../../models/user_model.dart';

class CreateTaskScreen extends StatefulWidget {
  final String projectId;
  final List<String> teamMembers;

  const CreateTaskScreen({
    super.key,
    required this.projectId,
    required this.teamMembers,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  String _assignedTo = '';
  TaskPriority _priority = TaskPriority.medium;
  bool _isLoading = false;

  List<UserModel> _assignableUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    if (widget.teamMembers.isNotEmpty) {
      _assignedTo = widget.teamMembers.first;
    }
    _fetchAssignableUsers();
  }

  Future<void> _fetchAssignableUsers() async {
    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    final Set<String> userIds = {};

    // Add team members
    userIds.addAll(widget.teamMembers);

    // Add chat participants
    if (currentUserId != null) {
      for (var chat in chatProvider.chats) {
        for (var participantId in chat.participants) {
          if (participantId != currentUserId) {
            userIds.add(participantId);
          }
        }
      }
    }

    List<UserModel> fetchedUsers = [];

    // Fetch user details
    try {
      // In a real app, you'd want a bulk fetch API.
      // For now, we'll fetch them in parallel to speed it up.
      final futures = userIds.map((id) => projectProvider.fetchUserById(id));
      final results = await Future.wait(futures);

      for (var user in results) {
        if (user != null) {
          fetchedUsers.add(user);
        }
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }

    if (mounted) {
      setState(() {
        _assignableUsers = fetchedUsers;
        _isLoadingUsers = false;

        // Ensure _assignedTo is valid
        if (_assignedTo.isNotEmpty &&
            !_assignableUsers.any((u) => u.id == _assignedTo)) {
          // If the currently assigned user ID isn't in the fetched list (e.g. error fetching), keep it but maybe warn?
          // Or just leave it as is, since we have the ID.
        } else if (_assignedTo.isEmpty && _assignableUsers.isNotEmpty) {
          _assignedTo = _assignableUsers.first.id;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    if (_formKey.currentState!.validate()) {
      if (_assignedTo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please assign the task to a team member'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final projectProvider =
          Provider.of<ProjectProvider>(context, listen: false);

      final taskId = await projectProvider.addTask(
        projectId: widget.projectId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assignedTo: _assignedTo,
        priority: _priority,
        dueDate: _dueDate,
      );

      setState(() {
        _isLoading = false;
      });

      if (taskId != null && mounted) {
        // Return true to indicate success
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(projectProvider.errorMessage ?? 'Failed to create task'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: AppTheme.darkSurfaceColor,
                    onSurface: AppTheme.darkTextColor,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor:
                  isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task title
              const Text(
                'Task Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _titleController,
                hintText: 'Enter task title',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Task description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _descriptionController,
                hintText: 'Enter task description',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a task description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Due date
              const Text(
                'Due Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGrayColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMMM dd, yyyy').format(_dueDate),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Priority
              const Text(
                'Priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.lightGrayColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TaskPriority>(
                    value: _priority,
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                    items: TaskPriority.values.map((priority) {
                      return DropdownMenuItem<TaskPriority>(
                        value: priority,
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag,
                              color: _getPriorityColor(priority),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(_getPriorityText(priority)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _priority = value;
                        });
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Assigned to
              const Text(
                'Assigned To',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _isLoadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGrayColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _assignedTo.isNotEmpty &&
                                  _assignableUsers
                                      .any((u) => u.id == _assignedTo)
                              ? _assignedTo
                              : null,
                          isExpanded: true,
                          hint: const Text('Select team member'),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppTheme.primaryColor,
                          ),
                          items: _assignableUsers.map((user) {
                            return DropdownMenuItem<String>(
                              value: user.id,
                              child: Text(user.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _assignedTo = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),

              const SizedBox(height: 32),

              // Create button
              CustomButton(
                text: 'Create Task',
                isLoading: _isLoading,
                onPressed: _createTask,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low Priority';
      case TaskPriority.medium:
        return 'Medium Priority';
      case TaskPriority.high:
        return 'High Priority';
    }
  }
}
