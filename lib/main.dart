import 'package:flutter/material.dart';

import 'presentation/theme/colours.dart';
import 'presentation/theme/type.dart';

void main() => runApp(const StarbookApp());

class StarbookApp extends StatelessWidget {
  const StarbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      // Placeholder until the week screen.
      home: const Scaffold(
        body: Center(child: Text('Starbook', style: TextStyles.childTitle)),
      ),
    );
  }
}
