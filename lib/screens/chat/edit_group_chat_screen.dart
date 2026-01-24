import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:curio_campus/utils/image_utils.dart';

import '../../utils/app_theme.dart';

class EditGroupChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? groupImageBase64;
  final List<String> participants;
  final String creatorId;

  const EditGroupChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.groupImageBase64,
    required this.participants,
    required this.creatorId,
  });

  @override
  State<EditGroupChatScreen> createState() => _EditGroupChatScreenState();
}

class _EditGroupChatScreenState extends State<EditGroupChatScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  String? _groupImageBase64;
  List<String> _participants = [];
  bool _isLoading = false;
  bool _isCurrentUserCreator = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.chatName);
    _groupImageBase64 = widget.groupImageBase64;
    _participants = List.from(widget.participants);

    // Check if current user is the creator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId =
          Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;
      if (currentUserId != null) {
        setState(() {
          _isCurrentUserCreator = widget.creatorId == currentUserId;
        });
      }
    });
  }

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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateGroupChat() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);

        await chatProvider.updateGroupChat(
          chatId: widget.chatId,
          name: _nameController.text.trim(),
          groupImageBase64: _groupImageBase64,
          participants: _participants,
        );

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          Navigator.pop(
              context, true); // Return true to indicate successful update
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group chat updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update group chat: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _removeMember(String userId) {
    if (!_isCurrentUserCreator) return;

    setState(() {
      _participants.remove(userId);
    });
  }

  void _showAddParticipantsDialog() async {
    if (!_isCurrentUserCreator) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final users = await chatProvider.getUsers();

    // Filter out users who are already in the group
    final filteredUsers =
        users.where((user) => !_participants.contains(user.id)).toList();

    if (filteredUsers.isEmpty) {
      if (!mounted) return; // Add mounted check before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available users are already in this group'),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Create a temporary list to track selections
    final List<String> tempSelectedUserIds = [];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor:
                  isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
              title: Text(
                'Add Participants',
                style: TextStyle(
                  color:
                      isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Select users to add to the group',
                        style: TextStyle(
                          color: isDarkMode
                              ? AppTheme.darkDarkGrayColor
                              : AppTheme.darkGrayColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          final userId = user.id;
                          final isSelected =
                              tempSelectedUserIds.contains(userId);

                          return CheckboxListTile(
                            title: Text(
                              user.name,
                              style: TextStyle(
                                color: isDarkMode
                                    ? AppTheme.darkTextColor
                                    : AppTheme.textColor,
                              ),
                            ),
                            subtitle: Text(
                              user.email,
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
                                  tempSelectedUserIds.add(userId);
                                } else {
                                  tempSelectedUserIds.remove(userId);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDarkMode
                          ? AppTheme.darkDarkGrayColor
                          : AppTheme.darkGrayColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Update the main participants list
                    this.setState(() {
                      _participants.addAll(tempSelectedUserIds);
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Add (${tempSelectedUserIds.length})',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Group'),
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
                      _groupImageBase64 != null && _groupImageBase64!.isNotEmpty
                          ? ImageUtils.loadBase64Image(
                              base64String: _groupImageBase64,
                              width: 100,
                              height: 100,
                              placeholder: CircleAvatar(
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
              Text(
                'Group Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color:
                      isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
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

              // Participants section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Participants (${_participants.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textColor,
                    ),
                  ),
                  if (_isCurrentUserCreator)
                    TextButton.icon(
                      onPressed: _showAddParticipantsDialog,
                      icon: Icon(
                        Icons.person_add,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      label: Text(
                        'Add',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildParticipantsList(),

              const SizedBox(height: 32),

              // Update button
              CustomButton(
                text: 'Update Group',
                isLoading: _isLoading,
                onPressed: _updateGroupChat,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsList() {
    return FutureBuilder<List<UserModel>>(
      future: Provider.of<ChatProvider>(context, listen: false).getUsers(),
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

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _participants.length,
          itemBuilder: (context, index) {
            final participantId = _participants[index];
            final user = users.firstWhere(
              (u) => u.id == participantId,
              orElse: () => UserModel(
                id: participantId,
                name: 'Unknown User',
                email: '',
                majorSkills: [],
                minorSkills: [],
                createdAt: DateTime.now(),
                lastActive: DateTime.now(),
              ),
            );

            final isCurrentUser = participantId ==
                Provider.of<AuthProvider>(context, listen: false)
                    .firebaseUser
                    ?.uid;
            final isCreator = participantId == widget.creatorId;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppTheme.darkLightGrayColor
                    : AppTheme.lightGrayColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: user.profileImageBase64 != null
                      ? MemoryImage(base64Decode(user.profileImageBase64!))
                      : null,
                  child: user.profileImageBase64 == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isCreator)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Creator',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    if (isCurrentUser && !isCreator)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppTheme.darkMediumGrayColor
                              : AppTheme.mediumGrayColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode
                                ? AppTheme.darkTextColor
                                : AppTheme.textColor,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  user.email,
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkDarkGrayColor
                        : AppTheme.darkGrayColor,
                  ),
                ),
                trailing: _isCurrentUserCreator && !isCreator
                    ? IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeMember(participantId),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
