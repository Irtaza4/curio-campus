import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/chat/create_group_chat_screen.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/utils/image_utils.dart';

import '../../utils/app_theme.dart';

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
    String displayName = chat.name;

    if (chat.type == ChatType.individual) {
      final currentUserId =
          Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;

      if (currentUserId != null && chat.participants.contains(currentUserId)) {
        final otherParticipantId = chat.participants.firstWhere(
              (id) => id != currentUserId,
          orElse: () => '',
        );

        if (otherParticipantId.isNotEmpty) {
          Provider.of<ProjectProvider>(context, listen: false)
              .fetchUserById(otherParticipantId)
              .then((user) {
            if (user != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                      chatId: chat.id, chatName: user.name),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(chatId: chat.id, chatName: displayName),
                ),
              );
            }
          });
          return;
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;
    final chats = chatProvider.chats;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchChats,
        child: chats.isEmpty
            ? Center(
          child: Text(
            'No messages yet',
            style: TextStyle(
              color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
            ),
          ),
        )
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: chats.length,
      separatorBuilder: (context, index) => Divider(
        color: isDarkMode ? AppTheme.darkMediumGrayColor : AppTheme.mediumGrayColor,
      ),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isCurrentUserLastSender =
            chat.lastMessageSenderId == currentUserId;

        String displayName = chat.name;

        if (chat.type == ChatType.individual && currentUserId != null) {
          final otherParticipantId = chat.participants.firstWhere(
                (id) => id != currentUserId,
            orElse: () => '',
          );

          return FutureBuilder<UserModel?>(
            future: Provider.of<ProjectProvider>(context, listen: false)
                .fetchUserById(otherParticipantId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              UserModel? user = snapshot.data;
              if (user != null) {
                displayName = user.name;
              }

              return _buildChatListItem(
                chat: chat,
                displayName: displayName,
                isCurrentUserLastSender: isCurrentUserLastSender,
                profileImageBase64: user?.profileImageBase64,
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
    String? profileImageBase64,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
      onDismissed: (_) => _deleteChat(chat.id),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: _buildChatAvatar(chat, displayName, profileImageBase64),
          title: Text(
            displayName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
            ),
          ),
          subtitle: Text(
            chat.lastMessageContent ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDarkMode ? AppTheme.darkDarkGrayColor : AppTheme.darkGrayColor,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(chat.lastMessageAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey[600],
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
      ),
    );
  }

// Add this new helper method
  Widget _buildChatAvatar(ChatModel chat, String displayName, String? profileImageBase64) {
    const double avatarSize = 40;

    if (chat.type == ChatType.group) {
      // Handle group avatar
      if (chat.groupImageUrl != null && chat.groupImageUrl!.isNotEmpty) {
        if (chat.groupImageUrl!.startsWith('http')) {
          // Network image (rounded using CircleAvatar)
          return CircleAvatar(
            radius: avatarSize / 2,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: NetworkImage(chat.groupImageUrl!),
            onBackgroundImageError: (_, __) {},
          );
        } else {
          // Base64 image (rounded using ClipOval)
          return _buildBase64CircleImage(
            base64String: chat.groupImageUrl!,
            size: avatarSize,
            placeholder: ImageUtils.getGroupPlaceholder(),
          );
        }
      } else {
        // Default group icon
        return ClipOval(
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: ImageUtils.getGroupPlaceholder(),
          ),
        );
      }
    } else {
      // Handle individual chat avatar
      if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
        return _buildBase64CircleImage(
          base64String: profileImageBase64,
          size: avatarSize,
          placeholder: ImageUtils.getUserPlaceholder(initial: displayName),
        );
      } else {
        return ClipOval(
          child: SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: ImageUtils.getUserPlaceholder(initial: displayName),
          ),
        );
      }
    }
  }
  Widget _buildBase64CircleImage({
    required String base64String,
    required double size,
    Widget? placeholder,
  }) {
    try {
      final bytes = base64Decode(base64String);
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } catch (e) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: placeholder ?? const Icon(Icons.person),
        ),
      );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Just now';
  }
}
