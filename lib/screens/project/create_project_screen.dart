import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({Key? key}) : super(key: key);

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  final List<String> _selectedTeamMembers = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Add current user to team members if not already added
      final currentUserId = authProvider.firebaseUser?.uid;
      if (currentUserId != null && !_selectedTeamMembers.contains(currentUserId)) {
        _selectedTeamMembers.add(currentUserId);
      }

      final projectId = await projectProvider.createProject(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        teamMembers: _selectedTeamMembers,
        deadline: _deadline,
      );

      setState(() {
        _isLoading = false;
      });

      if (projectId != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(projectProvider.errorMessage ?? 'Failed to create project'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
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

    if (picked != null && picked != _deadline) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project name
              const Text(
                'Project Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _nameController,
                hintText: 'Enter project name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Project description
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
                hintText: 'Enter project description',
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Deadline
              const Text(
                'Deadline',
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
                        DateFormat('MMMM dd, yyyy').format(_deadline),
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

              // Team members
              const Text(
                'Team Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildTeamMembersSection(),

              const SizedBox(height: 32),

              // Create button
              CustomButton(
                text: 'Create Project',
                isLoading: _isLoading,
                onPressed: _createProject,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMembersSection() {
    // In a real app, you would fetch users from the database
    // For this demo, we'll use dummy data
    final dummyUsers = [
      {'id': 'user1', 'name': 'Olivia Martin', 'email': 'olivia@example.com'},
      {'id': 'user2', 'name': 'Ethan Johnson', 'email': 'ethan@example.com'},
      {'id': 'user3', 'name': 'Sophia Williams', 'email': 'sophia@example.com'},
      {'id': 'user4', 'name': 'Noah Brown', 'email': 'noah@example.com'},
      {'id': 'user5', 'name': 'Emma Jones', 'email': 'emma@example.com'},
    ];

    return Column(
      children: [
        // Selected team members
        if (_selectedTeamMembers.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightGrayColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTeamMembers.map((userId) {
                final user = dummyUsers.firstWhere(
                      (u) => u['id'] == userId,
                  orElse: () => {'id': userId, 'name': 'Unknown User', 'email': ''},
                );

                return Chip(
                  label: Text(user['name'] as String),
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  deleteIconColor: AppTheme.primaryColor,
                  onDeleted: () {
                    setState(() {
                      _selectedTeamMembers.remove(userId);
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Add team members button
        InkWell(
          onTap: () {
            _showAddTeamMembersDialog(dummyUsers);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Team Members',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddTeamMembersDialog(List<Map<String, dynamic>> users) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Team Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = user['id'] as String;
                final isSelected = _selectedTeamMembers.contains(userId);

                return CheckboxListTile(
                  title: Text(user['name'] as String),
                  subtitle: Text(user['email'] as String),
                  value: isSelected,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        if (!_selectedTeamMembers.contains(userId)) {
                          _selectedTeamMembers.add(userId);
                        }
                      } else {
                        _selectedTeamMembers.remove(userId);
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
