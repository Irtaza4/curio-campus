import 'package:curio_campus/screens/project/create_project_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/screens/emergency/emergency_screen.dart';
import 'package:curio_campus/screens/matchmaking/matchmaking_screen.dart';
import 'package:curio_campus/screens/profile/profile_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/notification_badge.dart';

import '../../widgets/notification_drawer.dart';
import '../chat/message_screen.dart';
import '../project/project_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Define the screens without their own app bars
  final List<Widget> _screens = [
    const MessagesScreen(),
    const ProjectsScreen(),
    const EmergencyScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Fetch notifications when the home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).fetchNotifications();
    });
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await Provider.of<AuthProvider>(context, listen: false).logout();
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return const NotificationDrawer(
          title: 'Notifications',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      // Single app bar for all screens
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        automaticallyImplyLeading: false, // No back button
        actions: [
          // Add + button only for Projects screen
          if (_currentIndex == 1)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_)=>CreateProjectScreen()));
              },
            ),
          NotificationBadge(
            count: notificationProvider.unreadCount,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
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
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.airline_seat_flat_angled),
            activeIcon: Icon(Icons.airline_seat_flat_angled),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined),
            activeIcon: Icon(Icons.warning),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _getFloatingActionButton(),
    );
  }

  Widget? _getFloatingActionButton() {
    switch (_currentIndex) {
      case 1: // Projects screen
        return FloatingActionButton(
          onPressed: () {
            // Navigate to matchmaking screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MatchmakingScreen(),
              ),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.people_alt, color: Colors.white),
        );
      case 2: // Emergency screen
        return FloatingActionButton(
          onPressed: () {
            // Navigate to create emergency request screen
            Navigator.pushNamed(context, '/create_emergency');
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        );
      default:
        return null;
    }
  }
}

