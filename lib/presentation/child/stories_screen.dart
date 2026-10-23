import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/speaker.dart';
import '../providers.dart';
import '../sfx.dart';
import '../theme/colours.dart';
import '../theme/motion.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';
import '../widgets/picture.dart';
import '../widgets/plain_line.dart';
import '../widgets/tap.dart';

const _tints = [Color(0xFFFBEDE4), Color(0xFFEAF2E4), Color(0xFFE6EFF8)];

Color _tint(Pack pack, Story story) => _tints[pack.stories.indexOf(story) % 3];

bool _isHindi(Pack pack, Story story) =>
    (story.language ?? pack.language).startsWith('hi');

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

// Same split as tool/voice/render.py split_punct, so a spoken sentence
// matches the text its clip is keyed by.
final _edges = RegExp(r'^(\p{P}*)(.*?)(\p{P}*)$', unicode: true, dotAll: true);

(String, String, String) _parts(String token) {
  final m = _edges.firstMatch(token)!;
  return (m[1]!, m[2]!, m[3]!);
}

/// The sentence to speak, with [say] applied to each word's core, and for
/// each word the speaker counts, the index of the shown word it belongs to.
(String, List<int>) _spoken(List<String> words, Map<String, String> say) {
  final tokens = <String>[];
  final owners = <int>[];
  for (var k = 0; k < words.length; k++) {
    final (lead, core, trail) = _parts(words[k]);
    final said = say[core] ?? core;
    tokens.add('$lead$said$trail');
    if (core.isEmpty) continue;
    for (final part in said.split(' ')) {
      if (_parts(part).$2.isNotEmpty) owners.add(k);
    }
  }
  return (tokens.join(' '), owners);
}

/// The first size from 40 down that lays [words] out in at most 3 lines with
/// every word on one line; the minimum size when none does.
double _sentenceSize(
  List<String> words,
  TextStyle style,
  double width,
  TextScaler scaler,
) {
  for (var size = 40.0; size > TextStyles.storyMinSize; size -= 2) {
    var lines = 1;
    var used = 0.0;
    var fits = true;
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(
          text: word,
          style: style.copyWith(fontSize: size),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final box = painter.width + 8 + size * 0.2;
      painter.dispose();
      if (box > width) {
        fits = false;
        break;
      }
      if (used > 0 && used + box > width + 0.001) {
        lines++;
        used = 0;
      }
      used += box;
    }
    if (fits && lines <= 3) return size;
  }
  return TextStyles.storyMinSize;
}

Widget _header(String title) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
  child: Row(
    children: [
      const BackDisc(),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: _baloo(
            30,
            FontWeight.w700,
            Colours.ink,
          ).copyWith(height: 1.05),
        ),
      ),
    ],
  ),
);

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(packRepositoryProvider).installed;
    final rows = <(Pack, Story)>[
      for (final level in [1, 2, 3])
        for (final p in packs)
          for (final s in p.stories)
            if (s.level == level) (p, s),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header('Stories'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                itemCount: rows.length,
                separatorBuilder: (context, i) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _StoryRow(rows[i].$1, rows[i].$2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow(this.pack, this.story);

  final Pack pack;
  final Story story;

  @override
  Widget build(BuildContext context) {
    final cover =
        story.cover ?? story.pages.map((p) => p.picture).nonNulls.firstOrNull;
    return Tap(
      onTap: () => context.go('/stories/${pack.id}/${story.id}'),
      pressedScale: 0.97,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colours.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colours.paperDeep, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tint(pack, story),
                borderRadius: BorderRadius.circular(18),
              ),
              child: cover == null ? null : Picture(cover, size: 66),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: _baloo(
                      22,
                      FontWeight.w700,
                      Colours.ink,
                    ).copyWith(height: 1.1),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var n = 1; n <= 3; n++) ...[
                        if (n > 1) const SizedBox(width: 4),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: n <= story.level
                                ? Colours.sunflower
                                : Colours.paperDeep,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StoryReaderScreen extends ConsumerStatefulWidget {
  const StoryReaderScreen(this.packId, this.storyId, {super.key});

  final String packId;
  final String storyId;

  @override
  ConsumerState<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends ConsumerState<StoryReaderScreen> {
  final _pages = PageController();
  late final Speaker _speaker;
  late final Pack? _pack;
  late final Story? _story;
  int _index = 0;
  int? _lit;
  bool _playing = false;
  bool _slow = false;
  bool _finished = false;
  // Bumped by every new read, stop and turn; a callback from an older one
  // does nothing.
  int _turn = 0;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
    _slow = _speaker.slowReading;
    final packs = ref.read(packRepositoryProvider).installed;
    _pack = packs.where((p) => p.id == widget.packId).firstOrNull;
    _story = _pack?.stories.where((s) => s.id == widget.storyId).firstOrNull;
    if (_story != null) _reached(0);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _language => _story!.language ?? _pack!.language;

  List<String> _words(int page) =>
      _story!.pages[page].text.split(' ').where((w) => w.isNotEmpty).toList();

  void _done(int turn) {
    if (mounted && turn == _turn) {
      setState(() {
        _lit = null;
        _playing = false;
      });
    }
  }

  void _quiet() {
    _turn++;
    setState(() {
      _lit = null;
      _playing = false;
    });
    unawaited(_speaker.stop());
  }

  void _sayWord(int k) {
    final (_, core, _) = _parts(_words(_index)[k]);
    final said = _story!.say[core] ?? core;
    final turn = ++_turn;
    setState(() {
      _lit = k;
      _playing = false;
    });
    unawaited(
      _speaker.speakWord(said, _language, slow: _slow).then((_) => _done(turn)),
    );
  }

  void _play() {
    if (_playing) {
      _quiet();
      return;
    }
    final (text, owners) = _spoken(_words(_index), _story!.say);
    final turn = ++_turn;
    setState(() {
      _playing = true;
      _lit = null;
    });
    unawaited(
      _speaker
          .speakSentence(
            text,
            _language,
            slow: _slow,
            onWord: (i) {
              if (mounted && turn == _turn && i < owners.length) {
                setState(() => _lit = owners[i]);
              }
            },
          )
          .then((_) => _done(turn)),
    );
  }

  void _reached(int i) {
    final story = _story!;
    if (i == story.pages.length - 1 && !_finished) {
      _finished = true;
      unawaited(
        ref
            .read(progressRepositoryProvider)
            .finish(BookKind.story, '${_pack!.id}/${story.id}')
            .then((result) {
              if (result.isLeft() && mounted) {
                _finished = false;
                showLine(ScaffoldMessenger.of(context), notSavedChild);
              }
            }),
      );
    }
  }

  void _turned(int i) {
    _quiet();
    setState(() => _index = i);
    unawaited(ref.read(sfxProvider).play(Sound.flip));
    _reached(i);
  }

  void _go(int i) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(i);
    } else {
      unawaited(
        _pages.animateToPage(i, duration: Motion.long, curve: Motion.curve),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    final story = _story;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _turn++;
        unawaited(_speaker.stop());
        if (_finished) ref.invalidate(thisWeekProvider);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const BackDisc(),
                    if (story != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.title,
                              style: _baloo(
                                24,
                                FontWeight.w700,
                                Colours.ink,
                              ).copyWith(height: 1.05),
                            ),
                            Text(
                              '${_index + 1} of ${story.pages.length}',
                              style: _baloo(
                                17,
                                FontWeight.w600,
                                Colours.ink.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (pack != null && story != null) ...[
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: story.pages.length,
                    onPageChanged: _turned,
                    itemBuilder: (context, i) => _StoryPage(
                      story,
                      i,
                      tint: _tint(pack, story),
                      hindi: _isHindi(pack, story),
                      words: _words(i),
                      lit: i == _index ? _lit : null,
                      onWord: _sayWord,
                    ),
                  ),
                ),
                _tools(story),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tools(Story story) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      // The buttons need 320 dp of row; narrower rows scale them all evenly.
      child: LayoutBuilder(
        builder: (context, box) {
          final k = min(1.0, box.maxWidth / 320);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Tool(
                'Back page',
                76 * k,
                Colours.paperDeep,
                icon: SvgPicture.asset(
                  'assets/icons/back.svg',
                  width: 30 * k,
                  height: 30 * k,
                  colorFilter: const ColorFilter.mode(
                    Colours.ink,
                    BlendMode.srcIn,
                  ),
                ),
                enabled: _index > 0,
                onTap: () => _go(_index - 1),
              ),
              _Tool(
                'Read to me',
                92 * k,
                Colours.ink,
                icon: _playing
                    ? Container(
                        width: 12 * k,
                        height: 12 * k,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2 * k),
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/icons/play.svg',
                        width: 26 * k,
                        height: 26 * k,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                enabled: true,
                onTap: _play,
              ),
              _Tool(
                'Slow reading',
                76 * k,
                _slow ? Colours.leaf : Colours.paperDeep,
                icon: SvgPicture.asset(
                  'assets/icons/turtle.svg',
                  width: 32 * k,
                  height: 32 * k,
                ),
                enabled: true,
                toggled: _slow,
                onTap: () => setState(() => _slow = !_slow),
              ),
              _Tool(
                'Next page',
                76 * k,
                Colours.paperDeep,
                icon: SvgPicture.asset(
                  'assets/icons/next.svg',
                  width: 30 * k,
                  height: 30 * k,
                  colorFilter: const ColorFilter.mode(
                    Colours.ink,
                    BlendMode.srcIn,
                  ),
                ),
                enabled: _index < story.pages.length - 1,
                onTap: () => _go(_index + 1),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage(
    this.story,
    this.index, {
    required this.tint,
    required this.hindi,
    required this.words,
    required this.lit,
    required this.onWord,
  });

  final Story story;
  final int index;
  final Color tint;
  final bool hindi;
  final List<String> words;
  final int? lit;
  final void Function(int word) onWord;

  @override
  Widget build(BuildContext context) {
    final picture = story.pages[index].picture;
    final ask = story.pages[index].ask;
    final credit = story.credit;
    final style = hindi
        ? TextStyles.story.copyWith(fontFamily: Fonts.baloo)
        : TextStyles.story;
    final scaler = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(24),
              ),
              child: picture == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Picture(picture, size: 210),
                    ),
            ),
          ),
          if (ask != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              // Shrinks instead of wrapping, so it only ever takes one line
              // from the picture.
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Ask: $ask',
                    style: const TextStyle(
                      fontFamily: Fonts.hind,
                      fontSize: 13,
                      color: Colours.inkSoft,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 126),
            child: Align(
              alignment: Alignment.topLeft,
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = _sentenceSize(
                    words,
                    style,
                    box.maxWidth,
                    scaler,
                  );
                  return Wrap(
                    children: [
                      for (var k = 0; k < words.length; k++)
                        _Word(
                          words[k],
                          style,
                          size,
                          lit: k == lit,
                          onTap: _parts(words[k]).$2.isEmpty
                              ? null
                              : () => onWord(k),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (index == story.pages.length - 1) ...[
            Text('The end.', style: _baloo(28, FontWeight.w700, Colours.ink)),
            if (credit != null) ...[
              const SizedBox(height: 6),
              if (credit.text != null)
                Text(
                  credit.text!,
                  style: _baloo(15, FontWeight.w600, Colours.inkSoft),
                ),
              Text(
                '${credit.source}, ${credit.license}',
                style: _baloo(15, FontWeight.w600, Colours.inkSoft),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word(
    this.text,
    this.style,
    this.size, {
    required this.lit,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final double size;
  final bool lit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final word = Padding(
      padding: EdgeInsets.symmetric(horizontal: size * 0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: lit ? Colours.sunflower : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: style.copyWith(fontSize: size, color: Colours.ink),
        ),
      ),
    );
    final tap = onTap;
    return tap == null ? word : Tap(onTap: tap, child: word);
  }
}

class _Tool extends StatelessWidget {
  const _Tool(
    this.label,
    this.size,
    this.colour, {
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.toggled,
  });

  final String label;
  final double size;
  final Color colour;
  final Widget icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      toggled: toggled,
      child: Opacity(
        opacity: enabled ? 1 : 0.25,
        child: Tap(
          onTap: enabled ? onTap : () {},
          pressedScale: enabled ? 0.95 : 1,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: icon,
          ),
        ),
      ),
    );
  }
}
