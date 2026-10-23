import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';

final _idPattern = RegExp(r'^[a-z0-9][a-z0-9.-]*$');
final _refPattern = RegExp(r'^[a-z0-9][a-z0-9.-]*(/[a-z0-9][a-z0-9.-]*)?$');
final _languagePattern = RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$');
final _picturePattern = RegExp(r'^(emoji:.+|[a-z0-9][a-z0-9-]*)$');

final _stickerSet = defaultStickers.toSet();

const _colours = ['tomato', 'sunflower', 'leaf', 'sky', 'plum', 'sand'];
const _icons = [
  'pencil',
  'book',
  'story',
  'numbers',
  'letters',
  'shapes',
  'music',
  'draw',
  'talk',
  'habit',
];
const _trophies = [
  'cup-gold',
  'cup-silver',
  'medal',
  'ribbon',
  'crown',
  'rocket',
  'rainbow',
  'star-big',
  'book-gold',
  'heart',
];

/// Checks the output of `jsonDecode` against `schema/pack.schema.json` and
/// returns every problem as a line like `sheets[0].days[1].tasks[0]: text is missing`.
/// An empty list means the pack is valid.
List<String> validatePack(Object? json) {
  if (json is! Map<String, dynamic>) return ['the file is not a Starbook pack'];
  return (_Validator()..pack(json)).errors;
}

class _Validator {
  final errors = <String>[];

  void _err(String at, String message) =>
      errors.add(at.isEmpty ? message : '$at: $message');

  String _at(String parent, String field) =>
      parent.isEmpty ? field : '$parent.$field';

  Map<String, dynamic>? _object(
    Object? value,
    String at,
    List<String> required,
    List<String> allowed,
  ) {
    if (value is! Map<String, dynamic>) {
      _err(at, 'must be an object');
      return null;
    }
    for (final field in required) {
      if (!value.containsKey(field)) _err(at, '$field is missing');
    }
    for (final field in value.keys) {
      if (!allowed.contains(field)) _err(at, '$field is not allowed');
    }
    return value;
  }

  void _opt(
    Map<String, dynamic> m,
    String at,
    String field,
    void Function(Object? value, String at) check,
  ) {
    if (m.containsKey(field)) check(m[field], _at(at, field));
  }

  bool _string(Object? v, String at) {
    if (v is String) return true;
    _err(at, 'must be text');
    return false;
  }

  bool _text(Object? v, String at) {
    if (!_string(v, at)) return false;
    if ((v as String).isEmpty) {
      _err(at, 'must not be empty');
      return false;
    }
    return true;
  }

  bool _cheer(Object? v, String at) {
    if (!_text(v, at)) return false;
    if ((v as String).runes.length > 40) {
      _err(at, 'must be 40 characters or fewer');
      return false;
    }
    return true;
  }

  bool _tip(Object? v, String at) {
    if (!_string(v, at)) return false;
    final tip = (v as String).trim();
    if (tip.isEmpty) {
      _err(at, 'must not be empty');
      return false;
    }
    if (tip.contains('\n') || tip.contains('\r')) {
      _err(at, 'must not have line breaks');
      return false;
    }
    if (tip.runes.length > 80) {
      _err(at, 'must be 80 characters or fewer');
      return false;
    }
    return true;
  }

  bool _bool(Object? v, String at) {
    if (v is bool) return true;
    _err(at, 'must be true or false');
    return false;
  }

  bool _whole(Object? v, String at, {int? max}) {
    final isWhole =
        v is int || (v is double && v.isFinite && v == v.truncateToDouble());
    if (!isWhole) {
      _err(at, 'must be a whole number');
      return false;
    }
    final n = v as num;
    if (n < 1 || (max != null && n > max)) {
      _err(at, max == null ? 'must be 1 or more' : 'must be from 1 to $max');
      return false;
    }
    return true;
  }

  bool _oneOf(Object? v, String at, List<String> values) {
    if (!_string(v, at)) return false;
    if (values.contains(v)) return true;
    _err(at, '"$v" is not one of ${values.join(', ')}');
    return false;
  }

  bool _pattern(Object? v, String at, RegExp pattern, String name) {
    if (!_string(v, at)) return false;
    if (pattern.hasMatch(v as String)) return true;
    _err(at, '"$v" is not a valid $name');
    return false;
  }

  bool _itemId(Object? v, String at) => _pattern(v, at, _idPattern, 'id');
  bool _ref(Object? v, String at) => _pattern(v, at, _refPattern, 'reference');
  bool _language(Object? v, String at) =>
      _pattern(v, at, _languagePattern, 'language tag');
  bool _picture(Object? v, String at) =>
      _pattern(v, at, _picturePattern, 'picture');
  bool _weekday(Object? v, String at) =>
      _oneOf(v, at, [for (final d in Weekday.values) d.name]);
  bool _colour(Object? v, String at) => _oneOf(v, at, _colours);

  void _unique(Set<String> seen, Object? value, String at) {
    if (value is String && !seen.add(value)) {
      _err(at, '"$value" is already used');
    }
  }

  void _id(Map<String, dynamic> m, String at, Set<String> seen) {
    _opt(m, at, 'id', (v, p) {
      if (_itemId(v, p)) _unique(seen, v, p);
    });
  }

  List<Object?>? _list(Object? v, String at, {bool nonEmpty = false}) {
    if (v is! List) {
      _err(at, 'must be a list');
      return null;
    }
    if (nonEmpty && v.isEmpty) {
      _err(at, 'must not be empty');
      return null;
    }
    return v;
  }

  void _objects(
    Object? v,
    String at,
    void Function(Object? item, String at) check, {
    bool nonEmpty = false,
  }) {
    final list = _list(v, at, nonEmpty: nonEmpty);
    if (list == null) return;
    for (final (i, item) in list.indexed) {
      check(item, '$at[$i]');
    }
  }

  void pack(Map<String, dynamic> m) {
    const at = '';
    _object(
      m,
      at,
      ['starbook', 'id', 'revision', 'title'],
      [
        'starbook',
        'id',
        'revision',
        'title',
        'language',
        'author',
        'license',
        'sheets',
        'awards',
        'milestones',
        'wordbooks',
        'stories',
      ],
    );
    _opt(m, at, 'starbook', (v, p) {
      if (v != 1) _err(p, 'must be 1');
    });
    _opt(m, at, 'id', _itemId);
    _opt(m, at, 'revision', _whole);
    _opt(m, at, 'title', _text);
    _opt(m, at, 'language', _language);
    _opt(m, at, 'author', _string);
    _opt(m, at, 'license', _string);
    final sheets = <String>{};
    _opt(
      m,
      at,
      'sheets',
      (v, p) => _objects(v, p, (item, ip) => _sheet(item, ip, sheets)),
    );
    final awards = <String>{};
    _opt(
      m,
      at,
      'awards',
      (v, p) => _objects(v, p, (item, ip) => _award(item, ip, awards)),
    );
    final milestones = <String>{};
    _opt(
      m,
      at,
      'milestones',
      (v, p) => _objects(v, p, (item, ip) => _milestone(item, ip, milestones)),
    );
    final wordBooks = <String>{};
    _opt(
      m,
      at,
      'wordbooks',
      (v, p) => _objects(v, p, (item, ip) => _wordBook(item, ip, wordBooks)),
    );
    final stories = <String>{};
    _opt(
      m,
      at,
      'stories',
      (v, p) => _objects(v, p, (item, ip) => _story(item, ip, stories)),
    );
  }

  void _sheet(Object? v, String at, Set<String> ids) {
    final m = _object(
      v,
      at,
      ['id', 'title', 'days'],
      [
        'id',
        'title',
        'intro',
        'language',
        'days',
        'everyDay',
        'restDays',
        'restMessage',
        'weekGoal',
        'habits',
      ],
    );
    if (m == null) return;
    final taskIds = <String>{};
    final habitIds = <String>{};
    final weekdays = <String>{};
    _id(m, at, ids);
    _opt(m, at, 'title', _text);
    _opt(m, at, 'intro', _string);
    _opt(m, at, 'language', _language);
    _opt(m, at, 'days', (v, p) {
      if (v is List && v.length > 7) _err(p, 'must have at most 7 days');
      _objects(
        v,
        p,
        (item, ip) => _day(item, ip, weekdays, taskIds),
        nonEmpty: true,
      );
    });
    _opt(
      m,
      at,
      'everyDay',
      (v, p) => _objects(v, p, (item, ip) => _task(item, ip, taskIds)),
    );
    _opt(m, at, 'restDays', (v, p) {
      final list = _list(v, p);
      if (list == null) return;
      final seen = <String>{};
      for (final (i, item) in list.indexed) {
        if (_weekday(item, '$p[$i]')) _unique(seen, item, '$p[$i]');
      }
    });
    _opt(m, at, 'restMessage', _string);
    _opt(m, at, 'weekGoal', _string);
    _opt(
      m,
      at,
      'habits',
      (v, p) => _objects(v, p, (item, ip) => _habit(item, ip, habitIds)),
    );
  }

  void _habit(Object? v, String at, Set<String> ids) {
    final m = _object(
      v,
      at,
      ['id', 'text', 'picture'],
      ['id', 'text', 'picture', 'sticker', 'say'],
    );
    if (m == null) return;
    _id(m, at, ids);
    _opt(m, at, 'text', _text);
    _opt(m, at, 'picture', _picture);
    _opt(m, at, 'sticker', (v, p) {
      if (_string(v, p) && !_stickerSet.contains(v)) {
        _err(p, '"$v" is not a sticker');
      }
    });
    _opt(m, at, 'say', _text);
  }

  void _day(Object? v, String at, Set<String> weekdays, Set<String> taskIds) {
    final m = _object(
      v,
      at,
      ['weekday', 'title', 'tasks'],
      ['weekday', 'title', 'colour', 'tasks'],
    );
    if (m == null) return;
    _opt(m, at, 'weekday', (v, p) {
      if (_weekday(v, p)) _unique(weekdays, v, p);
    });
    _opt(m, at, 'title', _text);
    _opt(m, at, 'colour', _colour);
    _opt(
      m,
      at,
      'tasks',
      (v, p) => _objects(
        v,
        p,
        (item, ip) => _task(item, ip, taskIds),
        nonEmpty: true,
      ),
    );
  }

  void _task(Object? v, String at, Set<String> taskIds) {
    final m = _object(
      v,
      at,
      ['id', 'text'],
      [
        'id',
        'text',
        'say',
        'cheer',
        'tip',
        'language',
        'icon',
        'opens',
        'bonus',
      ],
    );
    if (m == null) return;
    _id(m, at, taskIds);
    _opt(m, at, 'text', _text);
    _opt(m, at, 'say', _text);
    _opt(m, at, 'cheer', _cheer);
    _opt(m, at, 'tip', _tip);
    _opt(m, at, 'language', _language);
    _opt(m, at, 'icon', (v, p) => _oneOf(v, p, _icons));
    _opt(m, at, 'opens', _ref);
    _opt(m, at, 'bonus', _bool);
  }

  void _award(Object? v, String at, Set<String> ids) {
    final m = _object(
      v,
      at,
      ['id', 'kind', 'label'],
      [
        'id',
        'kind',
        'label',
        'say',
        'language',
        'colour',
        'stars',
        'stickers',
        'retired',
      ],
    );
    if (m == null) return;
    _id(m, at, ids);
    _opt(
      m,
      at,
      'kind',
      (v, p) => _oneOf(v, p, [for (final k in AwardKind.values) k.name]),
    );
    _opt(m, at, 'label', _text);
    _opt(m, at, 'say', _text);
    _opt(m, at, 'language', _language);
    _opt(m, at, 'colour', _colour);
    _opt(m, at, 'stars', (v, p) => _whole(v, p, max: 3));
    _opt(m, at, 'retired', _bool);
    _opt(m, at, 'stickers', (v, p) {
      final list = _list(v, p, nonEmpty: true);
      if (list == null) return;
      final seen = <String>{};
      for (final (i, item) in list.indexed) {
        if (_picture(item, '$p[$i]')) _unique(seen, item, '$p[$i]');
      }
    });
  }

  void _milestone(Object? v, String at, Set<String> ids) {
    final m = _object(
      v,
      at,
      ['id', 'title', 'trophy', 'when'],
      ['id', 'title', 'trophy', 'when'],
    );
    if (m == null) return;
    _id(m, at, ids);
    _opt(m, at, 'title', _text);
    _opt(m, at, 'trophy', (v, p) => _oneOf(v, p, _trophies));
    _opt(m, at, 'when', (v, p) {
      final counters = [for (final c in MilestoneCounter.values) c.name];
      final w = _object(v, p, [], counters);
      if (w == null) return;
      if (w.length != 1) _err(p, 'must have exactly one counter');
      for (final e in w.entries) {
        if (counters.contains(e.key)) _whole(e.value, _at(p, e.key));
      }
    });
  }

  void _wordBook(Object? v, String at, Set<String> ids) {
    final m = _object(
      v,
      at,
      ['id', 'title', 'cards'],
      ['id', 'title', 'letter', 'colour', 'language', 'cards'],
    );
    if (m == null) return;
    _id(m, at, ids);
    _opt(m, at, 'title', _text);
    _opt(m, at, 'letter', _string);
    _opt(m, at, 'colour', _colour);
    _opt(m, at, 'language', _language);
    _opt(m, at, 'cards', (v, p) => _objects(v, p, _card, nonEmpty: true));
  }

  void _card(Object? v, String at) {
    final m = _object(
      v,
      at,
      ['word'],
      ['word', 'picture', 'big', 'count', 'group', 'say', 'language'],
    );
    if (m == null) return;
    if (!m.containsKey('picture') && !m.containsKey('big')) {
      _err(at, 'picture or big is missing');
    }
    if (m.containsKey('count') && !m.containsKey('picture')) {
      _err(at, 'count needs a picture');
    }
    _opt(m, at, 'word', _text);
    _opt(m, at, 'picture', _picture);
    _opt(m, at, 'big', _text);
    _opt(m, at, 'count', (v, p) => _whole(v, p, max: 10));
    _opt(m, at, 'group', _string);
    _opt(m, at, 'say', _text);
    _opt(m, at, 'language', _language);
  }

  void _story(Object? v, String at, Set<String> ids) {
    final m = _object(
      v,
      at,
      ['id', 'title', 'level', 'pages'],
      ['id', 'title', 'level', 'cover', 'language', 'pages', 'say', 'credit'],
    );
    if (m == null) return;
    _id(m, at, ids);
    _opt(m, at, 'title', _text);
    _opt(m, at, 'level', (v, p) => _whole(v, p, max: 3));
    _opt(m, at, 'cover', _picture);
    _opt(m, at, 'language', _language);
    _opt(m, at, 'pages', (v, p) => _objects(v, p, _page, nonEmpty: true));
    _opt(m, at, 'say', (v, p) {
      if (v is! Map<String, dynamic>) {
        _err(p, 'must be an object');
        return;
      }
      for (final e in v.entries) {
        _text(e.value, _at(p, e.key));
      }
    });
    _opt(m, at, 'credit', _credit);
  }

  void _page(Object? v, String at) {
    final m = _object(v, at, ['text'], ['text', 'picture']);
    if (m == null) return;
    _opt(m, at, 'text', _text);
    _opt(m, at, 'picture', _picture);
  }

  void _credit(Object? v, String at) {
    final m = _object(
      v,
      at,
      ['source', 'license'],
      ['source', 'url', 'license', 'text'],
    );
    if (m == null) return;
    for (final field in ['source', 'url', 'license', 'text']) {
      _opt(m, at, field, _string);
    }
  }
}
