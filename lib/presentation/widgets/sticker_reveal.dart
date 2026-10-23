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

/// Shows [stickers] together in rows, each popping in turn with its sound,
/// then calls [say] and, when the line ends (4 seconds at most), moves them
/// all to [to] (or shrinks them in place) and closes; a tap closes it at once.
Future<void> showGroupReveal(
  BuildContext context,
  List<String> stickers, {
  Rect? to,
  required Future<bool> Function() say,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  barrierLabel: '',
  transitionDuration: Motion.long,
  pageBuilder: (context, animation, secondaryAnimation) =>
      _GroupReveal(stickers: stickers, to: to, say: say),
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
const _gap = 900.0;
const _flight = 600.0;
const _space = 16.0;
const _lineCap = Duration(seconds: 4);

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
    final route = ModalRoute.of(context);
    if (route == null) return;
    // Another screen may have opened over the reveal; leave that one alone.
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
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

class _GroupReveal extends ConsumerStatefulWidget {
  const _GroupReveal({
    required this.stickers,
    required this.to,
    required this.say,
  });

  final List<String> stickers;
  final Rect? to;
  final Future<bool> Function() say;

  @override
  ConsumerState<_GroupReveal> createState() => _GroupRevealState();
}

class _GroupRevealState extends ConsumerState<_GroupReveal>
    with SingleTickerProviderStateMixin {
  late final _hold = _gap * widget.stickers.length;
  late final _length = _hold + _flight;
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _length.round()),
    animationBehavior: AnimationBehavior.preserve,
  );
  // Stickers whose sound has started, in order.
  int _sounded = 0;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sounds);
    _sounds();
    unawaited(_play());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sounds() {
    final ms = _controller.value * _length;
    while (!_closed &&
        _sounded < widget.stickers.length &&
        ms >= _gap * _sounded) {
      unawaited(ref.read(sfxProvider).sticker(widget.stickers[_sounded]));
      _sounded++;
    }
  }

  Future<void> _play() async {
    await _controller.animateTo(_hold / _length);
    if (!mounted || _closed) return;
    await widget.say().timeout(_lineCap, onTimeout: () => false);
    if (!mounted || _closed) return;
    await _controller.forward();
    _close();
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    final route = ModalRoute.of(context);
    if (route == null) return;
    // Another screen may have opened over the reveal; leave that one alone.
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final to = widget.to;
    final n = widget.stickers.length;
    final perRow = n >= 10 ? 4 : 3;
    final base = n >= 10 ? 84.0 : 112.0;
    final rows = (n + perRow - 1) ~/ perRow;
    final fit = math.min(
      1.0,
      math.min(
        screen.width / (perRow * base + (perRow - 1) * _space),
        screen.height / (rows * base + (rows - 1) * _space),
      ),
    );
    final step = (base + _space) * fit;
    final size = base * fit;
    final middle = screen.center(Offset.zero);
    final places = [
      for (var i = 0; i < n; i++)
        middle +
            Offset(
              (i % perRow -
                      (math.min(perRow, n - i ~/ perRow * perRow) - 1) / 2) *
                  step,
              (i ~/ perRow - (rows - 1) / 2) * step,
            ),
    ];
    // Built once; only the transforms and opacities around them change.
    final views = [
      for (var i = 0; i < n; i++)
        IgnorePointer(
          child: StickerView(
            widget.stickers[i],
            size: base,
            playAfter: Duration(milliseconds: (_gap * i).round()),
          ),
        ),
    ];
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
          builder: (context, _) {
            final ms = _controller.value * _length;
            final out = ((_length - ms) / (reduced ? _fade : _fadeOut)).clamp(
              0.0,
              1.0,
            );
            final e = reduced
                ? 0.0
                : Curves.easeInOut.transform(
                    ((ms - _hold) / _flight).clamp(0.0, 1.0),
                  );
            double shown(int i) {
              final t = ms - _gap * i;
              return reduced
                  ? (t / _fade).clamp(0.0, 1.0)
                  : _rise
                        .transform((t / _open).clamp(0.0, 1.0))
                        .clamp(0.0, 1.0);
            }

            Widget placed(int i) {
              var scale = fit;
              var centre = places[i];
              var opacity = shown(i) * out;
              if (!reduced) {
                final rise = _rise.transform(
                  ((ms - _gap * i) / _open).clamp(0.0, 1.0),
                );
                scale *= 0.6 + 0.4 * rise;
                if (to == null) {
                  scale *= _mix(1, 0.6, e);
                  opacity = shown(i) * (1 - e);
                } else {
                  centre = Offset.lerp(centre, to.center, e)!;
                  scale *= _mix(size, to.shortestSide, e) / size;
                }
              }
              return Positioned(
                left: centre.dx - base / 2,
                top: centre.dy - base / 2,
                width: base,
                height: base,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(scale: scale, child: views[i]),
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: (shown(0) * (reduced ? out : 1 - e)).clamp(0.0, 1.0),
                  child: const ColoredBox(color: _veil),
                ),
                for (var i = 0; i < n; i++) placed(i),
              ],
            );
          },
        ),
      ),
    );
  }
}
