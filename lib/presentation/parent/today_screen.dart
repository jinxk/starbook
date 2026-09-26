import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/picture.dart';

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

  Future<ParentToday> _reload() {
    ref.invalidate(parentTodayProvider);
    return ref.read(parentTodayProvider.future);
  }

  Future<void> _give(
    Week week,
    Weekday today,
    Task task,
    String awardRef,
    Award award,
    GivenAward? had,
  ) async {
    if (_busy || had?.awardRef == awardRef) return;
    _busy = true;
    try {
      final result = await ref
          .read(progressRepositoryProvider)
          .give(
            weekId: week.id,
            weekday: today,
            taskId: task.id,
            awardRef: awardRef,
            replaces: had?.id,
          );
      await _reload();
      if (!mounted) return;
      result.fold((_) {}, (given) {
        _messenger.currentState!
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${award.label} given for "${task.text}"',
                style: _hind(15, FontWeight.w500, Colors.white),
              ),
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colours.sunflower,
                onPressed: () => _undo(given.id, had?.id),
              ),
              duration: const Duration(seconds: 4),
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
      await ref
          .read(progressRepositoryProvider)
          .undo(awardId, restore: restore);
      await _reload();
    } finally {
      _busy = false;
    }
  }

  Future<void> _undoHabit(String habitId) async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(progressRepositoryProvider).undoHabit(habitId);
      await _reload();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(parentTodayProvider).value;
    final installed = ref.watch(packRepositoryProvider).installed;
    final today = Weekday.values[DateTime.now().weekday - 1];
    final week = data?.week;
    final day = week?.sheet.days.where((d) => d.weekday == today).firstOrNull;
    final everyDay = week?.sheet.everyDay ?? const <Task>[];
    final name = data?.child?.name?.trim() ?? '';
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
                          'Today, ${weekdayNames[today.index]}',
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: data == null
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (week != null && day != null) ...[
                                _heading(day.title),
                                for (final t in [
                                  ...day.tasks,
                                  ...everyDay.where((t) => !t.bonus),
                                ])
                                  _card(week, today, t, data.awards, installed),
                                if (everyDay.any((t) => t.bonus)) ...[
                                  _heading('Every day (bonus)'),
                                  for (final t in everyDay.where(
                                    (t) => t.bonus,
                                  ))
                                    _card(
                                      week,
                                      today,
                                      t,
                                      data.awards,
                                      installed,
                                    ),
                                ],
                              ],
                              if (week != null &&
                                  week.sheet.habits.isNotEmpty) ...[
                                _heading('Good habits'),
                                for (final h in week.sheet.habits)
                                  _habit(h, data.ticked.contains(h.id)),
                              ],
                              if (week != null) ...[
                                _heading("This week's reward"),
                                TextFormField(
                                  initialValue: week.specialReward,
                                  onChanged: (text) => unawaited(
                                    ref
                                        .read(progressRepositoryProvider)
                                        .setSpecialReward(week.id, text),
                                  ),
                                  style: _hind(
                                    16,
                                    FontWeight.w500,
                                    Colours.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ice cream on Sunday',
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
                                'Packs',
                                '${installed.length} installed ›',
                                onTap: () => context.push('/parent/packs'),
                              ),
                              _more('Whole week', 'edit tasks ›'),
                              _more('Child', name.isEmpty ? '›' : '$name ›'),
                              _more('Backup', 'export, import ›'),
                              _more(
                                'Settings',
                                'sound, reading speed, voices ›',
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

  Widget _more(String label, String value, {VoidCallback? onTap}) =>
      GestureDetector(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 10,
            children: [
              Text(label, style: _hind(16, FontWeight.w500, Colours.ink)),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: _hind(14, FontWeight.w400, Colours.inkSoft),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _card(
    Week week,
    Weekday today,
    Task task,
    List<GivenAward> awards,
    List<Pack> installed,
  ) {
    final had = awards
        .where((a) => a.weekday == today && a.taskId == task.id)
        .firstOrNull;
    final icon = task.icon;
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
          const SizedBox(height: 10),
          Row(
            spacing: 5,
            children: [
              for (final pack in installed)
                for (final award in pack.awards)
                  Expanded(
                    child: _chip(
                      award,
                      '${pack.id}/${award.id}',
                      had,
                      () => _give(
                        week,
                        today,
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

  Widget _habit(Habit habit, bool ticked) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _cardBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
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
          const Picture('star', size: 26),
          OutlinedButton(
            onPressed: () => _undoHabit(habit.id),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: const BorderSide(color: _chipBorder, width: 1.5),
              backgroundColor: Colors.white,
              foregroundColor: Colours.ink,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: _hind(13, FontWeight.w500, Colours.ink),
            ),
            child: const Text('Undo'),
          ),
        ] else
          dashedCircle(26, 2),
      ],
    ),
  );

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
