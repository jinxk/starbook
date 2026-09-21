import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/pack/default_packs.dart';
import 'package:starbook/data/repositories/sqlite_voice_repository.dart';
import 'package:starbook/data/speech/voice_speaker.dart';
import 'package:starbook/domain/failure.dart';
import 'package:starbook/domain/repositories.dart';

T ok<T>(Either<Failure, T> result) =>
    result.getOrElse((f) => throw StateError(f.message));

/// A voice pack zip. Clip n of [texts] is `clips/n.ogg`. [missing] adds a clip
/// the zip has no file for; [extra] adds a loose entry with that name. [words]
/// gives a clip its word timings, keyed by the clip text.
Uint8List _zip(
  String id,
  int revision,
  List<String> texts, {
  bool missing = false,
  String? extra,
  Map<String, List<List<double>>> words = const {},
  String language = 'en',
}) {
  final archive = Archive();
  final clips = <Map<String, Object>>[];
  for (var i = 0; i < texts.length; i++) {
    clips.add({
      'text': texts[i],
      'file': 'clips/$i.ogg',
      if (words.containsKey(texts[i])) 'words': words[texts[i]]!,
    });
    archive.add(ArchiveFile.bytes('clips/$i.ogg', [i, 1, 2]));
  }
  if (missing) clips.add({'text': 'Gone', 'file': 'clips/gone.ogg'});
  if (extra != null) archive.add(ArchiveFile.bytes(extra, [9]));
  archive.add(
    ArchiveFile.string(
      'voice.json',
      jsonEncode({
        'starbookVoice': 1,
        'id': id,
        'revision': revision,
        'title': id,
        'language': language,
        'clips': clips,
      }),
    ),
  );
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

class _Player extends Fake implements AudioPlayer {
  final played = <String>[];
  final rates = <double>[];
  final positions = StreamController<Duration>.broadcast();
  final _complete = StreamController<void>.broadcast();
  bool hold = false;

  void finish() => _complete.add(null);

  @override
  Stream<void> get onPlayerComplete => _complete.stream;

  @override
  Stream<Duration> get onPositionChanged => positions.stream;

  @override
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();

  @override
  Future<void> setPlaybackRate(double playbackRate) async =>
      rates.add(playbackRate);

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as DeviceFileSource).path);
    if (!hold) scheduleMicrotask(finish);
  }

  @override
  Future<void> stop() async {}
}

class _Tts extends Fake implements FlutterTts {
  final languages = <String>[];
  final rates = <double>[];
  final spoken = <String>[];
  VoidCallback? _completed;

  @override
  void setCompletionHandler(VoidCallback callback) => _completed = callback;

  @override
  void setCancelHandler(VoidCallback callback) {}

  @override
  void setErrorHandler(ErrorHandler handler) {}

  @override
  void setProgressHandler(ProgressHandler callback) {}

  @override
  Future<dynamic> setLanguage(String language) async => languages.add(language);

  @override
  Future<dynamic> setSpeechRate(double rate) async => rates.add(rate);

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    scheduleMicrotask(() => _completed?.call());
  }

  @override
  Future<dynamic> stop() async {}
}

void main() {
  late Database db;
  late Directory files;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = ok(await openStore(databaseFactoryFfi, inMemoryDatabasePath));
    files = await Directory.systemTemp.createTemp('starbook_voice');
  });

  tearDown(() async {
    await db.close();
    await files.delete(recursive: true);
  });

  String clip(String voice, int n) =>
      '${files.path}/voices/$voice/clips/$n.ogg';

  test('voice lookup: normalised text, language prefix, the active voice wins '
      'per language, and no clip gives null', () async {
    final repo = SqliteVoiceRepository(db, files.path);
    ok(
      await repo.start([
        _zip('a', 1, ['Rain! now', 'Hello']),
        _zip('b', 1, ['Rain! now']),
        _zip('h1', 1, ['नमस्ते'], language: 'hi'),
        _zip('h2', 1, ['नमस्ते'], language: 'hi'),
      ]),
    );
    expect(repo.active, {'a', 'h1'});

    expect(repo.clipFor('  Rain!   now ', 'en-IN')?.path, clip('a', 0));
    expect(repo.clipFor('rain! now', 'en-IN'), isNull);
    expect(repo.clipFor('Hello', 'hi-IN'), isNull);
    expect(repo.clipFor('Hello', 'eng'), isNull);
    expect(repo.clipFor('Nothing', 'en'), isNull);

    ok(await repo.pick('b'));
    ok(await repo.pick('h2'));
    final next = SqliteVoiceRepository(db, files.path);
    ok(await next.start([]));
    expect(next.clipFor('Rain! now', 'en-IN')?.path, clip('b', 0));
    expect(next.clipFor('नमस्ते', 'hi-IN')?.path, clip('h2', 0));
    expect(next.active, {'b', 'h2'});
  });

  test('a voice pack imported from a file goes through the bundled checks: a '
      'missing clip and a .. entry are rejected and write nothing; the same '
      'revision asks and replaces only when confirmed; a higher one '
      'replaces', () async {
    final repo = SqliteVoiceRepository(db, files.path);
    ok(await repo.start([]));

    final missing = _zip('m', 1, ['x'], missing: true);
    expect(repo.check(missing).isLeft(), true);
    expect((await repo.install(missing)).isLeft(), true);
    final loose = _zip('d', 1, ['x'], extra: '../x.ogg');
    expect((await repo.install(loose)).isLeft(), true);
    expect(await db.query('voices'), isEmpty);
    expect(Directory('${files.path}/voices/m').existsSync(), false);
    expect(Directory('${files.path}/voices/d').existsSync(), false);
    expect(File('${files.path}/voices/x.ogg').existsSync(), false);

    expect(
      repo.check(_zip('r', 1, ['Old'])),
      right((id: 'r', title: 'r', language: 'en', revision: 1)),
    );
    expect(
      await repo.install(_zip('r', 1, ['Old'])),
      right(InstallResult.installed),
    );
    expect(repo.clipFor('Old', 'en'), isNotNull);

    final same = _zip('r', 1, ['New']);
    expect(await repo.install(same), right(InstallResult.needsConfirm));
    expect(repo.clipFor('New', 'en'), isNull);
    expect(
      await repo.install(same, confirmed: true),
      right(InstallResult.installed),
    );
    expect(repo.clipFor('New', 'en'), isNotNull);
    expect(repo.clipFor('Old', 'en'), isNull);

    expect(
      await repo.install(_zip('r', 2, ['Newer'])),
      right(InstallResult.installed),
    );
  });

  test('voice pack install: a missing clip file and a .. entry are rejected '
      'and write nothing; a higher bundled revision replaces', () async {
    final repo = SqliteVoiceRepository(db, files.path);

    expect(
      (await repo.start([
        _zip('m', 1, ['x'], missing: true),
      ])).isLeft(),
      true,
    );
    expect(await db.query('voices'), isEmpty);
    expect(Directory('${files.path}/voices/m').existsSync(), false);

    expect(
      (await repo.start([
        _zip('d', 1, ['x'], extra: '../x.ogg'),
      ])).isLeft(),
      true,
    );
    expect(await db.query('voices'), isEmpty);
    expect(Directory('${files.path}/voices/d').existsSync(), false);
    expect(File('${files.path}/voices/x.ogg').existsSync(), false);

    ok(
      await repo.start([
        _zip('r', 1, ['Old']),
      ]),
    );
    ok(
      await repo.start([
        _zip('r', 2, ['New']),
      ]),
    );
    expect(repo.clipFor('New', 'en'), isNotNull);
    expect(repo.clipFor('Old', 'en'), isNull);

    ok(
      await repo.start([
        _zip('r', 2, ['Other']),
      ]),
    );
    expect(repo.clipFor('New', 'en'), isNotNull);
    expect(repo.clipFor('Other', 'en'), isNull);
  });

  test('the bundled packs install side by side: a Hindi line plays from Divya, '
      'an English line from Heart', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = SqliteVoiceRepository(db, files.path);
    ok(await repo.start(await loadDefaultVoices()));

    expect(
      repo.clipFor('अ से अनार', 'hi-IN')?.path,
      contains('/voices/starbook.voice.divya/'),
    );
    expect(
      repo.clipFor('A new trophy!', 'en-IN')?.path,
      contains('/voices/starbook.voice.heart/'),
    );
  });

  test('the speaker plays a matching clip and sends a line with no clip to '
      'the phone voice at sentence rate', () async {
    final repo = SqliteVoiceRepository(db, files.path);
    ok(
      await repo.start([
        _zip('a', 1, ['Rain! now']),
      ]),
    );
    final player = _Player();
    final tts = _Tts();
    final speaker = VoiceSpeaker(repo, player: player, tts: tts);

    expect(await speaker.speakSentence('Rain! now', 'en-IN'), isTrue);
    expect(player.played, [clip('a', 0)]);
    expect(tts.spoken, isEmpty);

    expect(await speaker.speakSentence('No clip', 'en-IN'), isTrue);
    expect(tts.rates, [0.4]);
    expect(tts.spoken, ['No clip']);
  });

  test("a clip's word timings call onWord once per word, in order, as the "
      'media position passes each start, and slow mode keeps the same media '
      'times', () async {
    final repo = SqliteVoiceRepository(db, files.path);
    ok(
      await repo.start([
        _zip(
          'a',
          1,
          ['I see a cat.'],
          words: {
            'I see a cat.': [
              [0.0, 0.2],
              [0.2, 0.5],
              [0.5, 0.6],
              [0.6, 1.0],
            ],
          },
        ),
      ]),
    );
    final player = _Player()..hold = true;
    final speaker = VoiceSpeaker(repo, player: player, tts: _Tts());
    final lit = <int>[];

    final read = speaker.speakSentence(
      'I see a cat.',
      'en-IN',
      slow: true,
      onWord: lit.add,
    );
    await pumpEventQueue();
    for (final ms in [50, 100, 300, 550, 700]) {
      player.positions.add(Duration(milliseconds: ms));
      await pumpEventQueue();
    }
    player.finish();

    expect(await read, isTrue);
    expect(lit, [0, 1, 2, 3]);
    expect(player.rates, [0.8]);
  });
}
