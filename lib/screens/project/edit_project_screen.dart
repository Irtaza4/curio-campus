import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/project_model.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:intl/intl.dart';

class EditProjectScreen extends StatefulWidget {
  final ProjectModel project;

  const EditProjectScreen({
    Key? key,
    required this.project,
  }) : super(key: key);

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  List<String> _selectedTeamMembers = [];
  bool _isLoading = false;
  List<UserModel> _chatContacts = [];
  bool _isLoadingContacts = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.project.name;
    _descriptionController.text = widget.project.description;
    _deadline = widget.project.deadline;
    _selectedTeamMembers = List.from(widget.project.teamMembers);

    // Schedule the fetch operation after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchChatContacts();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatContacts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingContacts = true;
    });

    try {
      // Fetch chats to get contacts
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      await chatProvider.fetchChats();

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

      if (!mounted) return;

      setState(() {
        _chatContacts = contacts;
        _isLoadingContacts = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingContacts = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching contacts: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

  void _toggleTeamMember(String userId) {
    setState(() {
      if (_selectedTeamMembers.contains(userId)) {
        _selectedTeamMembers.remove(userId);
      } else {
        _selectedTeamMembers.add(userId);
      }
    });
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProject = widget.project.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        deadline: _deadline,
        teamMembers: _selectedTeamMembers,
      );

      await Provider.of<ProjectProvider>(context, listen: false).updateProject(updatedProject);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating project: ${e.toString()}'),
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
        title: const Text('Edit Project'),
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
              const SizedBox(height: 4),
              const Text(
                'You can only add members from your chat contacts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              _isLoadingContacts
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
                  : _chatContacts.isEmpty
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No chat contacts found. Start chatting with people to add them to your project.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _chatContacts.length,
                itemBuilder: (context, index) {
                  final contact = _chatContacts[index];
                  final isSelected = _selectedTeamMembers.contains(contact.id);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: contact.profileImageBase64 != null && contact.profileImageBase64!.isNotEmpty
                          ? ClipOval(
                        child: Image.memory(
                          base64Decode(contact.profileImageBase64!),
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      )

                          : Text(
                        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(contact.name),
                    subtitle: Text(
                      contact.majorSkills.isNotEmpty
                          ? contact.majorSkills.join(', ')
                          : 'No skills listed',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      activeColor: AppTheme.primaryColor,
                      onChanged: (value) => _toggleTeamMember(contact.id),
                    ),
                    onTap: () => _toggleTeamMember(contact.id),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Save button
              CustomButton(
                text: 'Save Changes',
                onPressed: _saveProject,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
