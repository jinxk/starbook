# Starbook

A homework sticker book for preschool children. A parent loads the week's homework sheet, the child does the work, the parent hands out stars, and the child watches the week fill up, collects stickers and puts trophies on a shelf. Picture word books and very short read-along stories sit next to it for practice.

Made for children aged 3 to 6 and the grown-ups helping them. Android first, fully offline.

**Status:** early development. The design, the pack format and the default packs are being written; the app itself is not built yet.

## What it does

- **This week's page.** Each school day is a big slot that fills with stars as tasks get done. A full week earns the special reward the parent typed in.
- **Awards the parent picks.** Star, "Very good!", "Shabash!", or a sticker. All of them are defined in packs, so they can be renamed or extended.
- **Trophy room.** Milestones (first star, 10 stars, first full week, five stories read) put trophies on a shelf. Trophies are never taken away and there are no streaks to break.
- **Word books.** One picture and one word per card, tap to hear it. Short vowels by word family (a: cat, bat, hat, van, fan), "A for apple" sounds, and topic books for fruits, vegetables, flowers, animals, shapes, numbers and Hindi letters.
- **Stories.** Eight to ten pages, one short sentence per page in large type. Tap a word to hear it, or press play and watch each word light up as it is read.
- **Parent area** behind a gate a pre-reader cannot pass.

## Packs

Every sheet, word book, story, award and milestone is a JSON pack. Nothing is tied to one school. Write your own by copying a file from [`packs/`](packs), then import it from the parent area or open it with Starbook from WhatsApp, Gmail or Files. A newer revision of the same pack replaces the old one; stars already given stay.

See [Pack format](docs/pack-format.md).

## Privacy

No account, no ads, no analytics, no internet permission. Everything stays on the phone. See [Privacy](docs/privacy.md).

## Docs

- [Product](docs/product.md): what the app does and for whom
- [Design](docs/design.md): look, type, motion, sound, screens and on-screen text
- [Architecture](docs/architecture.md): code layout, database and rules
- [Pack format](docs/pack-format.md): writing your own packs
- [Pictures](docs/pictures.md): the built-in picture names

## Building

Needs Flutter (stable) and the Android SDK.

```
flutter pub get
flutter run
```

Checks before a pull request:

```
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

## Credits

- Pictures: [Fluent Emoji](https://github.com/microsoft/fluentui-emoji) by Microsoft, MIT licence. A few pictures with no emoji are drawn for this project.
- Fonts: Baloo 2 (Ek Type), Andika (SIL International), Hind (Indian Type Foundry), all under the SIL Open Font License.
- Sound effects: Kenney, CC0.

## Licence

Code under the [MIT licence](LICENSE). The default packs are CC0, so you can copy them into your own packs freely.

---

AI coding tools were used to build this app.
