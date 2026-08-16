import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/domain imports nothing from Flutter', () {
    final flutterImport = RegExp(
      r'''^\s*(import|export)\s+['"](package:flutter|dart:ui)''',
      multiLine: true,
    );
    final offenders = Directory('lib/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => flutterImport.hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
