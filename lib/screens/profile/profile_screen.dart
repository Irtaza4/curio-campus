import 'dart:convert'; // For base64 encoding
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/screens/profile/edit_profile_screen.dart';
import 'package:curio_campus/screens/settings/settings_screen.dart';

import '../../utils/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  // Convert the selected image to a base64 string
  Future<String?> convertImageToBase64(XFile image) async {
    try {
      final bytes = await File(image.path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print("Failed to convert image to base64: $e");
      return null;
    }
  }

  // Update the user's profile image URL in Firestore (base64)
  Future<void> updateUserProfileImage(String base64Image) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.userModel;

    // Update the user model with the new image base64 data
    user?.profileImageBase64 = base64Image;

    // Save the updated profile in Firestore
    await FirebaseFirestore.instance.collection('users').doc(user!.id).update({
      'profileImageUrl': base64Image,
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppTheme.primaryColor,
              child: Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        // Pick an image using image picker
                        XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);

                        if (pickedImage != null) {
                          // Convert the image to base64 and get the base64 string
                          String? base64Image = await convertImageToBase64(pickedImage);

                          if (base64Image != null) {
                            // Update the user's profile with the new base64 image data
                            await updateUserProfileImage(base64Image);
                          }
                        }
                      },
                      child: _buildProfileAvatar(user.profileImageBase64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Profile sections
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileSection(
                    title: 'MY SKILLS',
                    content: 'No skills added yet',
                    items: [...user.majorSkills, ...user.minorSkills],
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    title: 'MY TEAM',
                    content: 'No team members yet',
                    items: user.teamMembers.isNotEmpty ? user.teamMembers : null,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    title: 'MY COMPLETED PROJECTS',
                    content: 'No completed projects yet',
                    items: user.completedProjects.isNotEmpty ? user.completedProjects : null,
                  ),
                  const SizedBox(height: 24),
                  _buildActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      // Navigate to settings screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.info_outline,
                    label: 'Info and Help',
                    onTap: () {
                      // Navigate to help screen
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_)=>LoginScreen()));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? AppTheme.darkSurfaceColor : Colors.white,
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'profile_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditProfileScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildProfileAvatar(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.person,
          size: 50,
          color: AppTheme.primaryColor,
        ),
      );
    }

    // Decode the base64 image data
    final image = MemoryImage(base64Decode(base64Image));
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.white,
      backgroundImage: image,
    );
  }

  // Update the _buildProfileSection method to use theme-aware colors
  Widget _buildProfileSection({
    required String title,
    required String content,
    List<String>? items,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkLightGrayColor : AppTheme.lightGrayColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppTheme.darkDarkGrayColor : AppTheme.darkGrayColor,
            ),
          ),
          const SizedBox(height: 8),
          if (items != null && items.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      title.contains("SKILLS") ? Icons.check_circle :
                      title.contains("TEAM") ? Icons.person :
                      Icons.task_alt,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: isDarkMode ? AppTheme.darkBodyStyle : AppTheme.bodyStyle,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            )
          else
            Text(
              content,
              style: isDarkMode ? AppTheme.darkBodyStyle : AppTheme.bodyStyle,
            ),
        ],
      ),
    );
  }

  // Update the _buildActionButton method to use theme-aware colors
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkLightGrayColor : AppTheme.lightGrayColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDarkMode ? AppTheme.darkDarkGrayColor : AppTheme.darkGrayColor,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: isDarkMode ? AppTheme.darkBodyStyle : AppTheme.bodyStyle,
            ),
          ],
        ),
      ),
    );
  }
}
