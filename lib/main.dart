import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'data/db/store_db.dart';
import 'data/pack/default_packs.dart';
import 'data/repositories/sqlite_pack_repository.dart';
import 'data/repositories/sqlite_progress_repository.dart';
import 'presentation/providers.dart';
import 'presentation/router.dart';
import 'presentation/theme/colours.dart';
import 'presentation/theme/type.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final folder = await databaseFactorySqflitePlugin.getDatabasesPath();
  final opened = await openStore(
    databaseFactorySqflitePlugin,
    '$folder/starbook.db',
  );
  final db = opened.getOrElse((failure) => throw StateError(failure.message));
  final packs = SqlitePackRepository(db);
  final defaults = (await loadDefaultPacks()).getOrElse((_) => const []);
  // A failed start leaves the installed list unread, so read it once more.
  if ((await packs.start(defaults)).isLeft()) await packs.start(const []);
  runApp(
    ProviderScope(
      overrides: [
        packRepositoryProvider.overrideWithValue(packs),
        progressRepositoryProvider.overrideWithValue(
          SqliteProgressRepository(db, packs),
        ),
      ],
      child: const StarbookApp(),
    ),
  );
}

class StarbookApp extends ConsumerWidget {
  const StarbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
