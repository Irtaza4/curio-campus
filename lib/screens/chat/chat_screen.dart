import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/message_model.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/utils/image_utils.dart';
import 'package:curio_campus/screens/chat/call_screen.dart';
import 'package:curio_campus/screens/chat/image_viewer_screen.dart';
import 'package:curio_campus/widgets/call_message_bubble.dart';

import '../../utils/app_theme.dart';
import '../../widgets/audio_player.dart';
import '../../widgets/voice_recorder.dart';
import 'edit_group_chat_screen.dart';
import 'package:curio_campus/services/call_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _senderName = "";
  bool _isRecording = false;
  String? _otherUserId;
  String? _otherUserProfileImage;
  final Map<String, bool> _deletingMessages = {};

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

      if (!mounted) return;

      // Get the sender's name from the first message
      final messages =
          Provider.of<ChatProvider>(context, listen: false).messages;
      final currentUserId =
          Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;

      if (messages.isNotEmpty) {
        // Find the first message from the other person
        for (var message in messages) {
          if (message.senderId != currentUserId) {
            setState(() {
              _senderName = message.senderName;
              _otherUserId = message.senderId;
            });
            break;
          }
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
            if (!mounted) return;
            // Fetch the user's name
            final user =
                await Provider.of<ProjectProvider>(context, listen: false)
                    .fetchUserById(otherParticipantId);

            if (!mounted) return;
            if (user != null) {
              setState(() {
                _senderName = user.name;
                _otherUserId = otherParticipantId;
                _otherUserProfileImage = user.profileImageBase64;
              });
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
    if (mounted) {
      _scrollToBottom();
    }
  }

  // Fixed _initiateCall method to provide required parameters
  void _initiateCall(bool isVideoCall) {
    if (_otherUserId == null) return;

    final callService = CallService();

    callService.makeCall(
      recipientId: _otherUserId!,
      recipientName: _senderName.isNotEmpty ? _senderName : widget.chatName,
      recipientImage: _otherUserProfileImage,
      callType: isVideoCall ? CallType.video : CallType.voice,
    );
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
                leading: Icon(Icons.call, color: AppTheme.primaryColor),
                title: Text(
                  'Voice Call',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _initiateCall(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam, color: AppTheme.primaryColor),
                title: Text(
                  'Video Call',
                  style: TextStyle(
                    color: isDarkMode
                        ? AppTheme.darkTextColor
                        : AppTheme.textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _initiateCall(true);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor:
                          isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
                      title: Text(
                        'Logout',
                        style: TextStyle(
                            color: isDarkMode
                                ? AppTheme.darkTextColor
                                : AppTheme.textColor),
                      ),
                      content: Text(
                        'Are you sure you want to logout?',
                        style: TextStyle(
                            color: isDarkMode
                                ? AppTheme.darkTextColor
                                : AppTheme.textColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (!context.mounted) return;
                    await Provider.of<AuthProvider>(context, listen: false)
                        .logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
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
        if (bytes.length > 500 * 1024) {
          // If larger than 500KB
          // Further reduce quality
          final compressedFile = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 600,
            maxHeight: 600,
            imageQuality: 50,
          );

          if (compressedFile != null) {
            final compressedBytes =
                await File(compressedFile.path).readAsBytes();
            // Convert to base64
            final base64Image = base64Encode(compressedBytes);
            final fileName = compressedFile.name;

            if (mounted) {
              await Provider.of<ChatProvider>(context, listen: false)
                  .sendImageMessage(
                chatId: widget.chatId,
                imageBase64: base64Image,
                fileName: fileName,
              );
            }
          }
        } else {
          // Convert to base64
          final base64Image = base64Encode(bytes);
          final fileName = pickedFile.name;

          if (mounted) {
            await Provider.of<ChatProvider>(context, listen: false)
                .sendImageMessage(
              chatId: widget.chatId,
              imageBase64: base64Image,
              fileName: fileName,
            );
          }
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

  void _toggleVoiceRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  void _handleVoiceRecordingComplete(String audioBase64, int duration) {
    setState(() {
      _isRecording = false;
    });

    // Send the voice message
    Provider.of<ChatProvider>(context, listen: false).sendVoiceMessage(
      chatId: widget.chatId,
      audioBase64: audioBase64,
      duration: duration,
      context: context,
    );

    // Scroll to bottom after sending a voice message
    _scrollToBottom();
  }

  void _handleVoiceRecordingCancel() {
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _deleteMessage(String messageId) async {
    // Check if this message is already being deleted
    if (_deletingMessages[messageId] == true) return;

    // Mark this message as being deleted
    setState(() {
      _deletingMessages[messageId] = true;
    });

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (mounted) {
          await Provider.of<ChatProvider>(context, listen: false)
              .deleteMessage(widget.chatId, messageId);
        }

        // Refresh the messages list to ensure UI is updated
        await _fetchMessages();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete message: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _deletingMessages.remove(messageId);
      });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _senderName.isNotEmpty ? _senderName : widget.chatName,
        ),
        actions: [
          // Call button
          if (currentChat.type == ChatType.individual)
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _initiateCall(false),
            ),
          // Video call button
          if (currentChat.type == ChatType.individual)
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () => _initiateCall(true),
            ),
          // Only show edit button for group chats
          if (currentChat.type == ChatType.group)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _navigateToEditGroupChat(currentChat),
            ),
          // More options
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
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
                            color: isDarkMode
                                ? AppTheme.darkTextColor
                                : AppTheme.textColor,
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
                          final isCurrentUser =
                              message.senderId == currentUserId;

                          return _buildMessageBubble(
                            message: message,
                            isCurrentUser: isCurrentUser,
                          );
                        },
                      ),
          ),

          // Voice recorder (when active)
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: VoiceRecorder(
                onStop: _handleVoiceRecordingComplete,
                onCancel: _handleVoiceRecordingCancel,
              ),
            ),

          // Message input
          if (!_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.image,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: _pickAndSendImage,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.mic,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: _toggleVoiceRecording,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Write your message here',
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? AppTheme.darkDarkGrayColor
                              : Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? AppTheme.darkInputBackgroundColor
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.darkInputTextColor
                            : AppTheme.textColor,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
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
    final isBeingDeleted = _deletingMessages[message.id] == true;

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
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      message
                          .senderName, // Use sender name instead of chat name
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppTheme.darkDarkGrayColor
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: isCurrentUser && !isBeingDeleted
                      ? () => _deleteMessage(message.id)
                      : null,
                  child: Container(
                    padding: message.type == MessageType.image
                        ? const EdgeInsets.all(2)
                        : const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? (isDarkMode
                              ? AppTheme.darkOutgoingMessageBubbleColor
                              : AppTheme.primaryColor)
                          : (isDarkMode
                              ? AppTheme.darkMessageBubbleColor
                              : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(16),
                      border: isDarkMode && !isCurrentUser
                          ? Border.all(
                              color: AppTheme.darkMediumGrayColor, width: 1)
                          : null,
                    ),
                    child: isBeingDeleted
                        ? SizedBox(
                            width: 100,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isCurrentUser
                                          ? Colors.white
                                          : AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Deleting...',
                                  style: TextStyle(
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildMessageContent(
                            message, isCurrentUser, isDarkMode),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDarkMode
                          ? AppTheme.darkDarkGrayColor
                          : Colors.grey[600],
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

  Widget _buildMessageContent(
      MessageModel message, bool isCurrentUser, bool isDarkMode) {
    switch (message.type) {
      case MessageType.callEvent:
        return CallMessageBubble(
          message: {
            'callType': message.fileUrl == 'video' ? 'video' : 'voice',
            'status': message.content.contains('missed')
                ? 'missed'
                : (message.content.contains('declined') ? 'declined' : 'ended'),
            'duration': message.duration,
            'timestamp': message.timestamp,
            'isOutgoing': message.content.contains('outgoing'),
          },
          isCurrentUser: isCurrentUser,
        );
      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTap: () {
              // Open image viewer when tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrl: message.fileUrl != null &&
                            message.fileUrl!.startsWith('http')
                        ? message.fileUrl
                        : null,
                    imageBase64: message.fileUrl != null &&
                            !message.fileUrl!.startsWith('http')
                        ? message.fileUrl
                        : null,
                    title: 'Image from ${message.senderName}',
                  ),
                ),
              );
            },
            child: _buildImageContent(message.fileUrl),
          ),
        );
      case MessageType.audio:
        return AudioMessagePlayer(
          audioBase64: message.fileUrl ?? '',
          duration: message.duration,
        );
      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.video_library,
              color: isCurrentUser ? Colors.white70 : Colors.black54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              'Video message',
              style: TextStyle(
                color: isCurrentUser
                    ? Colors.white
                    : (isDarkMode
                        ? AppTheme.darkMessageTextColor
                        : Colors.black87),
              ),
            ),
          ],
        );
      case MessageType.file:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isCurrentUser ? Colors.white70 : Colors.black54,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              message.fileName ?? 'File',
              style: TextStyle(
                color: isCurrentUser
                    ? Colors.white
                    : (isDarkMode
                        ? AppTheme.darkMessageTextColor
                        : Colors.black87),
              ),
            ),
          ],
        );
      case MessageType.system:
        return Text(
          message.content,
          style: TextStyle(
            color: isCurrentUser
                ? Colors.white70
                : (isDarkMode
                    ? AppTheme.darkMessageTextColor.withValues(alpha: 0.7)
                    : Colors.black54),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        );
      default:
        return Text(
          message.content,
          style: TextStyle(
            color: isCurrentUser
                ? Colors.white
                : (isDarkMode ? AppTheme.darkMessageTextColor : Colors.black87),
          ),
        );
    }
  }

  Widget _buildImageContent(String? imageData) {
    if (imageData == null || imageData.isEmpty) {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[300],
        child: const Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 50,
        ),
      );
    }

    try {
      // Try to decode the base64 string using our improved utility
      final bytes = ImageUtils.safelyDecodeBase64(imageData);

      if (bytes == null) {
        return Container(
          width: 200,
          height: 200,
          color: Colors.grey[300],
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 50,
          ),
        );
      }

      return Image.memory(
        bytes,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error rendering image: $error');
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 50,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error decoding image: $e');
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[300],
        child: const Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 50,
        ),
      );
    }
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
