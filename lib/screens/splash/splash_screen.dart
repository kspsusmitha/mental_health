import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../modules/user/user_home_screen.dart';
import '../../modules/therapist/therapist_home_screen.dart';
import '../../modules/admin/admin_home_screen.dart';
import '../auth/module_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<Color?> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Background animation controller
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo scale and fade animation
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    // Text fade animation
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeInOut,
      ),
    );

    // Background gradient animation
    _backgroundAnimation = ColorTween(
      begin: const Color(0xFF667EEA),
      end: const Color(0xFF764BA2),
    ).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    _startAnimations();

    // Check auth state and navigate
    Timer(const Duration(seconds: 3), () async {
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser != null) {
          // User is logged in, route accordingly
          Widget homeScreen;
          switch (currentUser.userType) {
            case UserType.user:
              homeScreen = const UserHomeScreen();
              break;
            case UserType.therapist:
              homeScreen = const TherapistHomeScreen();
              break;
            case UserType.admin:
              homeScreen = const AdminHomeScreen();
              break;
          }
          
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => homeScreen,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }
        
        // Not logged in, go to module selection
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ModuleSelectionScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    });
  }

  void _startAnimations() {
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _textController.forward();
    });
    _backgroundController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _backgroundAnimation.value ?? const Color(0xFF667EEA),
                  const Color(0xFF764BA2),
                  const Color(0xFFF093FB),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    AnimatedBuilder(
                      animation: _logoAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoAnimation.value,
                          child: Opacity(
                            opacity: _logoAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.health_and_safety,
                                size: 70,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // Animated Text
                    AnimatedBuilder(
                      animation: _textAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textAnimation.value,
                          child: Column(
                            children: [
                              Text(
                                'MindCare',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Your Wellness Companion',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 80),

                    // Loading indicator
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

