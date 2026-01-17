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
import 'package:firebase_messaging/firebase_messaging.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
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

    // ✅ Print the FCM token to console
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        debugPrint('🔥 FCM Token: $token');
      } else {
        debugPrint('❌ Failed to get FCM token');
      }
    });

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

  void _checkAuthState() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final initialNotificationJson = prefs.getString('initial_notification');

      if (authProvider.isAuthenticated) {
        final projectProvider =
            Provider.of<ProjectProvider>(context, listen: false);
        await projectProvider.initProjects();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );

          if (initialNotificationJson != null) {
            final notificationData =
                jsonDecode(initialNotificationJson) as Map<String, dynamic>;
            _handleInitialNotification(notificationData);
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
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _handleInitialNotification(Map<String, dynamic> notificationData) {
    final notificationType = notificationData['type'];

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
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Image.asset(
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
                    Text(
                      'CurioCampus',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('. Collaborate .',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const Text('. Learn .',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const Text('. Achieve .',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 48),
                    const Text('LOADING ...',
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor),
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
