import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/domain/gate_question.dart';

void main() {
  test('gate questions obey their kind, have a two digit answer, never '
      'repeat in a row and cover all three kinds', () {
    final random = Random(7);
    final kinds = <GateKind>{};
    GateQuestion? last;
    for (var i = 0; i < 2000; i++) {
      final q = pickGateQuestion(random, last);
      kinds.add(q.kind);
      switch (q.kind) {
        case GateKind.sum:
          expect(q.a, inInclusiveRange(10, 99));
          expect(q.b, inInclusiveRange(10, 99));
        case GateKind.difference:
          expect(q.a, inInclusiveRange(10, 99));
          expect(q.b, inInclusiveRange(10, 99));
        case GateKind.times:
          expect(q.a, inInclusiveRange(2, 5));
          expect(q.b, inInclusiveRange(2, 9));
      }
      expect(q.answer, inInclusiveRange(10, 99), reason: q.text);
      expect(q.text, isNot(last?.text));
      last = q;
    }
    expect(kinds, GateKind.values.toSet());
  });
}
