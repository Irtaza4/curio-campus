import 'package:flutter/material.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart' as custom_auth;
import '../../chat/create_group_chat_screen.dart';
import '../../project/create_project_screen.dart';
import '../../matchmaking/matchmaking_screen.dart';
import '../../emergency/create_emergency_request_screen.dart';
import '../../settings/settings_screen.dart';
import '../../auth/login_screen.dart';
import '../../profile/edit_profile_screen.dart';

class MoreOptionsSheet extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onShowNotifications;

  const MoreOptionsSheet({
    super.key,
    required this.currentIndex,
    required this.onShowNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentIndex == 0)
              ListTile(
                leading:
                    const Icon(Icons.group_add, color: AppTheme.primaryColor),
                title: const Text('Create Group Chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateGroupChatScreen()),
                  );
                },
              )
            else if (currentIndex == 1) ...[
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: AppTheme.primaryColor),
                title: const Text('Create New Project'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateProjectScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline,
                    color: AppTheme.primaryColor),
                title: const Text('Find Team Members'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MatchmakingScreen()),
                  );
                },
              ),
            ] else if (currentIndex == 2)
              ListTile(
                leading:
                    const Icon(Icons.add_alert, color: AppTheme.primaryColor),
                title: const Text('Create Emergency Request'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateEmergencyRequestScreen()),
                  );
                },
              )
            else if (currentIndex == 3)
              ListTile(
                leading: const Icon(Icons.edit, color: AppTheme.primaryColor),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()),
                  );
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                onShowNotifications();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppTheme.primaryColor),
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
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text('Logout',
                  style: TextStyle(color: AppTheme.errorColor)),
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
                        child: const Text('Logout',
                            style: TextStyle(color: AppTheme.errorColor)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await Provider.of<custom_auth.AuthProvider>(context,
                          listen: false)
                      .logout();
                  if (context.mounted) {
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
      ),
    );
  }
}
