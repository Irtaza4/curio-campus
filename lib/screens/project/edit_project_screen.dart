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
import 'package:curio_campus/widgets/skill_selector.dart';

class EditProjectScreen extends StatefulWidget {
  final ProjectModel project;

  const EditProjectScreen({
    super.key,
    required this.project,
  });

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 7));
  List<String> _selectedSkills = [];
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
    _selectedSkills = List.from(widget.project.requiredSkills);

    // Check if the user is the creator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final projectProvider =
            Provider.of<ProjectProvider>(context, listen: false);
        if (widget.project.createdBy != projectProvider.currentUserId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only the project creator can edit this project.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
          return;
        }
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
      if (!mounted) return;
      final currentUserId =
          Provider.of<ProjectProvider>(context, listen: false).currentUserId;
      contactIds.remove(currentUserId);

      // Fetch user details for each contact
      if (!mounted) return;
      final contacts =
          await Provider.of<ProjectProvider>(context, listen: false)
              .fetchUsers(contactIds.toList());

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

  Future<void> _selectRequiredSkills() async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
        title: Text(
          'Required Skills',
          style: TextStyle(
            color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
          ),
        ),
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
            child: Text(
              'Done',
              style: TextStyle(
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
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
          content: Text(
              'No chat contacts found. Start chatting with people to add them to your project.'),
        ),
      );
      return;
    }

    // Create a stateful list to track selections within the dialog
    final List<String> tempSelectedMembers = List.from(_selectedTeamMembers);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            backgroundColor:
                isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
            title: Text(
              'Add Team Members',
              style: TextStyle(
                color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chatContacts.length,
                itemBuilder: (context, index) {
                  final contact = _chatContacts[index];
                  final isSelected = tempSelectedMembers.contains(contact.id);

                  return CheckboxListTile(
                    title: Text(
                      contact.name,
                      style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textColor,
                      ),
                    ),
                    subtitle: Text(
                      contact.email,
                      style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.darkDarkGrayColor
                            : AppTheme.darkGrayColor,
                      ),
                    ),
                    value: isSelected,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelectedMembers.add(contact.id);
                        } else {
                          tempSelectedMembers.remove(contact.id);
                        }
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        contact.name.isNotEmpty
                            ? contact.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTeamMembers = tempSelectedMembers;
                  });
                  Navigator.pop(context);
                },
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    final projectProvider =
        Provider.of<ProjectProvider>(context, listen: false);
    if (widget.project.createdBy != projectProvider.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to edit this project.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProject = widget.project.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        deadline: _deadline,
        teamMembers: _selectedTeamMembers,
        requiredSkills: _selectedSkills,
      );

      await Provider.of<ProjectProvider>(context, listen: false)
          .updateProject(updatedProject);

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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

                    // Required Skills
                    Text(
                      'Required Skills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textColor,
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
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.darkMediumGrayColor
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isDarkMode
                              ? AppTheme.darkInputBackgroundColor
                              : Colors.transparent,
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
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textColor,
                              ),
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
                            label: Text(
                              skill,
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textColor,
                              ),
                            ),
                            backgroundColor: isDarkMode
                                ? AppTheme.darkLightGrayColor
                                : AppTheme.lightGrayColor,
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
                    Text(
                      'Deadline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textColor,
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
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.darkMediumGrayColor
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isDarkMode
                              ? AppTheme.darkInputBackgroundColor
                              : Colors.transparent,
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
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Team members
                    Text(
                      'Team Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textColor,
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
                          border: Border.all(
                            color: isDarkMode
                                ? AppTheme.darkMediumGrayColor
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isDarkMode
                              ? AppTheme.darkInputBackgroundColor
                              : Colors.transparent,
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
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textColor,
                              ),
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
                          // Try to find user in loaded contacts, or fallback
                          final user = _chatContacts.firstWhere(
                            (contact) => contact.id == userId,
                            orElse: () => UserModel(
                              id: userId,
                              name:
                                  'User', // May need refinement if users not in contacts
                              email: '',
                              majorSkills: [],
                              minorSkills: [],
                              createdAt: DateTime.now(),
                              lastActive: DateTime.now(),
                              profileImageBase64: null,
                            ),
                          );

                          return Chip(
                            label: Text(
                              user.name,
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textColor,
                              ),
                            ),
                            backgroundColor: isDarkMode
                                ? AppTheme.darkLightGrayColor
                                : AppTheme.lightGrayColor,
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
