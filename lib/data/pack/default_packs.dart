import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right, left, right;

import '../../domain/failure.dart';
import 'pack_parser.dart';

/// The bundled pack texts, each already checked by [parsePack].
Future<Either<Failure, List<String>>> loadDefaultPacks() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths =
      manifest
          .listAssets()
          .where((p) => p.startsWith('packs/') && p.endsWith('.json'))
          .toList()
        ..sort();
  final texts = <String>[];
  for (final path in paths) {
    final text = await rootBundle.loadString(path);
    switch (parsePack(text)) {
      case Left(:final value):
        return left(Failure('$path: ${value.message}'));
      case Right():
        texts.add(text);
    }
  }
  return right(texts);
}
