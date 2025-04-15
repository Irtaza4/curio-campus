import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/screens/emergency/create_emergency_request_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_screen.dart';
import 'package:curio_campus/screens/project/create_project_screen.dart';
import 'package:curio_campus/screens/project/project_screen.dart';
import 'package:curio_campus/screens/profile/profile_screen.dart';
import 'package:curio_campus/screens/matchmaking/matchmaking_screen.dart';
import 'package:curio_campus/screens/chat/create_group_chat_screen.dart';
import 'package:curio_campus/screens/chat/message_screen.dart';
import 'package:curio_campus/screens/settings/settings_screen.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:curio_campus/services/call_service.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/notification_badge.dart';
import 'package:curio_campus/widgets/notification_drawer.dart';
import 'package:curio_campus/providers/auth_provider.dart' as custom_auth;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot>? _callSubscription;

  final List<Widget> _screens = [
    const MessagesScreen(),
    const ProjectsScreen(),
    const EmergencyScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🔔 Fetch notifications
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();

      // 📞 Listen for calls
      final callService = CallService();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Listen for new incoming calls
        callService.listenForIncomingCalls(currentUser.uid, context);

        // Listen for call status updates like 'ended', 'missed', 'declined'
        FirebaseFirestore.instance
            .collection('calls')
            .where('recipientId', isEqualTo: currentUser.uid)
            .snapshots()
            .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'];
            final callId = int.tryParse(data['callId'].toString());

            // Get timestamp
            final timestamp = data['startTime'];
            if (timestamp is Timestamp && callId != null) {
              final callTime = timestamp.toDate();
              final now = DateTime.now();
              final diff = now.difference(callTime).inSeconds;

              // Only respond to calls that just ended
              if (['ended', 'declined', 'missed'].contains(status) && diff < 10) {
                debugPrint("📴 Call $callId just ended ($status)");

                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }

              }
              }
            }
          }
            );
      }
    });
  }




  // void _listenForIncomingCall() async {
  //   final currentUser = FirebaseAuth.instance.currentUser;
  //   if (currentUser == null) return;
  //
  //   final callsCollection = FirebaseFirestore.instance.collection('calls');
  //
  //   _callSubscription = callsCollection
  //       .where('recipientId', isEqualTo: currentUser.uid)
  //       .where('status', isEqualTo: 'ringing')
  //       .snapshots()
  //       .listen((snapshot) {
  //     if (snapshot.docs.isNotEmpty) {
  //       final callDoc = snapshot.docs.first;
  //       final data = callDoc.data() as Map<String, dynamic>;
  //
  //       final callService = CallService();
  //       callService.handleIncomingCallFromNotification(
  //         callId: data['callId'].toString(),
  //         callerId: data['callerId'],
  //         callerName: data['callerName'],
  //         isVideoCall: data['callType'] == 'video',
  //         callerProfileImage: data['callerImage'],
  //       );
  //     }
  //   });
  // }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
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
              if (_currentIndex == 0)
                ListTile(
                  leading: Icon(Icons.group_add, color: AppTheme.primaryColor),
                  title: Text('Create Group Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateGroupChatScreen()),
                    );
                  },
                )
              else if (_currentIndex == 1) ...[
                ListTile(
                  leading: Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  title: Text('Create New Project'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.people_outline, color: AppTheme.primaryColor),
                  title: Text('Find Team Members'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
                    );
                  },
                ),
              ] else if (_currentIndex == 2)
                ListTile(
                  leading: Icon(Icons.add_alert, color: AppTheme.primaryColor),
                  title: Text('Create Emergency Request'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateEmergencyRequestScreen()),
                    );
                  },
                )
              else if (_currentIndex == 3)
                  ListTile(
                    leading: Icon(Icons.edit, color: AppTheme.primaryColor),
                    title: const Text('Edit Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/edit-profile');
                    },
                  ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.notifications_outlined, color: AppTheme.primaryColor),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  _showNotifications();
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: AppTheme.primaryColor),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await Provider.of<custom_auth.AuthProvider>(context, listen: false).logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getScreenTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Messages';
      case 1:
        return 'Projects';
      case 2:
        return 'Emergency';
      case 3:
        return 'Profile';
      default:
        return 'CurioCampus';
    }
  }

  void _showNotifications() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return const NotificationDrawer(title: 'Notifications');
      },
    );
  }

  void _navigateToCreateProject() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        automaticallyImplyLeading: false,
        actions: [
          if (_currentIndex == 1)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _navigateToCreateProject,
              tooltip: 'Create New Project',
            ),
          NotificationBadge(
            count: unreadCount,
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _showNotifications,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: isDarkMode ? AppTheme.darkDarkGrayColor : Colors.grey,
        backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.airline_seat_flat_angled),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  Widget? _getFloatingActionButton() {
    switch (_currentIndex) {
      case 1:
        return FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
          ),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.people_alt, color: Colors.white),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEmergencyRequestScreen()),
          ),
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        );
      default:
        return null;
    }
  }
}
