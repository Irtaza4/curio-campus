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
    return _notifications.where((notification) => notification.type == type).toList();
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
      _unreadCount = _notifications.where((notification) => !notification.isRead).length;

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
      final index = _notifications.indexWhere((notification) => notification.id == notificationId);
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
      _notifications = _notifications.map((notification) =>
          NotificationModel(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            timestamp: notification.timestamp,
            type: notification.type,
            relatedId: notification.relatedId,
            isRead: true,
            additionalData: notification.additionalData,
          )
      ).toList();

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
      final index = _notifications.indexWhere((notification) => notification.id == notificationId);
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
    if (_auth.currentUser == null) return;

    try {
      final userId = _auth.currentUser!.uid;
      final now = DateTime.now();
      final notificationId = const Uuid().v4();

      // Extract notification data
      final title = data['title'] as String? ?? 'New Notification';
      final message = data['body'] as String? ?? '';
      final type = _parseNotificationType(data['type'] as String? ?? 'system');
      final relatedId = data['relatedId'] as String?;
      final additionalData = data['data'] as Map<String, dynamic>?;

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

      // Save to Firestore
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

// Parse notification type from string
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
}

