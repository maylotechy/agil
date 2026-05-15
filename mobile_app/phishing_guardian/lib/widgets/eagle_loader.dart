import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../main.dart';

/// Reusable animated eagle loader — replaces CircularProgressIndicator
/// throughout the app for a consistent branded loading experience.
class EagleLoader extends StatefulWidget {
  final double size;
  final String? message;
  const EagleLoader({super.key, this.size = 80, this.message});

  @override
  State<EagleLoader> createState() => _EagleLoaderState();
}

class _EagleLoaderState extends State<EagleLoader>
    with TickerProviderStateMixin {
  late final AnimationController _rotate;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _rotate = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _rotate.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: Listenable.merge([_rotate, _pulse]),
        builder: (_, __) => Transform.scale(
          scale: _pulseAnim.value,
          child: SizedBox(
            width: s, height: s,
            child: Stack(alignment: Alignment.center, children: [
              // Rotating segmented arc
              Transform.rotate(
                angle: _rotate.value * 2 * math.pi,
                child: CustomPaint(size: Size(s, s), painter: _ArcPainter()),
              ),
              // Glow circle
              Container(
                width: s * 0.68, height: s * 0.68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimary.withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                        color: kPrimary.withValues(alpha: 0.2),
                        blurRadius: 14, spreadRadius: 2)
                  ],
                ),
              ),
              // App Icon v2
              ClipRRect(
                borderRadius: BorderRadius.circular(s * 0.15),
                child: Image.asset(
                  'assets/images/app_iconv2.png',
                  width: s * 0.55,
                  height: s * 0.55,
                ),
              ),
            ]),
          ),
        ),
      ),
      if (widget.message != null) ...[
        SizedBox(height: s * 0.18),
        Text(widget.message!,
            style: const TextStyle(color: kTextSub, fontSize: 13)),
      ],
    ]);
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint track
    canvas.drawCircle(center, radius,
        Paint()
          ..color = kPrimary.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // Segments
    final segs = [
      (deg: 200.0, alpha: 1.0),
      (deg: 60.0, alpha: 0.50),
      (deg: 25.0, alpha: 0.22),
    ];
    double start = -math.pi / 2;
    const gap = 8 * math.pi / 180;
    for (final s in segs) {
      final sweep = s.deg * math.pi / 180;
      canvas.drawArc(
        rect, start, sweep, false,
        Paint()
          ..color = kPrimary.withValues(alpha: s.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
