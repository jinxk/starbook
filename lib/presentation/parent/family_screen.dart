import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/repositories.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import 'parts.dart';

/// "8 November, 7:40 pm".
String familyTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${monthNames[t.month - 1]}, $hour:$minute '
      '${t.hour < 12 ? 'am' : 'pm'}';
}

void _toast(GlobalKey<ScaffoldMessengerState> messenger, String text) {
  messenger.currentState
    ?..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: hind(15, FontWeight.w500, Colors.white)),
        duration: const Duration(seconds: 4),
        persist: false,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colours.ink,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}

Widget _line(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
  child: Text(
    text,
    style: hind(14, FontWeight.w400, Colours.inkSoft).copyWith(height: 1.4),
  ),
);

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  FamilyState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final file = ref.read(incomingFileProvider);
      if (file == null) return;
      ref.read(incomingFileProvider.notifier).drop();
      unawaited(_receive(file.bytes));
    });
  }

  Future<void> _refresh() async {
    final state = await ref.read(familyRepositoryProvider).state();
    if (!mounted) return;
    setState(() => _state = state.getOrElse((_) => _state ?? _none));
  }

  static const FamilyState _none = (
    code: null,
    lastSent: null,
    lastReceived: null,
  );

  Future<void> _receive(Uint8List bytes) async {
    if (_busy) return;
    _busy = true;
    try {
      switch (await ref.read(familyRepositoryProvider).receive(bytes)) {
        case Left(:final value):
          _toast(_messenger, value.message);
        case Right():
          ref.invalidate(parentTodayProvider);
          ref.invalidate(thisWeekProvider);
          ref.invalidate(trophyRoomProvider);
          ref.invalidate(habitsTodayProvider);
          _toast(_messenger, 'Added what the other phone sent.');
      }
      await _refresh();
    } finally {
      _busy = false;
    }
  }

  Future<void> _send() async {
    if (_busy) return;
    _busy = true;
    try {
      switch (await ref.read(familyRepositoryProvider).send()) {
        case Left(:final value):
          _toast(_messenger, value.message);
        case Right(:final value):
          final day = DateTime.now().toIso8601String().substring(0, 10);
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(value, mimeType: 'application/octet-stream'),
              ],
              fileNameOverrides: ['starbook-week-$day.starbook-family'],
            ),
          );
      }
      await _refresh();
    } finally {
      _busy = false;
    }
  }

  Future<void> _pair() async {
    final paired = await context.push<bool>('/parent/family/pair');
    await _refresh();
    if (paired ?? false) {
      _toast(_messenger, 'Paired. You can now share the week.');
    }
  }

  Widget _row(String label, String note, VoidCallback onTap) => whiteRow(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: hind(16, FontWeight.w500, Colours.ink)),
        Text(note, style: hind(13, FontWeight.w400, Colours.inkSoft)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final when = [
      'Last sent: ${state?.lastSent == null ? 'Not yet' : familyTime(state!.lastSent!)}',
      'Last received: ${state?.lastReceived == null ? 'Not yet' : familyTime(state!.lastReceived!)}',
    ];
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        backgroundColor: Colours.parentPaper,
        body: SafeArea(
          child: Column(
            children: [
              parentHeader('Family phones'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (state == null)
                      const SizedBox.shrink()
                    else if (state.code == null) ...[
                      _line(
                        'No other phone is paired. Pair one to share the week.',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: parentButton('Pair another phone', _pair),
                      ),
                    ] else ...[
                      _row(
                        'Send to the other phone',
                        'Sends what is new since the last time',
                        _send,
                      ),
                      for (final line in when) _line(line),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: parentButton(
                          'Pair another phone',
                          _pair,
                          ghost: true,
                        ),
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

class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

enum _Step { choose, show, type }

class _PairScreenState extends ConsumerState<PairScreen> {
  final _typed = TextEditingController();
  var _step = _Step.choose;
  List<String>? _code;
  String? _wrong;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    final code = await ref.read(familyRepositoryProvider).showCode();
    if (!mounted) return;
    setState(() {
      _code = code.toNullable();
      _step = _Step.show;
    });
  }

  Future<void> _pair() async {
    final result = await ref.read(familyRepositoryProvider).pair(_typed.text);
    if (!mounted) return;
    switch (result) {
      case Left(:final value):
        setState(() => _wrong = value.message);
      case Right():
        context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return Scaffold(
      backgroundColor: Colours.parentPaper,
      body: SafeArea(
        child: Column(
          children: [
            parentHeader('Pair another phone'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      Flexible(child: parentButton('Show our code', _show)),
                      Flexible(
                        child: parentButton(
                          'I have a code',
                          () => setState(() => _step = _Step.type),
                          ghost: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_step == _Step.show && code != null) ...[
                    whiteRow(
                      child: Text(
                        code.join(' '),
                        style: hind(22, FontWeight.w500, Colours.ink),
                      ),
                    ),
                    _line(
                      'Type these six words on the other phone. Keep them in '
                      'the family.',
                    ),
                  ],
                  if (_step == _Step.type) ...[
                    TextField(
                      controller: _typed,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.none,
                      style: hind(18, FontWeight.w500, Colours.ink),
                      decoration: InputDecoration(
                        hintText: 'six words',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                      ),
                      onChanged: (_) {
                        if (_wrong != null) setState(() => _wrong = null);
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_wrong != null) _line(_wrong!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: parentButton('Pair', _pair),
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
