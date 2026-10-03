import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../theme/colours.dart';

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _fallback = [
  Colours.tomato,
  Colours.sunflower,
  Colours.leaf,
  Colours.sky,
  Colours.plum,
  Colours.sand,
];

/// The language of the week's sheet: its own, else its pack's, else en-IN.
String sheetLanguage(List<Pack> packs, Week week) {
  final packId = week.sheetRef.split('/').first;
  final pack = packs.where((p) => p.id == packId).firstOrNull;
  return week.sheet.language ?? pack?.language ?? 'en-IN';
}

/// The colour the pack names for [day], else one picked from the weekday.
Color dayColour(Day day) =>
    Colours.byName(day.colour) ?? _fallback[day.weekday.index % 6];

/// Text and icons on [c]: white, except ink on sunflower and sand.
Color onColour(Color c) =>
    c == Colours.sunflower || c == Colours.sand ? Colours.ink : Colors.white;

/// [c] as a heading on paper; sunflower is too pale there.
Color titleColour(Color c) =>
    c == Colours.sunflower ? const Color(0xFF9A6A00) : c;

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

const _svg = 'xmlns="http://www.w3.org/2000/svg"';

/// An empty slot: a dashed circle [size] wide with a [border] wide line.
Widget dashedCircle(double size, double border) => SvgPicture.string(
  '<svg $_svg viewBox="0 0 $size $size"><circle cx="${size / 2}" '
  'cy="${size / 2}" r="${(size - border) / 2}" fill="none" '
  'stroke="${_hex(Colours.dash)}" stroke-width="$border" '
  'stroke-dasharray="${border * 2} ${border * 1.5}"/></svg>',
  width: size,
  height: size,
);

/// The empty big star of a day that is not finished.
final dashedStar = SvgPicture.string(
  '<svg $_svg viewBox="0 0 24 24" fill="none" stroke="${_hex(Colours.dash)}" '
  'stroke-width="1.6" stroke-dasharray="2.5 2" stroke-linejoin="round">'
  '<path d="M12 2.8l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17.2l-5.6 3 1.1-6.3'
  '-4.6-4.4 6.3-.9z"/></svg>',
  width: 44,
  height: 44,
);

/// An empty album place: a dashed rounded square as wide as the space it gets.
Widget dashedSquare() => LayoutBuilder(
  builder: (context, box) => SvgPicture.string(
    '<svg $_svg viewBox="0 0 ${box.maxWidth} ${box.maxWidth}"><rect x="1" '
    'y="1" width="${box.maxWidth - 2}" height="${box.maxWidth - 2}" rx="14" '
    'fill="none" stroke="#e3d8bf" stroke-width="2" '
    'stroke-dasharray="4 3"/></svg>',
    width: box.maxWidth,
    height: box.maxWidth,
  ),
);

/// A dashed line as wide as the space it gets.
Widget dashedLine() => LayoutBuilder(
  builder: (context, box) => SvgPicture.string(
    '<svg $_svg viewBox="0 0 ${box.maxWidth} 2"><line x1="0" y1="1" '
    'x2="${box.maxWidth}" y2="1" stroke="${_hex(Colours.paperDeep)}" '
    'stroke-width="1.5" stroke-dasharray="4 3"/></svg>',
    width: box.maxWidth,
    height: 2,
  ),
);
