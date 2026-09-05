import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/award_mark.dart';
import '../widgets/landing.dart';
import '../widgets/picture.dart';
import '../widgets/tap.dart';
import 'days.dart';

const _months = [
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

const _defaultGoal = 'Finish all your days for a big reward!';
const _defaultRest = 'No homework today. Play, draw, dance!';

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

String? _filled(String? text) =>
    text == null || text.trim().isEmpty ? null : text;

/// `13 to 17 October`, `29 September to 3 October` or `13 October`.
String? _dates(Week week) {
  if (week.sheet.days.isEmpty) return null;
  final indexes = [for (final d in week.sheet.days) d.weekday.index]..sort();
  DateTime on(int i) =>
      DateTime(week.start.year, week.start.month, week.start.day + i);
  final first = on(indexes.first);
  final last = on(indexes.last);
  if (indexes.first == indexes.last) {
    return '${first.day} ${_months[first.month - 1]}';
  }
  final from = first.month == last.month
      ? '${first.day}'
      : '${first.day} ${_months[first.month - 1]}';
  return '$from to ${last.day} ${_months[last.month - 1]}';
}

/// When each new award lands: the first at once, the rest 800ms apart.
Map<int, Duration> _landing(ThisWeek data) {
  final ids = data.unseen.toList()..sort();
  return {
    for (var i = 0; i < ids.length; i++)
      ids[i]: Duration(milliseconds: 800 * i),
  };
}

String? _restLine(Sheet sheet, Weekday today) {
  if (sheet.restDays.isEmpty) return null;
  if (sheet.restDays.contains(today)) {
    return _filled(sheet.restMessage) ?? _defaultRest;
  }
  final names = [for (final d in sheet.restDays) weekdayNames[d.index]];
  final list = names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  return '$list: play days!';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(thisWeekProvider).value;
    final today = Weekday.values[DateTime.now().weekday - 1];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(data),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: data == null
                    ? const SizedBox.shrink()
                    : _Week(data, today),
              ),
            ),
            const _Dock(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.data);

  final ThisWeek? data;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final name = _filled(data?.child?.name);
    final picture = name == null ? null : _filled(data?.child?.picture);
    final dates = data == null ? null : _dates(data.week);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
      child: Row(
        children: [
          if (picture != null) ...[
            Picture(picture, size: 56, sticker: true),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: data == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null ? data.week.sheet.title : "$name's week",
                        style: _baloo(
                          32,
                          FontWeight.w700,
                          Colours.ink,
                        ).copyWith(height: 1),
                      ),
                      if (dates != null)
                        Text(
                          dates,
                          style: _baloo(18, FontWeight.w600, Colours.inkSoft),
                        ),
                    ],
                  ),
          ),
          Semantics(
            label: 'Grown-ups',
            button: true,
            child: Tap(
              onTap: () => context.go('/gate'),
              child: SizedBox.square(
                dimension: 72,
                child: Center(
                  child: Opacity(
                    opacity: 0.55,
                    child: SvgPicture.asset(
                      'assets/icons/lock.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        Colours.ink,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week(this.data, this.today);

  final ThisWeek data;
  final Weekday today;

  @override
  Widget build(BuildContext context) {
    final sheet = data.week.sheet;
    final rest = _restLine(sheet, today);
    final reward =
        _filled(data.week.specialReward) ??
        _filled(sheet.weekGoal) ??
        _defaultGoal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
          child: Transform.rotate(
            angle: -0.6 * pi / 180,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              decoration: const BoxDecoration(
                color: Colours.card,
                borderRadius: BorderRadius.all(Radius.circular(6)),
                boxShadow: [
                  BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1)),
                  BoxShadow(
                    color: Color(0x1F503C14),
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                    child: Text(
                      'MY STAR CHART',
                      style: _baloo(
                        15,
                        FontWeight.w700,
                        Colours.inkSoft,
                      ).copyWith(letterSpacing: 1.2),
                    ),
                  ),
                  for (var i = 0; i < sheet.days.length; i++) ...[
                    if (i > 0)
                      SizedBox(height: 16, child: Center(child: dashedLine())),
                    _DayRow(data, sheet.days[i], today),
                  ],
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(4, 22, 4, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Colours.paperDeep,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: Row(
            children: [
              const Picture('gift', size: 58, sticker: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "This week's reward",
                      style: TextStyle(
                        fontFamily: Fonts.hind,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colours.inkSoft,
                      ),
                    ),
                    Text(
                      reward,
                      style: _baloo(
                        22,
                        FontWeight.w700,
                        Colours.ink,
                      ).copyWith(height: 1.15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (rest != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
            child: Text(
              rest,
              textAlign: TextAlign.center,
              style: _baloo(16, FontWeight.w600, Colours.inkSoft),
            ),
          ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow(this.data, this.day, this.today);

  final ThisWeek data;
  final Day day;
  final Weekday today;

  @override
  Widget build(BuildContext context) {
    final sheet = data.week.sheet;
    final colour = dayColour(day);
    final tasks = [...day.tasks, ...sheet.everyDay];
    final plain = tasks.where((t) => !t.bonus).toList();
    GivenAward? awardOf(Task t) => data.awards
        .where((a) => a.weekday == day.weekday && a.taskId == t.id)
        .firstOrNull;
    final given = [for (final t in plain) awardOf(t)];
    final landing = _landing(data);
    // The note rises with the stars given that day, this one included.
    int stepOf(GivenAward a) => data.awards
        .where((o) => o.weekday == a.weekday && o.id <= a.id)
        .fold(0, (sum, o) => sum + o.stars);
    final done = dayDone(sheet, day, data.awards);
    // The big star drops after the last award that finishes the day.
    final seen = [
      for (final a in data.awards)
        if (!landing.containsKey(a.id)) a,
    ];
    Duration? starAfter;
    if (done && !dayDone(sheet, day, seen)) {
      final last = [
        for (final a in data.awards)
          if (a.weekday == day.weekday) ?landing[a.id],
      ].fold(Duration.zero, (a, b) => a > b ? a : b);
      starAfter = last + const Duration(milliseconds: 700);
    }
    final jobs = plain.length;
    return Tap(
      onTap: () => context.go('/day/${day.weekday.name}'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -3 * pi / 180,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colour,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekdayShort[day.weekday.index],
                            style: _baloo(
                              20,
                              FontWeight.w700,
                              onColour(colour),
                            ).copyWith(height: 1),
                          ),
                          Text(
                            jobs == 1 ? '1 job' : '$jobs jobs',
                            style: TextStyle(
                              fontFamily: Fonts.hind,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: onColour(colour).withValues(alpha: 0.9),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: [
                        for (final a in given)
                          SizedBox.square(
                            dimension: 30,
                            child: a == null
                                ? dashedCircle(30, 2)
                                : Center(
                                    child: AwardMark(
                                      a,
                                      size: 26,
                                      landAfter: landing[a.id],
                                      step: stepOf(a),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 52,
                    child: Center(
                      child: !done
                          ? dashedStar
                          : starAfter == null
                          ? const Picture('glowing-star', size: 50)
                          : Landing(
                              kind: LandingKind.drop,
                              after: starAfter,
                              child: const Picture('glowing-star', size: 50),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (day.weekday == today)
            Positioned(
              left: -6,
              top: 4,
              child: Transform.rotate(
                angle: -8 * pi / 180,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Colours.ink,
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontFamily: Fonts.hind,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _DockButton('Trophies', 'trophy', Color(0xFFF8E3B0)),
          _DockButton('Words', 'books', Color(0xFFF6D3CA)),
          _DockButton('Stories', 'open-book', Color(0xFFD3E6F6)),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton(this.label, this.picture, this.colour);

  final String label;
  final String picture;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Tap(
      // Each screen comes in a later unit.
      onTap: () {},
      pressedScale: 0.92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: Picture(picture, size: 56),
          ),
          const SizedBox(height: 4),
          Text(label, style: _baloo(17, FontWeight.w700, Colours.ink)),
        ],
      ),
    );
  }
}
