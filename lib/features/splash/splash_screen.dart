import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/admin/admin_home_screen.dart';
import 'package:unisharesync_mobile_app/features/dashboard/role_home_screen.dart';
import 'package:unisharesync_mobile_app/features/onboarding/onboarding_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future<void>.delayed(const Duration(seconds: 3));

    if (!mounted) {
      return;
    }

    final hasSession = await _authService.hasActiveSession();
    late final Widget nextScreen;

    if (!hasSession) {
      nextScreen = const OnboardingScreen();
    } else {
      final role = await _authService.getCurrentRole();
      final isLocalAdmin = await _authService.isLocalAdminSession();
      final isAdminSession = role == UserRole.admin || isLocalAdmin;

      nextScreen = isAdminSession
          ? AdminHomeScreen(isLocalAdmin: isLocalAdmin)
          : RoleHomeScreen(
              initialRole: role,
              isLocalAdmin: isLocalAdmin,
            );
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.32,
                  child: CustomPaint(
                    painter: _SplashDotGridPainter(
                      color: Color(0xFF4F9EFF),
                      spacing: 26,
                      radius: 1.15,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -size.height * 0.16,
              right: -size.width * 0.22,
              child: Container(
                width: size.width * 1.08,
                height: size.width * 1.08,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x664F9EFF),
                      Colors.transparent,
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.2,
              left: -size.width * 0.22,
              child: Container(
                width: size.width * 1.12,
                height: size.width * 1.12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x662DD4BF),
                      Colors.transparent,
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.3,
              right: -size.width * 0.1,
              child: Container(
                width: size.width * 0.62,
                height: size.width * 0.62,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x33FFA06B),
                      Colors.transparent,
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 46,
                          vertical: 56,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.62),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.85),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F9EFF).withOpacity(0.16),
                              blurRadius: 36,
                              spreadRadius: 0,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F9EFF)
                                        .withOpacity(0.26),
                                    blurRadius: 26,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFF4F9EFF),
                                    Color(0xFF2DD4BF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Image.asset(
                                  'lib/assets/logos/unisharesync.png',
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.hub_rounded,
                                    size: 96,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF2B5B94), Color(0xFF1B8577)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                'UniShareSync',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your Campus. Connected.',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: size.height * 0.08,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: child,
                  );
                },
                child: const Column(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: NewtonsCradleLoader(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewtonsCradleLoader extends StatefulWidget {
  final double size;
  final Color color;

  const NewtonsCradleLoader({
    super.key,
    this.size = 50.0,
    this.color = const Color(0xFF4F9EFF),
  });

  @override
  State<NewtonsCradleLoader> createState() => _NewtonsCradleLoaderState();
}

class _SplashDotGridPainter extends CustomPainter {
  const _SplashDotGridPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (double y = 0; y <= size.height; y += spacing) {
      for (double x = 0; x <= size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplashDotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}

class _NewtonsCradleLoaderState extends State<NewtonsCradleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _firstDotAnimation;
  late Animation<double> _lastDotAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _firstDotAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 70.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 70.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 50.0,
      ),
    ]).animate(_controller);

    _lastDotAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -70.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -70.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25.0,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDot(animation: _firstDotAnimation),
          _buildDot(),
          _buildDot(),
          _buildDot(animation: _lastDotAnimation),
        ],
      ),
    );
  }

  Widget _buildDot({Animation<double>? animation}) {
    final dotWidth = widget.size * 0.25;

    Widget dot = Container(
      width: dotWidth,
      height: widget.size,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: dotWidth,
        height: dotWidth,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );

    if (animation != null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..rotateZ(animation.value * math.pi / 180),
            child: child,
          );
        },
        child: dot,
      );
    }

    return dot;
  }
}
