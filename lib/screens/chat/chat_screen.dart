import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/message_model.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Import dart:io
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/providers/project_provider.dart';

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

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Upload image to Firebase Storage
        final storage = FirebaseStorage.instance;
        final userId = Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = 'chat_images/${widget.chatId}/${userId}_$timestamp.jpg';

        // Create the storage reference
        final storageRef = storage.ref().child(path);

        // Upload the file
        final uploadTask = storageRef.putFile(File(pickedFile.path));

        // Wait for the upload to complete
        final snapshot = await uploadTask;

        // Get the download URL
        final imageUrl = await snapshot.ref.getDownloadURL();
        final fileName = pickedFile.name;

        await Provider.of<ChatProvider>(context, listen: false).sendImageMessage(
          chatId: widget.chatId,
          imageUrl: imageUrl,
          fileName: fileName,
        );

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

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;

    // Use the sender's name if available, otherwise use the chat name
    final displayName = _senderName.isNotEmpty ? _senderName : widget.chatName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _senderName.isNotEmpty ? ' ${widget.chatName} ' : widget.chatName,
        ),
      ),

      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.messages.isEmpty
                ? const Center(child: Text('No messages yet'))
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
              color: Colors.white,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                        color: Colors.grey[600],
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
                        ? AppTheme.primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: message.type == MessageType.image
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      message.fileUrl ?? 'https://via.placeholder.com/300',
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
                        return Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                      : Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
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
