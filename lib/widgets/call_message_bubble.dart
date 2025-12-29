import 'package:flutter/material.dart';

import 'package:curio_campus/utils/app_theme.dart';

class CallMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;

  const CallMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final callType = message['callType'] == 'video' ? 'Video' : 'Voice';
    final status = message['status'] ?? 'unknown';
    final duration = message['duration'] ?? 0;
    final isOutgoing = message['isOutgoing'] ?? isCurrentUser;

    // Format the duration
    String durationString = '';
    if (duration > 0) {
      final minutes = (duration / 60).floor();
      final seconds = duration % 60;
      durationString = minutes > 0
          ? '$minutes min ${seconds > 0 ? '$seconds sec' : ''}'
          : '$seconds sec';
    }

    // Determine the icon and text based on call status
    IconData icon;
    String statusText;
    Color iconColor;

    switch (status) {
      case 'ended':
        if (duration > 0) {
          icon = Icons.call;
          statusText = isOutgoing ? 'Outgoing call' : 'Incoming call';
          iconColor = Colors.green;
        } else {
          icon = isOutgoing ? Icons.call_made : Icons.call_received;
          statusText = 'Missed call';
          iconColor = Colors.red;
        }
        break;
      case 'missed':
        icon = isOutgoing ? Icons.call_made : Icons.call_received;
        statusText = 'Missed call';
        iconColor = Colors.red;
        break;
      case 'declined':
        icon = isOutgoing ? Icons.call_made : Icons.call_received;
        statusText = 'Call declined';
        iconColor = Colors.orange;
        break;
      default:
        icon = isOutgoing ? Icons.call_made : Icons.call_received;
        statusText = 'Call';
        iconColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$callType call',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isCurrentUser
                      ? Colors.white
                      : (isDarkMode
                          ? AppTheme.darkMessageTextColor
                          : Colors.black87),
                ),
              ),
              Row(
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Colors.white70
                          : (isDarkMode
                              ? AppTheme.darkMessageTextColor
                                  .withValues(alpha: 0.7)
                              : Colors.grey[600]),
                      fontSize: 12,
                    ),
                  ),
                  if (duration > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '• $durationString',
                      style: TextStyle(
                        color: isCurrentUser
                            ? Colors.white70
                            : (isDarkMode
                                ? AppTheme.darkMessageTextColor
                                    .withValues(alpha: 0.7)
                                : Colors.grey[600]),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
