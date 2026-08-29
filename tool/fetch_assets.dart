// Downloads the bundled pictures, stickers, icons and licence texts.
// Run from the repo root: dart run tool/fetch_assets.dart
import 'dart:io';

const fluent =
    'https://raw.githubusercontent.com/microsoft/fluentui-emoji/'
    '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
const phosphor = 'https://raw.githubusercontent.com/phosphor-icons/core/v2.0.8';
const noto = 'https://fonts.gstatic.com/s/e/notoemoji/latest';
const ccLegalcode = 'https://creativecommons.org/licenses/by/4.0/legalcode.txt';

const icons = {
  'back': 'arrow-left',
  'next': 'arrow-right',
  'play': 'play',
  'lock': 'lock',
  'settings': 'gear',
  'import': 'download-simple',
  'share': 'share-fat',
  'undo': 'arrow-u-up-left',
  'pencil': 'pencil',
  'book': 'book',
  'story': 'book-open-text',
  'numbers': 'number-one',
  'letters': 'text-aa',
  'shapes': 'shapes',
  'music': 'music-notes',
  'draw': 'paint-brush',
  'talk': 'chat-circle',
  'habit': 'repeat',
};

final client = HttpClient();
final failures = <String>[];

/// The bytes at [url], or null on any failure (recorded unless [quiet]).
Future<List<int>?> get(String url, {bool quiet = false}) async {
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final bytes = <int>[for (final chunk in await response.toList()) ...chunk];
    if (response.statusCode == 200) return bytes;
    if (!quiet) failures.add('${response.statusCode} $url');
  } on Exception catch (e) {
    if (!quiet) failures.add('$e $url');
  }
  return null;
}

Future<void> save(String path, String url, {String? fallbackUrl}) async {
  var bytes = await get(url, quiet: fallbackUrl != null);
  if (bytes == null && fallbackUrl != null) bytes = await get(fallbackUrl);
  if (bytes == null) {
    if (fallbackUrl != null) failures.add('not found $url');
    return;
  }
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln(path);
}

String stemOf(String folder) => folder.toLowerCase().replaceAll(' ', '_');

Future<void> main() async {
  final pictures = RegExp(
    r'^\| `([a-z0-9-]+)` \| ([^|]+?) \|',
    multiLine: true,
  ).allMatches(File('docs/pictures.md').readAsStringSync());
  for (final m in pictures) {
    final name = m[1]!;
    final folder = m[2]!;
    if (folder == 'drawn') continue;
    final dir = '$fluent/assets/${Uri.encodeComponent(folder)}';
    final stem = stemOf(folder);
    await save(
      'assets/pictures/$name.svg',
      '$dir/Flat/${stem}_flat.svg',
      fallbackUrl: '$dir/Default/Flat/${stem}_flat_default.svg',
    );
  }

  final stickers = RegExp(
    r'^\| ([a-z0-9-]+) \| ([0-9a-f_]+|none) \| ([^|]+?) \|',
    multiLine: true,
  ).allMatches(File('docs/stickers.md').readAsStringSync());
  for (final m in stickers) {
    final name = m[1]!;
    final codepoint = m[2]!;
    final folder = m[3]!;
    await save(
      'assets/stickers/$name.png',
      '$fluent/assets/${Uri.encodeComponent(folder)}/3D/${stemOf(folder)}_3d.png',
    );
    if (codepoint != 'none') {
      await save('assets/stickers/$name.json', '$noto/$codepoint/lottie.json');
    }
  }

  for (final MapEntry(:key, :value) in icons.entries) {
    await save(
      'assets/icons/$key.svg',
      '$phosphor/assets/fill/$value-fill.svg',
    );
  }
  await save(
    'assets/icons/turtle.svg',
    '$fluent/assets/Turtle/Flat/turtle_flat.svg',
  );

  await save('assets/licenses/fluentui-emoji.txt', '$fluent/LICENSE');
  await save('assets/licenses/phosphor.txt', '$phosphor/LICENSE');
  await save('assets/licenses/cc-by-4.0.txt', ccLegalcode);

  client.close();
  if (failures.isNotEmpty) {
    stderr.writeln('Failed:');
    failures.forEach(stderr.writeln);
    exitCode = 1;
  }
}
