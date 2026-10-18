import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/speaker.dart';
import '../providers.dart';
import '../sfx.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';
import '../widgets/landing.dart';
import '../widgets/moment.dart';
import '../widgets/picture.dart';
import '../widgets/plain_line.dart';
import '../widgets/sticker_reveal.dart';
import '../widgets/sticker_view.dart';
import '../widgets/tap.dart';
import 'days.dart';

const _allDone = 'All done! A new sticker for you!';

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  // Habits ticked on this visit; they press in.
  final _landed = <String>{};
  DateTime? _landedOn;
  bool _busy = false;
  // True from the last tick until the all-done moment opens; Back waits.
  bool _waiting = false;
  late final Speaker _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
  }

  Future<void> _tick(Week week, Habit habit, Future<bool> reading) async {
    if (_busy) return;
    _busy = true;
    try {
      final repository = ref.read(progressRepositoryProvider);
      final result = await repository.tickHabit(week.id, habit.id);
      if (!mounted) return;
      if (result.isLeft()) {
        showLine(ScaffoldMessenger.of(context), notSavedChild);
        ref.invalidate(habitsTodayProvider);
      } else if (result.getOrElse((_) => false)) {
        setState(() {
          _landed.add(habit.id);
          _landedOn = DateUtils.dateOnly(ref.read(clockProvider)());
        });
        ref.invalidate(habitsTodayProvider);
        final sticker = (await repository.takeHabitSticker(
          week.id,
        )).getOrElse((_) => null);
        if (sticker != null && mounted) await _celebrate(sticker, reading);
      }
    } finally {
      _busy = false;
    }
  }

  /// The all-done moment and line, then the new book sticker; the store gives
  /// the sticker once a day.
  Future<void> _celebrate(String sticker, Future<bool> reading) async {
    setState(() => _waiting = true);
    try {
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 700)),
        reading.timeout(const Duration(seconds: 4), onTimeout: () => false),
      ]);
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
    if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
    unawaited(_speaker.speakSentence(_allDone, 'en-IN'));
    await showMoment(
      context,
      picture: 'party-popper',
      title: 'All done!',
      sparks: true,
      closeAfter: const Duration(milliseconds: 2500),
    );
    if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
    await showStickerReveal(context, sticker);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(habitsTodayProvider).value;
    final week = data?.week;
    // Ticks landed before midnight are not today's.
    final landed = _landedOn == DateUtils.dateOnly(ref.watch(clockProvider)())
        ? _landed
        : const <String>{};
    final doneToday = {...?data?.done, ...landed};
    return PopScope(
      canPop: !_waiting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        unawaited(_speaker.stop());
        ref.invalidate(thisWeekProvider);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    BackDisc(enabled: !_waiting),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My good habits',
                        style: _baloo(
                          30,
                          FontWeight.w700,
                          Colours.ink,
                        ).copyWith(height: 1.05),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: week == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 16,
                          children: [
                            for (final h in week.sheet.habits)
                              _HabitRow(
                                h,
                                done: doneToday.contains(h.id),
                                landed: landed.contains(h.id),
                                onRead: () => _speaker.speakSentence(
                                  h.say ?? h.text,
                                  sheetLanguage(
                                    ref.read(packRepositoryProvider).installed,
                                    week,
                                  ),
                                ),
                                onTick: (reading) => _tick(week, h, reading),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitRow extends ConsumerWidget {
  const _HabitRow(
    this.habit, {
    required this.done,
    required this.landed,
    required this.onRead,
    required this.onTick,
  });

  final Habit habit;
  final bool done;
  final bool landed;
  final Future<bool> Function() onRead;
  final void Function(Future<bool> reading) onTick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mark = Semantics(
      label: 'Done',
      excludeSemantics: true,
      child: StickerView(
        habit.sticker ?? habit.picture,
        size: 50,
        picture: habit.sticker == null,
        playAfter: landed ? Duration.zero : null,
      ),
    );
    return Tap(
      onTap: () {
        final reading = onRead();
        if (!done) onTick(reading);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colours.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colours.paperDeep, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Picture(habit.picture, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                habit.text,
                style: _baloo(
                  20,
                  FontWeight.w600,
                  Colours.ink,
                ).copyWith(height: 1.2),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox.square(
              dimension: 62,
              child: !done
                  ? dashedCircle(62, 2.5)
                  : Center(
                      child: landed
                          ? Landing(
                              kind: LandingKind.press,
                              after: Duration.zero,
                              onStart: () => unawaited(
                                ref.read(sfxProvider).play(Sound.peel),
                              ),
                              onPress: () {
                                unawaited(
                                  ref.read(sfxProvider).play(Sound.press),
                                );
                                unawaited(HapticFeedback.lightImpact());
                              },
                              child: mark,
                            )
                          : mark,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
