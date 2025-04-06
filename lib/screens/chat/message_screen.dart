import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/screens/chat/create_group_chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to schedule the fetch after the build is complete
    Future.microtask(() => _fetchChats());
  }

  Future<void> _fetchChats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<ChatProvider>(context, listen: false).fetchChats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching chats: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToChatScreen(ChatModel chat) {
    // Determine the correct chat name based on the chat type
    String displayName = chat.name;

    if (chat.type == ChatType.individual) {
      final currentUserId = Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;
      // For individual chats, if the chat name is the current user's name,
      // we need to find the other participant's name
      if (currentUserId != null && chat.participants.contains(currentUserId)) {
        // Get the other participant's ID
        final otherParticipantId = chat.participants.firstWhere(
              (id) => id != currentUserId,
          orElse: () => '',
        );

        // If we found another participant, use their name instead
        if (otherParticipantId.isNotEmpty) {
          // We'll use the chat name for now, but in a real app,
          // you would fetch the user's name from Firestore
          displayName = chat.name;
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chat.id, chatName: displayName),
      ),
    );
  }

  void _deleteChat(String chatId) async {
    await Provider.of<ChatProvider>(context, listen: false).deleteChat(chatId);
  }

  // Update the _showMoreOptions method to include more relevant options
  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group_add, color: AppTheme.primaryColor),
                title: const Text('Create Group Chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateGroupChatScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_chat_read, color: AppTheme.primaryColor),
                title: const Text('Mark All as Read'),
                onTap: () {
                  Navigator.pop(context);
                  // Implement mark all as read functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All messages marked as read'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.grey),
                title: const Text('Chat Settings'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to chat settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat settings coming soon'),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await Provider.of<AuthProvider>(context, listen: false).logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

// Add a method to show notifications
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All notifications marked as read'),
                            ),
                          );
                        },
                        child: const Text('Mark all as read'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildNotificationItem(
                        'New emergency request from Sarah',
                        'Need help with Flutter project',
                        '5 minutes ago',
                        Icons.warning_amber_rounded,
                        Colors.orange,
                      ),
                      _buildNotificationItem(
                        'John sent you a message',
                        'Hey, how\'s the project going?',
                        '30 minutes ago',
                        Icons.chat_bubble_outline,
                        AppTheme.primaryColor,
                      ),
                      _buildNotificationItem(
                        'Project deadline approaching',
                        'Mobile App UI Design due tomorrow',
                        '2 hours ago',
                        Icons.calendar_today,
                        Colors.blue,
                      ),
                      _buildNotificationItem(
                        'New match found',
                        'Emma has similar skills to your project requirements',
                        '1 day ago',
                        Icons.people_outline,
                        Colors.green,
                      ),
                      _buildNotificationItem(
                        'Task completed',
                        'Michael marked "Create wireframes" as complete',
                        '2 days ago',
                        Icons.task_alt,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(
      String title,
      String subtitle,
      String time,
      IconData icon,
      Color iconColor,
      ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.2),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        // Handle notification tap based on type
      },
    );
  }

// Update the build method to include the notification icon
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;
    final chats = chatProvider.chats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchChats,
        child: chats.isEmpty
            ? const Center(child: Text('No messages yet'))
            : _buildChatList(chats, currentUserId),
      ),
    );
  }

  Widget _buildChatList(List<ChatModel> chats, String? currentUserId) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: chats.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isCurrentUserLastSender = chat.lastMessageSenderId == currentUserId;

        return Dismissible(
          key: Key(chat.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _deleteChat(chat.id);
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: chat.type == ChatType.group && chat.groupImageUrl != null
                  ? NetworkImage(chat.groupImageUrl!)
                  : null,
              onBackgroundImageError: chat.type == ChatType.group && chat.groupImageUrl != null
                  ? (exception, stackTrace) {
                // Handle image loading error silently
              }
                  : null,
              child: chat.type == ChatType.group && chat.groupImageUrl == null
                  ? const Icon(Icons.group, color: Colors.white)
                  : chat.type == ChatType.individual && chat.groupImageUrl == null
                  ? Text(
                chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              )
                  : null,
            ),
            title: Text(
              chat.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              chat.lastMessageContent ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(chat.lastMessageAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (!isCurrentUserLastSender && chat.lastMessageContent != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            onTap: () => _navigateToChatScreen(chat),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }
}

