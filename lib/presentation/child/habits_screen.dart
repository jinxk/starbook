import 'dart:async';

import 'package:flutter/material.dart';
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
import '../widgets/picture.dart';
import '../widgets/plain_line.dart';
import '../widgets/tap.dart';
import 'days.dart';

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
  // Habit id to the note step of the star ticked on this visit.
  final _landed = <String, int>{};
  DateTime? _landedOn;
  bool _busy = false;
  late final Speaker _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
  }

  Future<void> _tick(Week week, Habit habit, int step) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await ref
          .read(progressRepositoryProvider)
          .tickHabit(week.id, habit.id);
      if (!mounted) return;
      if (result.isLeft()) {
        showLine(ScaffoldMessenger.of(context), notSavedChild);
        ref.invalidate(habitsTodayProvider);
      } else if (result.getOrElse((_) => false)) {
        setState(() {
          _landed[habit.id] = step;
          _landedOn = DateUtils.dateOnly(DateTime.now());
        });
        ref.invalidate(habitsTodayProvider);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(habitsTodayProvider).value;
    final week = data?.week;
    // Ticks landed before midnight are not today's.
    final landed = _landedOn == DateUtils.dateOnly(DateTime.now())
        ? _landed
        : const <String, int>{};
    final doneToday = {...?data?.done, ...landed.keys};
    return PopScope(
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
                    const BackDisc(),
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
                                landedStep: landed[h.id],
                                onRead: () => unawaited(
                                  _speaker.speakSentence(
                                    h.say ?? h.text,
                                    sheetLanguage(
                                      ref
                                          .read(packRepositoryProvider)
                                          .installed,
                                      week,
                                    ),
                                  ),
                                ),
                                onTick: () =>
                                    _tick(week, h, doneToday.length + 1),
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
    required this.landedStep,
    required this.onRead,
    required this.onTick,
  });

  final Habit habit;
  final bool done;
  final int? landedStep;
  final VoidCallback onRead;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final star = Semantics(
      label: 'Star',
      excludeSemantics: true,
      child: const Picture('star', size: 50),
    );
    final step = landedStep;
    return Tap(
      onTap: () {
        onRead();
        if (!done) onTick();
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
                      child: step != null
                          ? Landing(
                              kind: LandingKind.drop,
                              after: Duration.zero,
                              onStart: () => unawaited(
                                ref
                                    .read(sfxProvider)
                                    .play(Sound.star, step: step),
                              ),
                              child: star,
                            )
                          : star,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
