import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<String> _selectedParticipants = [];
  String? _groupImageBase64;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      try {
        final bytes = await File(pickedFile.path).readAsBytes();

        // Check file size - if too large, compress further
        if (bytes.length > 500 * 1024) {
          // If larger than 500KB
          final compressedFile = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 600,
            maxHeight: 600,
            imageQuality: 50,
          );

          if (compressedFile != null) {
            final compressedBytes =
                await File(compressedFile.path).readAsBytes();
            setState(() {
              _groupImageBase64 = base64Encode(compressedBytes);
            });
          }
        } else {
          setState(() {
            _groupImageBase64 = base64Encode(bytes);
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _createGroupChat() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Add current user to participants if not already added
      final currentUserId = authProvider.firebaseUser?.uid;
      if (currentUserId != null &&
          !_selectedParticipants.contains(currentUserId)) {
        _selectedParticipants.add(currentUserId);
      }

      final chatId = await chatProvider.createGroupChat(
        name: _nameController.text.trim(),
        participants: _selectedParticipants,
        groupImageUrl: _groupImageBase64,
      );

      setState(() {
        _isLoading = false;
      });

      if (chatId != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group chat created successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                chatProvider.errorMessage ?? 'Failed to create group chat'),
            backgroundColor: AppTheme.errorColor,
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
        title: const Text('Create Group Chat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      _groupImageBase64 != null
                          ? CircleAvatar(
                              radius: 50,
                              backgroundColor: isDarkMode
                                  ? AppTheme.darkLightGrayColor
                                  : AppTheme.lightGrayColor,
                              backgroundImage:
                                  MemoryImage(base64Decode(_groupImageBase64!)),
                              onBackgroundImageError: (_, __) {},
                            )
                          : CircleAvatar(
                              radius: 50,
                              backgroundColor: isDarkMode
                                  ? AppTheme.darkLightGrayColor
                                  : AppTheme.lightGrayColor,
                              child: Icon(
                                Icons.group,
                                size: 50,
                                color: isDarkMode
                                    ? AppTheme.darkDarkGrayColor
                                    : AppTheme.darkGrayColor,
                              ),
                            ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Group name
              const Text(
                'Group Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _nameController,
                hintText: 'Enter group name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Participants
              const Text(
                'Participants',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildParticipantsSection(),

              const SizedBox(height: 32),

              // Create button
              CustomButton(
                text: 'Create Group Chat',
                isLoading: _isLoading,
                onPressed: _createGroupChat,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return FutureBuilder<List<UserModel>>(
      future: Provider.of<ChatProvider>(context, listen: false)
          .getUsers(), // Fetch users from Firestore
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        final users = snapshot.data!;
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;

        return Column(
          children: [
            // Selected participants
            if (_selectedParticipants.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? AppTheme.darkLightGrayColor
                      : AppTheme.lightGrayColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedParticipants.map((userId) {
                    final user = users.firstWhere(
                      (u) => u.id == userId,
                      orElse: () => UserModel(
                          id: userId,
                          name: 'Unknown User',
                          email: '',
                          majorSkills: [],
                          minorSkills: [],
                          createdAt: DateTime.now(),
                          lastActive: DateTime.now()),
                    );

                    return Chip(
                      label: Text(user.name),
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      deleteIconColor: AppTheme.primaryColor,
                      onDeleted: () {
                        setState(() {
                          _selectedParticipants.remove(userId);
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Add participants button
            InkWell(
              onTap: () {
                // Convert List<UserModel> to List<Map<String, dynamic>> by calling toMap() on each UserModel
                final usersMap = users.map((user) => user.toMap()).toList();
                _showAddParticipantsDialog(usersMap);
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
                    const Icon(
                      Icons.person_add,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Participants',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        );
      },
    );
  }

  void _showAddParticipantsDialog(List<Map<String, dynamic>> users) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
          title: Text(
            'Add Participants',
            style: TextStyle(
              color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = user['id'] as String;
                final isSelected = _selectedParticipants.contains(userId);

                return CheckboxListTile(
                  title: Text(
                    user['name'] as String,
                    style: TextStyle(
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textColor,
                    ),
                  ),
                  subtitle: Text(
                    user['email'] as String,
                    style: TextStyle(
                      color: isDarkMode
                          ? AppTheme.darkDarkGrayColor
                          : AppTheme.darkGrayColor,
                    ),
                  ),
                  value: isSelected,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        if (!_selectedParticipants.contains(userId)) {
                          _selectedParticipants.add(userId);
                        }
                      } else {
                        _selectedParticipants.remove(userId);
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
