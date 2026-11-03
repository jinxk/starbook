import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../widgets/picture.dart';
import '../widgets/plain_line.dart';
import 'parts.dart';

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: chipBorder, width: 1.5),
);

/// [days] as the list shows them: Every day, a run of 3 or more such as
/// Mon to Fri, or the days one by one.
String daysLine(Set<Weekday> days) {
  final sorted = days.toList()..sort((a, b) => a.index.compareTo(b.index));
  if (sorted.length == 7) return 'Every day';
  final run = sorted.last.index - sorted.first.index == sorted.length - 1;
  if (run && sorted.length >= 3) {
    return '${weekdayShort[sorted.first.index]} to '
        '${weekdayShort[sorted.last.index]}';
  }
  return [for (final d in sorted) weekdayShort[d.index]].join(', ');
}

class OwnHabitsScreen extends ConsumerStatefulWidget {
  const OwnHabitsScreen({super.key});

  @override
  ConsumerState<OwnHabitsScreen> createState() => _OwnHabitsScreenState();
}

class _OwnHabitsScreenState extends ConsumerState<OwnHabitsScreen> {
  List<OwnHabit>? _habits;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final all = (await ref.read(progressRepositoryProvider).ownHabits())
        .getOrElse((_) => const []);
    if (!mounted) return;
    setState(
      () => _habits = [
        for (final h in all)
          if (!h.removed) h,
      ],
    );
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final habits = _habits;
    final note = hind(13, FontWeight.w400, Colours.inkSoft);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(parentTodayProvider);
      },
      child: Scaffold(
        backgroundColor: Colours.parentPaper,
        body: SafeArea(
          child: Column(
            children: [
              parentHeader('Own habits'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                      child: Text(
                        'Your child sees these on the days you pick, with the '
                        "week's habits.",
                        style: hind(
                          14,
                          FontWeight.w400,
                          Colours.inkSoft,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                    if (habits != null) ...[
                      for (final h in habits)
                        whiteRow(
                          onTap: () => _open('/parent/habits/${h.id}'),
                          child: Row(
                            spacing: 10,
                            children: [
                              Picture(h.picture, size: 30),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.text,
                                      style: hind(
                                        16,
                                        FontWeight.w500,
                                        Colours.ink,
                                      ).copyWith(height: 1.3),
                                    ),
                                    Text(daysLine(h.days), style: note),
                                  ],
                                ),
                              ),
                              Text(
                                'Edit ›',
                                style: hind(
                                  14,
                                  FontWeight.w400,
                                  Colours.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (habits.length < ownHabitsMax)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: parentButton(
                            'Add a habit',
                            () => _open('/parent/habits/new'),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                        child: Text('Up to 6 habits.', style: note),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adds an own habit, or edits habit [id] when given.
class OwnHabitScreen extends ConsumerStatefulWidget {
  const OwnHabitScreen({super.key, this.id});

  final int? id;

  @override
  ConsumerState<OwnHabitScreen> createState() => _OwnHabitScreenState();
}

class _OwnHabitScreenState extends ConsumerState<OwnHabitScreen> {
  final _words = TextEditingController();
  final _days = <Weekday>{};
  String? _picture;
  late bool _loaded = widget.id == null;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) unawaited(_load());
  }

  @override
  void dispose() {
    _words.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = (await ref.read(progressRepositoryProvider).ownHabits())
        .getOrElse((_) => const []);
    if (!mounted) return;
    final habit = all.where((h) => h.id == widget.id && !h.removed).firstOrNull;
    if (habit == null) {
      context.pop();
      return;
    }
    setState(() {
      _words.text = habit.text;
      _days.addAll(habit.days);
      _picture = habit.picture;
      _loaded = true;
    });
  }

  bool get _ready =>
      _words.text.trim().isNotEmpty && _days.isNotEmpty && _picture != null;

  Future<void> _save() async {
    if (_busy) return;
    _busy = true;
    try {
      final progress = ref.read(progressRepositoryProvider);
      final id = widget.id;
      final result = id == null
          ? await progress.addOwnHabit(_words.text, _picture!, {..._days})
          : await progress.editOwnHabit(
              OwnHabit(
                id: id,
                text: _words.text,
                picture: _picture!,
                days: {..._days},
              ),
            );
      if (!mounted) return;
      result.fold(
        (_) => showLine(ScaffoldMessenger.of(context), notSaved),
        (_) => context.pop(),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    final yes = await askSheet(
      context,
      'Remove this habit?',
      note: 'Its ticks and trophy stay.',
      yes: 'Remove',
      no: 'Keep',
    );
    if (!yes || !mounted || _busy) return;
    _busy = true;
    try {
      final result = await ref
          .read(progressRepositoryProvider)
          .removeOwnHabit(widget.id!);
      if (!mounted) return;
      result.fold(
        (_) => showLine(ScaffoldMessenger.of(context), notSaved),
        (_) => context.pop(),
      );
    } finally {
      _busy = false;
    }
  }

  Widget _dayChip(Weekday day) {
    final on = _days.contains(day);
    void toggle() => setState(() => on ? _days.remove(day) : _days.add(day));
    return Semantics(
      button: true,
      selected: on,
      label: weekdayNames[day.index],
      excludeSemantics: true,
      onTap: toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: on ? Colours.ink : Colors.white,
            border: Border.all(
              color: on ? Colours.ink : chipBorder,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              weekdayShort[day.index],
              style: hind(14, FontWeight.w500, on ? Colors.white : Colours.ink),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(String picture) {
    final chosen = _picture == picture;
    return Semantics(
      button: true,
      selected: chosen,
      label: picture,
      child: GestureDetector(
        key: ValueKey(picture),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _picture = picture),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: chosen ? Colours.ink : cardBorder,
              width: chosen ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Picture(picture, size: 52),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final everyDay = _days.length == 7;
    return Scaffold(
      backgroundColor: Colours.parentPaper,
      body: SafeArea(
        child: Column(
          children: [
            parentHeader(widget.id == null ? 'New habit' : 'Edit habit'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (_loaded) ...[
                    parentHeading('Words'),
                    TextField(
                      controller: _words,
                      maxLength: ownHabitTextMax,
                      onChanged: (_) => setState(() {}),
                      style: hind(16, FontWeight.w500, Colours.ink),
                      decoration: InputDecoration(
                        hintText: 'I went swimming',
                        hintStyle: hind(16, FontWeight.w500, Colours.inkSoft),
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: _inputBorder,
                        focusedBorder: _inputBorder,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        'Write it as your child would say it, starting with I. '
                        'It is read aloud.',
                        style: hind(
                          13,
                          FontWeight.w400,
                          Colours.inkSoft,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                    parentHeading('Days'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          if (everyDay) {
                            _days.clear();
                          } else {
                            _days.addAll(Weekday.values);
                          }
                        }),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: everyDay ? Colours.ink : chipBorder,
                            width: 1.5,
                          ),
                          backgroundColor: everyDay
                              ? Colours.ink
                              : Colors.white,
                          foregroundColor: everyDay
                              ? Colors.white
                              : Colours.ink,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: hind(13, FontWeight.w500, Colours.ink),
                        ),
                        child: const Text('Every day'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 5,
                      children: [
                        for (final d in Weekday.values)
                          Expanded(child: _dayChip(d)),
                      ],
                    ),
                    parentHeading('Picture'),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [for (final p in ownHabitPictures) _tile(p)],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      spacing: 10,
                      children: [
                        parentButton('Save', _ready ? _save : null),
                        if (widget.id != null)
                          parentButton('Remove', _remove, ghost: true),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
