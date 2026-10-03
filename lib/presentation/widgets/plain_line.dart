import 'package:flutter/material.dart';

import '../theme/colours.dart';
import '../theme/type.dart';

const notSaved = 'That did not save. Please try again.';
const notSavedChild = 'Please try that again.';

void showLine(ScaffoldMessengerState messenger, String text) {
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: const TextStyle(
            fontFamily: Fonts.hind,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        duration: const Duration(seconds: 4),
        persist: false,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colours.ink,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}
