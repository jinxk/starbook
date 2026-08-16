import 'package:flutter/animation.dart';

abstract final class Motion {
  // Page and screen changes run between short and long.
  static const short = Duration(milliseconds: 150);
  static const long = Duration(milliseconds: 250);
  static const curve = Curves.easeOut;
}
