import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../core/navigation/app_routes.dart';

class SplashScreen extends StatefulWidget {
  final SessionController sessionController;

  const SplashScreen({super.key, required this.sessionController});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Wait for animation + extra time for a premium feel
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

    if (!seenOnboarding) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      if (widget.sessionController.isAuthenticated) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'images/studyflow.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.school_rounded,
                    size: 100,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'StudyFlow',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16213D),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
