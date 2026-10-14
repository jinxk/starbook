import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/domain/progress/progress.dart';
import 'package:starbook/presentation/sfx.dart';

class _Player extends Fake implements AudioPlayer {
  _Player({this.fails = false});

  final bool fails;
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
    if (fails) throw PlatformException(code: 'no file');
    played.add((source as AssetSource).path);
  }
}

void main() {
  test('Sfx plays nothing when sound is off, and star steps stop at the top '
      'note', () async {
    final player = _Player();
    final sfx = Sfx(player)..on = false;
    await sfx.play(Sound.star);
    await sfx.sticker('lion');
    expect(player.played, isEmpty);

    sfx.on = true;
    await sfx.play(Sound.star, step: 9);
    expect(player.played, ['sounds/star-5.ogg']);
  });

  test('Sfx never throws when the player fails', () async {
    await expectLater(Sfx(_Player(fails: true)).play(Sound.trophy), completes);
  });

  test('every sound Sfx can play is bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final player = _Player();
    final sfx = Sfx(player);
    for (final sound in Sound.values) {
      await sfx.play(sound);
    }
    for (var step = 1; step <= 5; step++) {
      await sfx.play(Sound.star, step: step);
    }
    for (final name in defaultStickers) {
      await sfx.sticker(name);
    }
    expect(
      player.played.where((p) => p.startsWith('sticker-sounds/')).toSet(),
      hasLength(23),
    );
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final path in player.played) {
      expect(manifest.listAssets(), contains('assets/$path'), reason: path);
    }
  });
}
