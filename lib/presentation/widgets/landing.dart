import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';

import '../theme/colours.dart';

enum LandingKind { drop, press }

const _drop = Duration(milliseconds: 700);
const _glow = Duration(milliseconds: 400);
const _press = Duration(milliseconds: 650);
const _pressPoint = 0.55;
const _dropCurve = Cubic(0.2, 1.4, 0.4, 1);
const _pressCurve = Cubic(0.3, 1.6, 0.5, 1);

double _radians(double degrees) => degrees * pi / 180;

/// Plays [kind] once, [after] from now; the child is hidden until then.
class Landing extends StatefulWidget {
  const Landing({
    super.key,
    required this.kind,
    required this.after,
    required this.child,
    this.onStart,
    this.onPress,
  });

  final LandingKind kind;
  final Duration after;
  final Widget child;
  final VoidCallback? onStart;

  /// Called once when a press passes 55%.
  final VoidCallback? onPress;

  @override
  State<Landing> createState() => _LandingState();
}

class _LandingState extends State<Landing> with SingleTickerProviderStateMixin {
  // Preserve keeps the timing of the sounds when animations are off.
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.kind == LandingKind.drop ? _drop + _glow : _press,
    animationBehavior: AnimationBehavior.preserve,
  )..addListener(_tick);
  late final Timer _timer;
  bool _started = false;
  bool _pressFired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.after, _start);
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  // No sound or haptic while another screen is open on top.
  bool get _audible => ModalRoute.of(context)?.isCurrent != false;

  void _start() {
    if (!mounted) return;
    if (_audible) widget.onStart?.call();
    setState(() => _started = true);
    _controller.forward();
  }

  void _tick() {
    if (_pressFired || widget.kind != LandingKind.press) return;
    if (_controller.value < _pressPoint) return;
    _pressFired = true;
    if (_audible) widget.onPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return const SizedBox.shrink();
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => widget.kind == LandingKind.drop
          ? _dropped(_controller.value, child!)
          : _pressing(_controller.value, child!),
      child: widget.child,
    );
  }

  Widget _dropped(double value, Widget child) {
    final ms = value * (_drop + _glow).inMilliseconds;
    final t = (ms / _drop.inMilliseconds).clamp(0.0, 1.0);
    final eased = _dropCurve.transform(t);
    final glow = ((ms - _drop.inMilliseconds) / _glow.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (glow > 0 && glow < 1)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colours.sunflower.withValues(alpha: 0.45 * (1 - glow)),
              ),
            ),
          ),
        Opacity(
          opacity: (t / 0.6).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -160 * (1 - eased)),
            child: Transform.scale(
              scale: 1.6 + (1 - 1.6) * eased,
              child: Transform.rotate(
                angle: _radians(-30 * (1 - eased)),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pressing(double value, Widget child) {
    final first = value < _pressPoint;
    final eased = _pressCurve.transform(
      first ? value / _pressPoint : (value - _pressPoint) / (1 - _pressPoint),
    );
    final scale = first
        ? 1.8 + (0.88 - 1.8) * eased
        : 0.88 + (1 - 0.88) * eased;
    final turn = first ? 12 + (-4 - 12) * eased : -4 + 4 * eased;
    return Opacity(
      opacity: first ? eased.clamp(0.0, 1.0) : 1,
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: _radians(turn),
          child: Transform.translate(
            offset: Offset(0, first ? -30 * (1 - eased) : 0),
            child: child,
          ),
        ),
      ),
    );
  }
}
