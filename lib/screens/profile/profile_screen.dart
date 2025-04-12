import 'dart:convert'; // For base64 encoding
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/project_provider.dart'; // Add this import
import 'package:curio_campus/screens/profile/edit_profile_screen.dart';
import 'package:curio_campus/screens/settings/settings_screen.dart';
import 'package:curio_campus/utils/constants.dart';

import '../../utils/app_theme.dart';
import '../../models/project_model.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _teamMembers = [];
  List<ProjectModel> _completedProjects = [];
  bool _isLoadingTeamMembers = false;
  bool _isLoadingProjects = false;

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

    if (user != null) {
      // Update the user model with the new image base64 data
      user.profileImageBase64 = base64Image;

      // Save the updated profile in Firestore
      await _firestore.collection(Constants.usersCollection).doc(user.id).update({
        'profileImageBase64': base64Image,
      });

      // Force a rebuild
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTeamMembersAndProjects();
  }

  // Fetch real team members and projects data
  Future<void> _loadTeamMembersAndProjects() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final user = authProvider.userModel;

    if (user != null) {
      // Initialize projects if not already done
      if (projectProvider.projects.isEmpty) {
        await projectProvider.initProjects();
      }

      // Fetch team members
      setState(() {
        _isLoadingTeamMembers = true;
      });

      try {
        // Get unique team members from all projects
        Set<String> teamMemberIds = {};

        // Add team members from all projects
        for (var project in projectProvider.projects) {
          for (var memberId in project.teamMembers) {
            if (memberId != user.id) { // Don't include the current user
              teamMemberIds.add(memberId);
            }
          }
        }

        List<UserModel> members = [];

        for (String memberId in teamMemberIds) {
          final member = await projectProvider.fetchUserById(memberId);
          if (member != null) {
            members.add(member);
          }
        }

        setState(() {
          _teamMembers = members;
          _isLoadingTeamMembers = false;
        });
      } catch (e) {
        print("Error fetching team members: $e");
        setState(() {
          _isLoadingTeamMembers = false;
        });
      }

      // Fetch completed projects
      setState(() {
        _isLoadingProjects = true;
      });

      try {
        // Get completed projects (progress = 100%)
        List<ProjectModel> completedProjects = projectProvider.projects
            .where((project) => project.progress == 100)
            .toList();

        setState(() {
          _completedProjects = completedProjects;
          _isLoadingProjects = false;
        });
      } catch (e) {
        print("Error fetching completed projects: $e");
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  // Method to refresh data
  Future<void> _refreshData() async {
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);

    // Refresh projects from Firestore
    await projectProvider.fetchProjects();

    // Reload team members and completed projects
    await _loadTeamMembersAndProjects();
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
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      _buildProfileAvatar(user.profileImageBase64),
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
                      teamMembers: _teamMembers,
                      isLoading: _isLoadingTeamMembers,
                    ),
                    const SizedBox(height: 16),
                    _buildProfileSection(
                      title: 'MY COMPLETED PROJECTS',
                      content: 'No completed projects yet',
                      projects: _completedProjects,
                      isLoading: _isLoadingProjects,
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
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'profile_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EditProfileScreen(),
            ),
          ).then((_) => _loadTeamMembersAndProjects()); // Reload data when returning from edit screen
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

    try {
      // Decode the base64 image data
      final image = MemoryImage(base64Decode(base64Image));
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        backgroundImage: image,
      );
    } catch (e) {
      print("Error decoding base64 image: $e");
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
  }

  Widget _buildProfileSection({
    required String title,
    required String content,
    List<String>? items,
    List<UserModel>? teamMembers,
    List<ProjectModel>? projects,
    bool isLoading = false,
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
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (title.contains("TEAM") && teamMembers != null && teamMembers.isNotEmpty)
            _buildTeamMembersList(teamMembers)
          else if (title.contains("COMPLETED PROJECTS") && projects != null && projects.isNotEmpty)
              _buildCompletedProjectsList(projects)
            else if (items != null && items.isNotEmpty)
                _buildSimpleList(items, title.contains("SKILLS") ? Icons.check_circle :
                title.contains("TEAM") ? Icons.person : Icons.task_alt)
              else
                Text(
                  content,
                  style: isDarkMode ? AppTheme.darkBodyStyle : AppTheme.bodyStyle,
                ),
        ],
      ),
    );
  }

  Widget _buildSimpleList(List<String> items, IconData icon) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
              icon,
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
    );
  }

  Widget _buildTeamMembersList(List<UserModel> members) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: members.map((member) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
                child: member.profileImageBase64 != null && member.profileImageBase64!.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    base64Decode(member.profileImageBase64!),
                    fit: BoxFit.cover,
                    width: 32,
                    height: 32,
                  ),
                )
                    : Icon(
                  Icons.person,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: isDarkMode
                          ? AppTheme.darkBodyStyle.copyWith(fontWeight: FontWeight.bold)
                          : AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (member.majorSkills.isNotEmpty)
                      Text(
                        member.majorSkills.first,
                        style: isDarkMode
                            ? AppTheme.darkCaptionStyle
                            : AppTheme.captionStyle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompletedProjectsList(List<ProjectModel> projects) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: projects.map((project) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
                child: Icon(
                  Icons.task_alt,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: isDarkMode
                          ? AppTheme.darkBodyStyle.copyWith(fontWeight: FontWeight.bold)
                          : AppTheme.bodyStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Completed on ${_formatDate(project.createdAt)}',
                      style: isDarkMode
                          ? AppTheme.darkCaptionStyle
                          : AppTheme.captionStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

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
