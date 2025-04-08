import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/screens/chat/create_group_chat_screen.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/widgets/notification_badge.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/widgets/notification_drawer.dart';
import 'package:curio_campus/models/notification_model.dart';

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

        // If we found another participant, fetch their name
        if (otherParticipantId.isNotEmpty) {
          // Fetch the user's name from Firestore
          Provider.of<ProjectProvider>(context, listen: false)
              .fetchUserById(otherParticipantId)
              .then((user) {
            if (user != null && mounted) {
              // Navigate with the correct name
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: chat.id, chatName: user.name),
                ),
              );
            } else {
              // Fallback if user not found
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(chatId: chat.id, chatName: displayName),
                ),
              );
            }
          });
          return; // Return early as we're handling navigation in the async callback
        }
      }
    }

    // Default navigation if not an individual chat or couldn't find other participant
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;
    final chats = chatProvider.chats;
    final unreadCount = notificationProvider.unreadCount;

    return Scaffold(
      // Remove the appBar here
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchChats,
        child: chats.isEmpty
            ? const Center(child: Text('No messages yet'))
            : _buildChatList(chats, currentUserId),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'messages_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateGroupChatScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
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

        // Determine the display name for individual chats
        String displayName = chat.name;
        if (chat.type == ChatType.individual && currentUserId != null) {
          // Get the other participant's ID
          final otherParticipantId = chat.participants.firstWhere(
                (id) => id != currentUserId,
            orElse: () => '',
          );

          // Use FutureBuilder to get the user's name
          return FutureBuilder<UserModel?>(
            future: Provider.of<ProjectProvider>(context, listen: false)
                .fetchUserById(otherParticipantId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasData && snapshot.data != null) {
                displayName = snapshot.data!.name;
              }

              return _buildChatListItem(
                chat: chat,
                displayName: displayName,
                isCurrentUserLastSender: isCurrentUserLastSender,
              );
            },
          );
        }

        return _buildChatListItem(
          chat: chat,
          displayName: displayName,
          isCurrentUserLastSender: isCurrentUserLastSender,
        );
      },
    );
  }

  Widget _buildChatListItem({
    required ChatModel chat,
    required String displayName,
    required bool isCurrentUserLastSender,
  }) {
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
            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white),
          )
              : null,
        ),
        title: Text(
          displayName,
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
