import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:curio_campus/models/chat_model.dart';
import 'package:curio_campus/models/message_model.dart';
import 'package:curio_campus/models/user_model.dart';
import 'package:curio_campus/utils/constants.dart';
import 'dart:async';

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

  // Remove the real-time listener
  void removeMessageListener() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
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

      // Set up a real-time listener for chats
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

  Future<void> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? fileUrl,
    String? fileName,
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
      );

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

      // The message will be added to the local list via the real-time listener
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

      final chat = ChatModel(
        id: chatId,
        name: recipientName,
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
    required String imageUrl,
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

      final message = MessageModel(
        id: messageId,
        senderId: userId,
        senderName: userName,
        senderAvatar: userAvatar,
        chatId: chatId,
        content: 'Sent an image',
        type: MessageType.image,
        timestamp: now,
        fileUrl: imageUrl,
        fileName: fileName,
      );

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

      // The message will be added to the local list via the real-time listener
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
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

