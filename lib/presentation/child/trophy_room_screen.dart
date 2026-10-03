import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../providers.dart';
import '../theme/colours.dart';
import '../theme/type.dart';
import '../widgets/back_disc.dart';
import '../widgets/moment.dart';
import '../widgets/picture.dart';
import '../widgets/sticker_view.dart';
import '../widgets/tap.dart';
import 'days.dart';

/// The library picture for each trophy name a pack can use.
const trophyPictures = {
  'cup-gold': 'trophy',
  'cup-silver': 'medal-silver',
  'medal': 'medal-sports',
  'ribbon': 'ribbon',
  'crown': 'crown',
  'rocket': 'rocket',
  'rainbow': 'rainbow',
  'star-big': 'glowing-star',
  'book-gold': 'books',
  'heart': 'heart',
};

/// [say] is what is read aloud and [language] the language it is read in.
typedef ShelfTrophy = ({
  String ref,
  String picture,
  String title,
  String say,
  String language,
});

/// Every trophy the installed packs offer, in pack order: a pack's
/// milestones, then the habits of its sheets.
List<ShelfTrophy> shelfOf(List<Pack> packs) => [
  for (final p in packs) ...[
    for (final m in p.milestones)
      (
        ref: '${p.id}/${m.id}',
        picture: trophyPictures[m.trophy] ?? 'trophy',
        title: m.title,
        say: m.title,
        language: p.language,
      ),
    for (final s in p.sheets)
      for (final h in s.habits)
        (
          ref: '${p.id}/${s.id}/${h.id}',
          picture: h.picture,
          title: h.text,
          say: h.say ?? h.text,
          language: s.language ?? p.language,
        ),
  ],
];

// CSS grayscale(1) brightness(1.55) contrast(.35) from the mockup.
// dart format off
const _locked = ColorFilter.matrix([
  0.1153, 0.3880, 0.0392, 0, 82.875,
  0.1153, 0.3880, 0.0392, 0, 82.875,
  0.1153, 0.3880, 0.0392, 0, 82.875,
  0, 0, 0, 1, 0,
]);
// dart format on

TextStyle _baloo(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: Fonts.baloo,
  fontSize: size,
  fontWeight: weight,
  color: color,
);

class TrophyRoomScreen extends ConsumerWidget {
  const TrophyRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(trophyRoomProvider).value;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(ref.read(speakerProvider).stop());
      },
      child: Scaffold(
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
                      child: Text(
                        'My trophies',
                        style: _baloo(
                          30,
                          FontWeight.w700,
                          Colours.ink,
                        ).copyWith(height: 1.05),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: room == null
                      ? const SizedBox.shrink()
                      : _Room(room.trophies, room.album),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Room extends ConsumerWidget {
  const _Room(this.trophies, this.album);

  final List<Trophy> trophies;
  final List<String> album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedAt = {for (final t in trophies) t.milestoneRef: t.earnedAt};
    final shelf = [
      for (final t in shelfOf(ref.watch(packRepositoryProvider).installed))
        (t, earnedAt[t.ref]),
    ];
    final rows = [
      for (var i = 0; i < shelf.length; i += 3)
        shelf.sublist(i, i + 3 > shelf.length ? shelf.length : i + 3),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 30),
                _Plank(rows[i]),
              ],
            ],
          ),
        ),
        if (shelf.every((e) => e.$2 == null))
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 30, 10, 0),
            child: Text(
              'Your trophies will stand here.',
              textAlign: TextAlign.center,
              style: _baloo(18, FontWeight.w600, Colours.inkSoft),
            ),
          ),
        _Album(album),
      ],
    );
  }
}

class _Plank extends StatelessWidget {
  const _Plank(this.row);

  final List<(ShelfTrophy, DateTime?)> row;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: -14,
          height: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colours.sand,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x405A3214),
                  offset: Offset(0, 6),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [for (final (t, at) in row) _Trophy(t, at)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Trophy extends ConsumerWidget {
  const _Trophy(this.trophy, this.earnedAt);

  final ShelfTrophy trophy;
  final DateTime? earnedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picture = trophy.picture;
    final art = SizedBox(
      width: 96,
      child: Center(child: Picture(picture, size: 84)),
    );
    final d = earnedAt;
    if (d == null) {
      return Semantics(
        label: 'Not yet',
        child: Opacity(
          opacity: 0.38,
          child: ColorFiltered(colorFilter: _locked, child: art),
        ),
      );
    }
    return Semantics(
      label: trophy.title,
      button: true,
      child: Tap(
        onTap: () {
          unawaited(
            ref
                .read(speakerProvider)
                .speakSentence(trophy.say, trophy.language),
          );
          unawaited(
            showMoment(
              context,
              picture: picture,
              title: '${trophy.title}!',
              line:
                  'Earned on ${weekdayNames[d.weekday - 1]}, '
                  '${d.day} ${monthNames[d.month - 1]}',
            ),
          );
        },
        child: art,
      ),
    );
  }
}

class _Album extends StatelessWidget {
  const _Album(this.stickers);

  final List<String> stickers;

  @override
  Widget build(BuildContext context) {
    final empty = stickers.length < 8 ? 8 - stickers.length : 0;
    return Container(
      margin: const EdgeInsets.only(top: 44),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
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
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              'My stickers',
              style: _baloo(22, FontWeight.w700, Colours.ink),
            ),
          ),
          GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (final name in stickers)
                Semantics(
                  label: name.replaceAll('-', ' '),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: StickerView(name, size: 62),
                    ),
                  ),
                ),
              for (var i = 0; i < empty; i++) dashedSquare(),
            ],
          ),
        ],
      ),
    );
  }
}
