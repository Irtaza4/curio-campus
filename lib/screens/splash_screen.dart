import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:curio_campus/providers/auth_provider.dart';
import 'package:curio_campus/providers/project_provider.dart';
import 'package:curio_campus/screens/auth/login_screen.dart';
import 'package:curio_campus/screens/home/home_screen.dart';
import 'package:curio_campus/utils/app_theme.dart';
import 'package:curio_campus/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:curio_campus/screens/chat/chat_screen.dart';
import 'package:curio_campus/screens/emergency/emergency_request_detail_screen.dart';
import 'package:curio_campus/screens/project/project_detail_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Navigate to the appropriate screen after a delay
    Future.delayed(const Duration(seconds: Constants.splashDuration), () {
      _checkAuthState();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Update the _checkAuthState method to handle initial notification
  void _checkAuthState() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check for initial notification
      final prefs = await SharedPreferences.getInstance();
      final initialNotificationJson = prefs.getString('initial_notification');

      // Initialize projects if user is authenticated
      if (authProvider.isAuthenticated) {
        await Provider.of<ProjectProvider>(context, listen: false).initProjects();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );

          // Handle initial notification after navigation
          if (initialNotificationJson != null) {
            final notificationData = jsonDecode(initialNotificationJson) as Map<String, dynamic>;
            _handleInitialNotification(notificationData);
            // Clear the stored notification
            prefs.remove('initial_notification');
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in splash screen: $e');
      // Fallback to login screen if there's any error
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  // Add a method to handle initial notification
  void _handleInitialNotification(Map<String, dynamic> notificationData) {
    final notificationType = notificationData['type'];

    // Delay navigation to ensure HomeScreen is fully loaded
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      switch (notificationType) {
        case 'chat':
          final chatId = notificationData['chatId'];
          final chatName = notificationData['chatName'];
          if (chatId != null && chatName != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chatId,
                  chatName: chatName,
                ),
              ),
            );
          }
          break;
        case 'emergency':
          final requestId = notificationData['requestId'];
          final isOwnRequest = notificationData['isOwnRequest'] == 'true';
          if (requestId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmergencyRequestDetailScreen(
                  requestId: requestId,
                  isOwnRequest: isOwnRequest,
                ),
              ),
            );
          }
          break;
        case 'project':
          final projectId = notificationData['projectId'];
          if (projectId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(projectId: projectId),
              ),
            );
          }
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    SizedBox(
                      width: 180,
                      height: 180,
                      child:  Image.asset(
                        'assets/images/logo.png',
                        width: 200,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.hub,
                            size: 80,
                            color: AppTheme.primaryColor,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // App name
                    Text(
                      'CurioCampus',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tagline
                    const Text(
                      '. Collaborate .',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      '. Learn .',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      '. Achieve .',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Loading indicator
                    const Text(
                      'LOADING ...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

