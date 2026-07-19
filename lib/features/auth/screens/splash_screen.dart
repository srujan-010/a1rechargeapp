import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../../../core/constants/asset_paths.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/local_cache_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _pulseController;
  late Animation<double> _logoPulse;

  late AnimationController _ambientController;
  late AnimationController _loadingController;

  @override
  void initState() {
    super.initState();

    // Entrance Animation (Fade & initial scale)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    // Pulse Animation (every 3 seconds)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _logoPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.03).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 1.0).chain(CurveTween(curve: Curves.easeInOutSine)), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60), // Wait before next pulse
    ]).animate(_pulseController);

    // Ambient Background Animation (Very slow)
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Sleek Loading Line Animation
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _startAnimations();
    _checkAuth();
  }

  void _startAnimations() async {
    if (mounted) {
      await _entranceController.forward();
      if (mounted) _pulseController.repeat();
    }
  }

  Future<void> _checkAuth() async {
    // Keep splash visible for ~2.5 - 3 seconds for premium feel
    await Future.delayed(const Duration(milliseconds: 2800));

    if (!mounted) return;

    final session = await ref.read(sessionProvider.future);
    
    if (!mounted) return;

    if (session != null) {
      context.go(RouteNames.dashboard);
    } else {
      context.go(RouteNames.onboarding);
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _ambientController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030D26), // Very deep royal blue base
      body: Stack(
        children: [
          // Ambient Background Layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AmbientBackgroundPainter(_ambientController.value),
                );
              },
            ),
          ),
          
          // Centerpiece
          Align(
            alignment: Alignment.center,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedBuilder(
                animation: Listenable.merge([_entranceController, _pulseController]),
                builder: (context, child) {
                  // Combine entrance scale with the ongoing pulse scale
                  final scale = _logoScale.value * _logoPulse.value;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Very subtle radial glow behind logo
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A5BFF).withOpacity(0.15),
                            blurRadius: 80,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                      child: Container(
                        // 28-30% of screen width (approx 120px)
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Image.asset(
                              AssetPaths.appLogo,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    
                    // Main Title
                    const Text(
                      'A1 Recharge',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Tagline
                    Text(
                      'RECHARGE • BILLS • WALLET • COMMISSION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Loading & Trust Badge
          Align(
            alignment: Alignment.bottomCenter,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sleek Loading Line
                    Container(
                      width: 120,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: AnimatedBuilder(
                        animation: _loadingController,
                        builder: (context, child) {
                          // Curved movement for natural acceleration/deceleration
                          final curve = Curves.easeInOutSine.transform(_loadingController.value);
                          return Align(
                            alignment: Alignment(curve * 2 - 1, 0),
                            child: Container(
                              width: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF), // Cyan electric highlight
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withOpacity(0.8),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Trust Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.white.withOpacity(0.4),
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Secured by A1 Recharge Network',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.4),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ambient Background Painter ──────────────────────────────────────────────
class _AmbientBackgroundPainter extends CustomPainter {
  final double progress;

  _AmbientBackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDeepGradient(canvas, size);
    _drawLightStreaks(canvas, size);
    _drawAmbientParticles(canvas, size);
  }

  void _drawDeepGradient(Canvas canvas, Size size) {
    // Rich, premium, dark royal blue gradient mesh
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.2,
        colors: [
          const Color(0xFF0A2B70), // Lighter royal blue center
          const Color(0xFF030D26), // Deep edges
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawLightStreaks(Canvas canvas, Size size) {
    // Very subtle horizontal light streaks floating upwards
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Fixed math parameters for stable motion without random flicker
    void drawStreak(double startY, double width, double height, double speed, double phase) {
      double y = startY - (progress * size.height * speed);
      if (y < -height) y = size.height + (y % size.height);

      final opacity = math.sin((progress * math.pi * 2) + phase).abs() * 0.03; // Extremely faint

      paint.shader = LinearGradient(
        colors: [
          const Color(0xFF0A5BFF).withOpacity(0),
          const Color(0xFF0A5BFF).withOpacity(opacity),
          const Color(0xFF0A5BFF).withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, y, size.width, height));

      canvas.drawRect(Rect.fromLTWH(0, y, size.width, height), paint);
    }

    drawStreak(size.height * 0.2, size.width, 40, 0.2, 0);
    drawStreak(size.height * 0.8, size.width, 60, 0.15, math.pi / 2);
    drawStreak(size.height * 0.5, size.width, 30, 0.3, math.pi);
  }

  void _drawAmbientParticles(Canvas canvas, Size size) {
    // Tiny, premium, glowing dust particles. Barely noticeable.
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(1337); // Seed for deterministic positioning

    for (int i = 0; i < 20; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final speed = random.nextDouble() * 0.3 + 0.1;
      final maxRadius = random.nextDouble() * 1.5 + 0.5;
      
      // Moving slowly upwards
      double y = startY - (progress * size.height * speed);
      if (y < 0) y = size.height + y; 

      final opacity = math.sin((progress * speed * math.pi * 4) + random.nextDouble() * math.pi * 2);
      
      // Some particles are pure white, some are cyan
      final isCyan = i % 3 == 0;
      final color = isCyan ? const Color(0xFF00E5FF) : Colors.white;
      
      paint.color = color.withOpacity((opacity.abs() * 0.15).clamp(0.0, 0.15));
      
      canvas.drawCircle(Offset(startX, y), maxRadius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _AmbientBackgroundPainter oldDelegate) => oldDelegate.progress != progress;
}
