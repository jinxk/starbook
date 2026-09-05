import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../theme/colours.dart';
import 'tap.dart';

class BackDisc extends StatelessWidget {
  const BackDisc({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Back',
      button: true,
      child: Tap(
        onTap: () => context.pop(),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colours.paperDeep,
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(
            'assets/icons/back.svg',
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(Colours.ink, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
