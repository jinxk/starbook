import 'dart:math';

enum GateKind { sum, difference, times }

/// One parent gate question. The answer is always two digits.
class GateQuestion {
  const GateQuestion(this.kind, this.a, this.b);

  final GateKind kind;
  final int a;
  final int b;

  int get answer => switch (kind) {
    GateKind.sum => a + b,
    GateKind.difference => a - b,
    GateKind.times => a * b,
  };

  String get text => switch (kind) {
    GateKind.sum => '$a + $b',
    GateKind.difference => '$a − $b',
    GateKind.times => '$a × $b',
  };

  String get spoken => switch (kind) {
    GateKind.sum => '$a plus $b',
    GateKind.difference => '$a minus $b',
    GateKind.times => '$a times $b',
  };
}

/// A random question of a random kind, never the same as [last].
GateQuestion pickGateQuestion(Random random, GateQuestion? last) {
  while (true) {
    final next = switch (GateKind.values[random.nextInt(3)]) {
      GateKind.sum => _sum(random),
      GateKind.difference => _difference(random),
      GateKind.times => _times(random),
    };
    if (next.text != last?.text) return next;
  }
}

GateQuestion _sum(Random random) {
  final a = 10 + random.nextInt(80);
  return GateQuestion(GateKind.sum, a, 10 + random.nextInt(90 - a));
}

GateQuestion _difference(Random random) {
  final a = 20 + random.nextInt(80);
  return GateQuestion(GateKind.difference, a, 10 + random.nextInt(a - 19));
}

GateQuestion _times(Random random) {
  while (true) {
    final a = 2 + random.nextInt(4);
    final b = 2 + random.nextInt(8);
    if (a * b >= 10) return GateQuestion(GateKind.times, a, b);
  }
}
