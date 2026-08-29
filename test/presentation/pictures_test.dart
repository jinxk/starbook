import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/presentation/theme/colours.dart';
import 'package:starbook/presentation/widgets/picture.dart';
import 'package:starbook/presentation/widgets/sticker_view.dart';

Future<void> show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

final circle = find.byWidgetPredicate(
  (w) =>
      w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == Colours.paperDeep,
);

void main() {
  test('tilt is a fixed whole degree in -4..4 for every picture and sticker '
      'name', () {
    final names = [
      ...RegExp(r'^\| `([a-z0-9-]+)` \|', multiLine: true)
          .allMatches(File('docs/pictures.md').readAsStringSync())
          .map((m) => m[1]!),
      ...RegExp(r'^\| ([a-z0-9-]+) \| (?:[0-9a-f_]+|none) \|', multiLine: true)
          .allMatches(File('docs/stickers.md').readAsStringSync())
          .map((m) => m[1]!),
    ];
    expect(names.length, greaterThan(300));
    for (final name in names) {
      expect(tiltOf(name), inInclusiveRange(-4, 4), reason: name);
    }
    expect(tiltOf('lion'), -2);
    expect(tiltOf('cat'), -4);
  });

  testWidgets('a picture that is not in the library, and an emoji picture, '
      'render without an error', (tester) async {
    await show(tester, const Picture('no-such-picture'));
    expect(tester.takeException(), isNull);
    expect(circle, findsOneWidget);

    await show(tester, const Picture('emoji:🦚'));
    expect(tester.takeException(), isNull);
    expect(find.text('🦚'), findsOneWidget);
  });

  testWidgets('a sticker without an animation shows its still, and an unknown '
      'sticker falls back to the picture placeholder', (tester) async {
    await show(tester, const StickerView('elephant'));
    expect(tester.takeException(), isNull);
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
      images.map((i) => (i.image as AssetImage).assetName),
      everyElement('assets/stickers/elephant.png'),
    );
    expect(images, isNotEmpty);

    await show(tester, const StickerView('no-such-sticker'));
    expect(tester.takeException(), isNull);
    expect(circle, findsWidgets);
  });
}
