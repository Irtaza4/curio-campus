import 'package:curio_campus/screens/emergency/create_emergency_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/notification_provider.dart';
import 'package:curio_campus/screens/emergency/emergency_screen.dart';
import 'package:curio_campus/screens/matchmaking/matchmaking_screen.dart';
import 'package:curio_campus/screens/profile/profile_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/notification_badge.dart';
import 'package:curio_campus/screens/project/create_project_screen.dart';
import 'package:curio_campus/screens/settings/settings_screen.dart';
import 'package:curio_campus/screens/chat/create_group_chat_screen.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';

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
              // Show different options based on the current tab
              if (_currentIndex == 0) ...[
                // Messages tab options
                ListTile(
                  leading: Icon(
                    Icons.group_add,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'Create Group Chat',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupChatScreen(),
                      ),
                    );
                  },
                ),

              ] else if (_currentIndex == 1) ...[
                // Projects tab options
                ListTile(
                  leading: Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'Create New Project',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateProjectScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.people_outline,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'Find Team Members',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MatchmakingScreen(),
                      ),
                    );
                  },
                ),

              ] else if (_currentIndex == 2) ...[
                // Emergency tab options
                ListTile(
                  leading: Icon(
                    Icons.add_alert,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'Create Emergency Request',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateEmergencyRequestScreen(),
                      ),
                    );
                  },
                ),

              ] else if (_currentIndex == 3) ...[
                // Profile tab options
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: AppTheme.primaryColor,
                  ),
                  title: Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/edit-profile');
                  },
                ),

              ],

              // Common options for all tabs
              Divider(
                color: isDarkMode ? AppTheme.darkMediumGrayColor : AppTheme.mediumGrayColor,
              ),

              ListTile(
                leading: Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  'Notifications',
                  style: TextStyle(
                    color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showNotifications();
                },
              ),

              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
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
                      backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
                      title: Text('Logout',
                        style: TextStyle(
                            color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor
                        ),
                      ),
                      content: Text('Are you sure you want to logout?',
                        style: TextStyle(
                            color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(context,MaterialPageRoute(builder: (_)=>LoginScreen())),
                          child: const Text('Logout', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    await Provider.of<AuthProvider>(context, listen: false).logout();
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
        return const NotificationDrawer(
          title: 'Notifications',
        );
      },
    );
  }

  void _navigateToCreateProject() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateProjectScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        automaticallyImplyLeading: false, // No back button
        actions: [
          // Add button for Projects screen
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
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (context) => const NotificationDrawer(
                    title: 'Notifications',
                  ),
                );
              },
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
          heroTag: 'home_projects_fab',
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
          heroTag: 'home_emergency_fab',
          onPressed: () {
            // Navigate to create emergency request screen
            Navigator.push(context, MaterialPageRoute(builder: (_)=>CreateEmergencyRequestScreen()));
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        );
      default:
        return null;
    }
  }
}
