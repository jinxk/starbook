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
| Import a file | file_picker (system document picker, no storage permission) |
| Export and share | share_plus |
| Voice pack import | archive (unzip `.starbook-voice` files) |

Fonts (Baloo 2, Andika, Hind), pictures, stickers, icons, their licence texts (`assets/licenses/`), sound effects (`assets/sounds/`, sources in `CREDITS.md` there) and the default voice packs (`assets/voices/heart.starbook-voice` for English, `divya.starbook-voice` for Hindi) are bundled as assets. `dart run tool/fetch_assets.dart` downloads the Fluent pictures, stickers, icons and licence texts again from the pinned sources in [`pictures.md`](pictures.md) and [`stickers.md`](stickers.md). The sound effects are copied by hand from the Kenney packs. The voice pack renderer is a separate Python tool in `tool/voice/`, not part of the app build. Flutter is pinned to 3.44.6 in `pubspec.yaml` `environment` and in the CI workflow. Change both together, and check package versions against the new Flutter when you do.

## Layers

```
lib/
  domain/        pure Dart, no Flutter imports
    pack/        Pack, Sheet, Habit, Day, Task, Award, Milestone, WordBook, WordCard, Story, StoryPage, Credit
    progress/    Week, GivenAward, Trophy, Moments, Counters, Child
    repositories interfaces, use cases (one public execute() each)
  data/
    db/          sqflite open, migrations
    pack/        JSON parser and validator, default pack loader
    repositories implementations
    speech/      flutter_tts wrapper behind a domain Speaker interface
  presentation/
    child/       home, day, trophy room, habits, word books, stories
    parent/      gate, today, week, packs, backup, settings
    widgets/     sticker, award mark, landing, moment, tap, picture, read-along text
    theme/       colours, type, motion constants
    providers    Riverpod providers
    router       go_router routes: / (home), /day/:weekday, /trophies, /habits, /gate and /parent (parent today)
```

Domain defines the repository interfaces, data implements them, every repository call returns `Either<Failure, T>`.

## Packs at runtime

A pack file is parsed and validated in `data/pack` into domain objects. Validation is hand-written Dart that follows `schema/pack.schema.json` and returns a list of plain errors, each with the full path from the pack root (`sheets[0].days[1].tasks[0]: text is missing`). The schema file is the reference for pack authors; a test checks every default pack against the Dart validator only.

Installed packs are stored as their raw JSON in the `packs` table and parsed at start. They are small (tens of KB), so everything lives in memory after start.

References between packs use `pack-id/item-id`. A missing reference (a task that opens a word book from a removed pack) shows the task without its open bar; it never crashes. The day screen finds out what a reference opens (word book or story) with `bookKindOf` over the installed packs, and shows no bar when nothing matches.

Default packs are bundled from `packs/` in place (listed under `assets` in `pubspec.yaml`) and are checked on every start. A default that is not installed and was not offered before is installed. An installed default is replaced only when the bundled revision is higher. The `defaultsOffered` setting lists the default ids already offered, so a default the parent removed is never put back.

Import paths:
- Parent area, Import: file_picker, read the file, validate, install.
- Share or "open with" from another app: Android intent filters for `application/json` and `.json` files deliver the file to the app, which opens the parent gate and then the same import screen. A file never installs without the parent seeing it.

## Database

| Table | Columns | Notes |
|---|---|---|
| `packs` | id, revision, title, json, installed_at | raw pack JSON |
| `child` | id (always 1), name, picture | one child in version 1. The row may be missing, and name and picture may be empty; home then shows the sheet title and no picture |
| `weeks` | id, week_start, sheet_ref, sheet_json, special_reward | `sheet_json` is a copy of the sheet taken when the week starts, plus this week's edits. `special_reward` is the parent's text for the week, trimmed; blank text stores null. Updating or removing a pack never changes a week that has started. |
| `awards` | id, week_id, weekday, task_id, award_ref, stars, sticker, given_at, undone_at | undo sets `undone_at`; rows are never deleted. Replacing an award undoes the old row and inserts the new one in the same write. A unique index (`awards_live`) allows one award per task per day that is not undone |
| `trophies` | milestone_ref, earned_at | insert only |
| `finished` | kind (`wordbook` or `story`), ref, finished_at | one row per time a book is read to the end |
| `voices` | id, revision, title, language, manifest_json, folder, installed_at | voice packs; clips are unzipped into the app's files folder under `voices/<id>/`, the manifest is kept here and indexed in memory by normalised text |
| `habit_ticks` | day, habit_id | primary key (day, habit_id). `day` is the local date, for example `2026-01-05`. Added in schema version 2. Undo deletes the row, unlike awards |
| `settings` | key, value | sound, reading speed; `activeVoice` (the id of the voice pack that wins when two have a clip for the same text); `activeSheet` (`pack-id/sheet-id`, the first installed sheet when unset or not installed); `defaultsOffered` (JSON list of default pack ids already offered); `seenAward` (the id of the newest award the child has seen, so each award lands once on home); `seenWeek` (the id of the last week whose finished-week moment was shown); `seenTrophies` (JSON list of trophy refs the child has seen) |

Weeks start on Monday, local time. The week row is created when the app is first opened in that week, from the active sheet.

## Rules in code

- A day is done when every non-bonus task in it has an award that is not undone.
- A week is done when every day listed in its sheet is done.
- Counters (`stars`, `stickers`, `daysDone`, `weeksDone`, `wordbooksDone`, `storiesRead`) are computed from the tables, not stored.
- After every award and every finished book, milestones are checked and any newly reached ones are inserted into `trophies`. A trophy row is never deleted, even when the award that reached it is undone.
- `give` takes an optional `replaces` award id, the task's live award. It is undone in the same transaction as the new row, so a task never has two live awards. `undo` takes an optional `restore` id, the award that was replaced; it is made live again in the same transaction and milestones are checked. A restored award that home has already shown does not land again.
- `setSpecialReward(weekId, text)` writes the week's reward text; blank text clears it.
- The gate lockout is not stored. `GateLock` is a keep-alive provider that holds the seconds left: the third wrong try in a row sets 60 and a timer counts down. It lasts for the app run and survives leaving and reopening the gate, but a restart clears it.
- Sticker awards give the first sticker in the award's list that is not already in the album, then cycle. No randomness anywhere.
- `wordbooksDone` and `storiesRead` count distinct books, so reading the same story ten times counts once.
- `takeUnseen(weekId)` returns the ids of this week's awards that are not undone and are newer than `seenAward`, then sets `seenAward` to the newest award id in the table, all in one transaction. Home reads it once per load, so an award lands once, an undone award never lands, and a restart does not replay anything. The week provider reads the child row before it calls `takeUnseen`, so nothing that can fail runs after awards are marked seen.
- `album()` returns the sticker of every award that is not undone, newest first.
- `takeMoments(weekId)` returns whether the week is done and its moment not shown yet (`seenWeek` is not that week), and the newest trophy ref not in `seenTrophies`. It then sets `seenWeek` and marks every trophy so far as seen, in one transaction. Several new trophies make one celebration: only the newest is returned. Home calls it after the landings, and not while the gate or parent today is open, so it tries again on the next load.
- `tickHabit(weekId, habitId)` inserts today's row in `habit_ticks`, once a day: a second tick returns `Right(false)` and changes nothing. It fails for a week that is over or a habit not on the week's sheet. When the habit has a tick on each of the 7 days of the week, Monday to Sunday, it inserts the trophy `pack-id/sheet-id/habit-id` into `trophies`. That row is never removed, even when `undoHabit` deletes a tick later.
- Habit ticks reach no counter and no milestone.

## Read-aloud

`Speaker` (domain) has `speakWord`, `speakSentence` with a word callback, `stop`, and `voiceStatus(language)`. Both speak calls return true when the read ran to the end or failed and false when `stop` or a newer read cut it, so a caller can chain a second read only after the first finished. Each call stops the read in progress first. On start the app installs the bundled voice packs from `assets/voices/`: a higher revision replaces an installed pack, the same or a lower one writes nothing, and a pack that fails its checks is skipped and leaves the phone voice. The data implementation tries two sources in order:

1. **Voice pack clip** ([`voice-packs.md`](voice-packs.md)). Look up the spoken text in the active voice pack, then in any other installed one for that language. Play the clip with audioplayers. Word highlighting follows the clip's `words` timings against the player position. Slow mode plays the clip at 0.8 speed with pitch kept, and scales the timings to match.
2. **Phone text-to-speech** (flutter_tts) when no clip matches:
   - Words at rate 0.35, sentences at 0.4, slow mode 0.28 (flutter_tts scale on Android, where 0.5 is normal speed). Tune on a real phone.
   - Highlighting uses the TTS progress callback (word start and end offsets, Android 8 and later). If the engine sends no progress events, a fallback speaks the sentence word by word and highlights each in turn.

A clip without `words` splits its length evenly across the words for highlighting.
- Pause is stop plus restart from the current word, because offsets shift after a pause.
- `say` overrides from the pack are applied before speaking; the shown text never changes.
- The settings screen shows whether the English and Hindi voices are installed and work offline, and links to the phone's text-to-speech settings when they do not.

## Backup

Export writes one JSON file: `{ "starbookBackup": 1, "packs": [...], "child": {...}, "weeks": [...], "awards": [...], "trophies": [...], "finished": [...], "settings": {...} }`, shared through the share sheet. Import shows what the file holds and replaces everything after the parent confirms. The backup should also hold `habit_ticks` (not built yet).

## Android

- minSdk 24. Read-along highlighting needs 26; on 24 and 25 the word-by-word fallback runs.
- No permissions. The release manifest has no internet permission.
- `<queries>` entry for the text-to-speech service so flutter_tts can find the engine on Android 11 and later.
- Portrait and landscape both work; tablets get the same layout with more space.

## Tests

Few, and each one pins a rule:

- pack validator: one test per rule that rejects (missing id, bad weekday, duplicate ids, unknown kind, revision not a whole number), plus every default pack passes.
- revision rules: higher replaces, same or lower asks, started weeks keep their copy of the sheet.
- day and week completion with bonus tasks.
- milestones: reached once, inserted once, never removed after undo.
- sticker order: first missing, then cycle.
- week rollover on Monday, including a week that was never opened.
- unseen awards: taken once, still seen by a new repository on the same store, an undone award never unseen.
- two widget tests for home and the day screen: the rest line, default goal and open bar; new awards landing once with their sounds.
- backup export then import gives the same data.
- voice lookup: trim and collapsed spaces, language prefix match, the active voice wins, no clip gives nothing.
- voice pack install: a manifest naming a missing clip file is rejected; a zip entry with `..` in its path is rejected; a higher bundled revision replaces.
- the speaker plays a matching clip and sends a line with no clip to the phone voice at sentence rate.
- read-aloud widget checks: tapping a task reads it, lights the row until the read ends, gives no award, and leaving the day stops the read; a new trophy is spoken after "A new trophy!"; a habit tap reads the habit.
- one widget test for the parent gate: it opens only for the shown numbers, shows new numbers after a wrong try, and three wrong tries lock it for 60 seconds, a wait that outlasts closing and reopening the gate.
- one widget test for parent today: an award can be replaced and undone, and after Done the home lands only the award left live, once, with the typed reward.
- a store test: a replacing award undoes the old one in the same write, and undo brings the old one back, already seen.
- store tests for moments and the album: a finished week and the newest new trophy are each taken once, also after undo and redo and on a new repository; the album lists live stickers newest first.
- store tests for habits: a habit is ticked once a day, undo removes the tick and it can be ticked again; seven days of one week earn the habit trophy once, undo keeps it, and ticks reach no counter or milestone; a version 1 store upgrades to version 2 and keeps its data.
- one validator test: a habit list with a missing id, a missing text, a repeated id or a bad picture.
- two widget tests for parent today: a trophy and a finished week reached there are shown on home after the landings, week first, once each; a habit ticked on the habit screen plays one star note, a second tap changes nothing, and Undo lets the child tick it again.

## Gates

```
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```
