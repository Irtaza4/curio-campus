import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:curio_campus/models/notification_model.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:uuid/uuid.dart';

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  // Get notifications filtered by type
  List<NotificationModel> getNotificationsByType(NotificationType type) {
    return _notifications
        .where((notification) => notification.type == type)
        .toList();
  }

  // Fetch notifications from Firestore
  Future<void> fetchNotifications() async {
    if (_auth.currentUser == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _auth.currentUser!.uid;

      final querySnapshot = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      _notifications = querySnapshot.docs
          .map((doc) => NotificationModel.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();

      // Count unread notifications
      _unreadCount =
          _notifications.where((notification) => !notification.isRead).length;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Add a new notification
  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? relatedId,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final now = DateTime.now();
      final notificationId = const Uuid().v4();

      // Check if a similar notification already exists to prevent duplication
      if (relatedId != null) {
        final existingNotifications = await _firestore
            .collection(Constants.usersCollection)
            .doc(userId)
            .collection('notifications')
            .where('relatedId', isEqualTo: relatedId)
            .where('type', isEqualTo: type.toString().split('.').last)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        // If a similar notification exists and was created in the last 5 minutes, don't create a new one
        if (existingNotifications.docs.isNotEmpty) {
          final latestNotification = existingNotifications.docs.first;
          final latestTimestamp =
              DateTime.parse(latestNotification.data()['timestamp'] as String);

          if (now.difference(latestTimestamp).inMinutes < 5) {
            // Just update the existing notification to mark it as unread
            await _firestore
                .collection(Constants.usersCollection)
                .doc(userId)
                .collection('notifications')
                .doc(latestNotification.id)
                .update({
              'isRead': false,
              'timestamp': now.toIso8601String(),
              'message': message, // Update the message in case it changed
            });

            // Update local list if the notification exists there
            final index =
                _notifications.indexWhere((n) => n.id == latestNotification.id);
            if (index != -1) {
              _notifications[index] = NotificationModel(
                id: latestNotification.id,
                title: title,
                message: message,
                timestamp: now,
                type: type,
                relatedId: relatedId,
                isRead: false,
                additionalData: additionalData,
              );

              // If it was previously read, increment unread count
              if (_notifications[index].isRead) {
                _unreadCount++;
              }
            }

            notifyListeners();
            return;
          }
        }
      }

      // Create a new notification if no similar recent one exists
      final notification = NotificationModel(
        id: notificationId,
        title: title,
        message: message,
        timestamp: now,
        type: type,
        relatedId: relatedId,
        isRead: false,
        additionalData: additionalData,
      );

      await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .set(notification.toJson());

      // Add to local list
      _notifications.insert(0, notification);
      _unreadCount++;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      // Update local list
      final index = _notifications
          .indexWhere((notification) => notification.id == notificationId);
      if (index != -1) {
        final notification = _notifications[index];
        if (!notification.isRead) {
          _notifications[index] = NotificationModel(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            timestamp: notification.timestamp,
            type: notification.type,
            relatedId: notification.relatedId,
            isRead: true,
            additionalData: notification.additionalData,
          );
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      // Get all unread notifications
      final querySnapshot = await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      // Create a batch to update all at once
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // Update local list
      _notifications = _notifications
          .map((notification) => NotificationModel(
                id: notification.id,
                title: notification.title,
                message: notification.message,
                timestamp: notification.timestamp,
                type: notification.type,
                relatedId: notification.relatedId,
                isRead: true,
                additionalData: notification.additionalData,
              ))
          .toList();

      _unreadCount = 0;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      // Update local list
      final index = _notifications
          .indexWhere((notification) => notification.id == notificationId);
      if (index != -1) {
        final wasUnread = !_notifications[index].isRead;
        _notifications.removeAt(index);
        if (wasUnread) {
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Add sample notifications for testing
  Future<void> addSampleNotifications() async {
    if (_auth.currentUser == null) return;

    await addNotification(
      title: 'New message',
      message: 'John sent you a message: "Hey, how\'s it going?"',
      type: NotificationType.chat,
      relatedId: 'chat123',
    );

    await addNotification(
      title: 'Emergency request',
      message: 'Sarah needs help with Flutter project',
      type: NotificationType.emergency,
      relatedId: 'emergency456',
    );

    await addNotification(
      title: 'Project deadline',
      message: 'Mobile App UI Design due tomorrow',
      type: NotificationType.project,
      relatedId: 'project789',
    );

    await addNotification(
      title: 'Profile viewed',
      message: 'Emma viewed your profile',
      type: NotificationType.profile,
    );
  }

// Update the notification provider to handle real notifications instead of dummy data
// Add these methods to handle real-time notifications

// Method to handle incoming notifications from Firebase Cloud Messaging
  Future<void> handleIncomingNotification(Map<String, dynamic> data) async {
    try {
      // Extract notification data
      final title = data['title'] as String? ?? 'New Notification';
      final message = data['body'] as String? ?? '';
      final type = _parseNotificationType(data['type'] as String? ?? 'system');
      final relatedId = data['relatedId'] as String?;

      // Add notification using the existing method
      await addNotification(
        title: title,
        message: message,
        type: type,
        relatedId: relatedId,
        additionalData: data,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Helper method to parse notification type
  NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'chat':
        return NotificationType.chat;
      case 'emergency':
        return NotificationType.emergency;
      case 'project':
        return NotificationType.project;
      case 'profile':
        return NotificationType.profile;
      default:
        return NotificationType.system;
    }
  }

// Method to create a real notification when a message is received
  Future<void> createMessageNotification({
    required String senderId,
    required String senderName,
    required String chatId,
    required String chatName,
    required String message,
  }) async {
    if (_auth.currentUser == null) return;

    final userId = _auth.currentUser!.uid;

    // Don't create notification for messages sent by the current user
    if (senderId == userId) return;

    await addNotification(
      title: 'New message from $senderName',
      message: message,
      type: NotificationType.chat,
      relatedId: chatId,
      additionalData: {
        'senderId': senderId,
        'senderName': senderName,
        'chatName': chatName
      },
    );
  }

// Method to create a real notification when a project is updated
  Future<void> createProjectNotification({
    required String projectId,
    required String projectName,
    required String title,
    required String message,
  }) async {
    await addNotification(
      title: title,
      message: message,
      type: NotificationType.project,
      relatedId: projectId,
      additionalData: {
        'projectName': projectName,
      },
    );
  }

// Method to create a real notification when an emergency request is created
  Future<void> createEmergencyNotification({
    required String requestId,
    required String requesterName,
    required String title,
    required String message,
    required bool isOwnRequest,
  }) async {
    await addNotification(
      title: title,
      message: message,
      type: NotificationType.emergency,
      relatedId: requestId,
      additionalData: {
        'requesterName': requesterName,
        'isOwnRequest': isOwnRequest,
      },
    );
  }

// Add methods to handle chat request notifications and project/emergency notifications

// Method to create a chat request notification
  Future<void> createChatRequestNotification({
    required String senderId,
    required String senderName,
    required String chatId,
    required String message,
  }) async {
    if (_auth.currentUser == null) return;

    await addNotification(
      title: 'New chat request from $senderName',
      message: message,
      type: NotificationType.chat,
      relatedId: chatId,
      additionalData: {
        'senderId': senderId,
        'senderName': senderName,
        'isRequest': true,
        'chatId': chatId
      },
    );
  }

// Method to create a task completion notification
  Future<void> createTaskCompletionNotification({
    required String projectId,
    required String projectName,
    required String taskTitle,
    required String completedBy,
  }) async {
    await addNotification(
      title: 'Task Completed in $projectName',
      message: '$completedBy completed the task: $taskTitle',
      type: NotificationType.project,
      relatedId: projectId,
      additionalData: {
        'projectName': projectName,
        'taskTitle': taskTitle,
        'completedBy': completedBy,
        'isTaskCompletion': true
      },
    );
  }

// Method to create a skill-matched emergency request notification
  Future<void> createSkillMatchedEmergencyNotification({
    required String requestId,
    required String requesterName,
    required String title,
    required String skill,
  }) async {
    await addNotification(
      title: 'Emergency Request Matching Your Skills',
      message: '$requesterName needs help with $skill: $title',
      type: NotificationType.emergency,
      relatedId: requestId,
      additionalData: {
        'requesterName': requesterName,
        'skill': skill,
        'isSkillMatch': true
      },
    );
  }

// Method to accept a chat request
  Future<void> acceptChatRequest(String notificationId) async {
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;

      // Find the notification
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index == -1) return;

      final notification = _notifications[index];
      final additionalData = notification.additionalData;
      if (additionalData == null) return;

      final senderId = additionalData['senderId'] as String?;
      final senderName = additionalData['senderName'] as String?;
      final chatId = additionalData['chatId'] as String?;

      if (senderId == null || senderName == null || chatId == null) return;

      // Mark the notification as read
      await markAsRead(notificationId);

      // Update the notification to show it was accepted
      await _firestore
          .collection(Constants.usersCollection)
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'additionalData.accepted': true,
      });

      // Update local notification
      _notifications[index] = NotificationModel(
        id: notification.id,
        title: notification.title,
        message: notification.message,
        timestamp: notification.timestamp,
        type: notification.type,
        relatedId: notification.relatedId,
        isRead: true,
        additionalData: {
          ...additionalData,
          'accepted': true,
        },
      );

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

// Method to reject a chat request
  Future<void> rejectChatRequest(String notificationId) async {
    if (_auth.currentUser == null) return;

    try {
      // Find the notification
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index == -1) return;

      // Delete the notification
      await deleteNotification(notificationId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
