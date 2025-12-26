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

  @override
  void initState() {
    super.initState();
    if (widget.teamMembers.isNotEmpty) {
      _assignedTo = widget.teamMembers.first;
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
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
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    // Get chat participants for assignment
    List<String> chatParticipants = [];
    if (currentUserId != null) {
      for (var chat in chatProvider.chats) {
        for (var participantId in chat.participants) {
          if (participantId != currentUserId &&
              !chatParticipants.contains(participantId)) {
            chatParticipants.add(participantId);
          }
        }
      }
    }

    // Combine team members and chat participants
    final List<String> allAssignableUsers = [...widget.teamMembers];
    for (var participantId in chatParticipants) {
      if (!allAssignableUsers.contains(participantId)) {
        allAssignableUsers.add(participantId);
      }
    }

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
                  child: DropdownButton<String>(
                    value: _assignedTo.isEmpty ? null : _assignedTo,
                    isExpanded: true,
                    hint: const Text('Select team member or chat contact'),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.primaryColor,
                    ),
                    items: allAssignableUsers.map((userId) {
                      // For team members, use the dummy data
                      // For chat contacts, fetch the user name from the project provider
                      return DropdownMenuItem<String>(
                        value: userId,
                        child: FutureBuilder<UserModel?>(
                          future: Provider.of<ProjectProvider>(context,
                                  listen: false)
                              .fetchUserById(userId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text('Loading...');
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return Text(snapshot.data!.name);
                            }
                            return Text('User $userId');
                          },
                        ),
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
