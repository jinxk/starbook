import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../providers.dart';
import '../sfx.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import 'landing.dart';
import 'picture.dart';
import 'sticker_view.dart';

/// A given award as the child sees it: a star, a stamp or a sticker.
class AwardMark extends ConsumerWidget {
  const AwardMark(
    this.given, {
    super.key,
    required this.size,
    this.landAfter,
    this.step = 1,
  });

  final GivenAward given;
  final double size;

  /// Set only when the award is new to the child.
  final Duration? landAfter;
  final int step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final award = [
      for (final p in ref.read(packRepositoryProvider).installed)
        for (final a in p.awards)
          if ('${p.id}/${a.id}' == given.awardRef) a,
    ].firstOrNull;
    final sticker = given.sticker;
    final landAfter = this.landAfter;
    final Widget mark;
    if (award?.kind == AwardKind.stamp) {
      mark = _Stamp(award!, size);
    } else if (award?.kind == AwardKind.sticker && sticker != null) {
      mark = StickerView(
        sticker,
        size: size * 0.9,
        arriving: landAfter != null,
      );
    } else {
      mark = Picture('star', size: size * 0.8);
    }
    Widget body = FittedBox(fit: BoxFit.scaleDown, child: mark);
    if (landAfter != null) {
      final sfx = ref.read(sfxProvider);
      body = mark is StickerView
          ? Landing(
              kind: LandingKind.press,
              after: landAfter,
              onStart: () => unawaited(sfx.play(Sound.peel)),
              onPress: () {
                unawaited(sfx.play(Sound.press));
                unawaited(HapticFeedback.lightImpact());
              },
              child: body,
            )
          : Landing(
              kind: LandingKind.drop,
              after: landAfter,
              onStart: () => unawaited(sfx.play(Sound.star, step: step)),
              child: body,
            );
    }
    return IgnorePointer(
      child: SizedBox.square(dimension: size, child: body),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.award, this.size);

  final Award award;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -12 * pi / 180,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colours.byName(award.colour) ?? Colours.leaf,
          border: Border.all(color: const Color(0xE6FFFFFF), width: 3),
        ),
        child: FittedBox(
          child: Text(
            award.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Fonts.baloo,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.19,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
