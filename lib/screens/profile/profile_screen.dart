import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/screens/profile/edit_profile_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return user == null
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
                  _buildProfileAvatar(user.profileImageUrl),
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
                // My skills
                _buildProfileSection(
                  title: 'MY SKILLS',
                  content: user.majorSkills.isEmpty && user.minorSkills.isEmpty
                      ? 'No skills added yet'
                      : [...user.majorSkills, ...user.minorSkills].join(', '),
                ),

                const SizedBox(height: 16),

                // My team
                _buildProfileSection(
                  title: 'MY TEAM',
                  content: user.teamMembers.isEmpty
                      ? 'No team members yet'
                      : user.teamMembers.join(', '),
                ),

                const SizedBox(height: 16),

                // My completed projects
                _buildProfileSection(
                  title: 'MY COMPLETED PROJECTS',
                  content: user.completedProjects.isEmpty
                      ? 'No completed projects yet'
                      : user.completedProjects.join(', '),
                ),

                const SizedBox(height: 24),

                // Settings
                _buildActionButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    // Navigate to settings screen
                  },
                ),

                const SizedBox(height: 16),

                // Info and help
                _buildActionButton(
                  icon: Icons.info_outline,
                  label: 'Info and Help',
                  onTap: () {
                    // Navigate to help screen
                  },
                ),

                const SizedBox(height: 24),

                // Sign out button
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
    );
  }

  Widget _buildProfileAvatar(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
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

    return CachedNetworkImage(
      imageUrl: imageUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.person,
          size: 50,
          color: AppTheme.primaryColor,
        ),
      ),
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

