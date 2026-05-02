import 'dart:math' as math;

import 'package:fishing_with_friends/core/router/app_router.dart';
import 'package:fishing_with_friends/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Animated cold-start splash. Choreographs four overlapping phases on a
/// single controller — fish dive-in, wordmark, water ripple, studio
/// attribution — then routes to /home. Background matches the native
/// splash exactly (`AppColors.navyDeep`) so the handoff is invisible.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _totalDuration = Duration(milliseconds: 2600);
  static const _holdAfter = Duration(milliseconds: 350);

  late final AnimationController _controller;
  late final Animation<double> _fishScale;
  late final Animation<double> _fishOpacity;
  late final Animation<Offset> _fishOffset;
  late final Animation<double> _ripple;
  late final Animation<double> _wordmark;
  late final Animation<double> _studio;
  late final Animation<double> _exitFade;

  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);

    _fishScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _fishOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.30, curve: Curves.easeOut),
      ),
    );
    _fishOffset = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _ripple = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.85, curve: Curves.easeOut),
    );
    _wordmark = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _studio = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
    );
    _exitFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.92, 1, curve: Curves.easeIn),
    );

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed && !_routed) {
        _routed = true;
        await Future<void>.delayed(_holdAfter);
        if (!mounted) return;
        // Router redirect logic decides the actual destination
        // (sign-in / onboarding / home). We hand off to /home and let
        // the router send the user where they belong.
        context.go(AppRoutes.home);
      }
    });

    // Honor the OS reduced-motion preference: shorten + skip choreography.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disable) {
        _controller.duration = const Duration(milliseconds: 600);
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
          opacity: 1 - _exitFade.value,
          child: Scaffold(
            backgroundColor: AppColors.navyDeep,
            body: SafeArea(
              child: Stack(
                children: [
                  // Subtle vertical gradient — navyDeep at top to navy
                  // near the fish, gives the brand mark depth without
                  // looking gimmicky.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.navyDeep,
                            AppColors.navy,
                            AppColors.navyDeep,
                          ],
                          stops: [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final markSize = math.min(
                          constraints.maxWidth * 0.42,
                          200,
                        ).toDouble();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Spacer(flex: 3),
                            _Mark(
                              size: markSize,
                              scale: _fishScale.value,
                              opacity: _fishOpacity.value,
                              offset: _fishOffset.value,
                              ripple: _ripple.value,
                            ),
                            const SizedBox(height: 32),
                            Opacity(
                              opacity: _wordmark.value,
                              child: Transform.translate(
                                offset: Offset(0, 12 * (1 - _wordmark.value)),
                                child: const _Wordmark(),
                              ),
                            ),
                            const Spacer(flex: 4),
                            Opacity(
                              opacity: _studio.value,
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - _studio.value)),
                                child: const _StudioAttribution(),
                              ),
                            ),
                            const SizedBox(height: 48),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({
    required this.size,
    required this.scale,
    required this.opacity,
    required this.offset,
    required this.ripple,
  });

  final double size;
  final double scale;
  final double opacity;
  final Offset offset;
  final double ripple;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.8,
      height: size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Expanding water-ripple rings
          for (var i = 0; i < 3; i++)
            Opacity(
              opacity: (1 - ripple) * 0.35 *
                  (i == 0 ? 1 : (i == 1 ? 0.7 : 0.45)),
              child: Container(
                width: size * (1.0 + ripple * (1.4 + i * 0.4)),
                height: size * (1.0 + ripple * (1.4 + i * 0.4)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              ),
            ),
          // The fish itself
          Transform.translate(
            offset: Offset(offset.dx * size, offset.dy * size),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: const _FishMark(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vector fish silhouette — drawn directly so it stays crisp at any
/// density. Mirrors the placeholder PNG's body+tail composition but
/// with cleaner curves.
class _FishMark extends StatelessWidget {
  const _FishMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FishPainter());
  }
}

class _FishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final body = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.fill;
    final highlight = Paint()
      ..color = AppColors.orangeDeep
      ..style = PaintingStyle.fill;
    final eye = Paint()
      ..color = AppColors.navyDeep
      ..style = PaintingStyle.fill;
    final eyeShine = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Body — horizontal teardrop pointing right
    final bodyPath = Path()
      ..moveTo(cx - w * 0.18, cy)
      ..cubicTo(
        cx - w * 0.18, cy - h * 0.30,
        cx + w * 0.20, cy - h * 0.30,
        cx + w * 0.36, cy,
      )
      ..cubicTo(
        cx + w * 0.20, cy + h * 0.30,
        cx - w * 0.18, cy + h * 0.30,
        cx - w * 0.18, cy,
      )
      ..close();
    canvas.drawPath(bodyPath, body);

    // Tail — triangle pointing left
    final tailPath = Path()
      ..moveTo(cx - w * 0.14, cy)
      ..lineTo(cx - w * 0.40, cy - h * 0.22)
      ..lineTo(cx - w * 0.34, cy)
      ..lineTo(cx - w * 0.40, cy + h * 0.22)
      ..close();
    canvas.drawPath(tailPath, body);

    // Belly highlight — subtle deeper-orange wedge underneath
    final bellyPath = Path()
      ..moveTo(cx - w * 0.10, cy + h * 0.06)
      ..cubicTo(
        cx + w * 0.05, cy + h * 0.24,
        cx + w * 0.22, cy + h * 0.18,
        cx + w * 0.30, cy + h * 0.04,
      )
      ..cubicTo(
        cx + w * 0.18, cy + h * 0.12,
        cx + w * 0.04, cy + h * 0.14,
        cx - w * 0.10, cy + h * 0.06,
      )
      ..close();
    canvas.drawPath(bellyPath, highlight);

    // Top fin
    final finPath = Path()
      ..moveTo(cx - w * 0.04, cy - h * 0.22)
      ..quadraticBezierTo(
        cx + w * 0.04, cy - h * 0.34,
        cx + w * 0.12, cy - h * 0.22,
      )
      ..close();
    canvas
      ..drawPath(finPath, highlight)
      // Eye + shine
      ..drawCircle(Offset(cx + w * 0.18, cy - h * 0.06), w * 0.035, eye)
      ..drawCircle(
        Offset(cx + w * 0.19, cy - h * 0.07),
        w * 0.012,
        eyeShine,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Fishing with Friends',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _StudioAttribution extends StatelessWidget {
  const _StudioAttribution();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'a Bunshin Development Studios product',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
