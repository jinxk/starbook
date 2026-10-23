import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'picture.dart';
import 'sticker_view.dart';

const _hop = 500.0;
const _fade = 250.0;
const _grow = 200.0;
const _rock = 900.0;
const _size = 56.0;
const _small = 26 * 0.9;
const _hopTotal = 1750.0;
const _danceTotal = 1300.0;

double _radians(double degrees) => degrees * math.pi / 180;

double _mix(double a, double b, double t) => a + (b - a) * t;

/// Plays a short surprise over the screen and completes when it ends. With
/// [hop], the picture [name] hops along the [target] row to its big star;
/// otherwise the sticker [name] grows at [target], rocks and shrinks back.
/// It follows [target] each frame, draws nothing while another screen is on
/// top, and taps go through it.
Future<void> showSurprise(
  BuildContext context,
  String name, {
  required GlobalKey target,
  required bool hop,
}) {
  final route = ModalRoute.of(context);
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Surprise(
      name: name,
      target: target,
      hop: hop,
      route: route,
      onEnd: () {
        entry.remove();
        done.complete();
      },
    ),
  );
  Overlay.of(context).insert(entry);
  return done.future;
}

class _Surprise extends StatefulWidget {
  const _Surprise({
    required this.name,
    required this.target,
    required this.hop,
    required this.route,
    required this.onEnd,
  });

  final String name;
  final GlobalKey target;
  final bool hop;
  final ModalRoute<Object?>? route;
  final VoidCallback onEnd;

  @override
  State<_Surprise> createState() => _SurpriseState();
}

class _SurpriseState extends State<_Surprise>
    with SingleTickerProviderStateMixin {
  late final _total = widget.hop ? _hopTotal : _danceTotal;
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _total.round()),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward().whenComplete(widget.onEnd));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _hopping(Rect r, double ms, Widget child) {
    final i = math.min(ms ~/ _hop, 2);
    final u = ms < 1500 ? (ms - _hop * i) / _hop : 1.0;
    final start = r.left + 36;
    final end = r.right - 84;
    final x = _mix(start, end, (i + Curves.easeInOut.transform(u)) / 3);
    final lift = 28 * math.sin(math.pi * u);
    final s = u > 0.85 ? math.sin(math.pi * (u - 0.85) / 0.15) : 0.0;
    var opacity = math.min(1.0, ms / 100);
    if (ms > 1500) opacity *= 1 - (ms - 1500) / _fade;
    // The outlined picture is 12 larger than its art.
    const box = _size + 12;
    return Positioned(
      left: x - box / 2,
      top: r.center.dy - box / 2 - lift,
      width: box,
      height: box,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scaleX: 1 + 0.12 * s,
          scaleY: 1 - 0.15 * s,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  Widget _dancing(Rect r, double ms, Widget child) {
    const small = _small / _size;
    final double scale;
    if (ms < _grow) {
      scale = _mix(small, 1, Curves.easeOut.transform(ms / _grow));
    } else if (ms < _grow + _rock) {
      scale = 1;
    } else {
      scale = _mix(
        1,
        small,
        Curves.easeIn.transform((ms - _grow - _rock) / _grow),
      );
    }
    final angle = ms >= _grow && ms < _grow + _rock
        ? _radians(15 * math.sin(2 * math.pi * 3 * (ms - _grow) / _rock))
        : 0.0;
    return Positioned(
      left: r.center.dx - _size / 2,
      top: r.center.dy - _size / 2,
      width: _size,
      height: _size,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        // Built once; only the position and transforms around it change.
        child: widget.hop
            ? Picture(widget.name, size: _size, sticker: true)
            : StickerView(widget.name, size: _size),
        builder: (context, child) {
          final box = widget.target.currentContext?.findRenderObject();
          if (widget.route?.isCurrent == false ||
              box is! RenderBox ||
              !box.attached) {
            return const SizedBox.shrink();
          }
          final rect = box.localToGlobal(Offset.zero) & box.size;
          final ms = _controller.value * _total;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              widget.hop
                  ? _hopping(rect, ms, child!)
                  : _dancing(rect, ms, child!),
            ],
          );
        },
      ),
    );
  }
}
