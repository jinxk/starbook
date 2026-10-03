import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Unit;

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/repositories.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import 'parts.dart';

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(12),
  borderSide: const BorderSide(color: chipBorder, width: 1.5),
);

/// Whether every day still has a task that is not a bonus without [task].
bool _keepsWork(Sheet sheet, Task task) => sheet.days.every(
  (d) => [
    ...d.tasks,
    ...sheet.everyDay,
  ].where((t) => t.id != task.id).any((t) => !t.bonus),
);

class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;

  Future<void> _write(
    Future<Either<Failure, Unit>> Function(ProgressRepository progress) change,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await change(ref.read(progressRepositoryProvider));
      if (result case Left(:final value)) _toast(value.message);
      ref.invalidate(parentTodayProvider);
    } finally {
      _busy = false;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    _messenger.currentState!
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: hind(15, FontWeight.w500, Colors.white)),
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
  }

  Widget _field(String text, String? hint, ValueChanged<String> onChanged) =>
      TextFormField(
        initialValue: text,
        autofocus: true,
        maxLength: 80,
        onChanged: onChanged,
        style: hind(16, FontWeight.w500, Colours.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: hind(16, FontWeight.w500, Colours.inkSoft),
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
          enabledBorder: _inputBorder,
          focusedBorder: _inputBorder,
        ),
      );

  Future<void> _change(Week week, Task task) async {
    var text = task.text;
    final yes = await askSheet(
      context,
      'Change this task',
      row: _field(text, null, (t) => text = t),
      yes: 'Save',
      no: 'Cancel',
    );
    if (!yes || !mounted || text.trim().isEmpty) return;
    await _write((p) => p.editTask(week.id, task.id, text));
  }

  Future<void> _add(Week week, Day day) async {
    var text = '';
    final yes = await askSheet(
      context,
      'New task for ${weekdayNames[day.weekday.index]}',
      row: _field('', 'Practise letter B', (t) => text = t),
      yes: 'Add',
      no: 'Cancel',
    );
    if (!yes || !mounted || text.trim().isEmpty) return;
    await _write((p) => p.addTask(week.id, day.weekday, text));
  }

  Future<void> _remove(Week week, Task task) async {
    final yes = await askSheet(
      context,
      'Remove this task?',
      row: whiteRow(
        child: Text(task.text, style: hind(16, FontWeight.w500, Colours.ink)),
      ),
      note: 'Only this week. Stars already given stay.',
      yes: 'Remove',
      no: 'Cancel',
    );
    if (!yes || !mounted) return;
    await _write((p) => p.removeTask(week.id, task.id));
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colours.paperDeep,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: hind(11, FontWeight.w500, Colours.ink)),
  );

  Widget _task(
    Week week,
    Task task,
    List<GivenAward> awards, {
    bool only = false,
  }) {
    final given = awards.any((a) => a.taskId == task.id);
    return KeyedSubtree(
      key: ValueKey(task.id),
      child: whiteRow(
        onTap: () => _change(week, task),
        child: Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(
                task.text,
                style: hind(
                  16,
                  FontWeight.w500,
                  Colours.ink,
                ).copyWith(height: 1.3),
              ),
            ),
            if (given) _tag('done'),
            if (task.bonus) _tag('bonus'),
            if (!given && !only && _keepsWork(week.sheet, task))
              OutlinedButton(
                onPressed: () => _remove(week, task),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: chipBorder, width: 1.5),
                  backgroundColor: Colors.white,
                  foregroundColor: Colours.ink,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: hind(13, FontWeight.w500, Colours.ink),
                ),
                child: const Text('Remove'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(parentTodayProvider).value;
    final week = data?.week;
    final awards = data?.awards ?? const <GivenAward>[];
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(parentTodayProvider);
      },
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colours.parentPaper,
          body: SafeArea(
            child: Column(
              children: [
                parentHeader('Whole week'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (week != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                          child: Text(
                            'Changes here are for this week only. Next week '
                            'starts from the sheet again.',
                            style: hind(
                              14,
                              FontWeight.w400,
                              Colours.inkSoft,
                            ).copyWith(height: 1.4),
                          ),
                        ),
                        for (final day in week.sheet.days) ...[
                          parentHeading(
                            '${weekdayNames[day.weekday.index]} · ${day.title}',
                          ),
                          for (final task in day.tasks)
                            _task(
                              week,
                              task,
                              awards,
                              only: day.tasks.length == 1,
                            ),
                          if (!dayDone(week.sheet, day, awards))
                            Align(
                              alignment: Alignment.centerLeft,
                              child: parentButton(
                                'Add a task',
                                () => _add(week, day),
                                ghost: true,
                              ),
                            ),
                        ],
                        if (week.sheet.everyDay.isNotEmpty) ...[
                          parentHeading('Every day'),
                          for (final task in week.sheet.everyDay)
                            _task(week, task, awards),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
