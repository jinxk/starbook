# Architecture

Flutter, Android first. Offline only: the release build declares no internet permission. All data is in one SQLite database on the phone.

## Stack

| Need | Package |
|---|---|
| State | flutter_riverpod with riverpod_generator (codegen, `@riverpod`) |
| Navigation | go_router |
| Storage | sqflite |
| Results and errors | fpdart (`Either<Failure, T>`) |
| Value objects | equatable |
| Read-aloud | voice pack clips through audioplayers, flutter_tts as fallback |
| Sound effects | audioplayers |
| Pictures and icons | flutter_svg |
| Animated stickers | lottie |
| Import a file, save a backup | file_picker (system document picker and save dialog, no storage permission) |
| Share a backup | share_plus |
| Voice pack import | archive (unzip `.starbook-voice` files) |

Fonts (Baloo 2, Andika, Hind), pictures, stickers, icons, their licence texts (`assets/licenses/`), sound effects (`assets/sounds/`) and sticker sounds (`assets/sticker-sounds/`), with sources in the `CREDITS.md` of each asset folder, and the default voice packs (`assets/voices/heart.starbook-voice` for English, `divya.starbook-voice` for Hindi) are bundled as assets. `dart run tool/fetch_assets.dart` downloads the Fluent pictures, stickers, icons and licence texts again from the pinned sources in [`pictures.md`](pictures.md) and [`stickers.md`](stickers.md). The sound effects are copied by hand from the Kenney packs. The voice pack renderer is a separate Python tool in `tool/voice/`, not part of the app build. Flutter is pinned to 3.44.6 in `pubspec.yaml` `environment` and in the CI workflow. Change both together, and check package versions against the new Flutter when you do.

## Layers

```
lib/
  domain/        pure Dart, no Flutter imports
    pack/        Pack, Sheet, Habit, Day, Task, Award, Milestone, WordBook, WordCard, Story, StoryPage, Credit
    progress/    Week, GivenAward, Trophy, Moments, Counters, Child, the sticker pages
    repositories interfaces, use cases (one public execute() each)
  data/
    db/          sqflite open, migrations
    pack/        JSON parser and validator, default pack loader
    repositories implementations
    speech/      flutter_tts wrapper behind a domain Speaker interface
  presentation/
    child/       home, day, trophy room, sticker book, habits, word books, stories
    parent/      gate, today, week, child, packs, backup, settings, credits
    widgets/     sticker, award mark, landing, moment, tap, picture, read-along text, plain line (calm failure lines)
    theme/       colours, type, motion constants
    providers    Riverpod providers
    router       go_router routes: / (home), /day/:weekday, /trophies, /trophies/stickers, /stickers (the same sticker book, opened from the home dock, back returns home), /words, /words/:pack/:book, /stories, /stories/:pack/:story, /habits, /gate, /parent (parent today), /parent/packs, /parent/week, /parent/child, /parent/backup, /parent/settings and /parent/credits
```

Domain defines the repository interfaces, data implements them, every repository call returns `Either<Failure, T>`. A store error is logged and comes back as the failure "the phone could not save it"; no screen shows raw exception text. If the store cannot be opened at start, `main` runs a plain screen ("Starbook could not open just now.") instead of the app.

## Packs at runtime

A pack file is parsed and validated in `data/pack` into domain objects. Validation is hand-written Dart that follows `schema/pack.schema.json` and returns a list of plain errors, each with the full path from the pack root (`sheets[0].days[1].tasks[0]: text is missing`). The schema file is the reference for pack authors; a test checks every default pack against the Dart validator only.

Installed packs are stored as their raw JSON in the `packs` table and parsed at start, listed by install time and then id. They are small (tens of KB), so everything lives in memory after start. A replaced pack keeps its install time, so it keeps its place in the list.

References between packs use `pack-id/item-id`. A missing reference (a task that opens a word book from a removed pack) shows the task without its open bar; it never crashes. `fullRef` turns a bare `item-id` into `pack-id/item-id` using the pack of the week's sheet. The day screen finds out what a reference opens (word book or story) with `bookKindOf` over the installed packs, and shows no bar when nothing matches. When the child taps the bar, the day screen pushes `/words/<full ref>` or `/stories/<full ref>`.

Default packs are bundled from `packs/` in place (listed under `assets` in `pubspec.yaml`) and are checked on every start. A default that is not installed and was not offered before is installed. An installed default is replaced only when the bundled revision is higher. The `defaultsOffered` setting lists the default ids already offered, so a default the parent removed is never put back.

An award with `"retired": true` parses like any other award. `give` refuses it and the parent area lists no chip for it, but an award row that already points at it still draws with its label and stars, and the Packs screen leaves it out of the award count and out of the check for the pack that holds the only awards. The default pack keeps Star, "Very good!" and "Well done!" this way, at revision 5, so Sticker is its only live award.

Import paths, both ending on the Packs screen (`/parent/packs`):
- Parent area, Packs, Import a pack: file_picker, one button for pack and voice files.
- Share or "open with" from another app: `MainActivity` has intent filters for `application/json`, `application/octet-stream` and `application/zip` (view and send), and for a view of a file named `*.json` or `*.starbook-voice`. The activity is `singleTask`, and deep links are off (`flutter_deeplinking_enabled` is false). No package is used. On start and on every resume the app asks the activity for the file over its own MethodChannel, `starbook/open`, method `take`. The activity reads the file (at most 50 MB plus one byte, so the app can tell a file at the limit from a larger one), returns its name and bytes, and clears the intent. The app keeps the file in `incomingFileProvider` and goes to `/gate`. The gate opens `/parent/packs` instead of `/parent` when a file waits, and the Packs screen takes the file on its first frame. Leaving the gate without the right answer drops the file silently.

A file is never written before the parent has seen it. The Packs screen tells a voice pack by its first two bytes, `PK`, not by its name; anything else is read as strict UTF-8 JSON. `check` on the pack repository and on the voice repository runs the full checks and writes nothing. The screen then shows a preview sheet ("Add this pack?" or "Add this voice?") and calls `install` only after Add. A file over 50 MB is refused with "the file is larger than 50 MB", an empty or unreadable one with "the file could not be read", and a file that is not valid UTF-8 with "the file is not valid JSON". A refusal shows a sheet with one plain line and OK. At the same or a lower revision than the installed one, `install` returns `needsConfirm` and writes nothing until it is called again with `confirmed: true`; the screen asks "Replace this pack?" or "Replace this voice?" first.

A voice file gets the same checks as a bundled voice pack. A clip's `words`, when present, must be a list of entries that each start with a number, or the file is refused with "a clip has bad word timings". A voice replace writes the new clips to `voices/<id>~new`, moves the old folder to `voices/<id>~old`, moves the new one in and writes the row. If moving the new folder in or writing the row fails, the new folder is removed and the old one comes back, so a failed replace leaves the old voice. A `~new` folder left by an earlier failure is deleted at the start of the next install.

## Database

| Table | Columns | Notes |
|---|---|---|
| `packs` | id, revision, title, json, installed_at | raw pack JSON |
| `child` | id (always 1), name, picture | one child in version 1. The row may be missing, and name and picture may be empty; home then shows the sheet title and no picture |
| `weeks` | id, week_start, sheet_ref, sheet_json, special_reward | `sheet_json` is a copy of the sheet taken when the week starts, plus this week's edits. `special_reward` is the parent's text for the week, trimmed; blank text stores null. Updating or removing a pack never changes a week that has started. |
| `awards` | id, week_id, weekday, task_id, award_ref, stars, sticker, given_at, undone_at | undo sets `undone_at`; rows are never deleted. Replacing an award undoes the old row and inserts the new one in the same write. A unique index (`awards_live`) allows one award per task per day that is not undone |
| `trophies` | milestone_ref, earned_at | insert only. The ref is `pack-id/milestone-id`, `pack-id/sheet-id/habit-id` or `sticker-page:<page>` for a page trophy |
| `finished` | kind (`wordbook` or `story`), ref (`pack-id/item-id`), finished_at | one row per visit that reaches the last card or page, so the same book can have many rows |
| `voices` | id, revision, title, language, manifest_json, folder, installed_at | voice packs; clips are unzipped into the app's files folder under `voices/<id>/`, the manifest is kept here and indexed in memory by normalised text |
| `habit_ticks` | day, habit_id | primary key (day, habit_id). `day` is the local date, for example `2026-01-05`. Added in schema version 2. Undo deletes the row, unlike awards |
| `settings` | key, value | `sound` and `slowReading` (`true` or `false`, from the Settings screen; sound on and slow reading off when unset); `activeVoice` (a JSON list of voice ids, one for each language: the voice that wins when two have a clip for the same text in that language; picked on the Packs screen, and a plain id written by an older version is still read; a language with no pick uses its first voice by id); `activeSheet` (`pack-id/sheet-id`, the first installed sheet when unset or not installed; removing the active sheet's pack leaves the setting as it is and the first installed sheet is used); `defaultsOffered` (JSON list of default pack ids already offered); `seenAward` (the id of the newest award the child has seen, so each award lands once on home); `seenSticker` (the id of the newest live sticker award the sticker book has shown, so a new sticker plays there once); `seenWeek` (the id of the last week whose finished-week moment was shown); `seenTrophies` (JSON list of trophy refs the child has seen) |

Weeks start on Monday, local time. The week row is created when the app is first opened in that week, from the active sheet.

## Rules in code

- A day is done when every non-bonus task in it has an award that is not undone.
- A week is done when every day listed in its sheet is done.
- Counters (`stars`, `stickers`, `daysDone`, `weeksDone`, `wordbooksDone`, `storiesRead`) are computed from the tables, not stored.
- After every award and every finished book, milestones and sticker pages are checked and any newly reached ones are inserted into `trophies`. A trophy row is never deleted, even when the award that reached it is undone.
- `give` takes an optional `replaces` award id, the task's live award. It is undone in the same transaction as the new row, so a task never has two live awards. `undo` takes an optional `restore` id, the award that was replaced; it is made live again in the same transaction and milestones are checked. A restored award that home has already shown does not land again.
- `setSpecialReward(weekId, text)` writes the week's reward text; blank text clears it.
- Week edit changes the week's own copy of the sheet (`weeks.sheet_json`) in one transaction and never touches the pack or `awards`. `addTask` adds a task with id `added-<time>` to a school day that is not done. `editTask` changes a task's text and drops its `say`. `removeTask` refuses a day's only task and any removal that leaves a day with only bonus tasks, and the screen offers no Remove on a task that has an award. Blank text is refused. Next week starts from the pack's sheet again.
- `setChild` writes the one child row; blank name stores null and the picture is one of twelve bundled names. `prefs` and `setPrefs` read and write the `sound` and `slowReading` settings; the screens apply them to `Sfx` and the speaker straight away.
- A screen built on an earlier day (parent today, the habit screen) shows the new day on its next load and writes nothing to the old one; the app also reloads both on resume.
- The gate asks one of three kinds of question (`pickGateQuestion` in `lib/domain/gate_question.dart`): a sum `a + b` with a and b from 10 to 99 and a + b at most 99, a difference `a − b` with a and b from 10 to 99 and a − b at least 10, or a product `a × b` with a from 2 to 5, b from 2 to 9 and a × b at least 10. The answer is always two digits. It is never the same question as the last one shown, even across gate screens. A screen reader hears "plus", "minus" or "times". The gate lockout is not stored. `GateLock` is a keep-alive provider that holds the seconds left: the third wrong try in a row sets 60 and a timer counts down. It lasts for the app run and survives leaving and reopening the gate, but a restart clears it.
- The default sticker set is `stickerPages` in `progress.dart`: eight pages, 188 stickers: five of 24 (Animals, Sea and garden, Food, Sky and space, Fun things), Animal friends (20), Out and about (24) and Play and music (24), in the order of `stickers.md`. `defaultStickers` is their stickers in that order. A sticker names one page only.
- A sticker award picks at random among the stickers of the award's list (the default set when the award has none) that are not in the album. When the album holds them all, it picks among the whole list, so repeats come only once the set is complete. `nextSticker` takes the `Random`; the progress repository takes one in its constructor, and tests pass a fixed one. The pick runs inside the `give` transaction over the live album.
- `Sfx.sticker(name)` plays `assets/sticker-sounds/<name>.ogg` for the 32 stickers in `_calls` (`sfx.dart`, listed in `stickers.md`) and `twinkle.ogg` for every other name. It goes through the same single player (the one the page flip uses) and the same sound switch as `Sfx.play`, so nothing plays when sound is off. `StickerView` calls it on every tap, before the reduced-motion check, so it plays with "remove animations" on. The sticker book makes a grey sticker a plain silhouette with no tap, so it stays silent.
- A sticker page trophy has the ref `sticker-page:<page>` (for example `sticker-page:animals`); a pack ref cannot hold a colon, so it never clashes. `fullPages` returns the pages whose every sticker is in the live album, and the same step that checks milestones after an award inserts them into `trophies`, once. Nothing inserts one on upgrade or on restoring a backup: a page trophy comes only when an award that fills the page is given (or brought back by undo), and the 40 stickers from before the set grew fill no page. Undo takes a sticker out of the album but never the trophy. `shelfOf` puts the eight page trophies after the pack trophies, so home finds them to celebrate like any other.
- The sticker count the screens show is `stickersEarned`: the stickers of the set in the live album, each once. A sticker outside the set (from an imported pack) is not counted and has no trophy.
- `wordbooksDone` and `storiesRead` count distinct `ref` values of their kind in `finished`, so reading the same story ten times counts once.
- A word book or story writes its `finished` row (and checks milestones) when the last card or page shows, once per visit. Leaving the screen reloads the week, so home shows a trophy reached that way over the screen the child returns to (the word books list, the stories list or the day).
- `takeUnseen(weekId)` returns the ids of this week's awards that are not undone and are newer than `seenAward`, then sets `seenAward` to the newest award id in the table, all in one transaction. Home reads it once per load, so an award lands once, an undone award never lands, and a restart does not replay anything. The week provider reads the child row before it calls `takeUnseen`, so nothing that can fail runs after awards are marked seen.
- `album()` returns the sticker of every award that is not undone, newest first, repeats included.
- `takeNewSticker()` returns whether the newest live sticker award is newer than `seenSticker`, and then sets `seenSticker` to it, in one transaction. The sticker book reads it once per load, so a new sticker plays there once and an undone award never does.
- `takeMoments(weekId)` returns whether the week is done and its moment not shown yet (`seenWeek` is not that week), and the newest trophy ref not in `seenTrophies`. It then sets `seenWeek` and marks every trophy so far as seen, in one transaction. Several new trophies make one celebration: only the newest is returned. Home calls it after the landings, and not while the gate or parent today is open, so it tries again on the next load.
- `tickHabit(weekId, habitId)` inserts today's row in `habit_ticks`, once a day: a second tick returns `Right(false)` and changes nothing. It fails for a week that is over or a habit not on the week's sheet. When the habit has a tick on each of the 7 days of the week, Monday to Sunday, it inserts the trophy `pack-id/sheet-id/habit-id` into `trophies`. That row is never removed, even when `undoHabit` deletes a tick later.
- Habit ticks reach no counter and no milestone.

## Read-aloud

`Speaker` (domain) has `speakWord`, `speakSentence` with a word callback, `stop`, and `voiceStatus(language)`. Both speak calls return true when the read ran to the end or failed and false when `stop` or a newer read cut it, so a caller can chain a second read only after the first finished. Each call stops the read in progress first. On start the app installs the bundled voice packs from `assets/voices/`: a higher revision replaces an installed pack, the same or a lower one writes nothing, and a pack that fails its checks is skipped, and its lines use the phone voice. The data implementation tries two sources in order:

1. **Voice pack clip** ([`voice-packs.md`](voice-packs.md)). Look up the spoken text in the active voice pack, then in any other installed one for that language. Play the clip with audioplayers. Word highlighting follows the clip's `words` timings against the player position. Slow mode plays the clip at 0.8 speed with pitch kept, and scales the timings to match.
2. **Phone text-to-speech** (flutter_tts) when no clip matches:
   - Words at rate 0.35, sentences at 0.4, slow mode 0.28 (flutter_tts scale on Android, where 0.5 is normal speed). Tune on a real phone.
   - Highlighting uses the TTS progress callback (word start and end offsets, Android 8 and later). If the engine sends no progress events, the first sentence reads unlit; from the next one on, a fallback speaks the sentence word by word and highlights each in turn.

A clip without `words` splits its length evenly across the words for highlighting.
- There is no pause: tapping Read to me again stops the read.
- `say` overrides from the pack are applied before speaking; the shown text never changes.
- The settings screen shows whether the English and Hindi voices are installed and work offline, and links to the phone's text-to-speech settings when they do not.

## Backup

Export writes one JSON file: `{ "starbookBackup": 2, "made": "<ISO time>", "packs": [...], "child": [...], "weeks": [...], "awards": [...], "trophies": [...], "finished": [...], "habit_ticks": [...], "settings": [...] }`. The version is the store version, and each table is a plain list of its rows (the `voices` table is left out, its clips are files). The parent saves it with the system save dialog or shares it through the share sheet.

`check` reads a file and writes nothing. It refuses a file that is not JSON or not a backup ("the file is not a Starbook backup"), one with a newer version ("the backup is from a newer Starbook"), and one with a missing table, a row with a wrong column or type, a bad setting value, a weekday that does not exist, a pack that does not parse or whose id differs from its row, or a sheet that does not parse ("the backup is damaged"). A good file returns what it holds: the date, the child's name, the live stars and the pack count, shown in the "Restore this backup?" sheet.

`restore` runs the same checks, then deletes and refills every table in one transaction, so a failure part way changes nothing. It then reloads the packs and the voices; a pack added since the backup is gone, and an active voice that is not installed falls back to the first voice of its language. The screen applies the restored sound and reading speed settings at once.

## Android

- minSdk 24. Read-along highlighting needs 26; on 24 and 25 the first sentence reads unlit and the word-by-word fallback runs after it.
- No permissions. The release manifest has no internet permission.
- App icon: the hibiscus sticker, an adaptive icon (paper background colour and a foreground mipmap) and legacy mipmaps for Android 7. See [`design.md`](design.md).
- Reduced motion: when the phone asks for it (`MediaQuery.disableAnimationsOf`), screen changes are instant, landings fade in where they sit, and sticker animations and the trophy rise and sparks are skipped. Sounds keep their timing.
- `MainActivity` is `singleTask` and takes shared or opened files, see "Packs at runtime".
- `<queries>` entry for the text-to-speech service so flutter_tts can find the engine on Android 11 and later.
- Portrait and landscape both work; tablets get the same layout with more space.

## Tests

Few, and each one pins a rule, a boundary, a bug that once happened or a flow across layers. `flutter test` runs everything under `test/`. Grouped by file, with what each pins.

`test/assets_test.dart`
- every picture listed in `pictures.md` is bundled as an svg.
- every sticker in `stickers.md` has its files and sits on exactly one page, and the pages in `stickerPages` are the sticker list in order.
- every default pack names only library pictures, listed stickers and bundled icons.
- every asset folder the app ships (listed in `pubspec.yaml`, `packs/` included) has a `CREDITS.md`.

`test/domain_is_pure_dart_test.dart`
- `lib/domain` imports nothing from Flutter.

`test/domain/progress_test.dart`
- a day needs every non-bonus task (every-day tasks included), a week needs every day, an undone award does not count.
- a sticker award picks only stickers not yet earned until the list is complete, then any.
- the 40 stickers from before the set grew are all still in it and fill no page.
- a child who had all 120 stickers from before the set grew gets only new ones, from every new page, and the five old pages stay full.

`test/data/pack/pack_test.dart`
- the validator rejects, one test per rule: a pack without an id, a weekday that does not exist, an id used twice (awards, and a task id within a sheet), an award of an unknown kind, a `retired` that is not true or false, a revision that is not a whole number (but 2.0 counts as 2), and a habit list with a missing id or text, a repeated id or a bad picture.
- `parsePack` gives a failure and never throws for text that is not a pack, and accepts a BOM.
- every default pack loads from the bundle and passes.

`test/data/store_test.dart`
- revisions: a higher one replaces, the same or a lower one asks, a started week keeps its copy of the sheet.
- a switched sheet starts next week and the week in progress keeps its own; when the active sheet's pack is removed, the first installed sheet is used.
- default packs: one installs once, a removed one stays removed, a higher bundled revision replaces.
- milestones are inserted once and never removed after undo.
- a page trophy comes with the award that fills the page, once, and stays after undo; stickers stored before count (Animal friends, for a child who had the whole old set).
- a week starts on Monday local time, and a week never opened has no record.
- an unseen award is taken once, also on a new repository on the same store, and an undone award is never unseen.
- a replacing award undoes the old one in the same write, and undo brings the old one back, already seen.
- a finished week and the newest new trophy are each taken once, also after undo and redo and on a new repository.
- the album lists live stickers newest first; a replaced sticker leaves it and a restored one returns.
- a habit is ticked once a day, undo removes the tick and it can be ticked again.
- seven days of one week earn the habit trophy once, undo keeps it, and ticks reach no counter or milestone.
- a week edit changes this week only: a removed task's award stays in this week, a day keeps one task that is not a bonus, a done day takes no new task, and next week starts from the sheet as imported.
- a backup restores every table into another store, with habit ticks, the active voice and settings, and replaces what that store had.
- a refused restore changes nothing: not a backup, a newer backup, a backup that fails part way, a missing table, wrong column types, a bad weekday, and a bad `seenAward`, `seenSticker`, `seenTrophies` or `defaultsOffered` setting.
- a version 1 store upgrades to version 2 and keeps its data.

`test/data/voice_test.dart`
- voice lookup: trim and collapsed spaces, language prefix match, the active voice wins for each language, a plain stored id is still read, a pick for one language leaves the other, no clip gives nothing.
- a voice pack imported from a file goes through the bundled checks: a missing clip, a `..` entry and bad word timings are rejected and write nothing; the same revision asks and replaces only when confirmed; a higher one replaces.
- a bundled voice pack at start: a higher revision replaces, the same one does not.
- the bundled packs install side by side: a Hindi line plays from Divya, an English line from Heart.
- the speaker plays a matching clip and sends a line with no clip to the phone voice at sentence rate; slow reading applies when a call does not say.
- a clip's word timings call `onWord` once per word, in order, and slow mode keeps the same media times.

`test/presentation/pictures_test.dart`
- the tilt of a picture is a fixed whole degree from -4 to 4.
- a picture that is not in the library, and an emoji picture, render without throwing.
- a sticker without an animation shows its still, and an unknown sticker falls back.

`test/presentation/sfx_test.dart`
- no sound plays when sound is off (a sticker sound included), and star steps stop at the top note.
- `Sfx` never throws when the player fails.
- every sound `Sfx` can play is bundled, including the 33 sticker sound files (32 calls and the twinkle) that the default stickers reach.

`test/presentation/word_books_test.dart`
- the letter colouring marks exactly the book's letter and nothing else.

`test/presentation/stories_test.dart`
- play lights the word the speaker reports, stop and a page turn clear the light and cut the read, a late word from a cut read lights nothing, and a tapped word is read through the story's `say` map.
- a sentence that does not fit at 40sp steps down and never renders below 32sp.

`test/presentation/week_and_day_test.dart`
- home shows the week, the rest message today and the default goal; a finished day opens with one open bar and the banner.
- new awards land once on home with a rising star note and their sounds; the day screen plays nothing.
- an award that lands while the day screen is open plays no sound.
- a full page trophy celebrates over home with the page picture and name.
- the sticker book opens on the newest sticker's page, counts each sticker once and shows a More stickers page for a sticker outside the set.
- tapping an earned sticker plays its call (lion) or the twinkle (heart), and tapping a grey one plays nothing.
- a moment that comes due while the gate is open shows after the gate.
- tapping a task reads its `say` with the row lit until the read ends, gives no award, and leaving the day stops the read.

`test/presentation/parent_test.dart`
- the gate: opens parent today only for the right answer to the question, shows a new question after a wrong try, and three wrong tries lock it for 60 seconds, a wait that outlasts closing and reopening the gate.
- an award can be replaced and undone in parent today, and after Done the home lands only the live one, once, with the typed reward.
- a give the store refuses shows the calm line and never the store's text.
- an award given under the old default pack ("Well done!", Star or "Very good!", now retired) still shows with its own label after the new pack installs, and parent today does not offer it.
- a trophy and a finished week reached in parent today show on home after the landings, week first, once each.
- a habit ticked on the habit screen plays one star note, a second tap changes nothing, and Undo lets the child tick it again.
- the word book flow: a book read to its last card writes one `finished` row per visit, `wordbooksDone` counts distinct books, and the trophy shows once over the word books list.
- the story flow: the same for a story, with `storiesRead`, the trophy over the stories list, and the credit on the last page.
- the open-with flow: a file opened with Starbook waits for the gate, leaving the gate drops it, and after the gate the preview shows before anything is added.
- the packs screen: a bad file changes nothing, the same revision asks before it replaces, and remove asks first while the pack with the only awards cannot be removed.
- home with its five dock buttons shows no overflow on 320, 360 and 430 wide phones, the Stickers button opens the sticker book and back returns home.
- every screen fits a 360 x 640 phone and an 800 x 1280 tablet with no overflow, and every control has a screen-reader label.
- the parent changes a task for this week and names the child; today and home show both, and a task with a star has no Remove.

Not tested yet: the midnight guards in parent today and the habit screen (`lib` has no clock to move). The README screenshots are made by `tool/screenshots/screens_test.dart`, which is not part of `flutter test`; see the README.

## Gates

```
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```
