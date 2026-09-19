import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/repositories.dart';
import 'package:starbook/domain/speaker.dart';
import 'package:starbook/presentation/child/stories_screen.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/sfx.dart';
import 'package:starbook/presentation/theme/colours.dart';

class _Packs extends Fake implements PackRepository {
  _Packs(this.installed);

  @override
  final List<Pack> installed;
}

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

class _Speaker extends Fake implements Speaker {
  final sentences = <(String, bool)>[];
  final words = <(String, bool)>[];
  void Function(int word)? onWord;
  Completer<bool>? _open;
  var stops = 0;

  @override
  Future<bool> speakSentence(
    String text,
    String language, {
    bool slow = false,
    void Function(int word)? onWord,
  }) {
    sentences.add((text, slow));
    this.onWord = onWord;
    return (_open = Completer<bool>()).future;
  }

  @override
  Future<bool> speakWord(
    String text,
    String language, {
    bool slow = false,
  }) async {
    words.add((text, slow));
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    final open = _open;
    if (open != null && !open.isCompleted) open.complete(false);
  }
}

Future<void> _open(
  WidgetTester tester,
  List<String> pages, {
  Map<String, String> say = const {},
  _Speaker? speaker,
  _Player? player,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pack = Pack(
    id: 'p',
    revision: 1,
    title: 'P',
    language: 'en-IN',
    stories: [
      Story(
        id: 's',
        title: 'S',
        level: 1,
        say: say,
        pages: [for (final text in pages) StoryPage(text: text)],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        packRepositoryProvider.overrideWithValue(_Packs([pack])),
        speakerProvider.overrideWithValue(speaker ?? _Speaker()),
        sfxProvider.overrideWithValue(Sfx(player ?? _Player())),
      ],
      child: const MaterialApp(home: StoryReaderScreen('p', 's')),
    ),
  );
  await tester.pump();
}

bool _lit(WidgetTester tester, String word) {
  final box = tester.widget<Container>(
    find.ancestor(of: find.text(word), matching: find.byType(Container)).first,
  );
  return (box.decoration! as BoxDecoration).color == Colours.sunflower;
}

Future<void> _wait(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 350)),
);

void main() {
  testWidgets('play lights the word the speaker reports, stop and a page turn '
      'clear the light and cut the read, a late word from a cut read lights '
      'nothing, and a tapped word is read through the story\'s say map', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final speaker = _Speaker();
    final player = _Player();
    await _open(
      tester,
      ['Aaji has a bit.', 'I see a cat.', 'Bye now.'],
      say: {'Aaji': 'aa-jee'},
      speaker: speaker,
      player: player,
    );
    const page = ['Aaji', 'has', 'a', 'bit.'];
    bool anyLit() => page.any((w) => _lit(tester, w));

    await tester.tap(find.bySemanticsLabel('Read to me'));
    await tester.pump();
    expect(speaker.sentences, [('aa-jee has a bit.', false)]);
    expect(anyLit(), isFalse);
    speaker.onWord!(0);
    await tester.pump();
    expect(_lit(tester, 'Aaji'), isTrue);
    speaker.onWord!(1);
    await tester.pump();
    expect(_lit(tester, 'has'), isTrue);
    expect(_lit(tester, 'Aaji'), isFalse);

    await _wait(tester);
    await tester.tap(find.bySemanticsLabel('Read to me'));
    await tester.pump();
    expect(speaker.stops, 1);
    expect(anyLit(), isFalse);

    await tester.tap(find.text('bit.'));
    await tester.pump();
    expect(speaker.words.last, ('bit', false));
    await tester.tap(find.text('Aaji'));
    await tester.pump();
    expect(speaker.words.last, ('aa-jee', false));

    await tester.tap(find.bySemanticsLabel('Slow reading'));
    await tester.pump();
    await _wait(tester);
    await tester.tap(find.bySemanticsLabel('Read to me'));
    await tester.pump();
    expect(speaker.sentences.last, ('aa-jee has a bit.', true));
    final old = speaker.onWord!;
    old(2);
    await tester.pump();
    expect(_lit(tester, 'a'), isTrue);

    final stops = speaker.stops;
    await tester.tap(find.bySemanticsLabel('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    expect(speaker.stops, greaterThan(stops));
    expect(['I', 'see', 'a', 'cat.'].any((w) => _lit(tester, w)), isFalse);
    expect(player.played.last, 'sounds/flip.ogg');
    old(0);
    await tester.pump();
    expect(['I', 'see', 'a', 'cat.'].any((w) => _lit(tester, w)), isFalse);

    semantics.dispose();
  });

  testWidgets('a sentence that does not fit at 40 steps down and never '
      'renders below 32', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, [
      'I see a cat.',
      'The big red hen and the little dog sat on the mat by the door.',
      'Bye now.',
    ]);
    expect(tester.widget<Text>(find.text('cat.')).style!.fontSize, 40);

    await tester.tap(find.bySemanticsLabel('Next page'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('little')).style!.fontSize, 32);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
