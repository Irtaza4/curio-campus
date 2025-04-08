import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/widgets/custom_button.dart';
import 'package:curio_campus/widgets/custom_text_field.dart';
import 'package:curio_campus/widgets/skill_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<String> _majorSkills = [];
  List<String> _minorSkills = [];
  File? _profileImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  void _initializeUserData() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user != null) {
      _nameController.text = user.name;
      _majorSkills = List<String>.from(user.majorSkills);
      _minorSkills = List<String>.from(user.minorSkills);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Upload image if selected
      String? profileImageBase64;
      if (_profileImage != null) {
        profileImageBase64 = await authProvider.convertImageToBase64(_profileImage!);

        if (profileImageBase64 == null && mounted) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile image'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final success = await authProvider.updateProfile(
        name: _nameController.text.trim(),
        majorSkills: _majorSkills,
        minorSkills: _minorSkills,
        profileImageBase64: profileImageBase64,
      );

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile image
              Center(
                child: Stack(
                  children: [
                    _profileImage != null
                        ? CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.lightGrayColor,
                      backgroundImage: FileImage(_profileImage!),
                    )
                        : user.profileImageBase64 != null && user.profileImageBase64!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: user.profileImageBase64!,
                      imageBuilder: (context, imageProvider) => CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTheme.lightGrayColor,
                        backgroundImage: imageProvider,
                      ),
                      placeholder: (context, url) => CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTheme.lightGrayColor,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      errorWidget: (context, url, error) => CircleAvatar(
                        radius: 60,
                        backgroundColor: AppTheme.lightGrayColor,
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    )
                        : CircleAvatar(
                      radius: 60,
                      backgroundColor: AppTheme.lightGrayColor,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Name
              const Text(
                'Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _nameController,
                hintText: 'Enter your name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Major skills
              const Text(
                'Major Skills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SkillSelector(
                selectedSkills: _majorSkills,
                onSkillsChanged: (skills) {
                  setState(() {
                    _majorSkills = skills;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Minor skills
              const Text(
                'Minor Skills (Frameworks & Tools)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SkillSelector(
                selectedSkills: _minorSkills,
                onSkillsChanged: (skills) {
                  setState(() {
                    _minorSkills = skills;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Update button
              CustomButton(
                text: 'Update Profile',
                isLoading: _isLoading,
                onPressed: _updateProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
