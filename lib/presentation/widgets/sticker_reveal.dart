import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/motion.dart';
import 'sticker_view.dart';

/// Shows [sticker] big in the middle, plays it once with its sound, then moves
/// it to [to] (or shrinks it in place) and closes; a tap closes it at once.
Future<void> showStickerReveal(
  BuildContext context,
  String sticker, {
  Rect? to,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  barrierLabel: '',
  transitionDuration: Motion.long,
  pageBuilder: (context, animation, secondaryAnimation) =>
      _Reveal(sticker: sticker, to: to),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(
        opacity: animation.drive(CurveTween(curve: Motion.curve)),
        child: child,
      ),
);

const _total = 3100.0;
const _open = 300.0;
const _flightStart = 2500.0;
const _fadeOut = 150.0;
const _fade = 250.0;
const _size = 240.0;
const _rise = Cubic(0.2, 1.3, 0.4, 1);
const _veil = Color(0xF5FBF6EA);

double _mix(double a, double b, double t) => a + (b - a) * t;

class _Reveal extends ConsumerStatefulWidget {
  const _Reveal({required this.sticker, required this.to});

  final String sticker;
  final Rect? to;

  @override
  ConsumerState<_Reveal> createState() => _RevealState();
}

class _RevealState extends ConsumerState<_Reveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3100),
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(sfxProvider).sticker(widget.sticker));
    unawaited(_controller.forward().whenComplete(_close));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final to = widget.to;
    final middle = screen.center(Offset.zero);
    return PopScope(
      // The back button pops the route itself; stop the end of the timeline
      // popping again.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _closed = true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: AnimatedBuilder(
          animation: _controller,
          // Built once; only the transform and opacity around it change.
          child: IgnorePointer(
            child: StickerView(
              widget.sticker,
              size: _size,
              playAfter: Duration.zero,
            ),
          ),
          builder: (context, sticker) {
            final ms = _controller.value * _total;
            final double veil;
            final double opacity;
            var scale = 1.0;
            var centre = middle;
            if (reduced) {
              veil = opacity =
                  math.min(ms / _fade, 1) * math.min((_total - ms) / _fade, 1);
            } else {
              final rise = _rise.transform((ms / _open).clamp(0.0, 1.0));
              final shown = rise.clamp(0.0, 1.0);
              final e = Curves.easeInOut.transform(
                ((ms - _flightStart) / (_total - _flightStart)).clamp(0.0, 1.0),
              );
              scale = 0.6 + 0.4 * rise;
              if (to == null) {
                scale *= _mix(1, 0.6, e);
                veil = opacity = shown * (1 - e);
              } else {
                centre = Offset.lerp(middle, to.center, e)!;
                scale *= _mix(_size, to.shortestSide, e) / _size;
                veil = shown * (1 - e);
                opacity = shown * ((_total - ms) / _fadeOut).clamp(0.0, 1.0);
              }
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: veil.clamp(0.0, 1.0),
                  child: const ColoredBox(color: _veil),
                ),
                Positioned(
                  left: centre.dx - _size / 2,
                  top: centre.dy - _size / 2,
                  width: _size,
                  height: _size,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.scale(scale: scale, child: sticker),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
