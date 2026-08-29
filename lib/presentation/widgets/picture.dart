import 'dart:math' show pi;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/colours.dart';

const _outline = 6.0;
const _shadow = Color(0x383C280A);

/// A whole degree from -4 to 4 that is the same every time for [name].
int tiltOf(String name) {
  var h = 0;
  for (final c in name.codeUnits) {
    h = (h * 31 + c).toSigned(32);
  }
  return h.abs() % 9 - 4;
}

/// A library picture by name, or `emoji:<x>` as text. A name with no file
/// shows a plain circle.
class Picture extends StatelessWidget {
  const Picture(this.name, {super.key, this.size = 96, this.sticker = false});

  final String name;
  final double size;
  final bool sticker;

  @override
  Widget build(BuildContext context) {
    final Widget art;
    if (name.startsWith('emoji:')) {
      art = Text(
        name.substring('emoji:'.length),
        style: TextStyle(fontSize: size * 0.8),
        textScaler: TextScaler.noScaling,
      );
    } else {
      art = SvgPicture.asset(
        'assets/pictures/$name.svg',
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => SizedBox.square(
          dimension: size * 0.6,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colours.paperDeep,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    final box = SizedBox.square(
      dimension: size,
      child: Center(child: art),
    );
    return sticker ? StickerOutline(name: name, child: box) : box;
  }
}

/// A white outline that follows the shape of [child], a soft shadow under it
/// and the tilt of [name]. The outline and shadow sit in 6 logical px of
/// padding on every side, so the widget is the child's size plus 12 on each axis.
class StickerOutline extends StatelessWidget {
  const StickerOutline({super.key, required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grow = ImageFilter.dilate(radiusX: _outline, radiusY: _outline);
    return Transform.rotate(
      angle: tiltOf(name) * pi / 180,
      child: Padding(
        padding: const EdgeInsets.all(_outline),
        child: Stack(
          children: [
            Transform.translate(
              offset: const Offset(0, 4),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ImageFiltered(
                  imageFilter: grow,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      _shadow,
                      BlendMode.srcIn,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
            ImageFiltered(
              imageFilter: grow,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                child: child,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
