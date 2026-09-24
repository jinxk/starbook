import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fpdart/fpdart.dart'
    show Either, Left, Right, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/repositories.dart';
import '../db/store_db.dart';

typedef _Voice = ({
  String id,
  String title,
  String language,
  int revision,
  Map<String, Clip> clips,
});

typedef _Read = ({
  Archive zip,
  String manifest,
  List<String> names,
  VoiceInfo info,
});

final _voiceId = RegExp(r'^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$');

String _normalise(String text) => text.trim().replaceAll(RegExp(' {2,}'), ' ');

Either<Failure, T> _bad<T>(String reason) => left(Failure(reason));

class SqliteVoiceRepository implements VoiceRepository {
  SqliteVoiceRepository(this._db, this._files);

  final Database _db;
  final String _files;
  List<String> _picked = const [];
  Set<String> _activeIds = const {};
  List<_Voice> _voices = const [];

  @override
  Future<Either<Failure, Unit>> start(List<Uint8List> bundled) =>
      guard(() async {
        Either<Failure, Unit>? failed;
        for (final zip in bundled) {
          final result = await guard(() async {
            switch (_read(zip)) {
              case Left(:final value):
                return left<Failure, Unit>(value);
              case Right(:final value):
                final had = await _revision(value.info.id);
                if (had == null || value.info.revision > had) {
                  await _write(value);
                }
                return right(unit);
            }
          });
          if (result.isLeft()) failed ??= result;
        }
        await _reload();
        return failed ?? right(unit);
      });

  @override
  List<VoiceInfo> get installed => [
    for (final v in _voices)
      (id: v.id, title: v.title, language: v.language, revision: v.revision),
  ];

  @override
  Set<String> get active => _activeIds;

  @override
  Either<Failure, VoiceInfo> check(Uint8List zip) =>
      _read(zip).map((read) => read.info);

  @override
  Future<Either<Failure, InstallResult>> install(
    Uint8List zip, {
    bool confirmed = false,
  }) => guard(() async {
    switch (_read(zip)) {
      case Left(:final value):
        return left(value);
      case Right(:final value):
        final had = await _revision(value.info.id);
        if (had != null && value.info.revision <= had && !confirmed) {
          return right(InstallResult.needsConfirm);
        }
        await _write(value);
        await _reload();
        return right(InstallResult.installed);
    }
  });

  @override
  Future<Either<Failure, Unit>> pick(String id) => guard(() async {
    final voice = _voices.where((v) => v.id == id).firstOrNull;
    if (voice == null) return _bad('$id is not installed');
    final same = {
      for (final v in _voices)
        if (_language(v) == _language(voice)) v.id,
    };
    await _db.insert('settings', {
      'key': 'activeVoice',
      'value': jsonEncode([..._picked.where((p) => !same.contains(p)), id]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _reload();
    return right(unit);
  });

  @override
  Clip? clipFor(String text, String language) {
    final key = _normalise(text);
    final wanted = language.toLowerCase();
    final ordered = [
      ..._voices.where((v) => _activeIds.contains(v.id)),
      ..._voices.where((v) => !_activeIds.contains(v.id)),
    ];
    for (final voice in ordered) {
      final own = _language(voice);
      if (wanted != own && !wanted.startsWith('$own-')) continue;
      final clip = voice.clips[key];
      if (clip != null) return clip;
    }
    return null;
  }

  String _language(_Voice voice) => voice.language.toLowerCase();

  Either<Failure, _Read> _read(Uint8List bytes) {
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
    final String text;
    final Object? manifest;
    try {
      text = utf8.decode(file.content);
      manifest = jsonDecode(text);
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
    return right((
      zip: zip,
      manifest: text,
      names: names,
      info: (
        id: id,
        title: manifest['title'] as String,
        language: manifest['language'] as String,
        revision: revision,
      ),
    ));
  }

  Future<int?> _revision(String id) async {
    final rows = await _db.query(
      'voices',
      columns: ['revision'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['revision'] as int;
  }

  Future<void> _write(_Read read) async {
    final id = read.info.id;
    final folder = Directory('$_files/voices/$id');
    final fresh = Directory('${folder.path}~new');
    final old = Directory('${folder.path}~old');
    if (fresh.existsSync()) await fresh.delete(recursive: true);
    if (old.existsSync()) await old.delete(recursive: true);
    for (final name in read.names) {
      final target = File('${fresh.path}/$name');
      await target.create(recursive: true);
      await target.writeAsBytes(read.zip.find(name)!.content);
    }
    if (folder.existsSync()) await folder.rename(old.path);
    try {
      await fresh.rename(folder.path);
      await _db.insert('voices', {
        'id': id,
        'revision': read.info.revision,
        'title': read.info.title,
        'language': read.info.language,
        'manifest_json': read.manifest,
        'folder': 'voices/$id',
        'installed_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      if (folder.existsSync()) await folder.delete(recursive: true);
      if (old.existsSync()) await old.rename(folder.path);
      rethrow;
    }
    if (old.existsSync()) await old.delete(recursive: true);
  }

  Future<void> _reload() async {
    final picked = await _db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['activeVoice'],
    );
    _picked = picked.isEmpty
        ? const []
        : _ids(picked.single['value'] as String);
    final rows = await _db.query('voices', orderBy: 'id');
    _voices = [
      for (final r in rows)
        (
          id: r['id'] as String,
          title: r['title'] as String,
          language: r['language'] as String,
          revision: r['revision'] as int,
          clips: _clips(r['folder'] as String, r['manifest_json'] as String),
        ),
    ];
    _activeIds = {
      for (final language in {for (final v in _voices) _language(v)})
        _voices
            .where((v) => _language(v) == language)
            .firstWhere(
              (v) => _picked.contains(v.id),
              orElse: () => _voices.firstWhere((v) => _language(v) == language),
            )
            .id,
    };
  }

  List<String> _ids(String value) {
    try {
      final list = jsonDecode(value);
      if (list is List) return list.cast<String>();
    } catch (_) {}
    return [value];
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
