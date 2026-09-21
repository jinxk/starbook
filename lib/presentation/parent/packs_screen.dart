import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/repositories.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';

const _cardBorder = Color(0xFFEBE3D0);
const _chipBorder = Color(0xFFE2D8C2);
const _limit = 50 * 1024 * 1024;

TextStyle _hind(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.hind,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class PacksScreen extends ConsumerStatefulWidget {
  const PacksScreen({super.key});

  @override
  ConsumerState<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends ConsumerState<PacksScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  String? _active;
  String? _added;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final file = ref.read(incomingFileProvider);
      if (file == null) return;
      ref.read(incomingFileProvider.notifier).drop();
      unawaited(_open(file.name, file.bytes));
    });
  }

  Future<void> _refresh() async {
    final active = await ref.read(progressRepositoryProvider).activeSheet();
    if (!mounted) return;
    setState(() => _active = active.getOrElse((_) => null));
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile();
    if (file == null || !mounted) return;
    final size = await file.length();
    if (size != null && size > _limit) {
      return _error('the file is larger than 50 MB');
    }
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return _error('the file could not be read');
    }
    if (!mounted) return;
    await _open(file.name, bytes);
  }

  Future<void> _open(String name, Uint8List bytes) async {
    if (bytes.length > _limit) return _error('the file is larger than 50 MB');
    if (bytes.isEmpty) return _error('the file could not be read');
    if (bytes.length > 1 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      switch (ref.read(voiceRepositoryProvider).check(bytes)) {
        case Left(:final value):
          return _error(value.message);
        case Right(:final value):
          return _voiceSheet(name, bytes, value);
      }
    }
    final String json;
    try {
      json = utf8.decode(bytes);
    } on FormatException {
      return _error('the file is not valid JSON');
    }
    switch (ref.read(packRepositoryProvider).check(json)) {
      case Left(:final value):
        return _error(value.message);
      case Right(:final value):
        return _packSheet(name, json, value);
    }
  }

  Future<void> _packSheet(String name, String json, Pack pack) async {
    final packs = ref.read(packRepositoryProvider);
    final had = packs.installed.where((p) => p.id == pack.id).firstOrNull;
    final again = had != null && pack.revision <= had.revision;
    final by = pack.author == null ? '' : ' · from ${pack.author}';
    final yes = await _sheet(
      again ? 'Replace this pack?' : 'Add this pack?',
      row: _row(pack.title, '$name · revision ${pack.revision}$by', [
        for (final sheet in pack.sheets) _sheetTag(pack, sheet),
        ..._holds(pack),
      ]),
      note: again
          ? 'This pack is already added at revision ${had.revision}.'
          : null,
      yes: again ? 'Replace' : 'Add',
      no: 'Cancel',
    );
    if (!yes || !mounted || _busy) return;
    _busy = true;
    try {
      switch (await packs.install(json, confirmed: again)) {
        case Left(:final value):
          await _error(value.message);
        case Right():
          _added = pack.id;
          await _refresh();
          _toast('Added: ${pack.title}');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _voiceSheet(
    String name,
    Uint8List bytes,
    VoiceInfo voice,
  ) async {
    final voices = ref.read(voiceRepositoryProvider);
    final had = voices.installed.where((v) => v.id == voice.id).firstOrNull;
    final again = had != null && voice.revision <= had.revision;
    final yes = await _sheet(
      again ? 'Replace this voice?' : 'Add this voice?',
      row: _row(
        voice.title,
        '$name · revision ${voice.revision} · ${voice.language}',
        const [],
      ),
      note: again
          ? 'This voice is already added at revision ${had.revision}.'
          : null,
      yes: again ? 'Replace' : 'Add',
      no: 'Cancel',
    );
    if (!yes || !mounted || _busy) return;
    _busy = true;
    try {
      switch (await voices.install(bytes, confirmed: again)) {
        case Left(:final value):
          await _error(value.message);
        case Right():
          await _refresh();
          _toast('Added: ${voice.title}');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _error(String line) =>
      _sheet('This file could not be added.', note: line, yes: 'OK');

  Future<void> _remove(Pack pack) async {
    final yes = await _sheet(
      'Remove this pack?',
      row: _row(pack.title, _meta(pack), _tags(pack)),
      note: 'Stars already given stay.',
      yes: 'Remove',
      no: 'Cancel',
    );
    if (!yes || !mounted || _busy) return;
    _busy = true;
    try {
      await ref.read(packRepositoryProvider).remove(pack.id);
      await _refresh();
    } finally {
      _busy = false;
    }
  }

  Future<void> _use(String sheetRef) async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(progressRepositoryProvider).setActiveSheet(sheetRef);
      await _refresh();
    } finally {
      _busy = false;
    }
  }

  Future<void> _voice(String id) async {
    if (_busy) return;
    _busy = true;
    try {
      await ref.read(voiceRepositoryProvider).pick(id);
      if (mounted) setState(() {});
    } finally {
      _busy = false;
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    _messenger.currentState!
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: _hind(15, FontWeight.w500, Colors.white)),
          duration: const Duration(seconds: 4),
          persist: false,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colours.ink,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  /// A bottom sheet; true when the first button is pressed.
  Future<bool> _sheet(
    String heading, {
    Widget? row,
    String? note,
    required String yes,
    String? no,
  }) async {
    final answer = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x591E190F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(heading, style: _hind(20, FontWeight.w500, Colours.ink)),
            const SizedBox(height: 12),
            ?row,
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  note,
                  style: _hind(
                    14,
                    FontWeight.w400,
                    Colours.inkSoft,
                  ).copyWith(height: 1.4),
                ),
              )
            else if (row != null)
              const SizedBox(height: 4),
            Row(
              spacing: 10,
              children: [
                _button(yes, () => Navigator.of(context).pop(true)),
                if (no != null)
                  _button(
                    no,
                    () => Navigator.of(context).pop(false),
                    ghost: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return answer ?? false;
  }

  Widget _button(String label, VoidCallback onPressed, {bool ghost = false}) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: ghost ? Colors.transparent : Colours.ink,
          foregroundColor: ghost ? Colours.ink : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: ghost
                ? const BorderSide(color: Colours.dash, width: 1.5)
                : BorderSide.none,
          ),
          textStyle: _hind(16, FontWeight.w500, Colours.ink),
        ),
        child: Text(label),
      );

  String _sheetTag(Pack pack, Sheet sheet) {
    final tasks = sheet.days.fold(
      sheet.everyDay.length,
      (sum, d) => sum + d.tasks.length,
    );
    final name = pack.sheets.length == 1 ? '1 sheet' : sheet.title;
    return '$name: ${_n(sheet.days.length, 'day', 'days')}, '
        '${_n(tasks, 'task', 'tasks')}';
  }

  String _meta(Pack pack) => [
    pack.author,
    'revision ${pack.revision}',
    pack.license,
  ].nonNulls.join(' · ');

  List<String> _holds(Pack pack) {
    final stickers = {
      for (final a in pack.awards)
        if (a.kind == AwardKind.sticker)
          ...(a.stickers.isEmpty ? defaultStickers : a.stickers),
    };
    return [
      if (pack.awards.isNotEmpty) _n(pack.awards.length, 'award', 'awards'),
      if (pack.milestones.isNotEmpty)
        _n(pack.milestones.length, 'milestone', 'milestones'),
      if (stickers.isNotEmpty) _n(stickers.length, 'sticker', 'stickers'),
      if (pack.wordBooks.isNotEmpty)
        _n(pack.wordBooks.length, 'word book', 'word books'),
      if (pack.stories.isNotEmpty) _n(pack.stories.length, 'story', 'stories'),
    ];
  }

  List<String> _tags(Pack pack) => [
    if (pack.sheets.isNotEmpty) _n(pack.sheets.length, 'sheet', 'sheets'),
    if (_active?.startsWith('${pack.id}/') ?? false) 'active',
    ..._holds(pack),
  ];

  Widget _tag(String text) => Container(
    margin: const EdgeInsets.only(top: 6, right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colours.paperDeep,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: _hind(11, FontWeight.w500, Colours.ink)),
  );

  Widget _row(
    String title,
    String meta,
    List<String> tags, {
    Key? key,
    bool leaf = false,
    Widget? trailing,
    List<String> needed = const [],
  }) => Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: leaf ? Colours.leaf : _cardBorder),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: Text(
                title,
                style: _hind(16, FontWeight.w500, Colours.ink),
              ),
            ),
            ?trailing,
          ],
        ),
        Text(meta, style: _hind(13, FontWeight.w400, Colours.inkSoft)),
        Wrap(children: [for (final t in tags) _tag(t)]),
        for (final line in needed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              line,
              style: _hind(13, FontWeight.w400, Colours.inkSoft),
            ),
          ),
      ],
    ),
  );

  Widget _installedRow(Pack pack, List<Pack> installed) {
    final onlyAwards =
        pack.awards.isNotEmpty &&
        installed.every((p) => p.id == pack.id || p.awards.isEmpty);
    final onlySheets =
        pack.sheets.isNotEmpty &&
        installed.every((p) => p.id == pack.id || p.sheets.isEmpty);
    return _row(
      pack.title,
      _meta(pack),
      _tags(pack),
      key: ValueKey(pack.id),
      leaf: pack.id == _added,
      trailing: onlyAwards || onlySheets
          ? null
          : OutlinedButton(
              onPressed: () => _remove(pack),
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: _chipBorder, width: 1.5),
                backgroundColor: Colors.white,
                foregroundColor: Colours.ink,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: _hind(13, FontWeight.w500, Colours.ink),
              ),
              child: const Text('Remove'),
            ),
      needed: [
        if (onlyAwards) 'Needed for the awards.',
        if (onlySheets) 'Needed for the week.',
      ],
    );
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: _hind(
        13,
        FontWeight.w500,
        Colours.inkSoft,
      ).copyWith(letterSpacing: 0.78),
    ),
  );

  Widget _choice(
    String title,
    String below,
    bool active,
    VoidCallback onTap,
  ) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _hind(16, FontWeight.w500, Colours.ink)),
                Text(below, style: _hind(13, FontWeight.w400, Colours.inkSoft)),
              ],
            ),
          ),
          if (active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colours.paperDeep,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'active',
                style: _hind(11, FontWeight.w500, Colours.ink),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(packRepositoryProvider).installed;
    final voices = ref.watch(voiceRepositoryProvider);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(parentTodayProvider);
      },
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: Colours.parentPaper,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Row(
                    spacing: 10,
                    children: [
                      const BackDisc(),
                      Text(
                        'Packs',
                        style: _hind(26, FontWeight.w500, Colours.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final pack in installed)
                        _installedRow(pack, installed),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _button('Import a pack', _pick),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'You can also open a .json file with Starbook from '
                          'WhatsApp, Gmail or Files.',
                          style: _hind(
                            14,
                            FontWeight.w400,
                            Colours.inkSoft,
                          ).copyWith(height: 1.4),
                        ),
                      ),
                      if (_active != null) ...[
                        _heading('Active sheet'),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            'This week keeps its sheet. A new sheet starts '
                            'next week.',
                            style: _hind(
                              14,
                              FontWeight.w400,
                              Colours.inkSoft,
                            ).copyWith(height: 1.4),
                          ),
                        ),
                        for (final pack in installed)
                          for (final sheet in pack.sheets)
                            _choice(
                              sheet.title,
                              pack.title,
                              _active == '${pack.id}/${sheet.id}',
                              () => _use('${pack.id}/${sheet.id}'),
                            ),
                      ],
                      if (voices.installed.isNotEmpty) ...[
                        _heading('Voices'),
                        for (final voice in voices.installed)
                          _choice(
                            voice.title,
                            '${voice.language} · revision ${voice.revision}',
                            voices.active.contains(voice.id),
                            () => _voice(voice.id),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
