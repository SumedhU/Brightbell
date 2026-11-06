import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:brightbell/theme/app_theme.dart';

/// Length of the animation, including a short hold on the finished logo.
const _introDuration = Duration(milliseconds: 1820);
const _fadeDuration = Duration(milliseconds: 300);

/// Plays the animated logo while [ready] completes, then fades to [child].
///
/// [child] is built underneath the opaque splash as soon as [ready] completes,
/// so its first frames (such as waiting on auth state) are never visible.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.ready, required this.child});

  final Future<void> ready;
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: _introDuration,
  );
  late final _fade = AnimationController(vsync: this, duration: _fadeDuration);
  bool _childReady = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    final Future<void> intro;
    if (reduceMotion) {
      _intro.value = 1;
      intro = Future.value();
    } else {
      intro = _intro.forward();
    }

    await widget.ready;
    if (!mounted) return;
    setState(() => _childReady = true);

    await intro;
    if (!mounted) return;
    await _fade.forward();
    if (!mounted) return;
    setState(() => _finished = true);
  }

  @override
  void dispose() {
    _intro.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        if (_childReady)
          ExcludeSemantics(excluding: !_finished, child: widget.child),
        if (!_finished)
          AbsorbPointer(
            child: FadeTransition(
              opacity: ReverseAnimation(_fade),
              child: CustomPaint(
                painter: SplashPainter(_intro),
                size: Size.infinite,
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws the logo animation on a 1024-unit square centred on the screen.
///
/// [progress] runs from 0 to 1 across [_introDuration].
class SplashPainter extends CustomPainter {
  SplashPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static const _popCurve = Cubic(.34, 1.56, .64, 1);
  static const _sparkCurve = Cubic(.3, 1.4, .6, 1);
  static const _pivot = Offset(490, 555);

  // Offset by a 70-unit dash that reveals each ~62-unit line from its start.
  static const _sparkDash = 70.0;
  static const _sparkDuration = .32;
  static const _sparks = [
    (start: Offset(696, 199), end: Offset(707, 138), delay: .75),
    (start: Offset(748, 228), end: Offset(794, 187), delay: 1.0),
    (start: Offset(772, 284), end: Offset(834, 279), delay: 1.25),
  ];

  static const _plates = [
    Rect.fromLTWH(214, -145, 96, 290),
    Rect.fromLTWH(-310, -145, 96, 290),
    Rect.fromLTWH(142, -200, 96, 400),
    Rect.fromLTWH(-238, -200, 96, 400),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.cream);

    final scale = math.min(size.width, size.height) / 1024;
    canvas.save();
    canvas.translate(
      (size.width - 1024 * scale) / 2,
      (size.height - 1024 * scale) / 2,
    );
    canvas.scale(scale);

    final seconds = progress.value * _introDuration.inMilliseconds / 1000;
    _paintDumbbell(canvas, seconds);
    for (final spark in _sparks) {
      _paintSpark(canvas, spark, seconds);
    }
    canvas.restore();
  }

  void _paintDumbbell(Canvas canvas, double seconds) {
    final t = ((seconds - .1) / .55).clamp(0.0, 1.0);
    final eased = _popCurve.transform(t);
    final opacity = eased.clamp(0.0, 1.0);
    if (opacity == 0) return;

    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    canvas.translate(_pivot.dx, _pivot.dy);
    canvas.scale(.82 + .18 * eased);
    canvas.rotate((-30 - 8 * (1 - eased)) * math.pi / 180);

    canvas.drawRect(
      const Rect.fromLTWH(-150, -36, 300, 72),
      Paint()..color = AppColors.navy,
    );
    final fill = Paint()..color = AppColors.cream;
    final outline = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..strokeJoin = StrokeJoin.round;
    for (final plate in _plates) {
      final rounded = RRect.fromRectAndRadius(plate, const Radius.circular(30));
      canvas.drawRRect(rounded, fill);
      canvas.drawRRect(rounded, outline);
    }
    canvas.restore();
  }

  void _paintSpark(
    Canvas canvas,
    ({Offset start, Offset end, double delay}) spark,
    double seconds,
  ) {
    final t = ((seconds - spark.delay) / _sparkDuration).clamp(0.0, 1.0);
    if (t == 0) return;

    // The opacity keyframe finishes at 20%, with the curve applied to that span.
    final opacity = t < .2
        ? _sparkCurve.transform(t / .2).clamp(0.0, 1.0)
        : 1.0;
    final dash = _sparkDash * _sparkCurve.transform(t);
    final line = spark.end - spark.start;
    final length = line.distance;
    final from = math.max(0.0, dash - _sparkDash);
    final to = math.min(length, dash);
    if (to <= from) return;

    final direction = line / length;
    canvas.drawLine(
      spark.start + direction * from,
      spark.start + direction * to,
      Paint()
        ..color = AppColors.orange.withValues(alpha: opacity)
        ..strokeWidth = 32
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(SplashPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
