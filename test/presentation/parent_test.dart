import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/repositories/sqlite_pack_repository.dart';
import 'package:starbook/data/repositories/sqlite_progress_repository.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/main.dart';
import 'package:starbook/presentation/child/days.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/sfx.dart';

class _Player extends Fake implements AudioPlayer {
  final played = <String>[];

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as AssetSource).path);
  }
}

const _words = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

final _today = Weekday.values[DateTime.now().weekday - 1];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<Widget> _app(WidgetTester tester, _Player player) async {
  final (db, packs) = (await tester.runAsync(() async {
    final db = (await openStore(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
    )).getOrElse((f) => throw StateError(f.message));
    final packs = SqlitePackRepository(db);
    await packs.install(
      jsonEncode({
        'starbook': 1,
        'id': 'home',
        'revision': 1,
        'title': 'Home',
        'sheets': [
          {
            'id': 'week',
            'title': 'Week',
            'days': [
              {
                'weekday': _today.name,
                'title': 'Letters',
                'tasks': [
                  {'id': 't1', 'text': 'Write A'},
                ],
              },
            ],
            'everyDay': [
              {'id': 'e1', 'text': 'Read a story', 'bonus': true},
            ],
          },
        ],
        'awards': [
          {'id': 'star', 'kind': 'star', 'label': 'Star'},
          {
            'id': 'sticker',
            'kind': 'sticker',
            'label': 'Sticker',
            'stickers': ['lion'],
          },
        ],
      }),
    );
    return (db, packs);
  }))!;
  addTearDown(db.close);
  return ProviderScope(
    overrides: [
      packRepositoryProvider.overrideWithValue(packs),
      progressRepositoryProvider.overrideWithValue(
        SqliteProgressRepository(db, packs),
      ),
      sfxProvider.overrideWithValue(Sfx(player)),
    ],
    child: const StarbookApp(),
  );
}

List<int> _shown(WidgetTester tester) {
  final words = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .firstWhere(RegExp(r'^[a-z]+, [a-z]+, [a-z]+$').hasMatch);
  return [for (final w in words.split(', ')) _words.indexOf(w)];
}

Future<void> _type(WidgetTester tester, List<int> digits) async {
  for (final d in digits) {
    await tester.tap(find.widgetWithText(OutlinedButton, '$d'));
    await tester.pump();
  }
  await _settle(tester);
}

Future<void> _openGate(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
  await tester.tap(find.bySemanticsLabel('Grown-ups'));
  await _settle(tester);
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('the gate opens parent today only for the shown numbers, shows '
      'new numbers after a wrong try, and three wrong tries lock it for 60 '
      'seconds even across closing and reopening', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(await _app(tester, _Player()));
    await _settle(tester);

    await _openGate(tester);
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Type the numbers'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      final before = _shown(tester);
      await _type(tester, [before[0] % 9 + 1, before[1], before[2]]);
      if (i < 2) expect(_shown(tester), isNot(before));
    }
    expect(find.text('Please wait a minute (60)'), findsOneWidget);
    expect(find.text('Type the numbers'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, '1'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await _openGate(tester);
    expect(find.textContaining('Please wait a minute'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Type the numbers'), findsOneWidget);
    await _type(tester, _shown(tester));
    expect(find.text('Today, ${weekdayNames[_today.index]}'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an award given in parent today can be replaced and undone, and '
      'after Done the home lands only the award left live, once, with the '
      'typed reward', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    await tester.pumpWidget(await _app(tester, player));
    await _settle(tester);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    for (final text in [
      'LETTERS',
      'Write A',
      'EVERY DAY (BONUS)',
      'Read a story',
      "THIS WEEK'S REWARD",
      'MORE',
      'Packs',
      '1 installed ›',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    await tester.tap(find.text('★ Star').first);
    await _settle(tester);
    expect(find.text('Star given for "Write A"'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('◐ Sticker').first);
    await _settle(tester);
    expect(find.text('Sticker given for "Write A"'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField), 'Park on Sunday');
    await _settle(tester);

    await tester.tap(find.text('Done'));
    await tester.pump();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i == 3) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
    }
    expect(find.text('Park on Sunday'), findsOneWidget);
    expect(player.played, ['sounds/star-1.ogg']);
    semantics.dispose();
  });
}
