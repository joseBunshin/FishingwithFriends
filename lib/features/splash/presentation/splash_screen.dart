import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bunshin Development Studios cold-start splash.
///
/// This is the **studio** splash — same brand frame plays before every
/// Bunshin product, not the Fishing with Friends app. Reusable: copy
/// this single file into any future Bunshin Flutter app, point its
/// initial route at `SplashScreen()`, and it works.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// Bunshin studio palette — kept local so the studio splash has zero
// coupling to the host app's color tokens. Any Bunshin app can drop
// this file in and ship.
const _bunshinBg = Color(0xFF0A1A2A);
const _bunshinCyan = Color(0xFF4DD9D9);
const _bunshinCyanDim = Color(0xFF2BA8A8);

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: 3800);
  static const _holdAfter = Duration(milliseconds: 250);

  late final AnimationController _controller;
  late final Animation<double> _markIn;
  late final Animation<double> _wordmarkIn;
  late final Animation<double> _urlIn;
  late final Animation<double> _pacmanProgress;
  late final Animation<double> _exit;

  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);

    // Total duration is 3800ms. Pacman finishes at 0.58 (=2200ms),
    // then we hold the brand frame for ~1s before the exit fade starts
    // at 0.85 (=3230ms).
    _markIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.22, curve: Curves.easeOut),
    );
    _wordmarkIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.33, curve: Curves.easeOut),
    );
    _pacmanProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.58, curve: Curves.easeInOut),
    );
    _urlIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.58, curve: Curves.easeOut),
    );
    _exit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.94, 1, curve: Curves.easeIn),
    );

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed && !_routed) {
        _routed = true;
        await Future<void>.delayed(_holdAfter);
        if (!mounted) return;
        context.go(AppRoutes.home);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disable) {
        _controller.duration = const Duration(milliseconds: 700);
      }
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: 1 - _exit.value,
          child: Scaffold(
            backgroundColor: _bunshinBg,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final markSize = (w * 0.34).clamp(96.0, 180.0);

                  return Stack(
                    children: [
                      // Subtle radial vignette behind the brand mark
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.9,
                              colors: [
                                Color(0xFF14304F),
                                _bunshinBg,
                              ],
                              stops: [0, 1],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Brand mark — subtle scale + fade in
                            Opacity(
                              opacity: _markIn.value,
                              child: Transform.scale(
                                scale: 0.92 + 0.08 * _markIn.value,
                                child: SizedBox(
                                  width: markSize,
                                  height: markSize,
                                  child: const _GhostMark(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            // Wordmark — fade up
                            Opacity(
                              opacity: _wordmarkIn.value,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  10 * (1 - _wordmarkIn.value),
                                ),
                                child: const _Wordmark(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pacman gag — tiny pacman chases a single dot
                      // across the lower portion. On-brand wink without
                      // overpowering the wordmark.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 96,
                        child: SizedBox(
                          height: 16,
                          child: _PacmanRow(progress: _pacmanProgress.value),
                        ),
                      ),
                      // bunshin.io
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 36,
                        child: Opacity(
                          opacity: _urlIn.value,
                          child: const _UrlTag(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Ghost brand mark — vector so it stays crisp at any density.

class _GhostMark extends StatelessWidget {
  const _GhostMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GhostPainter());
  }
}

class _GhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final body = Paint()
      ..color = _bunshinCyan
      ..style = PaintingStyle.fill;
    final glow = Paint()
      ..color = _bunshinCyan.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final eyeWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final pupil = Paint()
      ..color = _bunshinBg
      ..style = PaintingStyle.fill;

    // Geometry — classic Pacman-style ghost.
    // Top: rounded dome. Sides: vertical. Bottom: 4 wave humps.
    final left = w * 0.10;
    final right = w * 0.90;
    final domeHeight = h * 0.55;
    final bodyTop = h * 0.10;
    final bodyBottom = h * 0.86;
    final centerY = bodyTop + domeHeight / 2;
    final radius = (right - left) / 2;
    final cx = (left + right) / 2;

    // Soft glow behind the body
    canvas.drawCircle(Offset(cx, centerY), radius * 1.05, glow);

    final path = Path()
      // Start at lower-left corner of the body
      ..moveTo(left, bodyBottom)
      ..lineTo(left, centerY)
      // Dome — semicircle from lower-left up and over to lower-right
      ..arcToPoint(
        Offset(right, centerY),
        radius: Radius.circular(radius),
      )
      ..lineTo(right, bodyBottom);

    // Wavy bottom — 4 humps total, alternating up-down so the silhouette
    // reads like the classic ghost feet.
    const humps = 4;
    final humpWidth = (right - left) / humps;
    for (var i = 0; i < humps; i++) {
      final startX = right - i * humpWidth;
      final endX = right - (i + 1) * humpWidth;
      final midX = (startX + endX) / 2;
      // Even humps point up (creating the gap between feet);
      // odd ones go up to a peak. This produces the W-W-W shape.
      final peakY = bodyBottom - h * 0.10;
      path
        ..lineTo(midX, peakY)
        ..lineTo(endX, bodyBottom);
    }
    path.close();
    canvas.drawPath(path, body);

    // Eyes — two whites with off-center pupils looking right (toward
    // the wordmark).
    final eyeR = w * 0.10;
    final pupilR = eyeR * 0.55;
    final eyeY = centerY - h * 0.05;
    final leftEye = Offset(cx - w * 0.16, eyeY);
    final rightEye = Offset(cx + w * 0.10, eyeY);
    canvas
      ..drawCircle(leftEye, eyeR, eyeWhite)
      ..drawCircle(rightEye, eyeR, eyeWhite)
      ..drawCircle(
        Offset(leftEye.dx + eyeR * 0.35, leftEye.dy + eyeR * 0.10),
        pupilR,
        pupil,
      )
      ..drawCircle(
        Offset(rightEye.dx + eyeR * 0.35, rightEye.dy + eyeR * 0.10),
        pupilR,
        pupil,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Wordmark + url

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'BUNSHIN',
          style: TextStyle(
            color: _bunshinCyan,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            height: 1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 56,
          height: 1.5,
          color: _bunshinCyanDim,
        ),
        const SizedBox(height: 10),
        const Text(
          'DEVELOPMENT STUDIOS',
          style: TextStyle(
            color: _bunshinCyanDim,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _UrlTag extends StatelessWidget {
  const _UrlTag();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'bunshin.io',
        style: TextStyle(
          color: _bunshinCyan.withValues(alpha: 0.85),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pacman-chasing-the-ghost gag — a quiet wink at the studio mark. A
// single dot sits center-bottom; pacman slides in from the left, eats
// the dot as it passes, exits right.

class _PacmanRow extends StatelessWidget {
  const _PacmanRow({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PacmanPainter(progress: progress));
  }
}

class _PacmanPainter extends CustomPainter {
  _PacmanPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    final r = h * 0.50;

    final yellow = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.fill;
    final dot = Paint()
      ..color = _bunshinCyan.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Pacman travels left → right across the strip
    final pacX = -r * 2 + (w + r * 4) * progress;
    final dotX = w * 0.55;

    // Draw the dot only while pacman hasn't reached it
    if (pacX < dotX - r * 0.6) {
      canvas.drawCircle(Offset(dotX, cy), 2.5, dot);
    }

    // Pacman with chomping mouth — opens 0..40deg over a 180ms cycle
    final chompPhase = (progress * 8) % 1; // 4 chomps over the run
    final mouthOpen = (chompPhase < 0.5
            ? chompPhase * 2
            : (1 - chompPhase) * 2) *
        0.7;
    final mouthAngle = mouthOpen * 0.7; // radians

    final path = Path()
      ..moveTo(pacX, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(pacX, cy), radius: r),
        mouthAngle,
        2 * 3.14159 - 2 * mouthAngle,
        false,
      )
      ..close();
    canvas.drawPath(path, yellow);
  }

  @override
  bool shouldRepaint(covariant _PacmanPainter old) =>
      old.progress != progress;
}
