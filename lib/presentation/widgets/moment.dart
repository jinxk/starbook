import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colours.dart';
import '../theme/motion.dart';
import '../theme/type.dart';
import 'picture.dart';

/// A full-screen moment over the page; a tap closes it, or [closeAfter].
Future<void> showMoment(
  BuildContext context, {
  required String picture,
  required String title,
  String? line,
  bool sparks = false,
  Duration? closeAfter,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: Colors.transparent,
  barrierLabel: '',
  transitionDuration: Motion.long,
  pageBuilder: (context, animation, secondaryAnimation) => _Moment(
    picture: picture,
    title: title,
    line: line,
    sparks: sparks,
    closeAfter: closeAfter,
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(
        opacity: animation.drive(CurveTween(curve: Motion.curve)),
        child: child,
      ),
);

const _rise = Cubic(0.2, 1.3, 0.4, 1);

const _sparkColours = [
  Colours.tomato,
  Colours.sunflower,
  Colours.leaf,
  Colours.sky,
  Colours.plum,
  Colours.sand,
];

class _Moment extends StatefulWidget {
  const _Moment({
    required this.picture,
    required this.title,
    required this.line,
    required this.sparks,
    required this.closeAfter,
  });

  final String picture;
  final String title;
  final String? line;
  final bool sparks;
  final Duration? closeAfter;

  @override
  State<_Moment> createState() => _MomentState();
}

class _MomentState extends State<_Moment> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    animationBehavior: AnimationBehavior.preserve,
  )..forward();
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final after = widget.closeAfter;
    if (after != null) _timer = Timer(after, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    final route = ModalRoute.of(context);
    if (route == null) return;
    // Another screen may have opened over the moment; leave that one alone.
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The back button pops the route itself; stop the timer popping again.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _closed = true;
        _timer?.cancel();
      },
      child: Material(
        color: const Color(0xF5FBF6EA),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final ms = _controller.value * 900;
              final reduced = MediaQuery.disableAnimationsOf(context);
              final t = (ms / 800).clamp(0.0, 1.0);
              final rise = reduced ? t : _rise.transform(t);
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.sparks && !reduced) ..._sparks(ms),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(0, reduced ? 0 : 120 * (1 - rise)),
                          child: Transform.scale(
                            scale: reduced ? 1 : 0.6 + 0.4 * rise,
                            child: Opacity(
                              opacity: rise.clamp(0.0, 1.0),
                              child: Picture(widget.picture, size: 200),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: Fonts.baloo,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            color: Colours.ink,
                          ),
                        ),
                        if (widget.line != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            widget.line!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: Fonts.baloo,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colours.inkSoft,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _spark(int k, double ms, Size size) {
    final t = ((ms - k * 9) / 700).clamp(0.0, 1.0);
    final e = Curves.easeOut.transform(t);
    return Positioned(
      left: size.width / 2 + math.cos(k) * 170 * e,
      top: size.height * 0.4 + math.sin(k * 1.7) * 220 * e,
      child: Opacity(
        opacity: 1 - e,
        child: Transform.rotate(
          angle: 260 * e * math.pi / 180,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _sparkColours[k % 6],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sparks(double ms) {
    final size = MediaQuery.sizeOf(context);
    return [
      for (var k = 0; k < 22; k++)
        if (ms > k * 9) _spark(k, ms, size),
    ];
  }
}
