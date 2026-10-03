import 'package:flutter/painting.dart';

abstract final class Fonts {
  static const baloo = 'Baloo2';
  static const andika = 'Andika';
  static const hind = 'Hind';
}

abstract final class TextStyles {
  static const childTitle = TextStyle(
    fontFamily: Fonts.baloo,
    fontSize: 40,
    fontWeight: FontWeight.w700,
  );

  static const childLabel = TextStyle(
    fontFamily: Fonts.baloo,
    fontSize: 28,
    fontWeight: FontWeight.w600,
  );

  static const story = TextStyle(
    fontFamily: Fonts.andika,
    fontFamilyFallback: [Fonts.baloo],
    fontSize: 40,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const storyMinSize = 32.0;

  static const wordCard = TextStyle(
    fontFamily: Fonts.andika,
    fontFamilyFallback: [Fonts.baloo],
    fontSize: 72,
    fontWeight: FontWeight.w700,
  );

  static const coverLetter = TextStyle(
    fontFamily: Fonts.andika,
    fontFamilyFallback: [Fonts.baloo],
    fontSize: 92,
    fontWeight: FontWeight.w700,
  );
}
