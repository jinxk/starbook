import 'package:flutter/painting.dart';

abstract final class Colours {
  static const paper = Color(0xFFFBF6EA);
  static const paperDeep = Color(0xFFF1E8D3);
  static const ink = Color(0xFF2B2A33);
  static const inkSoft = Color(0xFF67646E);
  static const tomato = Color(0xFFE8553D);
  static const sunflower = Color(0xFFF5B82E);
  static const leaf = Color(0xFF2E7D4F);
  static const sky = Color(0xFF3C8DD6);
  static const plum = Color(0xFF8A4FA3);
  static const sand = Color(0xFFC9774B);
  static const card = Color(0xFFFFFDF7);
  static const dash = Color(0xFFD8CCB0);
  static const parentPaper = Color(0xFFF7F3EA);

  /// The colour called [name] in a pack, or null for any other text.
  static Color? byName(String? name) => switch (name) {
    'tomato' => tomato,
    'sunflower' => sunflower,
    'leaf' => leaf,
    'sky' => sky,
    'plum' => plum,
    'sand' => sand,
    _ => null,
  };
}
