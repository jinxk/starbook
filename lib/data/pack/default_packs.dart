import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right, left, right;

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart';
import 'pack_parser.dart';

Future<Either<Failure, List<Pack>>> loadDefaultPacks() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths =
      manifest
          .listAssets()
          .where((p) => p.startsWith('packs/') && p.endsWith('.json'))
          .toList()
        ..sort();
  final packs = <Pack>[];
  for (final path in paths) {
    final result = parsePack(await rootBundle.loadString(path));
    switch (result) {
      case Left(:final value):
        return left(Failure('$path: ${value.message}'));
      case Right(:final value):
        packs.add(value);
    }
  }
  return right(packs);
}
