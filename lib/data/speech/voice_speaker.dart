import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/repositories.dart';
import '../../domain/speaker.dart';

final _punctuation = RegExp(r'^\p{P}+$', unicode: true);

/// Character offsets of the spoken words: space-separated tokens that are not
/// all punctuation.
List<int> _wordStarts(String text) {
  final starts = <int>[];
  var offset = 0;
  for (final token in text.split(' ')) {
    if (token.isNotEmpty && !_punctuation.hasMatch(token)) starts.add(offset);
    offset += token.length + 1;
  }
  return starts;
}

class VoiceSpeaker implements Speaker {
  VoiceSpeaker(this._voices, {AudioPlayer? player, FlutterTts? tts})
    : _player = player ?? AudioPlayer(),
      _tts = tts ?? FlutterTts() {
    _tts.setCompletionHandler(() => _ttsEnd(true));
    _tts.setErrorHandler((_) => _ttsEnd(true));
    _tts.setCancelHandler(() => _ttsEnd(false));
    _tts.setProgressHandler((text, start, end, word) {
      if (_ttsOwner != _turn) return;
      _progress = true;
      final i = _starts.lastIndexWhere((s) => s <= start);
      if (i >= 0) _onWord?.call(i);
    });
  }

  final VoiceRepository _voices;
  final AudioPlayer _player;
  final FlutterTts _tts;

  int _turn = 0;
  Completer<bool>? _pending;
  // The read that is speaking through the phone voice. Engine events count
  // only for the current read, so a late event from an older read does nothing.
  int? _ttsOwner;
  List<int> _starts = const [];
  void Function(int)? _onWord;
  bool _progress = false;
  // Set once a sentence that wanted word callbacks got no progress events.
  bool _noProgress = false;

  @override
  Future<bool> speakWord(String text, String language, {bool slow = false}) =>
      _speak(text, language, slow ? 0.28 : 0.35, slow, null);

  @override
  Future<bool> speakSentence(
    String text,
    String language, {
    bool slow = false,
    void Function(int word)? onWord,
  }) => _speak(text, language, slow ? 0.28 : 0.4, slow, onWord);

  @override
  Future<void> stop() async {
    _newTurn();
    await _halt();
  }

  @override
  Future<VoiceStatus> voiceStatus(String language) async {
    try {
      final wanted = language.toLowerCase();
      final usable = [
        for (final v in await _tts.getVoices as List)
          if (v is Map &&
              '${v['locale']}'
                  .toLowerCase()
                  .replaceAll('_', '-')
                  .startsWith(wanted) &&
              !'${v['features']}'.contains('notInstalled'))
            v,
      ];
      return (
        installed: usable.isNotEmpty,
        offline: usable.any((v) => '${v['network_required']}' == '0'),
      );
    } catch (_) {
      return (installed: false, offline: false);
    }
  }

  // Takes the turn before any await, so two quick calls cannot both play.
  void _newTurn() {
    _turn++;
    _ttsOwner = null;
    _end(_pending, false);
    _pending = null;
  }

  Future<void> _halt() async {
    await _quietly(_player.stop);
    await _quietly(_tts.stop);
  }

  void _ttsEnd(bool completed) {
    if (_ttsOwner != _turn) return;
    _ttsOwner = null;
    _end(_pending, completed);
  }

  static void _end(Completer<bool>? read, bool completed) {
    if (read != null && !read.isCompleted) read.complete(completed);
  }

  Future<bool> _speak(
    String text,
    String language,
    double rate,
    bool slow,
    void Function(int)? onWord,
  ) async {
    _newTurn();
    final turn = _turn;
    await _halt();
    if (turn != _turn) return false;
    final clip = _voices.clipFor(text, language);
    if (clip != null) {
      final played = await _playClip(clip, text, slow, onWord, turn);
      if (played != null) return played;
    }
    try {
      if (onWord != null && _noProgress) {
        return await _wordByWord(text, language, rate, onWord, turn);
      }
      _progress = false;
      _onWord = onWord;
      _starts = _wordStarts(text);
      final completed = await _utter(text, language, rate, turn);
      if (onWord != null && completed && !_progress) _noProgress = true;
      return completed;
    } catch (_) {
      return true;
    }
  }

  // Null when the clip could not be played, so the phone voice takes over.
  Future<bool?> _playClip(
    Clip clip,
    String text,
    bool slow,
    void Function(int)? onWord,
    int turn,
  ) async {
    final read = _pending = Completer<bool>();
    final subs = <StreamSubscription<Object?>>[];
    try {
      subs.add(
        _player.onPlayerComplete.listen(
          (_) => _end(read, true),
          onError: (_) => _end(read, false),
        ),
      );
      try {
        await _player.setPlaybackRate(slow ? 0.8 : 1);
        await _player.play(DeviceFileSource(clip.path));
      } catch (_) {
        return turn == _turn ? null : false;
      }
      if (turn != _turn) {
        await _quietly(_player.stop);
        return false;
      }
      // Subscribed after play so the stop from _halt is not heard. A stop that
      // is not a completion ends the read.
      subs.add(
        _player.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.stopped || state == PlayerState.disposed) {
            _end(read, false);
          }
        }),
      );
      if (onWord != null) {
        final starts = clip.starts ?? await _evenSplit(text);
        var last = -1;
        subs.add(
          _player.onPositionChanged.listen((position) {
            final seconds = position.inMilliseconds / 1000;
            final i = starts.lastIndexWhere((s) => s <= seconds);
            if (i >= 0 && i != last) onWord(last = i);
          }),
        );
      }
      return await read.future;
    } finally {
      for (final sub in subs) {
        await sub.cancel();
      }
    }
  }

  Future<List<double>> _evenSplit(String text) async {
    try {
      final length = await _player.getDuration();
      final words = _wordStarts(text).length;
      if (length == null || words == 0) return const [];
      final seconds = length.inMilliseconds / 1000;
      return [for (var i = 0; i < words; i++) seconds * i / words];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {}
  }

  Future<bool> _wordByWord(
    String text,
    String language,
    double rate,
    void Function(int) onWord,
    int turn,
  ) async {
    _onWord = null;
    final words = [
      for (final token in text.split(' '))
        if (token.isNotEmpty && !_punctuation.hasMatch(token)) token,
    ];
    for (var i = 0; i < words.length; i++) {
      if (turn != _turn) return false;
      onWord(i);
      if (!await _utter(words[i], language, rate, turn)) return false;
    }
    return true;
  }

  Future<bool> _utter(
    String text,
    String language,
    double rate,
    int turn,
  ) async {
    final read = _pending = Completer<bool>();
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(rate);
    if (read.isCompleted) return read.future;
    _ttsOwner = turn;
    await _tts.speak(text);
    return read.future;
  }
}
