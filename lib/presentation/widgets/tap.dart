import 'package:flutter/widgets.dart';

/// A child-facing button: it shrinks the moment a finger lands and ignores
/// repeats within 300ms of the last tap it accepted.
class Tap extends StatefulWidget {
  const Tap({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedScale = 0.95,
  });

  final VoidCallback onTap;
  final Widget child;
  final double pressedScale;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  static const _repeat = Duration(milliseconds: 300);
  bool _down = false;
  DateTime? _last;

  void _set(bool down) => setState(() => _down = down);

  void _tap() {
    final now = DateTime.now();
    final last = _last;
    if (last != null && now.difference(last) < _repeat) return;
    _last = now;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 100),
          child: widget.child,
        ),
      ),
    );
  }
}
