import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/progress/progress.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import 'parts.dart';

/// `3 to 9 November` or `27 October to 2 November`, with the year after the
/// last date when it is not [now]'s year.
String weekDates(DateTime start, DateTime now) {
  final last = DateTime(start.year, start.month, start.day + 6);
  final from = start.month == last.month
      ? '${start.day}'
      : '${start.day} ${monthNames[start.month - 1]}';
  final year = last.year == now.year ? '' : ' ${last.year}';
  return '$from to ${last.day} ${monthNames[last.month - 1]}$year';
}

String _key(DateTime start) => start.toIso8601String().substring(0, 10);

final _grey = hind(14, FontWeight.w400, Colours.inkSoft).copyWith(height: 1.4);
final _plain = hind(14, FontWeight.w400, Colours.ink).copyWith(height: 1.4);

Widget _screen(String title, List<Widget> children) => Scaffold(
  backgroundColor: Colours.parentPaper,
  body: SafeArea(
    child: Column(
      children: [
        parentHeader(title),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: children,
          ),
        ),
      ],
    ),
  ),
);

class PastWeeksScreen extends ConsumerWidget {
  const PastWeeksScreen({super.key});

  Widget _card(
    BuildContext context,
    KeptWeek kept,
    PastWeeks data,
    DateTime now,
  ) {
    final sheet = kept.week.sheet;
    final jobs = jobsDone(sheet, kept.awards);
    return whiteRow(
      onTap: () => context.push('/parent/past/${_key(kept.week.start)}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Text(
                  weekDates(kept.week.start, now),
                  style: hind(16, FontWeight.w500, Colours.ink),
                ),
              ),
              Text('›', style: hind(16, FontWeight.w400, Colours.inkSoft)),
            ],
          ),
          Text(sheet.title, style: _grey),
          if (sheet.letters.isNotEmpty)
            Text('Letters ${sheet.letters.join(', ')}', style: _grey),
          Text('${jobs.done} of ${jobs.total} jobs done', style: _plain),
          for (final (habit, days) in habitDays([
            ...sheet.habits,
            ...data.own,
          ], kept.ticks))
            Text(
              '${habit.text} · $days ${days == 1 ? 'day' : 'days'}',
              style: _plain,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(pastWeeksProvider).value;
    final now = ref.watch(clockProvider)();
    return _screen('Past weeks', [
      if (data != null && data.weeks.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text(
            'Past weeks will show here from next Monday.',
            style: _grey,
          ),
        ),
      if (data != null)
        for (final kept in data.weeks) _card(context, kept, data, now),
    ]);
  }
}

/// One kept week, read only: each day with a job done or a habit ticked.
class PastWeekScreen extends ConsumerWidget {
  const PastWeekScreen(this.start, {super.key});

  /// The week's Monday, as yyyy-mm-dd.
  final String start;

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(text, style: hind(13, FontWeight.w500, Colours.inkSoft)),
  );

  Widget _line(String text) => Text(
    text,
    style: hind(15, FontWeight.w400, Colours.ink).copyWith(height: 1.4),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(pastWeeksProvider).value;
    final now = ref.watch(clockProvider)();
    final kept = data?.weeks
        .where((k) => _key(k.week.start) == start)
        .firstOrNull;
    if (data == null || kept == null) return _screen('', const []);
    final sheet = kept.week.sheet;
    return _screen(weekDates(kept.week.start, now), [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: Text(
          [
            sheet.title,
            if (sheet.letters.isNotEmpty) 'Letters ${sheet.letters.join(', ')}',
          ].join(' · '),
          style: _grey,
        ),
      ),
      for (final d in markedDays(kept, [...sheet.habits, ...data.own])) ...[
        parentHeading(
          [
            '${weekdayNames[d.date.weekday - 1]} ${d.date.day}',
            if (d.day case final day?) day.title,
          ].join(' · '),
        ),
        whiteRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.jobs.isNotEmpty) ...[
                _label('Jobs done'),
                for (final t in d.jobs) _line(t.text),
              ],
              if (d.habits.isNotEmpty) ...[
                _label('Habits ticked'),
                for (final h in d.habits) _line(h.text),
              ],
            ],
          ),
        ),
      ],
    ]);
  }
}
