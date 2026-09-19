import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/speaker.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/award_mark.dart';
import '../widgets/back_disc.dart';
import '../widgets/picture.dart';
import '../widgets/tap.dart';
import 'days.dart';

const _bonusRow = Color(0xFFFFF7DF);
const _speakingRow = Color(0xFFFFEDB8);

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class DayScreen extends ConsumerWidget {
  const DayScreen(this.weekday, {super.key});

  final Weekday weekday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(thisWeekProvider).value;
    final day = data?.week.sheet.days
        .where((d) => d.weekday == weekday)
        .firstOrNull;
    final colour = day == null ? Colours.ink : dayColour(day);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const BackDisc(),
                  if (day != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekdayNames[weekday.index],
                            style: _baloo(
                              30,
                              FontWeight.w700,
                              titleColour(colour),
                            ).copyWith(height: 1.05),
                          ),
                          Text(
                            day.title,
                            style: _baloo(
                              17,
                              FontWeight.w600,
                              Colours.ink.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: data == null || day == null
                    ? const SizedBox.shrink()
                    : _Tasks(data, day),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tasks extends ConsumerStatefulWidget {
  const _Tasks(this.data, this.day);

  final ThisWeek data;
  final Day day;

  @override
  ConsumerState<_Tasks> createState() => _TasksState();
}

class _TasksState extends ConsumerState<_Tasks> {
  late final Speaker _speaker;
  String? _speaking;

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

  Future<void> _read(Task task, String language) async {
    setState(() => _speaking = task.id);
    final finished = await _speaker.speakSentence(
      task.say ?? task.text,
      language,
    );
    if (finished && mounted) setState(() => _speaking = null);
  }

  // Stops the read before another screen opens on top of this one.
  void _leaveRead() {
    unawaited(_speaker.stop());
    setState(() => _speaking = null);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final day = widget.day;
    final sheet = data.week.sheet;
    final colour = dayColour(day);
    final packs = ref.watch(packRepositoryProvider).installed;
    final language = sheetLanguage(packs, data.week);
    final groups = <Widget>[];
    for (final task in [...day.tasks, ...sheet.everyDay]) {
      final award = data.awards
          .where((a) => a.weekday == day.weekday && a.taskId == task.id)
          .firstOrNull;
      final opens = task.opens;
      final kind = opens == null
          ? null
          : bookKindOf(packs, data.week.sheetRef, opens);
      groups.add(
        Padding(
          padding: EdgeInsets.only(top: groups.isEmpty ? 0 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskRow(
                task,
                award,
                titleColour(colour),
                speaking: _speaking == task.id,
                onTap: () => unawaited(_read(task, task.language ?? language)),
              ),
              if (opens != null && kind != null) ...[
                const SizedBox(height: 16),
                _OpenBar(
                  kind,
                  task.bonus ? Colours.sunflower : colour,
                  onTap: () {
                    _leaveRead();
                    if (kind == BookKind.wordbook) {
                      unawaited(
                        context.push(
                          '/words/${fullRef(data.week.sheetRef, opens)}',
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...groups,
        if (dayDone(sheet, day, data.awards))
          Container(
            margin: const EdgeInsets.fromLTRB(4, 18, 4, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Picture('glowing-star', size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You finished ${weekdayNames[day.weekday.index]}!',
                    style: _baloo(22, FontWeight.w700, onColour(colour)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow(
    this.task,
    this.award,
    this.iconColour, {
    required this.speaking,
    required this.onTap,
  });

  final Task task;
  final GivenAward? award;
  final Color iconColour;
  final bool speaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = task.icon;
    final award = this.award;
    return Tap(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: speaking
              ? _speakingRow
              : (task.bonus ? _bonusRow : Colours.card),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colours.paperDeep, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 52,
              child: icon == null
                  ? null
                  : Center(
                      child: SvgPicture.asset(
                        'assets/icons/$icon.svg',
                        width: 40,
                        height: 40,
                        colorFilter: ColorFilter.mode(
                          iconColour,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.bonus)
                    const Text(
                      'BONUS',
                      style: TextStyle(
                        fontFamily: Fonts.hind,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.52,
                        color: Colours.inkSoft,
                      ),
                    ),
                  Text(
                    task.text,
                    style: _baloo(
                      20,
                      FontWeight.w600,
                      Colours.ink,
                    ).copyWith(height: 1.2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox.square(
              dimension: 62,
              child: award == null
                  ? dashedCircle(62, 2.5)
                  : Center(child: AwardMark(award, size: 62)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenBar extends StatelessWidget {
  const _OpenBar(this.kind, this.colour, {required this.onTap});

  final BookKind kind;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = onColour(colour);
    return Tap(
      // Stories come in a later unit.
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x4DFFFFFF),
                shape: BoxShape.circle,
              ),
              child: SvgPicture.asset(
                'assets/icons/play.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(on, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              kind == BookKind.wordbook ? 'Practise' : 'Pick a story',
              style: _baloo(22, FontWeight.w700, on),
            ),
          ],
        ),
      ),
    );
  }
}
