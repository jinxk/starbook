import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/domain/progress/progress.dart';

final _pictureRows = RegExp(
  r'^\| `([a-z0-9-]+)` \| ([^|]+?) \|',
  multiLine: true,
).allMatches(File('docs/pictures.md').readAsStringSync());

final _stickerRows = RegExp(
  r'^\| ([a-z0-9-]+) \| ([0-9a-f_]+|none) \| [^|]+? \| ([^|]+?) \|',
  multiLine: true,
).allMatches(File('docs/stickers.md').readAsStringSync());

Future<Set<String>> bundled() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest.listAssets().toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every library picture is bundled', () async {
    final assets = await bundled();
    final names = _pictureRows.map((m) => m[1]!);
    expect(names.length, greaterThan(300));
    for (final name in names) {
      expect(assets, contains('assets/pictures/$name.svg'));
    }
  });

  test('every sticker has its files, sits on exactly one page, and the pages '
      'are the sticker list in order', () async {
    final assets = await bundled();
    for (final m in _stickerRows) {
      expect(assets, contains('assets/stickers/${m[1]}.png'));
      expect(
        assets.contains('assets/stickers/${m[1]}.json'),
        m[2] != 'none',
        reason: m[1],
      );
    }
    expect([
      for (final p in stickerPages)
        for (final s in p.stickers) (s, p.name),
    ], _stickerRows.map((m) => (m[1]!, m[3]!)).toList());
    expect(defaultStickers.toSet().length, defaultStickers.length);
  });

  test('default packs name only library pictures, listed stickers and '
      'bundled icons', () async {
    final assets = await bundled();
    final pictures = _pictureRows.map((m) => m[1]!).toSet();
    final stickers = _stickerRows.map((m) => m[1]!).toSet();

    void walk(Object? node, String where) {
      if (node is List) {
        for (final item in node) {
          walk(item, where);
        }
      } else if (node is Map<String, dynamic>) {
        for (final MapEntry(:key, :value) in node.entries) {
          switch ((key, value)) {
            case ('picture' || 'cover', final String name)
                when !name.startsWith('emoji:'):
              expect(pictures, contains(name), reason: where);
            case ('stickers', final List names):
              for (final name in names) {
                expect(stickers, contains(name), reason: where);
              }
            case ('icon', final String name):
              expect(assets, contains('assets/icons/$name.svg'), reason: where);
            default:
              walk(value, where);
          }
        }
      }
    }

    final files = Directory(
      'packs',
    ).listSync().where((f) => f.path.endsWith('.json'));
    expect(files, isNotEmpty);
    for (final file in files) {
      walk(jsonDecode(File(file.path).readAsStringSync()), file.path);
    }
  });
}
