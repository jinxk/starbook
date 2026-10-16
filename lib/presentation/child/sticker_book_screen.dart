import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/progress/progress.dart';
import '../providers.dart';
import '../sfx.dart';
import '../theme/colours.dart';
import '../theme/motion.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';
import '../widgets/picture.dart';
import '../widgets/sticker_view.dart';
import 'word_books_screen.dart' show PageArrow;

final _set = defaultStickers.toSet();

const _pageColours = [
  Colours.leaf,
  Colours.sky,
  Colours.tomato,
  Colours.plum,
  Colours.sand,
  Colours.sunflower,
];

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class StickerBookScreen extends ConsumerWidget {
  const StickerBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(stickerBookProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const BackDisc(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My stickers',
                          style: _baloo(
                            30,
                            FontWeight.w700,
                            Colours.ink,
                          ).copyWith(height: 1.05),
                        ),
                        if (data != null)
                          Text(
                            '${stickersEarned(data.album)} of '
                            '${defaultStickers.length}',
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
              ),
            ),
            if (data != null) Expanded(child: _Book(data)),
          ],
        ),
      ),
    );
  }
}

class _Book extends ConsumerStatefulWidget {
  const _Book(this.data);

  final StickerBook data;

  @override
  ConsumerState<_Book> createState() => _BookState();
}

class _BookState extends ConsumerState<_Book> {
  late final List<String> _more = [
    for (final s in widget.data.album.toSet())
      if (!_set.contains(s)) s,
  ];
  late final int _count = stickerPages.length + (_more.isEmpty ? 0 : 1);
  late final PageController _pages = PageController(initialPage: _start());
  late int _index = _start();
  late bool _fresh = widget.data.fresh;

  int _start() {
    final album = widget.data.album;
    if (album.isEmpty) return 0;
    final i = stickerPages.indexWhere((p) => p.stickers.contains(album.first));
    return i < 0 ? stickerPages.length : i;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _turned(int i) {
    setState(() {
      _index = i;
      _fresh = false;
    });
    unawaited(ref.read(sfxProvider).play(Sound.flip));
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
    final album = widget.data.album;
    final owned = album.toSet();
    final colour = _pageColours[_index % _pageColours.length];
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: _count,
            onPageChanged: _turned,
            itemBuilder: (context, i) => i < stickerPages.length
                ? _PageCard(
                    name: stickerPages[i].name,
                    stickers: stickerPages[i].stickers,
                    picture: stickerPages[i].picture,
                    owned: owned,
                    arriving: _fresh ? album.first : null,
                  )
                : _PageCard(
                    name: 'More stickers',
                    stickers: _more,
                    owned: owned,
                    arriving: _fresh ? album.first : null,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Row(
            children: [
              PageArrow(
                'Back',
                'back',
                colour,
                enabled: _index > 0,
                onTap: () => _go(_index - 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < _count; i++)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: i == _index ? Colours.ink : Colours.dash,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PageArrow(
                'Next',
                'next',
                colour,
                enabled: _index < _count - 1,
                onTap: () => _go(_index + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One album page. [picture] is null for the page of stickers outside the
/// set, which has no count and no trophy.
class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.name,
    required this.stickers,
    this.picture,
    required this.owned,
    required this.arriving,
  });

  final String name;
  final List<String> stickers;
  final String? picture;
  final Set<String> owned;
  final String? arriving;

  @override
  Widget build(BuildContext context) {
    final earned = stickers.where(owned.contains).length;
    final full = picture != null && earned == stickers.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: const BoxDecoration(
        color: Colours.card,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A503C14),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: _baloo(26, FontWeight.w700, Colours.ink),
                  ),
                ),
                if (picture != null) ...[
                  if (full) ...[
                    Picture(picture!, size: 40),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colours.paperDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$earned of ${stickers.length}',
                      style: _baloo(18, FontWeight.w700, Colours.ink),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              padding: EdgeInsets.zero,
              children: [
                for (final s in stickers)
                  if (owned.contains(s))
                    Semantics(
                      label: s.startsWith('emoji:')
                          ? s.substring('emoji:'.length)
                          : s.replaceAll('-', ' '),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StickerView(
                            s,
                            size: 62,
                            arriving: s == arriving,
                          ),
                        ),
                      ),
                    )
                  else
                    Semantics(
                      label: 'Not yet',
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Transform.rotate(
                            angle: tiltOf(s) * pi / 180,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  Colours.dash,
                                  BlendMode.srcIn,
                                ),
                                child: Image.asset(
                                  'assets/stickers/$s.png',
                                  width: 62,
                                  height: 62,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
