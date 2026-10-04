// Writes the README screenshots to docs/screenshots/. Run on demand:
//   flutter test --update-goldens tool/screenshots
// Plain `flutter test` runs test/ only. Run it on a school day (Monday to
// Friday) so parent today has tasks. The gate shows a random sum.
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/repositories/sqlite_pack_repository.dart';
import 'package:starbook/data/repositories/sqlite_progress_repository.dart';
import 'package:starbook/data/repositories/sqlite_voice_repository.dart';
import 'package:starbook/domain/failure.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';
import 'package:starbook/domain/speaker.dart';
import 'package:starbook/main.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/router.dart';
import 'package:starbook/presentation/sfx.dart';

class _Player extends Fake implements AudioPlayer {
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {}
}

class _Speaker extends Fake implements Speaker {
  @override
  bool slowReading = false;

  @override
  Future<bool> speakSentence(
    String text,
    String language, {
    bool? slow,
    void Function(int word)? onWord,
  }) async => true;

  @override
  Future<bool> speakWord(String text, String language, {bool? slow}) async =>
      true;

  @override
  Future<void> stop() async {}

  @override
  Future<VoiceStatus> voiceStatus(String language) async =>
      (installed: true, offline: true);
}

T _ok<T>(Either<Failure, T> result) =>
    result.getOrElse((f) => throw StateError(f.message));

/// Loads every font the app bundles, so text is not drawn in the test font.
Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// A week with Asha's name, stars on Monday, a Very good! stamp, a sticker,
/// one habit ticked and one trophy, all already seen so nothing animates.
Future<Widget> _app(WidgetTester tester) async {
  final (db, dir, packs, progress) = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('starbook_screens');
    final db = _ok(
      await openStore(databaseFactoryFfiNoIsolate, '${dir.path}/starbook.db'),
    );
    final packs = SqlitePackRepository(db);
    final files = Directory('packs').listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    _ok(await packs.start([for (final f in files) f.readAsStringSync()]));
    final progress = SqliteProgressRepository(db, packs);
    final week = _ok(await progress.currentWeek())!;
    Future<void> give(Weekday day, int task, String award) async {
      final tasks = week.sheet.days.firstWhere((d) => d.weekday == day).tasks;
      _ok(
        await progress.give(
          weekId: week.id,
          weekday: day,
          taskId: tasks[task].id,
          awardRef: 'starbook.basics/$award',
        ),
      );
    }

    await give(Weekday.monday, 0, 'star');
    await give(Weekday.monday, 1, 'star');
    await give(Weekday.monday, 2, 'very-good');
    await give(Weekday.monday, 3, 'sticker');
    final today = Weekday.values[DateTime.now().weekday - 1];
    if (today != Weekday.monday && today.index < 5) {
      await give(today, 0, 'star');
      await give(today, 1, 'very-good');
    }
    _ok(await progress.tickHabit(week.id, 'teeth-morning'));
    _ok(await progress.setChild(const Child(name: 'Asha', picture: 'lion')));
    _ok(await progress.setSpecialReward(week.id, 'Ice cream on Sunday'));
    _ok(await progress.takeUnseen(week.id));
    _ok(await progress.takeMoments(week.id));
    return (db, dir, packs, progress);
  }))!;
  addTearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });
  return ProviderScope(
    overrides: [
      packRepositoryProvider.overrideWithValue(packs),
      voiceRepositoryProvider.overrideWithValue(
        SqliteVoiceRepository(db, dir.path),
      ),
      progressRepositoryProvider.overrideWithValue(progress),
      sfxProvider.overrideWithValue(Sfx(_Player())),
      speakerProvider.overrideWithValue(_Speaker()),
    ],
    child: const StarbookApp(),
  );
}

/// Lets pictures, stickers and fonts load from the bundle, then runs the
/// animations out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void _shoot(String name, String route, {bool toEnd = false}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app(tester));
    await _settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    );
    container.read(routerProvider).go(route);
    await _settle(tester);
    if (toEnd) {
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -4000),
      );
      await _settle(tester);
    }
    await expectLater(
      find.byType(StarbookApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    WidgetsApp.debugAllowBannerOverride = false;
    await _loadFonts();
  });

  _shoot('home', '/');
  _shoot('day', '/day/monday');
  _shoot('trophies', '/trophies');
  _shoot('word-book', '/words/starbook.vowels/short-a');
  _shoot('story', '/stories/starbook.first-stories/i-see');
  _shoot('gate', '/gate');
  // Scrolled to the end: the star and half circle on the award chips are in
  // none of the bundled fonts, so a test draws them as boxes.
  _shoot('parent-today', '/parent', toEnd: true);
}
