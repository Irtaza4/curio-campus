import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/models/message_model.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';
import 'dart:async';
import 'package:curio_campus/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentChatId;


  // For real-time updates
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _chatsSubscription;

  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentChatId => _currentChatId;

  // Setup real-time listener for messages
  void setupMessageListener({
    required String chatId,
    required Function onNewMessage,
  }) {
    // Cancel any existing subscription
    _messagesSubscription?.cancel();

    // Set up a new subscription
    _messagesSubscription = _firestore
        .collection(Constants.chatsCollection)
        .doc(chatId)
        .collection(Constants.messagesCollection)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      // Process new messages
      final newMessages = snapshot.docs
          .map((doc) => MessageModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Update the messages list
      _messages = newMessages;

      // Mark messages as read
      _markMessagesAsRead(chatId);

      // Notify listeners
      notifyListeners();

      // Call the callback
      onNewMessage();
    });
  }

  // Setup real-time listener for chats
  void setupChatsListener() {
    // Cancel any existing subscription
    _chatsSubscription?.cancel();

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Set up a new subscription
    _chatsSubscription = _firestore
        .collection(Constants.chatsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
      // Process chats
      final newChats = snapshot.docs
          .map((doc) => ChatModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Sort in memory
      newChats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      // Update the chats list
      _chats = newChats;

      // Notify listeners
      notifyListeners();
    });
  }

  // Remove the real-time listeners
  void removeListeners() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;

    _chatsSubscription?.cancel();
    _chatsSubscription = null;
  }

  // Mark messages as read
  Future<void> _markMessagesAsRead(String chatId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();
    bool hasUnreadMessages = false;

    for (final message in _messages) {
      if (!message.isRead && message.senderId != userId) {
        final messageRef = _firestore
            .collection(Constants.chatsCollection)
            .doc(chatId)
            .collection(Constants.messagesCollection)
            .doc(message.id);

        batch.update(messageRef, {'isRead': true});
        hasUnreadMessages = true;
      }
    }

    if (hasUnreadMessages) {
      await batch.commit();
    }
  }

  Future<void> fetchChats() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      // Set up real-time listener for chats
      setupChatsListener();

      // Initial fetch
      final querySnapshot = await _firestore
          .collection(Constants.chatsCollection)
          .where('participants', arrayContains: userId)
          .get();

      _chats = querySnapshot.docs
          .map((doc) => ChatModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Sort in memory instead of in the query
      _chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchMessages(String chatId) async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    _currentChatId = chatId;
    notifyListeners();

    try {
      // Set up real-time listener for messages
      setupMessageListener(
        chatId: chatId,
        onNewMessage: () {
          // This will be called when new messages arrive
        },
      );

      // Initial fetch
      final querySnapshot = await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      _messages = querySnapshot.docs
          .map((doc) => MessageModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      }))
          .toList();

      // Mark messages as read
      await _markMessagesAsRead(chatId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Delete a message
  Future<void> deleteMessage(String chatId, String messageId) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      // Find the message to check if the current user is the sender
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex == -1) return;

      final message = _messages[messageIndex];

      // Only allow the sender to delete their own messages
      if (message.senderId != userId) {
        _errorMessage = 'You can only delete your own messages';
        notifyListeners();
        return;
      }

      // Delete the message from Firestore
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .doc(messageId)
          .delete();

      // Remove from local list
      _messages.removeAt(messageIndex);

      // Update the last message in the chat if this was the last message
      if (messageIndex == 0 && _messages.isNotEmpty) {
        final newLastMessage = _messages.first;
        await _firestore
            .collection(Constants.chatsCollection)
            .doc(chatId)
            .update({
          'lastMessageContent': newLastMessage.content,
          'lastMessageSenderId': newLastMessage.senderId,
          'lastMessageAt': newLastMessage.timestamp.toIso8601String(),
        });
      } else if (_messages.isEmpty) {
        // If there are no more messages, update with empty values
        await _firestore
            .collection(Constants.chatsCollection)
            .doc(chatId)
            .update({
          'lastMessageContent': null,
          'lastMessageSenderId': null,
          'lastMessageAt': DateTime.now().toIso8601String(),
        });
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      // Fetch all users from Firestore (adjust the query as needed)
      final querySnapshot = await _firestore
          .collection(Constants.usersCollection)
          .get();

      // Map the fetched data into a list of UserModel objects
      final users = querySnapshot.docs.map((doc) {
        return UserModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();

      return users;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  // Send a voice message
  Future<void> sendVoiceMessage({
    required String chatId,
    required String audioBase64,
    required int duration,
    BuildContext? context,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String;
      final userAvatar = userData['profileImageUrl'] as String?;

      final now = DateTime.now();
      final messageId = const Uuid().v4();

      // Ensure the audio data is properly formatted
      String formattedAudio = audioBase64;
      if (formattedAudio.startsWith('/')) {
        formattedAudio = formattedAudio.substring(1);
      }

      final message = MessageModel(
        id: messageId,
        senderId: userId,
        senderName: userName,
        senderAvatar: userAvatar,
        chatId: chatId,
        content: 'Voice message',
        type: MessageType.audio,
        timestamp: now,
        fileUrl: formattedAudio,
        duration: duration,
      );

      // Add message to local list immediately for instant feedback
      _messages.insert(0, message);
      notifyListeners();

      // Add message to chat
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .doc(messageId)
          .set(message.toJson());

      // Update chat with last message info
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .update({
        'lastMessageContent': 'Voice message',
        'lastMessageSenderId': userId,
        'lastMessageAt': now.toIso8601String(),
      });

      // Notify other participants
      _notifyParticipants(chatId, userId, userName, 'Voice message', context);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Helper method to notify participants
  Future<void> _notifyParticipants(
      String chatId,
      String senderId,
      String senderName,
      String content,
      BuildContext? context
      ) async {
    try {
      // Get chat details to create notification
      final chatDoc = await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final chatName = chatData['name'] as String;
        final participants = List<String>.from(chatData['participants'] ?? []);

        // Create notification for each participant except the sender
        for (final participantId in participants) {
          if (participantId != senderId) {
            // Create a new notification
            final notificationId = const Uuid().v4();

            await _firestore
                .collection(Constants.usersCollection)
                .doc(participantId)
                .collection('notifications')
                .doc(notificationId)
                .set({
              'id': notificationId,
              'title': 'New message from $senderName',
              'message': content,
              'timestamp': DateTime.now().toIso8601String(),
              'type': 'chat',
              'relatedId': chatId,
              'isRead': false,
              'additionalData': {
                'senderId': senderId,
                'senderName': senderName,
                'chatName': chatName
              },
            });

            // If context is provided, also update the notification provider
            if (context != null) {
              try {
                final notificationProvider = Provider.of<NotificationProvider>(
                  context,
                  listen: false,
                );

                await notificationProvider.createMessageNotification(
                  senderId: senderId,
                  senderName: senderName,
                  chatId: chatId,
                  chatName: chatName,
                  message: content,
                );
              } catch (e) {
                debugPrint('Error updating notification provider: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error notifying participants: $e');
    }
  }

  // Enhance the sendMessage method to trigger a notification
  Future<void> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? fileUrl,
    String? fileName,
    int? duration,
    BuildContext? context,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String;
      final userAvatar = userData['profileImageUrl'] as String?;

      final now = DateTime.now();
      final messageId = const Uuid().v4();

      final message = MessageModel(
        id: messageId,
        senderId: userId,
        senderName: userName,
        senderAvatar: userAvatar,
        chatId: chatId,
        content: content,
        type: type,
        timestamp: now,
        fileUrl: fileUrl,
        fileName: fileName,
        duration: duration,
      );

      // Add message to local list immediately for instant feedback
      _messages.insert(0, message);
      notifyListeners();

      // Add message to chat
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .doc(messageId)
          .set(message.toJson());

      // Update chat with last message info
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .update({
        'lastMessageContent': content,
        'lastMessageSenderId': userId,
        'lastMessageAt': now.toIso8601String(),
      });

      // Notify other participants
      _notifyParticipants(chatId, userId, userName, content, context);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<String?> createChat({
    required String recipientId,
    required String recipientName,
    ChatType type = ChatType.individual,
  }) async {
    if (_auth.currentUser == null) return null;

    try {
      final userId = _auth.currentUser!.uid;

      // Check if chat already exists
      final querySnapshot = await _firestore
          .collection(Constants.chatsCollection)
          .where('participants', arrayContains: userId)
          .get();

      for (final doc in querySnapshot.docs) {
        final chat = ChatModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });

        if (chat.type == ChatType.individual &&
            chat.participants.contains(recipientId)) {
          return chat.id;
        }
      }

      // Create new chat
      final now = DateTime.now();
      final chatId = const Uuid().v4();

      // For individual chats, use the recipient's name as the chat name
      final chatName = type == ChatType.individual ? recipientName : recipientName;

      final chat = ChatModel(
        id: chatId,
        name: chatName,
        participants: [userId, recipientId],
        type: type,
        createdAt: now,
        lastMessageAt: now,
      );

      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .set(chat.toJson());

      // Add chat to local list
      _chats.insert(0, chat);
      notifyListeners();

      return chatId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Updated to include creatorId
  Future<String?> createGroupChat({
    required String name,
    required List<String> participants,
    String? groupImageUrl,
  }) async {
    if (_auth.currentUser == null) return null;

    try {
      final userId = _auth.currentUser!.uid;

      // Ensure current user is in participants
      if (!participants.contains(userId)) {
        participants.add(userId);
      }

      // Create new chat
      final now = DateTime.now();
      final chatId = const Uuid().v4();

      final chat = ChatModel(
        id: chatId,
        name: name,
        participants: participants,
        type: ChatType.group,
        createdAt: now,
        lastMessageAt: now,
        groupImageUrl: groupImageUrl,
        creatorId: userId, // Set the creator ID to the current user
      );

      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .set(chat.toJson());

      // Add chat to local list
      _chats.insert(0, chat);
      notifyListeners();

      return chatId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // New method to update a group chat
  Future<void> updateGroupChat({
    required String chatId,
    required String name,
    String? groupImageBase64,
    required List<String> participants,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      // Ensure current user is in participants
      if (!participants.contains(userId)) {
        participants.add(userId);
      }

      // Update the chat document
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .update({
        'name': name,
        'participants': participants,
        if (groupImageBase64 != null) 'groupImageUrl': groupImageBase64,
      });

      // Update the local chat list
      final index = _chats.indexWhere((chat) => chat.id == chatId);
      if (index != -1) {
        final updatedChat = ChatModel(
          id: _chats[index].id,
          name: name,
          participants: participants,
          type: _chats[index].type,
          createdAt: _chats[index].createdAt,
          lastMessageAt: _chats[index].lastMessageAt,
          lastMessageContent: _chats[index].lastMessageContent,
          lastMessageSenderId: _chats[index].lastMessageSenderId,
          groupImageUrl: groupImageBase64 ?? _chats[index].groupImageUrl,
          creatorId: _chats[index].creatorId,
        );

        _chats[index] = updatedChat;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      throw e;
    }
  }

  // New method to get chat details
  Future<ChatModel?> getChatDetails(String chatId) async {
    try {
      final docSnapshot = await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .get();

      if (docSnapshot.exists) {
        return ChatModel.fromJson({
          'id': docSnapshot.id,
          ...docSnapshot.data()!,
        });
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteChat(String chatId) async {
    if (_auth.currentUser == null) return;

    try {
      // Delete all messages in the chat
      final messagesSnapshot = await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .get();

      final batch = _firestore.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(_firestore.collection(Constants.chatsCollection).doc(chatId));

      await batch.commit();

      // Remove chat from local list
      _chats.removeWhere((chat) => chat.id == chatId);

      if (_currentChatId == chatId) {
        _currentChatId = null;
        _messages = [];
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  bool isMessageRead(String chatId, String messageId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    // Find the message in the messages list
    final message = _messages.firstWhere(
          (m) => m.id == messageId,
      orElse: () => MessageModel(
        id: '',
        senderId: '',
        senderName: '',
        chatId: '',
        content: '',
        type: MessageType.text,
        timestamp: DateTime.now(),
      ),
    );

    // If the message is sent by the current user, it's considered read
    if (message.senderId == userId) return true;

    // Otherwise, check the isRead property
    return message.isRead;
  }

  Future<void> sendImageMessage({
    required String chatId,
    String? imageUrl,
    String? imageBase64,
    required String fileName,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String;
      final userAvatar = userData['profileImageUrl'] as String?;

      final now = DateTime.now();
      final messageId = const Uuid().v4();

      // Use either the URL or base64 string
      final fileData = imageBase64 ?? imageUrl;

      final message = MessageModel(
        id: messageId,
        senderId: userId,
        senderName: userName,
        senderAvatar: userAvatar,
        chatId: chatId,
        content: 'Sent an image',
        type: MessageType.image,
        timestamp: now,
        fileUrl: fileData,
        fileName: fileName,
      );

      // Add message to local list immediately for instant feedback
      _messages.insert(0, message);
      notifyListeners();

      // Add message to chat
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .doc(messageId)
          .set(message.toJson());

      // Update chat with last message info
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .update({
        'lastMessageContent': 'Sent an image',
        'lastMessageSenderId': userId,
        'lastMessageAt': now.toIso8601String(),
      });
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
// Add this method to send call event messages
  Future<void> sendCallEventMessage({
    required String chatId,
    required String callType,
    required String status,
    int? duration,
    required bool isOutgoing,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] as String;
      final userAvatar = userData['profileImageUrl'] as String?;

      final now = DateTime.now();
      final messageId = const Uuid().v4();

      // Create content based on call type and status
      String content = '${callType == 'video' ? 'Video' : 'Voice'} call ';
      if (status == 'missed') {
        content += 'missed';
      } else if (status == 'declined') {
        content += 'declined';
      } else if (status == 'ended' && (duration == null || duration == 0)) {
        content += 'missed';
      } else if (status == 'failed') {
        content += 'failed';
      } else {
        content += isOutgoing ? 'outgoing' : 'incoming';
      }

      final message = MessageModel(
        id: messageId,
        senderId: userId,
        senderName: userName,
        senderAvatar: userAvatar,
        chatId: chatId,
        content: content,
        type: MessageType.call_event,
        timestamp: now,
        duration: duration,
        fileUrl: callType, // Store call type in fileUrl field
      );

      // Add message to local list immediately for instant feedback
      _messages.insert(0, message);
      notifyListeners();

      // Add message to chat
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .collection(Constants.messagesCollection)
          .doc(messageId)
          .set(message.toJson());

      // Update chat with last message info
      await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .update({
        'lastMessageContent': content,
        'lastMessageSenderId': userId,
        'lastMessageAt': now.toIso8601String(),
        'lastMessageType': 'call_event', // Add message type for better UI handling
      });

      // Send a notification to the other user about the call event
      final otherParticipants = (await _firestore
          .collection(Constants.chatsCollection)
          .doc(chatId)
          .get())
          .data()?['participants'] as List<dynamic>?;

      if (otherParticipants != null) {
        for (final participantId in otherParticipants) {
          if (participantId != userId) {
            // Get the participant's FCM token
            final participantDoc = await _firestore
                .collection(Constants.usersCollection)
                .doc(participantId as String)
                .get();

            if (participantDoc.exists) {
              final fcmToken = participantDoc.data()?['fcmToken'] as String?;
              if (fcmToken != null && fcmToken.isNotEmpty) {
                // Send a notification about the call event
                // This would typically be done via a Cloud Function
                debugPrint('Would send call event notification to $participantId with token $fcmToken');
              }
            }
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

// Add a method to fetch call history
  Future<List<MessageModel>> fetchCallHistory() async {
    if (_auth.currentUser == null) return [];

    try {
      final userId = _auth.currentUser!.uid;

      // Get all chats where the user is a participant
      final chatDocs = await _firestore
          .collection(Constants.chatsCollection)
          .where('participants', arrayContains: userId)
          .get();

      List<MessageModel> callMessages = [];

      // For each chat, get call event messages
      for (final chatDoc in chatDocs.docs) {
        final chatId = chatDoc.id;

        final messageDocs = await _firestore
            .collection(Constants.chatsCollection)
            .doc(chatId)
            .collection(Constants.messagesCollection)
            .where('type', isEqualTo: 'call_event')
            .orderBy('timestamp', descending: true)
            .limit(20) // Limit to recent calls
            .get();

        for (final messageDoc in messageDocs.docs) {
          final messageData = messageDoc.data();
          callMessages.add(MessageModel.fromJson(messageData));
        }
      }

      // Sort by timestamp (most recent first)
      callMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return callMessages;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  bool isChatRead(String chatId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    // Find the chat in the chats list
    final chat = _chats.firstWhere(
          (c) => c.id == chatId,
      orElse: () => ChatModel(
        id: '',
        name: '',
        participants: [],
        type: ChatType.individual,
        createdAt: DateTime.now(),
        lastMessageAt: DateTime.now(),
      ),
    );

    // If the last message is sent by the current user, it's considered read
    if (chat.lastMessageSenderId == userId) return true;

    // Otherwise, check if there are any unread messages in this chat
    // For simplicity, we'll just use the lastMessageSenderId
    return chat.lastMessageSenderId == null;
  }
}
