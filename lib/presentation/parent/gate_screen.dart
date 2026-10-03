import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';

const _words = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

TextStyle _hind(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.hind,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class GateScreen extends ConsumerStatefulWidget {
  const GateScreen({super.key});

  @override
  ConsumerState<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends ConsumerState<GateScreen> {
  static final _random = Random();

  late List<int> _numbers = _pick(null);
  List<int> _typed = [];

  /// Three digits from 1 to 9 that differ from [last].
  List<int> _pick(List<int>? last) {
    while (true) {
      final next = [for (var i = 0; i < 3; i++) 1 + _random.nextInt(9)];
      if (last == null || next.join() != last.join()) return next;
    }
  }

  void _press(int digit) {
    if (ref.read(gateLockProvider) > 0) return;
    final typed = [..._typed, digit];
    if (typed.length < 3) {
      setState(() => _typed = typed);
      return;
    }
    final lock = ref.read(gateLockProvider.notifier);
    if (typed.join() == _numbers.join()) {
      lock.passed();
      context.go(
        ref.read(incomingFileProvider) == null ? '/parent' : '/parent/packs',
      );
      return;
    }
    lock.failed();
    setState(() {
      _typed = [];
      _numbers = _pick(_numbers);
    });
  }

  void _delete() {
    if (ref.read(gateLockProvider) > 0 || _typed.isEmpty) return;
    setState(() => _typed = _typed.sublist(0, _typed.length - 1));
  }

  Widget _key(Widget label, VoidCallback onPressed) => SizedBox(
    width: 76,
    height: 62,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        foregroundColor: Colours.ink,
        overlayColor: Colours.paperDeep,
        side: const BorderSide(color: Color(0xFFE6DCC6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: _hind(26, FontWeight.w500, Colours.ink),
      ),
      child: label,
    ),
  );

  Widget _digit(int d) => _key(Text('$d'), () => _press(d));

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(gateLockProvider);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        ref.invalidate(thisWeekProvider);
        ref.read(incomingFileProvider.notifier).drop();
      },
      child: Scaffold(
        backgroundColor: Colours.parentPaper,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BackDisc(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Grown-ups only',
                          style: _hind(28, FontWeight.w500, Colours.ink),
                        ),
                        if (locked > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 22, bottom: 8),
                            child: Text(
                              'Please wait a minute ($locked)',
                              style: _hind(20, FontWeight.w500, Colours.ink),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Type the numbers',
                            style: _hind(16, FontWeight.w400, Colours.inkSoft),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 22, bottom: 8),
                            child: Text(
                              [for (final n in _numbers) _words[n]].join(', '),
                              style: _hind(
                                26,
                                FontWeight.w500,
                                Colours.ink,
                              ).copyWith(letterSpacing: 0.52),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 12,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Container(
                                  width: 44,
                                  height: 54,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colours.dash,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    i < _typed.length ? '${_typed[i]}' : '',
                                    style: _hind(
                                      26,
                                      FontWeight.w500,
                                      Colours.ink,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final row in const [
                          [1, 2, 3],
                          [4, 5, 6],
                          [7, 8, 9],
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 12,
                              children: [for (final d in row) _digit(d)],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 12,
                          children: [
                            const SizedBox(width: 76, height: 62),
                            _digit(0),
                            _key(
                              const Icon(
                                Icons.backspace_outlined,
                                size: 26,
                                semanticLabel: 'Delete',
                              ),
                              _delete,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
