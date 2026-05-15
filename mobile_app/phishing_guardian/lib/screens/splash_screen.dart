import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import '../main.dart';
import '../services/storage_service.dart';
import 'agreement_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Shield entrance: scale + fade
  late final AnimationController _entranceCtrl;
  late final Animation<double> _shieldScale;
  late final Animation<double> _shieldFade;

  // Rotating arc around the shield
  late final AnimationController _rotateCtrl;

  // Gentle pulse on the shield
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // Text fade-in
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  bool? _hasAgreed;

  @override
  void initState() {
    super.initState();

    // ── Entrance ─────────────────────────────────────────────────────
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shieldScale = CurvedAnimation(
        parent: _entranceCtrl, curve: Curves.elasticOut);
    _shieldFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _entranceCtrl,
            curve: const Interval(0.0, 0.35, curve: Curves.easeIn)));

    // ── Rotating arc ─────────────────────────────────────────────────
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // ── Pulse ─────────────────────────────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ── Text ─────────────────────────────────────────────────────────
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _run();
  }

  Future<void> _run() async {
    // Fetch agreement state in parallel with animation
    final agreedFuture = StorageService.hasUserAgreed();

    _entranceCtrl.forward();

    // Check internet connection
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
      }
    } on SocketException catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      if (!mounted) return;
      _showNoInternetDialog();
      return; // Stop here, dialog will retry or user can close app
    }

    // Wait for entrance to finish, then show text
    await Future.delayed(const Duration(milliseconds: 950));
    _textCtrl.forward();

    // Wait for minimum display + fetch to both complete
    final results = await Future.wait([
      agreedFuture,
      Future.delayed(const Duration(milliseconds: 1600)),
    ]);
    _hasAgreed = results[0] as bool;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            _hasAgreed! ? const MainShell() : const AgreementScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: kPrimary),
            SizedBox(width: 8),
            Text('No Connection', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'It seems like you are not connected to the internet. Please check your connection and try again.',
          style: TextStyle(color: kTextSub),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _run(); // Retry
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated Shield ───────────────────────────────────────
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_entranceCtrl, _pulseCtrl, _rotateCtrl]),
              builder: (_, child) {
                final scale = _shieldScale.value * _pulse.value;
                return Opacity(
                  opacity: _shieldFade.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Rotating segmented arc
                          Transform.rotate(
                            angle: _rotateCtrl.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(150, 150),
                              painter: _SegmentedArcPainter(),
                            ),
                          ),
                          // Inner glowing red box
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: kPrimary,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20), // Smoother border
                            child: Image.asset(
                              'assets/images/app_iconv2.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 36),

            // ── App Name + Tagline ────────────────────────────────────
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(children: [
                  const Text(
                    'Agil',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AI-powered scam protection',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  _ScanningDots(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Segmented rotating arc ────────────────────────────────────────────────

class _SegmentedArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track background
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, bgPaint);

    // Three arc segments with decreasing opacity
    final segments = [
      (sweepDeg: 200.0, opacity: 0.8),
      (sweepDeg: 60.0,  opacity: 0.4),
      (sweepDeg: 25.0,  opacity: 0.2),
    ];

    double startAngle = -math.pi / 2; // top
    const gapAngle = 8.0 * math.pi / 180;

    for (final seg in segments) {
      final sweep = seg.sweepDeg * math.pi / 180;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: seg.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Animated scanning dots ────────────────────────────────────────────────

class _ScanningDots extends StatefulWidget {
  @override
  State<_ScanningDots> createState() => _ScanningDotsState();
}

class _ScanningDotsState extends State<_ScanningDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Initializing',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          ...List.generate(3, (i) {
            final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1.0 - t) * 2)
                .clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(opacity),
              ),
            );
          }),
        ],
      ),
    );
  }
}
