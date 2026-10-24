import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/speaker.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/motion.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';
import '../widgets/picture.dart';
import '../widgets/tap.dart';
import 'day_screen.dart';

const _words = [
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
];
const _endLine = 'You got to the end!';
const _lit = Color(0xFFFFEDB8);

/// The 1 to 10 board: spin 1 or 2, move the token, hear each number. It
/// stores nothing.
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  late final Speaker _speaker;
  // 0 is the start cell.
  var _at = 0;
  int? _spin;
  var _moving = false;
  var _turns = 0.0;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
  }

  @override
  void dispose() {
    unawaited(_speaker.stop());
    super.dispose();
  }

  void _spinOnce() {
    if (_spin != null) return;
    final spin = ref.read(randomProvider).nextInt(2) + 1;
    // The arrow points up at 0 turns, at the left half ("1") at 0.75 and at
    // the right half ("2") at 0.25.
    setState(() {
      _spin = spin;
      _turns = _turns.ceilToDouble() + 2 + (spin == 1 ? 0.75 : 0.25);
    });
  }

  Future<void> _move() async {
    if (_spin == null || _moving) return;
    _moving = true;
    final to = min(_at + _spin!, 10);
    while (_at < to) {
      setState(() => _at++);
      await _speaker.speakWord(_words[_at - 1], 'en-IN');
      if (!mounted) return;
    }
    setState(() {
      _spin = null;
      _moving = false;
    });
    if (_at == 10) unawaited(_speaker.speakSentence(_endLine, 'en-IN'));
  }

  void _again() {
    unawaited(_speaker.stop());
    setState(() => _at = 0);
  }

  Widget _cell(int i, double cell) {
    if (i == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colours.dash, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: i == _at ? _lit : Colours.card,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colours.paperDeep, offset: Offset(0, 2)),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$i',
          style: TextStyles.wordCard.copyWith(
            fontSize: min(40.0, cell * 0.8),
            color: Colours.ink,
          ),
        ),
      ),
    );
  }

  Widget _half(int n, Color fill, Color on, double dial) => Opacity(
    opacity: _spin == null || _spin == n ? 1 : 0.35,
    child: ColoredBox(
      color: fill,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            '$n',
            textScaler: TextScaler.noScaling,
            style: TextStyles.wordCard.copyWith(
              fontSize: dial * 0.28,
              color: on,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              for (var i = 0; i < n; i++)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: on, shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _spinner(double dial, bool still) => Semantics(
    label: 'Spin',
    button: true,
    excludeSemantics: true,
    child: Tap(
      onTap: _spinOnce,
      child: SizedBox.square(
        dimension: dial,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Row(
                children: [
                  Expanded(child: _half(1, Colours.sky, Colors.white, dial)),
                  Expanded(
                    child: _half(2, Colours.sunflower, Colours.ink, dial),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _turns,
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              child: SizedBox.square(
                dimension: dial,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: dial * 0.14),
                    child: Container(
                      width: 10,
                      height: dial * 0.36,
                      decoration: BoxDecoration(
                        color: Colours.ink,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colours.paper,
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colours.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final picture = ref.watch(thisWeekProvider).value?.child?.picture;
    final token = picture == null || picture.isEmpty ? 'teddy-bear' : picture;
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const BackDisc(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Count to 10',
                      style: TextStyles.childTitle.copyWith(
                        fontSize: 30,
                        color: Colours.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final cell = (box.maxWidth - 48) / 11;
                  final cellHeight = (cell * 1.6).clamp(48.0, 96.0);
                  final dial = min(box.maxWidth * 0.55, 220.0);
                  final line = SizedBox(
                    width: cell * 11,
                    height: 80 + cellHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: cellHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i <= 10; i++)
                                SizedBox(
                                  width: cell,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    child: _cell(i, cell),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AnimatedPositioned(
                          duration: still ? Duration.zero : Motion.long,
                          curve: Motion.curve,
                          left: _at * cell + cell / 2 - 36,
                          top: 0,
                          width: 72,
                          height: 72,
                          child: Semantics(
                            label: 'Move',
                            button: true,
                            excludeSemantics: true,
                            child: Tap(
                              onTap: () => unawaited(_move()),
                              child: Picture(token, size: 60, sticker: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            line,
                            const SizedBox(height: 40),
                            if (_at == 10)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: OpenBar(
                                  'Play again',
                                  Colours.sky,
                                  onTap: _again,
                                ),
                              )
                            else
                              _spinner(dial, still),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
