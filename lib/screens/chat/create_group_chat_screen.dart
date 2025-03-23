import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';

class CreateGroupChatScreen extends StatefulWidget {
  const CreateGroupChatScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<String> _selectedParticipants = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroupChat() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: Colors.red,
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
      if (currentUserId != null && !_selectedParticipants.contains(currentUserId)) {
        _selectedParticipants.add(currentUserId);
      }

      final chatId = await chatProvider.createGroupChat(
        name: _nameController.text.trim(),
        participants: _selectedParticipants,
      );

      setState(() {
        _isLoading = false;
      });

      if (chatId != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group chat created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.errorMessage ?? 'Failed to create group chat'),
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
        title: const Text('Create Group Chat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        // Selected participants
        if (_selectedParticipants.isNotEmpty) ...[
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
              children: _selectedParticipants.map((userId) {
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
            _showAddParticipantsDialog(dummyUsers);
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
        ),
      ],
    );
  }

  void _showAddParticipantsDialog(List<Map<String, dynamic>> users) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Participants'),
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
                  title: Text(user['name'] as String),
                  subtitle: Text(user['email'] as String),
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

