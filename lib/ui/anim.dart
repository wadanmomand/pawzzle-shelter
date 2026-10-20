/// Juice: bounce-on-press buttons, page transitions, confetti bursts,
/// and rolling currency counters. No new dependencies — pure Flutter.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shelter/ui/theme.dart';

/// Wraps any tappable child with a press-down scale bounce (0.94 -> 1.0).
class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BounceButton({super.key, required this.child, required this.onTap});

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.94,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) => _c.forward(),
      onTapCancel: () => _c.forward(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _c, child: widget.child),
    );
  }
}

/// Page route with a soft fade + slight scale-up transition.
PageRouteBuilder<T> fadeScaleRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Fire-and-forget confetti burst over the whole screen (1.4s, then gone).
class ConfettiBurst {
  static void show(BuildContext context) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiOverlay(
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _ConfettiOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiOverlay({required this.onDone});

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _Particle {
  double x, y, vx, vy, size, rot, vr;
  Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.size, this.rot, this.vr,
      this.color);
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rand = Random();
  late final List<_Particle> _parts;

  static const _colors = [
    Color(0xFFFFD54F), // gold
    Color(0xFFFF8A65), // coral
    Color(0xFF4DB6AC), // teal
    Colors.white,
    Color(0xFFFFB300),
  ];

  @override
  void initState() {
    super.initState();
    _parts = List.generate(64, (_) {
      final a = _rand.nextDouble() * 2 * pi;
      final sp = 220 + _rand.nextDouble() * 420;
      return _Particle(
        0.5,
        0.35,
        cos(a) * sp,
        sin(a) * sp - 260,
        5 + _rand.nextDouble() * 7,
        _rand.nextDouble() * 2 * pi,
        (_rand.nextDouble() - 0.5) * 12,
        _colors[_rand.nextInt(_colors.length)],
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final t = _c.value;
    // integrate: v += g*dt style — cheap Euler with fixed step per frame value
    return IgnorePointer(
      child: CustomPaint(
        size: size,
        painter: _ConfettiPainter(_parts, t, size),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> parts;
  final double t;
  final Size screen;
  _ConfettiPainter(this.parts, this.t, this.screen);

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1.0 - t).clamp(0.0, 1.0);
    for (final p in parts) {
      // closed-form-ish motion: pos = p0 + v*t + 0.5*g*t^2 (t in seconds)
      final tt = t * 1.4;
      final x = (p.x + p.vx * tt / screen.width) * screen.width;
      final y = (p.y + p.vy * tt / screen.height + 520 * tt * tt / screen.height) *
          screen.height;
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.vr * tt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.62),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

/// Currency text that rolls/fades when the value changes.
class AnimatedNumber extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const AnimatedNumber({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 130),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.18), end: Offset.zero)
            .animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Text(
        text,
        key: ValueKey(text),
        style: style ??
            const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textDark,
            ),
      ),
    );
  }
}
