import 'dart:convert'; // Add this import for base64 encoding
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/message_model.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Import dart:io
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/utils/image_utils.dart';

import '../../utils/app_theme.dart';
import 'edit_group_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _senderName = ""; // Store the sender's name

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to schedule the fetch after the build is complete
    Future.microtask(() => _fetchMessages());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<ChatProvider>(context, listen: false)
          .fetchMessages(widget.chatId);

      // Get the sender's name from the first message
      final messages = Provider.of<ChatProvider>(context, listen: false).messages;
      if (messages.isNotEmpty) {
        final currentUserId = Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;

        // Find the first message from the other person
        for (var message in messages) {
          if (message.senderId != currentUserId) {
            setState(() {
              _senderName = message.senderName;
            });
            break;
          }
        }

        // If we couldn't find a message from the other person, use the chat name
        if (_senderName.isEmpty) {
          // Try to get the other participant's name from the chat
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          final chat = chatProvider.chats.firstWhere(
                (c) => c.id == widget.chatId,
            orElse: () => ChatModel(
              id: widget.chatId,
              name: widget.chatName,
              participants: [],
              type: ChatType.individual,
              createdAt: DateTime.now(),
              lastMessageAt: DateTime.now(),
            ),
          );

          if (chat.type == ChatType.individual && currentUserId != null) {
            // Get the other participant's ID
            final otherParticipantId = chat.participants.firstWhere(
                  (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherParticipantId.isNotEmpty) {
              // Fetch the user's name
              final user = await Provider.of<ProjectProvider>(context, listen: false)
                  .fetchUserById(otherParticipantId);

              if (user != null && mounted) {
                setState(() {
                  _senderName = user.name;
                });
              }
            }
          }
        }
      }

      // Scroll to bottom after messages are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching messages: ${e.toString()}'),
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

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();

    await Provider.of<ChatProvider>(context, listen: false).sendMessage(
      chatId: widget.chatId,
      content: message,
      context: context, // Pass the context
    );

    // Scroll to bottom after sending a message
    _scrollToBottom();
  }

  void _showMoreOptions() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
                      title: Text('Logout',
                        style: TextStyle(
                            color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor
                        ),
                      ),
                      content: Text('Are you sure you want to logout?',
                        style: TextStyle(
                            color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor
                        ),
                      ),
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

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // Reduced from 1024 to ensure smaller file size
      maxHeight: 800,
      imageQuality: 70, // Reduce quality to decrease file size
    );

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Read the file as bytes
        final bytes = await File(pickedFile.path).readAsBytes();

        // Check file size - if too large, compress further
        if (bytes.length > 500 * 1024) { // If larger than 500KB
          // Further reduce quality
          final compressedFile = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 600,
            maxHeight: 600,
            imageQuality: 50,
          );

          if (compressedFile != null) {
            final compressedBytes = await File(compressedFile.path).readAsBytes();
            // Convert to base64
            final base64Image = base64Encode(compressedBytes);
            final fileName = compressedFile.name;

            await Provider.of<ChatProvider>(context, listen: false).sendImageMessage(
              chatId: widget.chatId,
              imageBase64: base64Image,
              fileName: fileName,
            );
          }
        } else {
          // Convert to base64
          final base64Image = base64Encode(bytes);
          final fileName = pickedFile.name;

          await Provider.of<ChatProvider>(context, listen: false).sendImageMessage(
            chatId: widget.chatId,
            imageBase64: base64Image,
            fileName: fileName,
          );
        }

        // Scroll to bottom after sending an image
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error sending image: ${e.toString()}'),
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
  }

  // Add this method to your _ChatScreenState class
  void _navigateToEditGroupChat(ChatModel chat) async {
    if (chat.type != ChatType.group) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditGroupChatScreen(
          chatId: chat.id,
          chatName: chat.name,
          groupImageBase64: chat.groupImageUrl,
          participants: chat.participants,
          creatorId: chat.creatorId ?? '',
        ),
      ),
    );

    // If the group was updated, refresh the chat details
    if (result == true) {
      _fetchMessages();
    }
  }

  // Update the build method to add an edit button in the AppBar for group chats
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Get the current chat
    final currentChat = chatProvider.chats.firstWhere(
          (chat) => chat.id == widget.chatId,
      orElse: () => ChatModel(
        id: widget.chatId,
        name: widget.chatName,
        participants: [],
        type: ChatType.individual,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
      ),
    );

    // Use the sender's name if available, otherwise use the chat name
    final displayName = _senderName.isNotEmpty ? _senderName : widget.chatName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _senderName.isNotEmpty ? ' ${widget.chatName} ' : widget.chatName,
        ),
        actions: [
          // Only show edit button for group chats
          if (currentChat.type == ChatType.group)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToEditGroupChat(currentChat),
            ),
        ],
      ),

      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.messages.isEmpty
                ? Center(
              child: Text(
                'No messages yet',
                style: TextStyle(
                  color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                ),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final message = chatProvider.messages[index];
                final isCurrentUser = message.senderId == currentUserId;

                return _buildMessageBubble(
                  message: message,
                  isCurrentUser: isCurrentUser,
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.image,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Write your message here',
                      hintStyle: TextStyle(
                        color: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDarkMode ? AppTheme.darkInputBackgroundColor : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.darkInputTextColor : AppTheme.textColor,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required MessageModel message,
    required bool isCurrentUser,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(message.senderAvatar!)
                  : null,
              onBackgroundImageError: message.senderAvatar != null
                  ? (exception, stackTrace) {
                // Handle image loading error silently
              }
                  : null,
              child: message.senderAvatar == null
                  ? Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      message.senderName, // Use sender name instead of chat name
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey[600],
                      ),
                    ),
                  ),
                Container(
                  padding: message.type == MessageType.image
                      ? const EdgeInsets.all(2)
                      : const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? (isDarkMode ? AppTheme.darkOutgoingMessageBubbleColor : AppTheme.primaryColor)
                        : (isDarkMode ? AppTheme.darkMessageBubbleColor : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(16),
                    border: isDarkMode && !isCurrentUser
                        ? Border.all(color: AppTheme.darkMediumGrayColor, width: 1)
                        : null,
                  ),
                  child: message.type == MessageType.image
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: message.fileUrl != null && message.fileUrl!.startsWith('http')
                    // Handle existing URL-based images
                        ? Image.network(
                      message.fileUrl!,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 200,
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        // Local placeholder instead of network image
                        return ImageUtils.getPlaceholderImage(
                          width: 200,
                          height: 200,
                        );
                      },
                    )
                    // Handle base64 images
                        : message.fileUrl != null && message.fileUrl!.isNotEmpty
                        ? Image.memory(
                      base64Decode(message.fileUrl!),
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: isDarkMode ? AppTheme.darkLightGrayColor : Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    )
                        : Container(
                      width: 200,
                      height: 200,
                      color: isDarkMode ? AppTheme.darkLightGrayColor : Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.image,
                          color: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey,
                          size: 48,
                        ),
                      ),
                    ),
                  )
                      : Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Colors.white
                          : (isDarkMode ? AppTheme.darkMessageTextColor : Colors.black87),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser) const SizedBox(width: 24),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat('h:mm a').format(timestamp);
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}
