import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:curio_campus/widgets/skill_selector.dart';
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
  List<String> _selectedTeamMembers = [];
  List<String> _selectedSkills = []; // Added for required skills
  bool _isLoading = false;
  List<UserModel> _chatContacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _fetchChatContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatContacts() async {
    setState(() {
      _isLoadingContacts = true;
    });

    try {
      // Fetch chats to get contacts
      await Provider.of<ChatProvider>(context, listen: false).fetchChats();
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Get unique user IDs from chats
      final Set<String> contactIds = {};
      for (final chat in chatProvider.chats) {
        contactIds.addAll(chat.participants);
      }

      // Remove current user ID
      final currentUserId = Provider.of<ProjectProvider>(context, listen: false).currentUserId;
      contactIds.remove(currentUserId);

      // Fetch user details for each contact
      final List<UserModel> contacts = [];
      for (final userId in contactIds) {
        final user = await Provider.of<ProjectProvider>(context, listen: false).fetchUserById(userId);
        if (user != null) {
          contacts.add(user);
        }
      }

      setState(() {
        _chatContacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingContacts = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching contacts: ${e.toString()}'),
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

  Future<void> _selectTeamMembers() async {
    if (_isLoadingContacts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading contacts, please wait...'),
        ),
      );
      return;
    }

    if (_chatContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No chat contacts found. Start chatting with people to add them to your project.'),
        ),
      );
      return;
    }

    final List<String> tempSelectedMembers = List.from(_selectedTeamMembers);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Team Members'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _chatContacts.length,
            itemBuilder: (context, index) {
              final contact = _chatContacts[index];
              final isSelected = tempSelectedMembers.contains(contact.id);

              return CheckboxListTile(
                title: Text(contact.name),
                subtitle: Text(contact.email),
                value: isSelected,
                onChanged: (value) {
                  if (value == true) {
                    tempSelectedMembers.add(contact.id);
                  } else {
                    tempSelectedMembers.remove(contact.id);
                  }
                  setState(() {});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedTeamMembers = tempSelectedMembers;
              });
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // New method to select required skills
  Future<void> _selectRequiredSkills() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Required Skills'),
        content: SizedBox(
          width: double.maxFinite,
          child: SkillSelector(
            selectedSkills: _selectedSkills,
            onSkillsChanged: (skills) {
              setState(() {
                _selectedSkills = skills;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final projectId = await Provider.of<ProjectProvider>(context, listen: false).createProject(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        teamMembers: _selectedTeamMembers,
        deadline: _deadline,
        requiredSkills: _selectedSkills, // Pass required skills
      );

      if (mounted) {
        if (projectId != null) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create project'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project name
              CustomTextField(
                controller: _nameController,
                hintText: 'Enter project name',
                labelText: 'Project Name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Project description
              CustomTextField(
                controller: _descriptionController,
                hintText: 'Enter project description',
                labelText: 'Description',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a project description';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Required Skills
              const Text(
                'Required Skills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectRequiredSkills,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedSkills.isEmpty
                            ? 'Select required skills'
                            : '${_selectedSkills.length} skill(s) selected',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedSkills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedSkills.map((skill) {
                    return Chip(
                      label: Text(skill),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _selectedSkills.remove(skill);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),

              // Deadline
              const Text(
                'Deadline',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_deadline),
                        style: const TextStyle(fontSize: 16),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectTeamMembers,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedTeamMembers.isEmpty
                            ? 'Add team members'
                            : '${_selectedTeamMembers.length} member(s) selected',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedTeamMembers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedTeamMembers.map((userId) {
                    final user = _chatContacts.firstWhere(
                          (contact) => contact.id == userId,
                      orElse: () => UserModel(
                        id: userId,
                        name: 'Unknown User',
                        email: '',
                        majorSkills: [],
                        minorSkills: [],
                        createdAt: DateTime.now(),
                        lastActive: DateTime.now(),
                      ),
                    );

                    return Chip(
                      label: Text(user.name),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _selectedTeamMembers.remove(userId);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 32),

              // Create button
              CustomButton(
                text: 'Create Project',
                onPressed: _createProject,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

