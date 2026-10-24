import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/repositories.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/picture.dart';
import '../widgets/plain_line.dart';
import '../widgets/sticker_view.dart';

const _cardBorder = Color(0xFFEBE3D0);
const _chipBorder = Color(0xFFE2D8C2);

TextStyle _hind(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.hind,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class ParentTodayScreen extends ConsumerStatefulWidget {
  const ParentTodayScreen({super.key});

  @override
  ConsumerState<ParentTodayScreen> createState() => _ParentTodayScreenState();
}

class _ParentTodayScreenState extends ConsumerState<ParentTodayScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;
  // The day the data on screen was loaded; a rebuild with the same data keeps it.
  ParentToday? _shown;
  late DateTime _builtOn = DateUtils.dateOnly(ref.read(clockProvider)());
  // The day shown; null is Today.
  DateTime? _picked;

  bool get _stale => DateUtils.dateOnly(ref.read(clockProvider)()) != _builtOn;

  Future<ParentToday> _reload() {
    ref.invalidate(parentTodayProvider);
    return ref.read(parentTodayProvider.future);
  }

  Future<void> _give(
    Week week,
    DateTime day,
    Task task,
    String awardRef,
    Award award,
    GivenAward? had,
  ) async {
    if (_busy || had?.awardRef == awardRef) return;
    _busy = true;
    try {
      // The screen was built on an earlier day: show the new day, write nothing.
      if (_stale) {
        await _reload();
        return;
      }
      final result = await ref
          .read(progressRepositoryProvider)
          .give(
            weekId: week.id,
            weekday: Weekday.values[day.weekday - 1],
            taskId: task.id,
            awardRef: awardRef,
            replaces: had?.id,
          );
      if (result.isLeft()) {
        if (mounted) showLine(_messenger.currentState!, notSaved);
        return;
      }
      final fresh = await _reload();
      if (!mounted) return;
      result.fold((_) {}, (given) {
        final name = fresh.child?.name?.trim() ?? '';
        final style = _hind(15, FontWeight.w500, Colors.white);
        _messenger.currentState!
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    '${award.label} given for "${task.text}"'
                    '${day == _builtOn ? '' : ' on ${weekdayNames[day.weekday - 1]}'}',
                    style: style,
                  ),
                  Text(
                    'Now tell ${name.isEmpty ? 'your child' : name} what was '
                    'done, with a high five.',
                    style: style,
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colours.sunflower,
                onPressed: () => _undo(given.id, had?.id),
              ),
              duration: const Duration(seconds: 6),
              persist: false,
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colours.ink,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> _undo(int awardId, int? restore) async {
    if (_busy) return;
    _busy = true;
    try {
      if (_stale) {
        await _reload();
        return;
      }
      final result = await ref
          .read(progressRepositoryProvider)
          .undo(awardId, restore: restore);
      if (result.isLeft() && mounted) {
        showLine(_messenger.currentState!, notSaved);
      }
      await _reload();
    } finally {
      _busy = false;
    }
  }

  Future<void> _tick(Week week, DateTime day, Habit habit) async {
    if (_busy) return;
    _busy = true;
    try {
      if (_stale) {
        await _reload();
        return;
      }
      final progress = ref.read(progressRepositoryProvider);
      final result = await progress.tickHabit(week.id, habit.id, day: day);
      if (result.isLeft()) {
        if (mounted) showLine(_messenger.currentState!, notSaved);
        return;
      }
      String? sticker;
      if (result.getOrElse((_) => false)) {
        sticker = (await progress.takeHabitSticker(
          week.id,
          day: day,
          byParent: true,
        )).getOrElse((_) => null);
      }
      await _reload();
      if (sticker != null && mounted) {
        final when = day == _builtOn ? 'today' : weekdayNames[day.weekday - 1];
        showLine(
          _messenger.currentState!,
          'All habits done for $when. A new sticker is in the book.',
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _undoHabit(String habitId, DateTime day) async {
    if (_busy) return;
    _busy = true;
    try {
      if (_stale) {
        await _reload();
        return;
      }
      final result = await ref
          .read(progressRepositoryProvider)
          .undoHabit(habitId, day: day);
      if (result.isLeft() && mounted) {
        showLine(_messenger.currentState!, notSaved);
      }
      await _reload();
    } finally {
      _busy = false;
    }
  }

  Future<void> _setHabits(HabitPrefs prefs) async {
    if (_busy) return;
    _busy = true;
    try {
      if (_stale) {
        await _reload();
        return;
      }
      final result = await ref
          .read(progressRepositoryProvider)
          .setHabitPrefs(prefs);
      if (result.isLeft() && mounted) {
        showLine(_messenger.currentState!, notSaved);
      }
      await _reload();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(parentTodayProvider).value;
    final installed = ref.watch(packRepositoryProvider).installed;
    final clock = ref.watch(clockProvider)();
    if (!identical(data, _shown)) {
      _shown = data;
      final builtOn = DateUtils.dateOnly(clock);
      if (builtOn != _builtOn) _picked = null;
      _builtOn = builtOn;
    }
    // The days follow the loaded data, not the clock, so a redraw after
    // midnight keeps the chips and header until the screen reloads.
    final now = _builtOn;
    final days = markableDays(now);
    final picked = days.contains(_picked) ? _picked! : days.last;
    final isToday = picked == days.last;
    final weekday = Weekday.values[picked.weekday - 1];
    final dayName = weekdayNames[weekday.index];
    final inThisWeek = mondayOf(picked) == mondayOf(now);
    final week = data?.week;
    final pickedWeek = inThisWeek ? week : data?.lastWeek;
    final pickedAwards =
        (inThisWeek ? data?.awards : data?.lastAwards) ?? const <GivenAward>[];
    final pickedTicks = data?.ticked[picked] ?? const <String>{};
    final day = pickedWeek?.sheet.days
        .where((d) => d.weekday == weekday)
        .firstOrNull;
    final everyDay = pickedWeek?.sheet.everyDay ?? const <Task>[];
    final name = data?.child?.name?.trim() ?? '';
    final header = isToday
        ? 'Today, $dayName'
        : picked == days[5]
        ? 'Yesterday, $dayName'
        : '$dayName, ${picked.day} ${monthNames[picked.month - 1]}';
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(thisWeekProvider);
      },
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colours.parentPaper,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: Text(
                          header,
                          style: _hind(26, FontWeight.w500, Colours.ink),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Colours.paperDeep,
                          foregroundColor: Colours.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: _hind(16, FontWeight.w500, Colours.ink),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                if (data != null && week != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Row(
                      spacing: 5,
                      children: [
                        for (final d in days)
                          Expanded(
                            child: _dayChip(
                              d,
                              picked: d == picked,
                              stored:
                                  (mondayOf(d) == mondayOf(now)
                                      ? week
                                      : data.lastWeek) !=
                                  null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isToday)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        'This counts for $dayName'
                        '${inThisWeek ? '' : ' last week'}, not today.',
                        style: _hind(13, FontWeight.w400, Colours.inkSoft),
                      ),
                    ),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: data == null
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (pickedWeek != null && day != null) ...[
                                _heading(day.title),
                                for (final t in [
                                  ...day.tasks,
                                  ...everyDay.where((t) => !t.bonus),
                                ])
                                  _card(
                                    pickedWeek,
                                    picked,
                                    t,
                                    pickedAwards,
                                    installed,
                                  ),
                                if (everyDay.any((t) => t.bonus)) ...[
                                  _heading('Every day (bonus)'),
                                  for (final t in everyDay.where(
                                    (t) => t.bonus,
                                  ))
                                    _card(
                                      pickedWeek,
                                      picked,
                                      t,
                                      pickedAwards,
                                      installed,
                                    ),
                                ],
                              ],
                              if (pickedWeek != null &&
                                  pickedWeek.sheet.habits.isNotEmpty) ...[
                                _heading('Good habits'),
                                for (final h in pickedWeek.sheet.habits)
                                  _habit(
                                    pickedWeek,
                                    picked,
                                    h,
                                    pickedTicks.contains(h.id),
                                    data.tickedDays[h.id] ?? 0,
                                    data.habits,
                                  ),
                              ],
                              if (week != null) ...[
                                _heading("This week's reward"),
                                TextFormField(
                                  key: ValueKey(week.id),
                                  initialValue: week.specialReward,
                                  onChanged: (text) => unawaited(
                                    _stale
                                        ? _reload()
                                        : ref
                                              .read(progressRepositoryProvider)
                                              .setSpecialReward(week.id, text)
                                              .then((result) {
                                                if (result.isLeft() &&
                                                    mounted) {
                                                  showLine(
                                                    _messenger.currentState!,
                                                    notSaved,
                                                  );
                                                }
                                              }),
                                  ),
                                  style: _hind(
                                    16,
                                    FontWeight.w500,
                                    Colours.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Park with Papa on Sunday',
                                    hintStyle: _hind(
                                      16,
                                      FontWeight.w500,
                                      Colours.inkSoft,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.all(12),
                                    enabledBorder: _inputBorder,
                                    focusedBorder: _inputBorder,
                                  ),
                                ),
                              ],
                              _heading('More'),
                              _more(
                                'How to use Starbook together',
                                '›',
                                longLabel: true,
                                onTap: () => context.push('/parent/tips'),
                              ),
                              _more(
                                'Packs',
                                '${installed.length} installed ›',
                                onTap: () => context.push('/parent/packs'),
                              ),
                              _more(
                                'Whole week',
                                'edit tasks ›',
                                onTap: () => context.push('/parent/week'),
                              ),
                              _more(
                                'Child',
                                name.isEmpty ? '›' : '$name ›',
                                onTap: () => context.push('/parent/child'),
                              ),
                              _more(
                                'Backup',
                                'export, import ›',
                                onTap: () => context.push('/parent/backup'),
                              ),
                              _more(
                                'Settings',
                                'sound, reading speed, voices ›',
                                onTap: () => context.push('/parent/settings'),
                              ),
                              _more(
                                'Credits',
                                'fonts, pictures, sounds ›',
                                onTap: () => context.push('/parent/credits'),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final _habitButton = OutlinedButton.styleFrom(
    shape: const StadiumBorder(),
    side: const BorderSide(color: _chipBorder, width: 1.5),
    backgroundColor: Colors.white,
    foregroundColor: Colours.ink,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: _hind(13, FontWeight.w500, Colours.ink),
  );

  static final _inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _chipBorder, width: 1.5),
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: _hind(
        13,
        FontWeight.w500,
        Colours.inkSoft,
      ).copyWith(letterSpacing: 0.78),
    ),
  );

  Widget _more(
    String label,
    String value, {
    VoidCallback? onTap,
    bool longLabel = false,
  }) {
    final labelText = Text(
      label,
      style: _hind(16, FontWeight.w500, Colours.ink),
    );
    final valueText = Text(
      value,
      textAlign: TextAlign.end,
      style: _hind(14, FontWeight.w400, Colours.inkSoft),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _cardBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: longLabel
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 10,
                children: [
                  Flexible(child: labelText),
                  valueText,
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [labelText, valueText],
                ),
              ),
      ),
    );
  }

  Widget _card(
    Week week,
    DateTime day,
    Task task,
    List<GivenAward> awards,
    List<Pack> installed,
  ) {
    final weekday = Weekday.values[day.weekday - 1];
    final had = awards
        .where((a) => a.weekday == weekday && a.taskId == task.id)
        .firstOrNull;
    final icon = task.icon;
    final tip = task.tip;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 10,
            children: [
              if (icon != null)
                SvgPicture.asset(
                  'assets/icons/$icon.svg',
                  width: 30,
                  height: 30,
                  colorFilter: const ColorFilter.mode(
                    Colours.ink,
                    BlendMode.srcIn,
                  ),
                ),
              Expanded(
                child: Text(
                  task.text,
                  style: _hind(
                    16,
                    FontWeight.w500,
                    Colours.ink,
                  ).copyWith(height: 1.3),
                ),
              ),
            ],
          ),
          if (tip != null)
            Padding(
              padding: EdgeInsets.only(left: icon == null ? 0 : 40, top: 4),
              child: Text(
                tip,
                style: _hind(
                  13,
                  FontWeight.w400,
                  Colours.inkSoft,
                ).copyWith(height: 1.3),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            spacing: 5,
            children: [
              for (final pack in installed)
                for (final award in pack.awards.where((a) => !a.retired))
                  Expanded(
                    child: _chip(
                      award,
                      '${pack.id}/${award.id}',
                      had,
                      () => _give(
                        week,
                        day,
                        task,
                        '${pack.id}/${award.id}',
                        award,
                        had,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayChip(DateTime day, {required bool picked, required bool stored}) {
    final i = day.weekday - 1;
    final today = day == _builtOn;
    final label =
        '${today ? 'Today, ' : ''}${weekdayNames[i]} ${day.day} '
        '${monthNames[day.month - 1]}';
    final colour = picked
        ? Colors.white
        : stored
        ? Colours.ink
        : Colours.inkSoft.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      selected: picked,
      label: label,
      excludeSemantics: true,
      onTap: stored ? () => setState(() => _picked = day) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: stored ? () => setState(() => _picked = day) : null,
        child: Stack(
          children: [
            if (!stored) Positioned.fill(child: dashedBox(10)),
            Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              decoration: stored
                  ? BoxDecoration(
                      color: picked ? Colours.ink : Colors.white,
                      border: Border.all(
                        color: picked ? Colours.ink : _chipBorder,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      today ? 'Today' : weekdayShort[i],
                      style: _hind(11, FontWeight.w400, colour),
                    ),
                    Text(
                      '${day.day}',
                      style: _hind(15, FontWeight.w500, colour),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _habit(
    Week week,
    DateTime day,
    Habit habit,
    bool ticked,
    int days,
    HabitPrefs prefs,
  ) {
    final note = _hind(
      13,
      FontWeight.w400,
      Colours.inkSoft,
    ).copyWith(height: 1.3);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 10,
            children: [
              Picture(habit.picture, size: 30),
              Expanded(
                child: Text(
                  habit.text,
                  style: _hind(
                    16,
                    FontWeight.w500,
                    Colours.ink,
                  ).copyWith(height: 1.3),
                ),
              ),
              if (ticked) ...[
                IgnorePointer(
                  child: StickerView(
                    habit.sticker ?? habit.picture,
                    size: 26,
                    picture: habit.sticker == null,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _undoHabit(habit.id, day),
                  style: _habitButton,
                  child: const Text('Undo'),
                ),
              ] else ...[
                dashedCircle(26, 2),
                OutlinedButton(
                  onPressed: () => _tick(week, day, habit),
                  style: _habitButton,
                  child: const Text('Tick'),
                ),
              ],
            ],
          ),
          if (days >= 20 && !prefs.answered.contains(habit.id))
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Text(
                    'This habit looks steady. Keep it, or swap in a new habit?',
                    style: note,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _setHabits((
                          answered: {...prefs.answered, habit.id},
                          stickerOff: prefs.stickerOff,
                        )),
                        style: _habitButton,
                        child: const Text('Keep it'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setHabits((
                          answered: {...prefs.answered, habit.id},
                          stickerOff: {...prefs.stickerOff, habit.id},
                        )),
                        style: _habitButton,
                        child: const Text('Sticker off'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/parent/packs'),
                        style: _habitButton,
                        child: const Text('Swap habit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (prefs.stickerOff.contains(habit.id))
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: Text(
                      'No daily sticker for this habit.',
                      style: note,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _setHabits((
                      answered: prefs.answered,
                      stickerOff: prefs.stickerOff.difference({habit.id}),
                    )),
                    style: _habitButton,
                    child: const Text('Sticker on'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    Award award,
    String awardRef,
    GivenAward? had,
    VoidCallback onGive,
  ) {
    final on = had?.awardRef == awardRef;
    final label = switch (award.kind) {
      AwardKind.star => '★ ${award.label}',
      AwardKind.sticker => '◐ ${award.label}',
      AwardKind.stamp => award.label,
    };
    return OutlinedButton(
      onPressed: onGive,
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: on ? Colours.ink : _chipBorder, width: 1.5),
        backgroundColor: on ? Colours.ink : Colors.white,
        foregroundColor: on ? Colors.white : Colours.ink,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        textStyle: _hind(13, FontWeight.w500, Colours.ink),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }
}
