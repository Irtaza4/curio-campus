import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/models/emergency_request_model.dart';
import 'package:curio_campus/providers/emergency_provider.dart';
import 'package:curio_campus/screens/emergency/create_emergency_request_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/emergency/edit_emergency_request_screen.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/widgets/notification_badge.dart';
import 'package:curio_campus/widgets/notification_drawer.dart';
import 'package:curio_campus/models/notification_model.dart';

import '../../utils/image_utils.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Use Future.microtask to schedule the fetch after the build is complete
    Future.microtask(() {
      _fetchAllEmergencyRequests();
      _fetchMyEmergencyRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllEmergencyRequests() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<EmergencyProvider>(context, listen: false)
          .fetchEmergencyRequests();
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching emergency requests: ${e.toString()}'),
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

  Future<void> _fetchMyEmergencyRequests() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<EmergencyProvider>(context, listen: false)
          .fetchMyEmergencyRequests();
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching your emergency requests: ${e.toString()}'),
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

  void _navigateToCreateEmergencyRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateEmergencyRequestScreen(),
      ),
    ).then((_) {
      // Refresh both tabs when returning from create screen
      _fetchAllEmergencyRequests();
      _fetchMyEmergencyRequests();
    });
  }

  void _navigateToEditEmergencyRequest(EmergencyRequestModel request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEmergencyRequestScreen(request: request),
      ),
    ).then((_) {
      // Refresh both tabs when returning from edit screen
      _fetchAllEmergencyRequests();
      _fetchMyEmergencyRequests();
    });
  }

  Future<void> _ignoreRequest(String requestId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<EmergencyProvider>(context, listen: false)
          .ignoreEmergencyRequest(requestId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request moved to ignored list'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ignoring request: ${e.toString()}'),
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

  Future<void> _unignoreRequest(String requestId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<EmergencyProvider>(context, listen: false)
          .unignoreEmergencyRequest(requestId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request moved back to active list'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unignoring request: ${e.toString()}'),
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

  Future<void> _deleteRequest(EmergencyRequestModel request) async {
    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: Text('Are you sure you want to delete "${request.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // If user canceled, do nothing
    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await Provider.of<EmergencyProvider>(context, listen: false)
          .deleteEmergencyRequest(request.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the lists
        _fetchMyEmergencyRequests();
        _fetchAllEmergencyRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting request: ${e.toString()}'),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;
    final unreadCount = notificationProvider.unreadCount;

    return Scaffold(
      // Remove the appBar here
      body: Column(
        children: [
          // Add TabBar directly without AppBar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All Requests'),
              Tab(text: 'My Requests'),
            ],
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Requests Tab
                _buildAllRequestsTab(currentUserId),

                // My Requests Tab
                _buildMyRequestsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'emergency_fab',
        onPressed: _navigateToCreateEmergencyRequest,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAllRequestsTab(String? currentUserId) {
    return Consumer<EmergencyProvider>(
      builder: (context, emergencyProvider, child) {
        final activeRequests = emergencyProvider.emergencyRequests;
        final ignoredRequests = emergencyProvider.ignoredRequests;

        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (activeRequests.isEmpty && ignoredRequests.isEmpty)
            ? const Center(
          child: Text('No emergency requests available'),
        )
            : RefreshIndicator(
          onRefresh: _fetchAllEmergencyRequests,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Active requests section
              if (activeRequests.isNotEmpty) ...[
                const Text(
                  'Active Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ...activeRequests.map((request) => _buildRequestCard(
                  request,
                  isOwnRequest: false,
                  isIgnored: false,
                  onIgnore: () => _ignoreRequest(request.id),
                )),
              ],

              // Ignored requests section
              if (ignoredRequests.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Ignored Requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                ...ignoredRequests.map((request) => _buildRequestCard(
                  request,
                  isOwnRequest: false,
                  isIgnored: true,
                  onUnignore: () => _unignoreRequest(request.id),
                )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyRequestsTab() {
    return Consumer<EmergencyProvider>(
      builder: (context, emergencyProvider, child) {
        final myRequests = emergencyProvider.myEmergencyRequests;

        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : myRequests.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You haven\'t created any emergency requests yet'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToCreateEmergencyRequest,
                child: const Text('Create Request'),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _fetchMyEmergencyRequests,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: myRequests.length,
            itemBuilder: (context, index) {
              final request = myRequests[index];
              return _buildRequestCard(
                request,
                isOwnRequest: true,
                onDelete: () => _deleteRequest(request),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(
      EmergencyRequestModel request, {
        required bool isOwnRequest,
        bool isIgnored = false,
        Function()? onIgnore,
        Function()? onUnignore,
        Function()? onDelete,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isIgnored ? Colors.grey.shade100 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: isIgnored ? Colors.grey : AppTheme.primaryColor,
              child: ImageUtils.getUserPlaceholder(
                initial: request.requesterName.isNotEmpty ? request.requesterName[0].toUpperCase() : '?',
              ),
            ),
            const SizedBox(width: 16),

            // Request info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOwnRequest ? 'Your Request' : request.requesterName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isIgnored ? Colors.grey : AppTheme.primaryColor,
                        ),
                      ),
                      Row(
                        children: [
                          // Ignore/Unignore button for other's requests
                          if (!isOwnRequest) ...[
                            if (isIgnored)
                              TextButton.icon(
                                onPressed: onUnignore,
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text('Restore'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 30),
                                ),
                              )
                            else
                              TextButton.icon(
                                onPressed: onIgnore,
                                icon: const Icon(Icons.visibility_off, size: 18),
                                label: const Text('Ignore'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 30),
                                ),
                              ),
                          ],

                          // Edit and Delete buttons for own requests
                          if (isOwnRequest && !request.isResolved) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              color: AppTheme.primaryColor,
                              onPressed: () => _navigateToEditEmergencyRequest(request),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              color: Colors.red,
                              onPressed: onDelete,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Delete',
                            ),
                            const SizedBox(width: 8),
                          ],

                          // View button
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmergencyRequestDetailScreen(
                                    requestId: request.id,
                                    isOwnRequest: isOwnRequest,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isIgnored ? Colors.grey : AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              minimumSize: const Size(60, 30),
                            ),
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isIgnored ? Colors.grey.shade700 : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: request.requiredSkills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isIgnored
                              ? Colors.grey.withOpacity(0.1)
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(
                            fontSize: 12,
                            color: isIgnored ? Colors.grey : AppTheme.primaryColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Deadline: ${DateFormat('MMM d, h:mm a').format(request.deadline)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (request.isResolved) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Resolved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (isIgnored) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Ignored',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
