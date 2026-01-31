import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/theme_provider.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:curio_campus/screens/profile/edit_profile_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
              title: 'Dark Mode',
              trailing: Switch.adaptive(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                thumbColor: WidgetStateProperty.all(AppTheme.primaryColor),
                activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
              onTap: () {
                themeProvider.toggleTheme();
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.battery_alert,
              title: 'Background Activity',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Background Activity'),
                    content: const Text(
                        'To ensure you receive calls and messages while the app is in the background, please allow background activity. Do you want to continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (Platform.isAndroid) {
                    final androidInfo = await DeviceInfoPlugin().androidInfo;
                    if (androidInfo.version.sdkInt >= 23) {
                      const intent = AndroidIntent(
                        action:
                            'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
                      );
                      await intent.launch();
                    }
                  }
                }
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.edit,
              title: 'Edit Profile',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            _buildSettingItem(
              icon: Icons.logout,
              title: 'Logout',
              titleColor: AppTheme.errorColor,
              iconColor: AppTheme.errorColor,
              trailing: Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.errorColor),
              onTap: () async {
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
                        child: Text('Logout',
                            style: TextStyle(color: AppTheme.errorColor)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await authProvider.logout();
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

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ??
            (isDarkMode ? AppTheme.darkDarkGrayColor : AppTheme.darkGrayColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor ??
              (isDarkMode ? AppTheme.darkTextColor : AppTheme.textColor),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
