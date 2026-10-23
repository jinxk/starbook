import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'data/db/store_db.dart';
import 'data/pack/default_packs.dart';
import 'data/repositories/sqlite_backup_repository.dart';
import 'data/repositories/sqlite_pack_repository.dart';
import 'data/repositories/sqlite_progress_repository.dart';
import 'data/repositories/sqlite_voice_repository.dart';
import 'data/speech/voice_speaker.dart';
import 'presentation/providers.dart';
import 'presentation/router.dart';
import 'presentation/sfx.dart';
import 'presentation/theme/colours.dart';
import 'presentation/theme/type.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final String folder;
  final Database db;
  try {
    folder = await databaseFactorySqflitePlugin.getDatabasesPath();
    final opened = await openStore(
      databaseFactorySqflitePlugin,
      '$folder/starbook.db',
    );
    if (opened.toNullable() case final open?) {
      db = open;
    } else {
      runApp(const _CannotOpen());
      return;
    }
  } catch (_) {
    runApp(const _CannotOpen());
    return;
  }
  final packs = SqlitePackRepository(db);
  final defaults = (await loadDefaultPacks()).getOrElse((_) => const []);
  // A failed start returns before it reads the installed list, so start again
  // with no packs to read what is already installed.
  if ((await packs.start(defaults)).isLeft()) await packs.start(const []);
  final voices = SqliteVoiceRepository(
    db,
    '${Directory(folder).parent.path}/files',
  );
  // A failed voice install leaves the phone voice.
  await voices.start(await loadDefaultVoices());
  final progress = SqliteProgressRepository(db, packs);
  final prefs = (await progress.prefs()).getOrElse(
    (_) => (sound: true, slowReading: false),
  );
  runApp(
    ProviderScope(
      overrides: [
        packRepositoryProvider.overrideWithValue(packs),
        voiceRepositoryProvider.overrideWithValue(voices),
        sfxProvider.overrideWithValue(Sfx()..on = prefs.sound),
        speakerProvider.overrideWithValue(
          VoiceSpeaker(voices)..slowReading = prefs.slowReading,
        ),
        progressRepositoryProvider.overrideWithValue(progress),
        backupRepositoryProvider.overrideWithValue(
          SqliteBackupRepository(db, packs, voices, defaultPacks: defaults),
        ),
      ],
      child: const StarbookApp(),
    ),
  );
}

class _CannotOpen extends StatelessWidget {
  const _CannotOpen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colours.paper,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Starbook could not open just now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Fonts.baloo,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colours.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please close it and open it again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Fonts.hind,
                      fontSize: 16,
                      color: Colours.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StarbookApp extends ConsumerStatefulWidget {
  const StarbookApp({super.key});

  @override
  ConsumerState<StarbookApp> createState() => _StarbookAppState();
}

class _StarbookAppState extends ConsumerState<StarbookApp> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _resumed);
    _take();
  }

  // A screen left open past midnight reads the new day when it shows again.
  void _resumed() {
    ref.invalidate(parentTodayProvider);
    ref.invalidate(habitsTodayProvider);
    _take();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  /// Asks Android for the file another app opened with Starbook, if any.
  Future<void> _take() async {
    final Map<String, Object?>? file;
    try {
      file = await const MethodChannel(
        'starbook/open',
      ).invokeMapMethod<String, Object?>('take');
    } on MissingPluginException {
      return;
    }
    if (file == null || !mounted) return;
    ref.read(incomingFileProvider.notifier).set((
      name: file['name']! as String,
      bytes: file['bytes']! as Uint8List,
    ));
    ref.read(routerProvider).go('/gate');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Starbook',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colours.ink,
          onPrimary: Colours.paper,
          surface: Colours.paper,
          onSurface: Colours.ink,
          onSurfaceVariant: Colours.inkSoft,
        ),
        fontFamily: Fonts.hind,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
