import 'package:flutter/material.dart';

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
];

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: ListView(
        children: [
          for (final (title, subtitle) in _credits)
            ListTile(title: Text(title), subtitle: Text(subtitle)),
        ],
      ),
    );
  }
}
