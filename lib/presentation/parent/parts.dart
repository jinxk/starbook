import 'package:flutter/material.dart';

import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';

const cardBorder = Color(0xFFEBE3D0);
const chipBorder = Color(0xFFE2D8C2);

TextStyle hind(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.hind,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

Widget parentHeader(String title) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
  child: Row(
    spacing: 10,
    children: [
      const BackDisc(),
      Text(title, style: hind(26, FontWeight.w500, Colours.ink)),
    ],
  ),
);

Widget parentHeading(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
  child: Text(
    text.toUpperCase(),
    style: hind(
      13,
      FontWeight.w500,
      Colours.inkSoft,
    ).copyWith(letterSpacing: 0.78),
  ),
);

Widget parentButton(
  String label,
  VoidCallback onPressed, {
  bool ghost = false,
}) => TextButton(
  onPressed: onPressed,
  style: TextButton.styleFrom(
    backgroundColor: ghost ? Colors.transparent : Colours.ink,
    foregroundColor: ghost ? Colours.ink : Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: ghost
          ? const BorderSide(color: Colours.dash, width: 1.5)
          : BorderSide.none,
    ),
    textStyle: hind(16, FontWeight.w500, Colours.ink),
  ),
  child: Text(label),
);

Widget whiteRow({required Widget child, VoidCallback? onTap}) =>
    GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );

/// A bottom sheet; true when the first button is pressed. The sheet rises with
/// the keyboard, so a text field in [row] stays in view.
Future<bool> askSheet(
  BuildContext context,
  String heading, {
  Widget? row,
  String? note,
  required String yes,
  String? no,
}) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: const Color(0x591E190F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(heading, style: hind(20, FontWeight.w500, Colours.ink)),
            const SizedBox(height: 12),
            ?row,
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  note,
                  style: hind(
                    14,
                    FontWeight.w400,
                    Colours.inkSoft,
                  ).copyWith(height: 1.4),
                ),
              )
            else if (row != null)
              const SizedBox(height: 4),
            Row(
              spacing: 10,
              children: [
                parentButton(yes, () => Navigator.of(context).pop(true)),
                if (no != null)
                  parentButton(
                    no,
                    () => Navigator.of(context).pop(false),
                    ghost: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return answer ?? false;
}
