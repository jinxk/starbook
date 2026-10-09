import 'dart:async';

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
import 'days.dart';

const _dotOff = Color(0xFFDCCFB3);

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

Color _bookColour(WordBook book) => Colours.byName(book.colour) ?? Colours.sky;

/// Text and icons on a book colour: white, except ink on sunflower and sand.
Color _onBook(Color c) =>
    c == Colours.sunflower || c == Colours.sand ? Colours.ink : Colors.white;

bool _isHindi(Pack pack, WordBook book) =>
    (book.language ?? pack.language).startsWith('hi');

/// [word] with every [letter] in [mark]; the rest takes the parent style.
TextSpan markedWord(String word, String? letter, Color mark) {
  if (letter == null || letter.isEmpty) return TextSpan(text: word);
  final parts = word.split(letter);
  return TextSpan(
    children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0)
          TextSpan(
            text: letter,
            style: TextStyle(color: mark),
          ),
        if (parts[i].isNotEmpty) TextSpan(text: parts[i]),
      ],
    ],
  );
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

class WordBooksScreen extends ConsumerWidget {
  const WordBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(packRepositoryProvider).installed;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header('Word books'),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 3 / 4,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (final p in packs)
                    for (final b in p.wordBooks)
                      _Cover(
                        b,
                        hindi: _isHindi(p, b),
                        onTap: () => context.go('/words/${p.id}/${b.id}'),
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

class _Cover extends StatelessWidget {
  const _Cover(this.book, {required this.hindi, required this.onTap});

  final WordBook book;
  final bool hindi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = _bookColour(book);
    final on = _onBook(colour);
    final picture = book.cards.map((c) => c.picture).nonNulls.firstOrNull;
    final letter =
        book.letter ?? (picture == null ? book.cards.first.big : null);
    return Tap(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E503C14),
              offset: Offset(0, 8),
              blurRadius: 16,
            ),
          ],
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 10,
              child: ColoredBox(color: Color(0x1A000000)),
            ),
            if (letter != null)
              Positioned(
                left: 14,
                right: 14,
                top: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    letter,
                    style: TextStyles.coverLetter.copyWith(
                      fontFamily: hindi ? Fonts.baloo : null,
                      fontSize: hindi ? 80 : null,
                      height: 1,
                      color: on,
                    ),
                  ),
                ),
              ),
            if (picture != null)
              Positioned(
                right: 8,
                bottom: 36,
                child: Picture(
                  picture,
                  size: letter != null ? 64 : 96,
                  sticker: true,
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                book.title,
                style: _baloo(19, FontWeight.w700, on).copyWith(height: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WordCardScreen extends ConsumerStatefulWidget {
  const WordCardScreen(this.packId, this.bookId, {super.key});

  final String packId;
  final String bookId;

  @override
  ConsumerState<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends ConsumerState<WordCardScreen> {
  final _pages = PageController();
  late final Speaker _speaker;
  late final Pack? _pack;
  late final WordBook? _book;
  Timer? _read;
  int _index = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(speakerProvider);
    final packs = ref.read(packRepositoryProvider).installed;
    _pack = packs.where((p) => p.id == widget.packId).firstOrNull;
    _book = _pack?.wordBooks.where((b) => b.id == widget.bookId).firstOrNull;
    if (_book != null) _show(0, const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _read?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _say() {
    final pack = _pack!;
    final book = _book!;
    final card = book.cards[_index];
    unawaited(
      _speaker.speakWord(
        card.say ?? card.word,
        card.language ?? book.language ?? pack.language,
      ),
    );
  }

  // Reads the card [after] it is shown; a newer show cancels a pending read.
  void _show(int i, Duration after) {
    final book = _book!;
    _read?.cancel();
    _read = Timer(after, _say);
    if (i == book.cards.length - 1 && !_finished) {
      _finished = true;
      unawaited(
        ref
            .read(progressRepositoryProvider)
            .finish(BookKind.wordbook, '${_pack!.id}/${book.id}')
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
    setState(() => _index = i);
    _read?.cancel();
    unawaited(_speaker.stop());
    unawaited(ref.read(sfxProvider).play(Sound.flip));
    _show(i, const Duration(milliseconds: 450));
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
    final book = _book;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _read?.cancel();
        unawaited(_speaker.stop());
        if (_finished) ref.invalidate(thisWeekProvider);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _header(book?.title ?? ''),
              if (pack != null && book != null) ...[
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: book.cards.length,
                    onPageChanged: _turned,
                    itemBuilder: (context, i) => _CardPage(
                      book.cards[i],
                      book: book,
                      hindi: _isHindi(pack, book),
                      last: i == book.cards.length - 1,
                      onTap: () {
                        _read?.cancel();
                        _say();
                      },
                    ),
                  ),
                ),
                _pager(book),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pager(WordBook book) {
    final colour = _bookColour(book);
    final count = book.cards.length;
    return Padding(
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
                for (var i = 0; i < count; i++)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: i == _index ? Colours.ink : _dotOff,
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
            enabled: _index < count - 1,
            onTap: () => _go(_index + 1),
          ),
        ],
      ),
    );
  }
}

class _CardPage extends StatelessWidget {
  const _CardPage(
    this.card, {
    required this.book,
    required this.hindi,
    required this.last,
    required this.onTap,
  });

  final WordCard card;
  final WordBook book;
  final bool hindi;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picture = card.picture;
    final group = card.group;
    final word = TextStyles.wordCard.copyWith(
      fontFamily: hindi ? Fonts.baloo : null,
      height: 1,
      color: Colours.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Tap(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          decoration: BoxDecoration(
            color: Colours.card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F503C14),
                offset: Offset(0, 12),
                blurRadius: 28,
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (picture != null)
                      Picture(picture, size: 230)
                    else
                      SizedBox(
                        height: 230,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            card.big ?? '',
                            style: word.copyWith(fontSize: 140),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                          markedWord(
                            card.word,
                            hindi ? null : book.letter,
                            titleColour(_bookColour(book)),
                          ),
                          style: word.copyWith(letterSpacing: 1.44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      last ? 'All done!' : 'Tap to hear',
                      style: _baloo(15, FontWeight.w600, Colours.inkSoft),
                    ),
                  ],
                ),
              ),
              if (group != null)
                Positioned(
                  top: 16,
                  right: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colours.paperDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      group,
                      style: const TextStyle(
                        fontFamily: Fonts.andika,
                        fontFamilyFallback: [Fonts.baloo],
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colours.ink,
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

class PageArrow extends StatelessWidget {
  const PageArrow(
    this.label,
    this.icon,
    this.colour, {
    super.key,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String icon;
  final Color colour;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.25,
        child: Tap(
          onTap: enabled ? onTap : () {},
          pressedScale: enabled ? 0.95 : 1,
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            child: SvgPicture.asset(
              'assets/icons/$icon.svg',
              width: 34,
              height: 34,
              colorFilter: ColorFilter.mode(_onBook(colour), BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
