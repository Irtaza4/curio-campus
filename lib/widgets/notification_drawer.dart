import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/notification_model.dart';
import 'package:curio_campus/providers/notification_provider.dart';

import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/models/chat_model.dart';

import '../services/call_service.dart';

class NotificationDrawer extends StatelessWidget {
  final NotificationType? filterType;
  final String title;

  const NotificationDrawer({
    super.key,
    this.filterType,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final notifications = filterType != null
        ? notificationProvider.getNotificationsByType(filterType!)
        : notificationProvider.notifications;

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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await notificationProvider.markAllAsRead();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('All notifications marked as read'),
                            ),
                          );
                        }
                      },
                      child: const Text('Mark all as read'),
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: notificationProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : notifications.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () =>
                              notificationProvider.fetchNotifications(),
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return _buildNotificationItem(
                                context,
                                notification,
                                notificationProvider,
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    NotificationModel notification,
    NotificationProvider notificationProvider,
  ) {
    // Check if this is a chat request notification
    final additionalData = notification.additionalData;
    final bool isChatRequest = additionalData != null &&
        additionalData['isRequest'] == true &&
        additionalData['accepted'] != true;

    // Check if this is a task completion notification
    final bool isTaskCompletion =
        additionalData != null && additionalData['isTaskCompletion'] == true;

    // Check if this is a skill-matched emergency notification
    final bool isSkillMatch =
        additionalData != null && additionalData['isSkillMatch'] == true;

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        notificationProvider.deleteNotification(notification.id);
      },
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: notification.getColor().withValues(alpha: 0.2),
              child:
                  Icon(notification.getIcon(), color: notification.getColor()),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight:
                    notification.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Text(notification.message),
            trailing: Text(
              notification.getTimeAgo(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            onTap: () async {
              // Mark as read
              if (!notification.isRead) {
                await notificationProvider.markAsRead(notification.id);
              }

              // Navigate based on notification type
              if (context.mounted) {
                Navigator.pop(context); // Close the drawer
                _navigateToNotificationDestination(context, notification);
              }
            },
          ),

          // Show accept/reject buttons for chat requests
          if (isChatRequest)
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await notificationProvider
                          .acceptChatRequest(notification.id);
                      if (context.mounted) {
                        Navigator.pop(context); // Close the drawer
                        _navigateToNotificationDestination(
                            context, notification);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await notificationProvider
                          .rejectChatRequest(notification.id);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ),

          // Show additional info for task completions
          if (isTaskCompletion)
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Task completed',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Show additional info for skill-matched emergency requests
          if (isSkillMatch)
            Padding(
              padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.priority_high, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Matches your skills',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToNotificationDestination(
    BuildContext context,
    NotificationModel notification,
  ) {
    switch (notification.type) {
      case NotificationType.chat:
        if (notification.relatedId != null) {
          final chatProvider =
              Provider.of<ChatProvider>(context, listen: false);
          final chat = chatProvider.chats.firstWhere(
            (chat) => chat.id == notification.relatedId,
            orElse: () => ChatModel(
              id: notification.relatedId!,
              name: notification.title,
              participants: [],
              type: ChatType.individual,
              createdAt: DateTime.now(),
              lastMessageAt: DateTime.now(),
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chat.id,
                chatName: chat.name,
              ),
            ),
          );
        }
        break;

      case NotificationType.emergency:
        if (notification.relatedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmergencyRequestDetailScreen(
                requestId: notification.relatedId!,
                isOwnRequest:
                    notification.additionalData?['isOwnRequest'] == true,
              ),
            ),
          );
        }
        break;

      case NotificationType.project:
        if (notification.relatedId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(
                projectId: notification.relatedId!,
              ),
            ),
          );
        }
        break;

      case NotificationType.profile:
        Navigator.of(context).popUntil((route) => route.isFirst);
        Provider.of<NotificationProvider>(context, listen: false)
            .markAsRead(notification.id);
        break;

      case NotificationType.system:
        Navigator.pop(context);
        break;

      case NotificationType.call:
        // ✅ Fix: handle call notification using CallService
        if (notification.additionalData != null &&
            notification.relatedId != null) {
          final callService = CallService();
          callService.handleIncomingCallFromNotification(
            callId: notification.relatedId!,
            callerId: notification.additionalData?['callerId'] ?? '',
            callerName: notification.additionalData?['callerName'] ?? 'Unknown',
            isVideoCall: notification.additionalData?['callType'] == 'video',
            callerProfileImage: notification.additionalData?['callerImage'],
          );
        } else {
          debugPrint('Call notification missing required data.');
        }
        break;
    }
  }
}
