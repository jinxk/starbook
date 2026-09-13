import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fpdart/fpdart.dart' show Either, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/repositories.dart';
import '../db/store_db.dart';

typedef _Voice = ({String id, String language, Map<String, Clip> clips});

final _voiceId = RegExp(r'^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$');

String _normalise(String text) => text.trim().replaceAll(RegExp(' {2,}'), ' ');

Either<Failure, Unit> _bad(String reason) =>
    left(Failure('Voice pack rejected: $reason'));

class SqliteVoiceRepository implements VoiceRepository {
  SqliteVoiceRepository(this._db, this._files);

  final Database _db;
  final String _files;
  String? _active;
  List<_Voice> _voices = const [];

  @override
  Future<Either<Failure, Unit>> start(List<Uint8List> bundled) =>
      guard(() async {
        Either<Failure, Unit>? failed;
        for (final zip in bundled) {
          final result = await _install(zip);
          if (result.isLeft()) failed ??= result;
        }
        await _reload();
        return failed ?? right(unit);
      });

  @override
  Clip? clipFor(String text, String language) {
    final key = _normalise(text);
    final wanted = language.toLowerCase();
    final ordered = [
      ..._voices.where((v) => v.id == _active),
      ..._voices.where((v) => v.id != _active),
    ];
    for (final voice in ordered) {
      final own = voice.language.toLowerCase();
      if (wanted != own && !wanted.startsWith('$own-')) continue;
      final clip = voice.clips[key];
      if (clip != null) return clip;
    }
    return null;
  }

  Future<Either<Failure, Unit>> _install(Uint8List bytes) => guard(() async {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return _bad('not a zip file');
    }
    if (zip.files.any((f) => f.name.contains('..'))) {
      return _bad('an entry path contains ..');
    }
    final file = zip.find('voice.json');
    if (file == null) return _bad('voice.json is missing');
    final Object? manifest;
    try {
      manifest = jsonDecode(utf8.decode(file.content));
    } catch (_) {
      return _bad('voice.json is not valid JSON');
    }
    if (manifest is! Map<String, dynamic>) {
      return _bad('voice.json is not an object');
    }
    if (manifest['starbookVoice'] != 1) return _bad('starbookVoice is not 1');
    final id = manifest['id'];
    if (id is! String || !_voiceId.hasMatch(id)) return _bad('bad id');
    final revision = manifest['revision'];
    if (revision is! int) return _bad('revision is not a whole number');
    for (final key in ['title', 'language']) {
      final value = manifest[key];
      if (value is! String || value.isEmpty) return _bad('$key is missing');
    }
    final clips = manifest['clips'];
    if (clips is! List) return _bad('clips is not a list');
    final names = <String>[];
    for (final clip in clips) {
      if (clip is! Map || clip['text'] is! String || clip['file'] is! String) {
        return _bad('a clip needs text and file');
      }
      final name = clip['file'] as String;
      if (zip.find(name)?.isFile != true) {
        return _bad('$name is not in the zip');
      }
      names.add(name);
    }

    final rows = await _db.query(
      'voices',
      columns: ['revision'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty && revision <= (rows.single['revision'] as int)) {
      return right(unit);
    }

    final folder = Directory('$_files/voices/$id');
    if (folder.existsSync()) await folder.delete(recursive: true);
    for (final name in names) {
      final target = File('${folder.path}/$name');
      await target.create(recursive: true);
      await target.writeAsBytes(zip.find(name)!.content);
    }
    await _db.insert('voices', {
      'id': id,
      'revision': revision,
      'title': manifest['title'],
      'language': manifest['language'],
      'manifest_json': utf8.decode(file.content),
      'folder': 'voices/$id',
      'installed_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return right(unit);
  });

  Future<void> _reload() async {
    final active = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['activeVoice'],
    );
    _active = active.isEmpty ? null : active.single['value'] as String;
    final rows = await _db.query('voices', orderBy: 'id');
    _voices = [
      for (final r in rows)
        (
          id: r['id'] as String,
          language: r['language'] as String,
          clips: _clips(r['folder'] as String, r['manifest_json'] as String),
        ),
    ];
  }

  Map<String, Clip> _clips(String folder, String manifestJson) {
    final clips = <String, Clip>{};
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    for (final clip in manifest['clips'] as List) {
      final words = clip['words'] as List?;
      clips.putIfAbsent(
        _normalise(clip['text'] as String),
        () => (
          path: '$_files/$folder/${clip['file']}',
          starts: words == null
              ? null
              : [for (final w in words) ((w as List).first as num).toDouble()],
        ),
      );
    }
    return clips;
  }
}
