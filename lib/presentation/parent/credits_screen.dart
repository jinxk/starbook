import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

const _credits = [
  (
    'Baloo 2',
    'Font. The Baloo 2 Project Authors (Ek Type). SIL Open Font License 1.1.',
  ),
  ('Andika', 'Font. SIL International. SIL Open Font License 1.1.'),
  ('Hind', 'Font. Indian Type Foundry. SIL Open Font License 1.1.'),
  ('Fluent Emoji', 'Pictures and still stickers. Microsoft. MIT License.'),
  (
    'Noto Animated Emoji',
    'Animated stickers. Google. Creative Commons Attribution 4.0 '
        '(creativecommons.org/licenses/by/4.0). Not changed.',
  ),
  ('Phosphor Icons', 'Buttons. Phosphor Icons. MIT License.'),
  ('Kenney', 'Sound effects. kenney.nl. CC0, public domain.'),
  (
    'Sticker sounds',
    'Animal calls and a celesta twinkle from Freesound, '
        'by _justMonke_, Vaporpup, D.jones, kwahmah_02, tuberatanka, Kinoton, '
        'Breviceps, celldroid, invertedturtle, qubodup, poodaddy69, LoafDV, '
        'BOAAY, jfournier18, betterchinese, florianreichelt, '
        'stamperadam, Bidone, JonCon_Library, StarNinjas37, alegemaate, '
        'GrayEpic, haulaway, jahjahjahjah, Sojan and HappyPizzaBread. CC0, '
        'public domain. Trimmed, level-adjusted and faded.',
  ),
  (
    'Fox sound',
    '"Fox, Vocal Cry, Distant, 01.wav" by InspectorJ, '
        'freesound.org/people/InspectorJ/sounds/485009. Creative Commons '
        'Attribution 4.0 (creativecommons.org/licenses/by/4.0). Trimmed, '
        'level-adjusted and faded.',
  ),
  ('Indic Parler-TTS', 'Hindi voice. AI4Bharat. Apache License 2.0.'),
  ('Kokoro-82M', 'English voice. hexgrad. Apache License 2.0.'),
];

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = [
      for (final pack in ref.watch(packRepositoryProvider).installed)
        for (final story in pack.stories)
          if (story.credit != null) story,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: ListView(
        children: [
          for (final (title, subtitle) in _credits)
            ListTile(title: Text(title), subtitle: Text(subtitle)),
          for (final story in stories)
            ListTile(
              title: Text(story.title),
              subtitle: Text(
                [
                  ?story.credit!.text,
                  '${story.credit!.source}, ${story.credit!.license}',
                ].join('\n'),
              ),
            ),
        ],
      ),
    );
  }
}
