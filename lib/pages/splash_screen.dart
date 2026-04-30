import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'mood_checkin_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _spinnerController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _rotateAnim;

  static final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // ✅ CRITICAL: Hide status bar and navigation bar immediately
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _setupAnimations();
    _navigate();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(curvedAnimation);

    _scaleAnim = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _slideAnim = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _rotateAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinnerController.dispose();
    // ✅ Re-show status bar when leaving splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _navigate() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      final isLoggedIn = await _authService.isLoggedIn()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      if (!mounted) return;

      if (isLoggedIn) {
        final shouldCheckin = await MoodCheckinPage.shouldShowToday()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);

        if (!mounted) return;

        if (shouldCheckin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MoodCheckinPage(onComplete: _goHome),
            ),
          );
        } else {
          _goHome();
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Navigation error: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ CRITICAL: Remove default Scaffold padding
      extendBody: true,
      extendBodyBehindAppBar: true,
      // ✅ No AppBar
      appBar: null,
      // ✅ Body fills entire screen
      body: SizedBox.expand(
        child: Container(
          // ✅ Gradient fills everything
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade800,
                Colors.purple.shade600,
                Colors.blue.shade600,
                Colors.cyan.shade400,
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
          ),
          // ✅ Stack ensures content is centered
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ✨ Animated background circles
              _buildAnimatedBackground(),
              // ✨ Main animated content
              _buildMainContent(),
            ],
          ),
        ),
      ),
    );
  }

  // ✨ Background decoration
  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Large circle - bottom right
        Positioned(
          bottom: -100,
          right: -100,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
        ),
        // Medium circle - top left
        Positioned(
          top: -80,
          left: -80,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✨ Main animated content
  Widget _buildMainContent() {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✨ Animated icon with glow
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.2),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.blue.shade400.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _rotateAnim,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotateAnim.value * 0.3,
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 130,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // ✨ App title with gradient effect
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, Colors.cyan.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'EMOTRA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ✨ Subtitle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Understand Emotions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Everywhere & Anytime',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),

            // ✨ Loading indicator
            _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }

  // ✨ Custom animated loading spinner
  Widget _buildLoadingIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating ring
              RotationTransition(
                turns: _spinnerController,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Inner rotating ring (opposite direction)
              RotationTransition(
                turns: Tween(begin: 1.0, end: 0.0).animate(_spinnerController),
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.cyan.shade300.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Center dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Loading...',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}