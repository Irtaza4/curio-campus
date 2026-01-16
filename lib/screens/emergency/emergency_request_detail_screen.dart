import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/emergency_request_model.dart';
import 'package:curio_campus/providers/emergency_provider.dart';
import 'package:curio_campus/providers/chat_provider.dart';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:curio_campus/screens/emergency/edit_emergency_request_screen.dart';

class EmergencyRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final bool isOwnRequest;

  const EmergencyRequestDetailScreen({
    super.key,
    required this.requestId,
    this.isOwnRequest = false,
  });

  @override
  State<EmergencyRequestDetailScreen> createState() =>
      _EmergencyRequestDetailScreenState();
}

class _EmergencyRequestDetailScreenState
    extends State<EmergencyRequestDetailScreen> {
  bool _isLoading = false;
  EmergencyRequestModel? _request;

  @override
  void initState() {
    super.initState();
    _fetchRequestDetails();
  }

  Future<void> _fetchRequestDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final emergencyProvider =
          Provider.of<EmergencyProvider>(context, listen: false);
      _request =
          await emergencyProvider.fetchEmergencyRequestById(widget.requestId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching request details: $e'),
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

  Future<void> _resolveRequest() async {
    if (_request == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final emergencyProvider =
          Provider.of<EmergencyProvider>(context, listen: false);
      final success =
          await emergencyProvider.resolveEmergencyRequest(_request!.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchRequestDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving request: $e'),
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

  Future<void> _contactRequester() async {
    if (_request == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final chatId = await chatProvider.createChat(
        recipientId: _request!.requesterId,
        recipientName: _request!.requesterName,
      );

      setState(() {
        _isLoading = false;
      });

      if (chatId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              chatName: _request!.requesterName,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editRequest() async {
    if (_request == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEmergencyRequestScreen(request: _request!),
      ),
    );

    if (result == true) {
      _fetchRequestDetails();
    }
  }

  Future<void> _deleteRequest() async {
    if (_request == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
            'Are you sure you want to delete this emergency request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final emergencyProvider =
          Provider.of<EmergencyProvider>(context, listen: false);
      final success =
          await emergencyProvider.deleteEmergencyRequest(_request!.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting request: $e'),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOwnRequest
            ? 'Your Emergency Request'
            : 'Emergency Request'),
        actions: [
          if (widget.isOwnRequest &&
              _request != null &&
              !_request!.isResolved) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editRequest,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteRequest,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _request == null
              ? const Center(child: Text('Request not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request header
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Fix: Add theme-aware card color
                        color: isDarkMode
                            ? Theme.of(context).cardColor
                            : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Requester avatar
                                  _request!.requesterAvatar != null &&
                                          _request!.requesterAvatar!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: _request!.requesterAvatar!,
                                          imageBuilder:
                                              (context, imageProvider) =>
                                                  CircleAvatar(
                                            radius: 30,
                                            backgroundImage: imageProvider,
                                          ),
                                          placeholder: (context, url) =>
                                              CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                AppTheme.lightGrayColor,
                                            child: CircularProgressIndicator(
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                AppTheme.primaryColor,
                                            child: Text(
                                              _request!.requesterName[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                              ),
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 30,
                                          backgroundColor:
                                              AppTheme.primaryColor,
                                          child: Text(
                                            _request!.requesterName[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                            ),
                                          ),
                                        ),
                                  const SizedBox(width: 16),

                                  // Requester info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.isOwnRequest
                                              ? 'Your Request'
                                              : _request!.requesterName,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            // Fix: Use theme-aware color for name
                                            color: widget.isOwnRequest
                                                ? AppTheme.primaryColor
                                                : (isDarkMode
                                                    ? Colors.white
                                                    : Colors.black),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              // Fix: Use theme-aware icon color
                                              color: isDarkMode
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Posted ${DateFormat('MMM d, h:mm a').format(_request!.createdAt)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                // Fix: Use theme-aware text color
                                                color: isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Request title
                              Text(
                                _request!.title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  // Fix: Use theme-aware text color
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Request description
                              Text(
                                _request!.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  // Fix: Use theme-aware text color
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Deadline
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getDeadlineColor(_request!.deadline),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timer,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Deadline: ${DateFormat('MMM d, h:mm a').format(_request!.deadline)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Status
                              if (_request!.isResolved) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Resolved',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Required skills
                      const Text(
                        'Required Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _request!.requiredSkills.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              skill,
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      if (!_request!.isResolved) ...[
                        if (widget.isOwnRequest) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _editRequest,
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Request'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _resolveRequest,
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Mark as Resolved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _contactRequester,
                                  icon: const Icon(Icons.chat,
                                      color: Colors.white),
                                  label: const Text('Contact Requester'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _resolveRequest,
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
                                  label: const Text('Mark as Resolved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        if (!widget.isOwnRequest) ...[
                          ElevatedButton.icon(
                            onPressed: _contactRequester,
                            icon: const Icon(
                              Icons.chat,
                              color: Colors.white,
                            ),
                            label: const Text('Contact Requester'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }

  Color _getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inHours;

    if (difference < 0) {
      return Colors.red;
    } else if (difference < 24) {
      return Colors.orange;
    } else {
      return AppTheme.primaryColor;
    }
  }
}
