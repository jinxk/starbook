import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/motion.dart';
import 'picture.dart';

double _radians(double degrees) => degrees * pi / 180;

final _rotation = TweenSequence<double>([
  for (final (from, to, weight) in [
    (0.0, -8.0, 30.0),
    (-8.0, 5.0, 30.0),
    (5.0, 0.0, 40.0),
  ])
    TweenSequenceItem(
      tween: Tween(
        begin: _radians(from),
        end: _radians(to),
      ).chain(CurveTween(curve: Motion.curve)),
      weight: weight,
    ),
]);

final _scale = TweenSequence<double>([
  for (final (from, to, weight) in [
    (1.0, 1.15, 30.0),
    (1.15, 0.95, 30.0),
    (0.95, 1.0, 40.0),
  ])
    TweenSequenceItem(
      tween: Tween(begin: from, end: to).chain(CurveTween(curve: Motion.curve)),
      weight: weight,
    ),
]);

/// A sticker: the Noto animation when there is one, else the still with a
/// wobble. It plays once when it [arriving] and once on each tap.
class StickerView extends StatefulWidget {
  const StickerView(
    this.name, {
    super.key,
    this.size = 96,
    this.arriving = false,
  });

  final String name;
  final double size;
  final bool arriving;

  @override
  State<StickerView> createState() => _StickerViewState();
}

class _StickerViewState extends State<StickerView>
    with TickerProviderStateMixin {
  late final _lottie = AnimationController(vsync: this);
  late final _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  bool _loaded = false;

  @override
  void dispose() {
    _lottie.dispose();
    _wobble.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name == widget.name) return;
    _loaded = false;
    _lottie
      ..stop()
      ..value = 0
      ..duration = null;
    _wobble
      ..stop()
      ..value = 0;
  }

  void _onLoaded(LottieComposition composition) {
    // The outline paints the animation three times, so this fires three times.
    if (!mounted || _loaded) return;
    _loaded = true;
    _lottie.duration = composition.duration;
    if (widget.arriving && !MediaQuery.disableAnimationsOf(context)) {
      _lottie.forward();
    }
  }

  void _onTap() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (_loaded) {
      _lottie.forward(from: 0);
    } else {
      _wobble.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final size = widget.size;
    return GestureDetector(
      onTapDown: (_) => _onTap(),
      child: AnimatedBuilder(
        animation: _wobble,
        builder: (context, child) => Transform.rotate(
          angle: _rotation.evaluate(_wobble),
          child: Transform.scale(scale: _scale.evaluate(_wobble), child: child),
        ),
        child: StickerOutline(
          name: name,
          child: Lottie.asset(
            'assets/stickers/$name.json',
            controller: _lottie,
            onLoaded: _onLoaded,
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/stickers/$name.png',
              width: size,
              height: size,
              errorBuilder: (context, error, stackTrace) =>
                  Picture(name, size: size),
            ),
          ),
        ),
      ),
    );
  }
}
