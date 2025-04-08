import 'dart:convert'; // For base64 encoding
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/screens/profile/edit_profile_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';

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
                    content: user.majorSkills.isEmpty && user.minorSkills.isEmpty
                        ? 'No skills added yet'
                        : [...user.majorSkills, ...user.minorSkills].join(', '),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    title: 'MY TEAM',
                    content: user.teamMembers.isEmpty
                        ? 'No team members yet'
                        : user.teamMembers.join(', '),
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    title: 'MY COMPLETED PROJECTS',
                    content: user.completedProjects.isEmpty
                        ? 'No completed projects yet'
                        : user.completedProjects.join(', '),
                  ),
                  const SizedBox(height: 24),
                  _buildActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      // Navigate to settings screen
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
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
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

  Widget _buildProfileSection({
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrayColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
          color: AppTheme.lightGrayColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
