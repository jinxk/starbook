import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:share_plus/share_plus.dart';

import '../../domain/repositories.dart';
import '../child/days.dart';
import '../providers.dart';
import '../theme/colours.dart';
import 'parts.dart';

const _limit = 50 * 1024 * 1024;

String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;

  String _fileName() {
    final now = DateTime.now();
    final day = now.toIso8601String().substring(0, 10);
    return 'starbook-backup-$day.json';
  }

  Future<Uint8List?> _export() async {
    final result = await ref.read(backupRepositoryProvider).export();
    switch (result) {
      case Left(:final value):
        _toast(value.message);
        return null;
      case Right(:final value):
        return Uint8List.fromList(utf8.encode(value));
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    _busy = true;
    try {
      final bytes = await _export();
      if (bytes == null) return;
      final saved = await FilePicker.saveFile(
        fileName: _fileName(),
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (saved != null) _toast('Backup saved.');
    } finally {
      _busy = false;
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    _busy = true;
    try {
      final bytes = await _export();
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json')],
          fileNameOverrides: [_fileName()],
        ),
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    _busy = true;
    try {
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
      if (bytes.length > _limit) return _error('the file is larger than 50 MB');
      if (bytes.isEmpty) return _error('the file could not be read');
      final String json;
      try {
        json = utf8.decode(bytes);
      } on FormatException {
        return _error('the file is not a Starbook backup');
      }
      final backup = ref.read(backupRepositoryProvider);
      switch (backup.check(json)) {
        case Left(:final value):
          return _error(value.message);
        case Right(:final value):
          if (!await _confirm(value) || !mounted) return;
      }
      switch (await backup.restore(json)) {
        case Left(:final value):
          return _error(value.message);
        case Right():
          await _applyPrefs();
          ref.invalidate(parentTodayProvider);
          ref.invalidate(thisWeekProvider);
          _toast('Backup restored.');
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _applyPrefs() async {
    final prefs = (await ref.read(progressRepositoryProvider).prefs())
        .getOrElse((_) => (sound: true, slowReading: false));
    if (!mounted) return;
    ref.read(sfxProvider).on = prefs.sound;
    ref.read(speakerProvider).slowReading = prefs.slowReading;
  }

  Future<bool> _confirm(BackupInfo info) {
    final made = info.made;
    final name = info.child?.trim() ?? '';
    return askSheet(
      context,
      'Restore this backup?',
      row: whiteRow(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Made on ${made.day} ${monthNames[made.month - 1]} ${made.year}',
              style: hind(16, FontWeight.w500, Colours.ink),
            ),
            Text(
              [
                if (name.isNotEmpty) name,
                _n(info.stars, 'star', 'stars'),
                _n(info.packs, 'pack', 'packs'),
              ].join(' · '),
              style: hind(13, FontWeight.w400, Colours.inkSoft),
            ),
          ],
        ),
      ),
      note: 'It replaces what is on this phone now.',
      yes: 'Restore',
      no: 'Cancel',
    );
  }

  Future<void> _error(String line) => askSheet(
    context,
    'This backup could not be restored.',
    note: line,
    yes: 'OK',
  );

  void _toast(String text) {
    if (!mounted) return;
    _messenger.currentState!
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: hind(15, FontWeight.w500, Colors.white)),
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

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
    child: Text(
      text,
      style: hind(14, FontWeight.w400, Colours.inkSoft).copyWith(height: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) {
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
                parentHeader('Backup'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _line(
                        'One file with the stars, stickers, trophies, habits, '
                        "this week's tasks, the child, packs and settings.",
                      ),
                      Row(
                        spacing: 10,
                        children: [
                          parentButton('Save a backup', _save),
                          parentButton('Share a backup', _share, ghost: true),
                        ],
                      ),
                      parentHeading('Restore'),
                      _line(
                        'Voice packs you added are not in the file. Add them '
                        'again on Packs.',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: parentButton(
                          'Restore a backup',
                          _restore,
                          ghost: true,
                        ),
                      ),
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
