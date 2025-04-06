import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/notification_model.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/models/chat_model.dart';

class NotificationDrawer extends StatelessWidget {
  final NotificationType? filterType;
  final String title;

  const NotificationDrawer({
    Key? key,
    this.filterType,
    required this.title,
  }) : super(key: key);

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
                  ? const Center(child: Text('No notifications'))
                  : ListView.builder(
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.getColor().withOpacity(0.2),
          child: Icon(notification.getIcon(), color: notification.getColor()),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
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
    );
  }

  void _navigateToNotificationDestination(
      BuildContext context,
      NotificationModel notification,
      ) {
    switch (notification.type) {
      case NotificationType.chat:
        if (notification.relatedId != null) {
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          // Fix the null error by providing a default ChatModel instead of null
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
                chatId: notification.relatedId!,
                chatName: notification.title,
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
                isOwnRequest: notification.additionalData?['isOwnRequest'] == true,
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
      // Navigate to profile screen or specific profile section
        Navigator.of(context).popUntil((route) => route.isFirst);
        Provider.of<NotificationProvider>(context, listen: false).markAsRead(notification.id);
        break;
      case NotificationType.system:
      // Handle system notifications
        Navigator.pop(context);
        break;
    }
  }
}

