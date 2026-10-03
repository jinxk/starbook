import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/speaker.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../widgets/plain_line.dart';
import 'parts.dart';

const _languages = [
  ('English', 'en-IN', 'This is the phone voice.'),
  ('Hindi', 'hi-IN', 'यह फ़ोन की आवाज़ है।'),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final Speaker _speaker;
  final _status = <String, VoiceStatus>{};

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
    for (final (_, code, _) in _languages) {
      unawaited(_load(code));
    }
  }

  @override
  void dispose() {
    unawaited(_speaker.stop());
    super.dispose();
  }

  Future<void> _load(String code) async {
    final status = await _speaker.voiceStatus(code.substring(0, 2));
    if (mounted) setState(() => _status[code] = status);
  }

  Future<void> _save() async {
    final result = await ref.read(progressRepositoryProvider).setPrefs((
      sound: ref.read(sfxProvider).on,
      slowReading: _speaker.slowReading,
    ));
    if (result.isLeft() && mounted) {
      showLine(ScaffoldMessenger.of(context), notSaved);
    }
  }

  Future<void> _phoneSettings() async {
    try {
      await const MethodChannel(
        'starbook/open',
      ).invokeMethod<bool>('ttsSettings');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Widget _switchRow(
    String title,
    String below,
    bool value,
    ValueChanged<bool> onChanged,
  ) => whiteRow(
    child: Row(
      spacing: 10,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: hind(16, FontWeight.w500, Colours.ink)),
              Text(below, style: hind(13, FontWeight.w400, Colours.inkSoft)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Colours.leaf,
        ),
      ],
    ),
  );

  String _statusText(VoiceStatus status) => !status.installed
      ? 'Not installed'
      : status.offline
      ? 'Ready, works offline'
      : 'Needs internet';

  Widget _voiceRow(String title, String code, String sample) {
    final status = _status[code];
    if (status == null) return const SizedBox.shrink();
    return whiteRow(
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: hind(16, FontWeight.w500, Colours.ink)),
                Text(
                  _statusText(status),
                  style: hind(13, FontWeight.w400, Colours.inkSoft),
                ),
              ],
            ),
          ),
          parentButton(
            'Hear it',
            () => unawaited(_speaker.speakSentence(sample, code)),
            ghost: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sfx = ref.read(sfxProvider);
    final voices = ref.read(voiceRepositoryProvider);
    final active = [
      for (final v in voices.installed)
        if (voices.active.contains(v.id)) v.title,
    ];
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(parentTodayProvider);
      },
      child: Scaffold(
        backgroundColor: Colours.parentPaper,
        body: SafeArea(
          child: Column(
            children: [
              parentHeader('Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    parentHeading('Sound and reading'),
                    _switchRow(
                      'Sounds',
                      'Star, sticker and trophy sounds.',
                      sfx.on,
                      (on) {
                        setState(() => sfx.on = on);
                        unawaited(_save());
                      },
                    ),
                    _switchRow(
                      'Slow reading',
                      'Stories, word cards and tasks read slower.',
                      _speaker.slowReading,
                      (slow) {
                        setState(() => _speaker.slowReading = slow);
                        unawaited(_save());
                      },
                    ),
                    parentHeading('Phone voice'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        'Used for words that have no recorded clip.',
                        style: hind(
                          14,
                          FontWeight.w400,
                          Colours.inkSoft,
                        ).copyWith(height: 1.4),
                      ),
                    ),
                    for (final (title, code, sample) in _languages)
                      _voiceRow(title, code, sample),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: parentButton(
                        'Phone voice settings',
                        () => unawaited(_phoneSettings()),
                        ghost: true,
                      ),
                    ),
                    parentHeading('Recorded voices'),
                    whiteRow(
                      onTap: () async {
                        await context.push('/parent/packs');
                        if (mounted) setState(() {});
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        spacing: 10,
                        children: [
                          Text(
                            'Voices',
                            style: hind(16, FontWeight.w500, Colours.ink),
                          ),
                          Flexible(
                            child: Text(
                              '${active.isEmpty ? 'none' : active.join(', ')} ›',
                              textAlign: TextAlign.end,
                              style: hind(14, FontWeight.w400, Colours.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
