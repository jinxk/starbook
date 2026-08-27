import 'package:audioplayers/audioplayers.dart';

enum Sound { star, peel, press, trophy, flip }

class Sfx {
  Sfx([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool on = true;

  /// [step] is the star's number in the day, from 1; it raises the note.
  Future<void> play(Sound sound, {int step = 1}) async {
    if (!on) return;
    final file = sound == Sound.star ? 'star-${step.clamp(1, 5)}' : sound.name;
    try {
      await _player.play(AssetSource('sounds/$file.ogg'));
    } catch (_) {
      // A missing or broken file stays silent.
    }
  }
}
