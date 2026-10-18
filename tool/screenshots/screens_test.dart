// Screenshot tool, run on demand. Plain `flutter test` runs test/ only.
//
// Writes the README screenshots to docs/screenshots/:
//   flutter test --update-goldens tool/screenshots
// The gate shows a random sum.
//
// Writes the Play store images and a contact sheet to a folder (default
// tmp/store):
//   flutter test tool/screenshots --plain-name store --dart-define=out=<folder>
// (Play images, outside the repo). The store group needs the Windows font
// Segoe UI Symbol (C:/Windows/Fonts/seguisym.ttf).
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart' show getCrc32;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/rendering.dart';
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
import 'package:starbook/presentation/theme/colours.dart';
import 'package:starbook/presentation/theme/type.dart';
import 'package:starbook/presentation/widgets/sticker_view.dart';

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

/// nextSticker takes the first sticker not owned yet, so the seed fills the
/// Animals page.
class _First extends Fake implements Random {
  @override
  int nextInt(int max) => 0;
}

/// A Wednesday, so home and parent today show a school day on any run day.
DateTime _now() => DateTime(2026, 10, 14, 10);

/// A week with Asha's name, stickers on Monday and Wednesday, three habits ticked
/// and one trophy, all already seen so nothing animates. With [newSticker],
/// one more sticker is left unseen on Monday so home opens the reveal.
Future<Widget> _app(WidgetTester tester, {bool newSticker = false}) async {
  final (db, dir, packs, progress) = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('starbook_screens');
    final db = _ok(
      await openStore(databaseFactoryFfiNoIsolate, '${dir.path}/starbook.db'),
    );
    final packs = SqlitePackRepository(db);
    final files =
        Directory('packs')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    _ok(await packs.start([for (final f in files) f.readAsStringSync()]));
    final progress = SqliteProgressRepository(
      db,
      packs,
      now: _now,
      random: _First(),
    );
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

    await give(Weekday.monday, 0, 'sticker');
    await give(Weekday.monday, 1, 'sticker');
    await give(Weekday.monday, 2, 'sticker');
    await give(Weekday.monday, 3, 'sticker');
    await give(Weekday.wednesday, 0, 'sticker');
    await give(Weekday.wednesday, 1, 'sticker');
    _ok(await progress.tickHabit(week.id, 'bath'));
    _ok(await progress.tickHabit(week.id, 'teeth-morning'));
    _ok(await progress.tickHabit(week.id, 'breakfast'));
    _ok(await progress.setChild(const Child(name: 'Asha', picture: 'lion')));
    _ok(await progress.setSpecialReward(week.id, 'Ice cream on Sunday'));
    _ok(await progress.takeUnseen(week.id));
    _ok(await progress.takeMoments(week.id));
    if (newSticker) await give(Weekday.monday, 4, 'sticker');
    return (db, dir, packs, progress);
  }))!;
  addTearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });
  return ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(_now),
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

const _out = String.fromEnvironment('out', defaultValue: 'tmp/store');

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

List<int> _chunk(String type, List<int> data) {
  final body = [...ascii.encode(type), ...data];
  return [..._u32(data.length), ...body, ..._u32(getCrc32(body))];
}

/// Play takes 24-bit PNG with no alpha; Flutter's encoder always writes alpha.
Future<Uint8List> _png(ui.Image image) async {
  final rgba = (await image.toByteData())!.buffer.asUint8List();
  final w = image.width;
  final rows = BytesBuilder();
  for (var i = 0; i < rgba.length; i += 4) {
    if (i % (w * 4) == 0) rows.addByte(0);
    rows.add(rgba.sublist(i, i + 3));
  }
  return Uint8List.fromList([
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    ..._chunk('IHDR', [..._u32(w), ..._u32(image.height), 8, 2, 0, 0, 0]),
    ..._chunk('IDAT', zlib.encode(rows.takeBytes())),
    ..._chunk('IEND', []),
  ]);
}

Future<void> _save(
  WidgetTester tester,
  Size size,
  Widget canvas,
  String file,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        key: const ValueKey('canvas'),
        color: Colours.paperDeep,
        child: canvas,
      ),
    ),
  );
  await tester.runAsync(() async {
    final image = await captureImage(
      tester.element(find.byKey(const ValueKey('canvas'))),
    );
    File('$_out/$file').writeAsBytesSync(await _png(image));
  });
}

void _store(
  String name,
  String caption,
  String route, {
  bool reveal = false,
  bool symbols = false,
}) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await _app(tester, newSticker: reveal));
    if (reveal) {
      // The reveal draws its sticker at 240.
      final shown = find.byWidgetPredicate(
        (w) => w is StickerView && w.size == 240,
      );
      for (var i = 0; i < 40 && shown.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      expect(shown, findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    } else {
      await _settle(tester);
      ProviderScope.containerOf(
        tester.element(find.byType(StarbookApp)),
      ).read(routerProvider).go(route);
      await _settle(tester);
    }
    if (symbols) {
      // ★ and ◐ are in no bundled font; a phone takes them from a system font.
      for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
        final span = p.text as TextSpan;
        p.text = TextSpan(
          text: span.text,
          children: span.children,
          style: span.style!.copyWith(fontFamilyFallback: const ['Symbols']),
        );
      }
      await tester.pump();
    }
    final screen = (await tester.runAsync(
      () => captureImage(tester.element(find.byType(StarbookApp))),
    ))!;
    await _save(
      tester,
      const Size(1080, 1920),
      Column(
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 72),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: Fonts.baloo,
                    fontWeight: FontWeight.w700,
                    fontSize: 68,
                    color: Colours.ink,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 675,
            height: 1500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(44),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332B2A33),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: RawImage(
                image: screen,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
      '$name.png',
    );
    debugDisableShadows = true;
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    WidgetsApp.debugAllowBannerOverride = false;
    await _loadFonts();
  });

  group('store', () {
    setUpAll(() async {
      final symbols = FontLoader('Symbols')
        ..addFont(
          File(
            'C:/Windows/Fonts/seguisym.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await symbols.load();
      Directory(_out).createSync(recursive: true);
    });

    _store('01-home', 'Stickers fill up the school week', '/');
    _store(
      '02-sticker-reveal',
      'A new sticker for good work',
      '/',
      reveal: true,
    );
    _store('03-sticker-book', 'Stickers go in the sticker book', '/stickers');
    _store('04-habits', 'Good habits earn stickers too', '/habits');
    _store(
      '05-parent-today',
      'Parents give the stickers',
      '/parent',
      symbols: true,
    );
    _store(
      '06-word-book',
      'Tap to hear each word',
      '/words/starbook.vowels/short-a',
    );
    _store(
      '07-story',
      'Short stories to read along',
      '/stories/starbook.first-stories/i-see',
    );
    _store('08-trophies', 'Trophies stay on the shelf', '/trophies');

    testWidgets('contact-sheet', (tester) async {
      addTearDown(tester.view.reset);
      final files =
          Directory(_out)
              .listSync()
              .whereType<File>()
              .where((f) => RegExp(r'^\d').hasMatch(f.uri.pathSegments.last))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      final images = (await tester.runAsync(
        () => Future.wait([
          for (final f in files) decodeImageFromList(f.readAsBytesSync()),
        ]),
      ))!;
      await _save(
        tester,
        const Size(1560, 1352),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              for (final i in images)
                RawImage(
                  image: i,
                  width: 360,
                  height: 640,
                  filterQuality: FilterQuality.high,
                ),
            ],
          ),
        ),
        'contact-sheet.png',
      );
    });
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
