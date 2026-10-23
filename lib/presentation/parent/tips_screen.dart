import 'package:flutter/material.dart';

import '../theme/colours.dart';
import 'parts.dart';

const _tips = [
  'Sit with your child.',
  '10 to 15 minutes is enough. Stop at "All done for today".',
  'Say what they did, not "clever".',
  'Give the sticker right after the job.',
  'Count real things together.',
  'Ask one question on each story page, then wait.',
  'A missed day is fine.',
  'Keep free drawing and play outside the sticker chart.',
];

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colours.parentPaper,
    body: SafeArea(
      child: Column(
        children: [
          parentHeader('How to use Starbook together'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                for (final tip in _tips)
                  whiteRow(
                    child: Text(
                      tip,
                      style: hind(
                        16,
                        FontWeight.w400,
                        Colours.ink,
                      ).copyWith(height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
