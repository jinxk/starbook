import 'package:audioplayers/audioplayers.dart';

enum Sound { star, peel, press, trophy, flip }

/// Stickers with their own call in assets/sticker-sounds; the rest twinkle.
const _calls = {
  'lion',
  'tiger',
  'elephant',
  'dog',
  'cat',
  'peacock',
  'owl',
  'bear',
  'fox',
  'cow',
  'pig',
  'horse',
  'goat',
  'rooster',
  'chick',
  'dolphin',
  'frog',
  'whale',
  'seal',
  'otter',
  'flamingo',
  'bee',
};

class Sfx {
  Sfx([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool on = true;

  /// [step] is the star's number in the day, from 1; it raises the note.
  Future<void> play(Sound sound, {int step = 1}) => _play(
    'sounds/${sound == Sound.star ? 'star-${step.clamp(1, 5)}' : sound.name}.ogg',
  );

  Future<void> sticker(String name) =>
      _play('sticker-sounds/${_calls.contains(name) ? name : 'twinkle'}.ogg');

  Future<void> _play(String path) async {
    if (!on) return;
    try {
      await _player.play(AssetSource(path));
    } catch (_) {
      // A missing or broken file stays silent.
    }
  }
}
