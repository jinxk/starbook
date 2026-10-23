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
    parent/      gate, today, week, child, packs, backup, settings, credits, tips
    widgets/     sticker, award mark, landing, sticker reveal, moment, tap, picture, read-along text, plain line (calm failure lines)
    theme/       colours, type, motion constants
    providers    Riverpod providers
    router       go_router routes: / (home), /day/:weekday, /trophies, /trophies/stickers, /stickers (the same sticker book, opened from the home dock, back returns home), /words, /words/:pack/:book, /stories, /stories/:pack/:story, /habits, /gate, /parent (parent today), /parent/packs, /parent/week, /parent/child, /parent/backup, /parent/settings, /parent/credits and /parent/tips
```

Domain defines the repository interfaces, data implements them, every repository call returns `Either<Failure, T>`. A store error is logged and comes back as the failure "the phone could not save it"; no screen shows raw exception text. If the store cannot be opened at start, `main` runs a plain screen ("Starbook could not open just now.") instead of the app.

## Packs at runtime

A pack file is parsed and validated in `data/pack` into domain objects. Validation is hand-written Dart that follows `schema/pack.schema.json` and returns a list of plain errors, each with the full path from the pack root (`sheets[0].days[1].tasks[0]: text is missing`). The schema file is the reference for pack authors; a test checks every default pack against the Dart validator only.

Installed packs are stored as their raw JSON in the `packs` table and parsed at start, listed by install time and then id. They are small (tens of KB), so everything lives in memory after start. A replaced pack keeps its install time, so it keeps its place in the list.

References between packs use `pack-id/item-id`. A missing reference (a task that opens a word book from a removed pack) shows the task without its open bar; it never crashes. `fullRef` turns a bare `item-id` into `pack-id/item-id` using the pack of the week's sheet. The day screen finds out what a reference opens (word book or story) with `bookKindOf` over the installed packs, and shows no bar when nothing matches. When the child taps the bar, the day screen pushes `/words/<full ref>` or `/stories/<full ref>`.

Default packs are bundled from `packs/` in place (listed under `assets` in `pubspec.yaml`) and are checked on every start. A default that is not installed and was not offered before is installed. An installed default is replaced only when the bundled revision is higher. The `defaultsOffered` setting lists the default ids already offered, so a default the parent removed is never put back.

An award with `"retired": true` parses like any other award. `give` refuses it and the parent area lists no chip for it, but an award row that already points at it still draws with its label and stars, and the Packs screen leaves it out of the award count and out of the check for the pack that holds the only awards. The default pack keeps Star, "Very good!" and "Well done!" this way, at revision 5, so Sticker is its only live award.

A habit may carry an optional `sticker`, a name from the sticker set. The validator refuses any other name (`sheets[0].habits[5].sticker: "bubble" is not a sticker`). A habit without one shows its `picture` as a sticker (`StickerView` with `picture: true`) and never gives a book sticker. The sample pack `packs/sample-week.json` ("Sample weeks") is at revision 7 and has two sheets, "Little learner week" first and "Superstar homework week", with the same habit ids. Both give bath `bubbles`, teeth-morning `sunrise`, teeth-night `moon` and breakfast `pancakes`; lunch and dinner have none. A week keeps the sheet it started with, so the default habit stickers show from the first Monday after the update. Every task of "Little learner week" has a `tip`, which shows from the same Monday; the other sheet has none.

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
| `awards` | id, week_id, weekday, task_id, award_ref, stars, sticker, given_at, undone_at | undo sets `undone_at`; rows are never deleted. Replacing an award undoes the old row and inserts the new one in the same write. A unique index (`awards_live`) allows one award per task per day that is not undone. The sticker for finishing all habits of a day is one row here too, with task id and award ref `habits:done` (the constant `habitsDoneTask` in `lib/domain/progress/progress.dart`, so home can read it) and 0 stars (see `takeHabitSticker`); no table or column was added for it |
| `trophies` | milestone_ref, earned_at | insert only. The ref is `pack-id/milestone-id`, `pack-id/sheet-id/habit-id` or `sticker-page:<page>` for a page trophy. A habit trophy is one per pack and habit, whichever sheet earned it, so only the first row for a habit is written |
| `finished` | kind (`wordbook` or `story`), ref (`pack-id/item-id`), finished_at | one row per visit that reaches the last card or page, so the same book can have many rows |
| `voices` | id, revision, title, language, manifest_json, folder, installed_at | voice packs; clips are unzipped into the app's files folder under `voices/<id>/`, the manifest is kept here and indexed in memory by normalised text |
| `habit_ticks` | day, habit_id | primary key (day, habit_id). `day` is the local date, for example `2026-01-05`. Added in schema version 2. Undo deletes the row, unlike awards, and never touches the `habits:done` award row |
| `settings` | key, value | `sound` and `slowReading` (`true` or `false`, from the Settings screen; sound on and slow reading off when unset); `activeVoice` (a JSON list of voice ids, one for each language: the voice that wins when two have a clip for the same text in that language; picked on the Packs screen, and a plain id written by an older version is still read; a language with no pick uses its first voice by id); `activeSheet` (`pack-id/sheet-id`; when unset, the sheet of the newest week, else the first installed sheet; the first installed sheet also when the setting names a sheet that is not installed; removing the active sheet's pack leaves the setting as it is and the first installed sheet is used); `defaultsOffered` (JSON list of default pack ids already offered); `seenAward` (the id of the newest award the child has seen, so each award lands once on home); `seenSticker` (written by older versions; nothing reads it now, restore does not check it, and a store or backup that has the row keeps it); `seenWeek` (the id of the last week whose finished-week moment was shown); `seenTrophies` (JSON list of trophy refs the child has seen); `seenDays` (JSON list of marks `weekId/weekday/place` for the lines already spoken, where place is `home` or `day` for a day line, or `done` for the done-for-today card's line; it holds only the current week's marks); `allDoneMoment` (the id of the `habits:done` award that a parent's tick gave for today, waiting for home to play its moment; `takeMoments` removes it) |

Weeks start on Monday, local time. The week row is created when the app is first opened in that week, from the active sheet.

## Rules in code

- A day is done when every non-bonus task in it has an award that is not undone.
- A week is done when every day listed in its sheet is done.
- Counters (`stars`, `stickers`, `daysDone`, `weeksDone`, `wordbooksDone`, `storiesRead`) are computed from the tables, not stored.
- After every award and every finished book, milestones and sticker pages are checked and any newly reached ones are inserted into `trophies`. A trophy row is never deleted, even when the award that reached it is undone.
- `give` takes an optional `replaces` award id, the task's live award. It is undone in the same transaction as the new row, so a task never has two live awards. `undo` takes an optional `restore` id, the award that was replaced; it is made live again in the same transaction and milestones are checked. A restored award that home has already shown does not land again.
- The days a parent can mark are `markableDays(now)` in `progress.dart`: today and the 6 days before it, oldest first, at midnight. They are built with `DateTime(y, m, d - i)`, not a `Duration`, so a clock change does not move them. The progress repository checks a day against this with its own `now` and refuses any other day with "that day cannot be marked": `give` (the day is the week's Monday plus the weekday), `undo` (the day of the award being undone), `tickHabit` and `undoHabit` (their `day`, today when null), and `takeHabitSticker`, which returns `Right(null)`. No screen can write another day. `weekOf(day)` reads the stored week whose Monday holds a day and never creates one (`currentWeek` is the only writer of week rows), so a day of a week the app never opened has no sheet and parent today dims its chip. A day of last week is marked in last week's row with that week's own sheet copy.
- `setSpecialReward(weekId, text)` writes the week's reward text; blank text clears it.
- Week edit changes the week's own copy of the sheet (`weeks.sheet_json`) in one transaction and never touches the pack or `awards`. `addTask` adds a task with id `added-<time>` to a school day that is not done. `editTask` changes a task's text and drops its `say`, `cheer` and `tip`. `removeTask` refuses a day's only task and any removal that leaves a day with only bonus tasks, and the screen offers no Remove on a task that has an award. Blank text is refused. Next week starts from the pack's sheet again.
- `setChild` writes the one child row; blank name stores null and the picture is one of twelve bundled names. `prefs` and `setPrefs` read and write the `sound` and `slowReading` settings; the screens apply them to `Sfx` and the speaker straight away.
- A screen built on an earlier day (parent today, the habit screen) shows the new day on its next load and writes nothing to the old one; the app also reloads both on resume.
- Home (today's weekday), parent today (the day it was built on, the stale check, its 7 day chips and the day it shows; `parentTodayProvider` holds this week, the stored week before it when the 7 days reach it, their live awards and the ticks of each of the 7 days) and the habit screen (the day it landed on) read the time through `clockProvider` (`providers.dart`), a keep-alive provider of a `DateTime Function()`. In the app it is `DateTime.now`; the screenshot tool overrides it with a fixed school day and gives the progress repository the same time. These clocks stay on the real time: the double-tap guard in `tap.dart`, the backup file name in `backup_screen.dart`, and `installed_at` in the voice repository. The progress, backup and pack repositories take an optional `now` that defaults to `DateTime.now`.
- The gate asks one of three kinds of question (`pickGateQuestion` in `lib/domain/gate_question.dart`): a sum `a + b` with a and b from 10 to 99 and a + b at most 99, a difference `a − b` with a and b from 10 to 99 and a − b at least 10, or a product `a × b` with a from 2 to 5, b from 2 to 9 and a × b at least 10. The answer is always two digits. It is never the same question as the last one shown, even across gate screens. A screen reader hears "plus", "minus" or "times". The gate lockout is not stored. `GateLock` is a keep-alive provider that holds the seconds left: the third wrong try in a row sets 60 and a timer counts down. It lasts for the app run and survives leaving and reopening the gate, but a restart clears it.
- The default sticker set is `stickerPages` in `progress.dart`: eight pages, 188 stickers: five of 24 (Animals, Sea and garden, Food, Sky and space, Fun things), Animal friends (20), Out and about (24) and Play and music (24), in the order of `stickers.md`. `defaultStickers` is their stickers in that order. A sticker names one page only.
- A sticker award picks at random among the stickers of the award's list (the default set when the award has none) that are not in the album. When the album holds them all, it picks among the whole list, so repeats come only once the set is complete. `nextSticker` takes the `Random`; the progress repository takes one in its constructor, and tests pass a fixed one. The pick runs inside the `give` transaction over the live album.
- `Sfx.sticker(name)` plays `assets/sticker-sounds/<name>.ogg` for the 32 stickers in `_calls` (`sfx.dart`, listed in `stickers.md`) and `twinkle.ogg` for every other name. It goes through the same single player (the one the page flip uses) and the same sound switch as `Sfx.play`, so nothing plays when sound is off. `StickerView` calls it on every tap, before the reduced-motion check, so it plays with "remove animations" on; the sticker reveal calls it once when it opens. The sticker book makes a grey sticker a plain silhouette with no tap, so it stays silent.
- A sticker page trophy has the ref `sticker-page:<page>` (for example `sticker-page:animals`); a pack ref cannot hold a colon, so it never clashes. `fullPages` returns the pages whose every sticker is in the live album, and the same step that checks milestones after an award inserts them into `trophies`, once. Nothing inserts one on upgrade or on restoring a backup: a page trophy comes only when an award that fills the page is given (or brought back by undo), and the 40 stickers from before the set grew fill no page. Undo takes a sticker out of the album but never the trophy. `shelfOf` puts the eight page trophies after the pack trophies, so home finds them to celebrate like any other.
- The sticker count the screens show is `stickersEarned`: the stickers of the set in the live album, each once. A sticker outside the set (from an imported pack) is not counted and has no trophy.
- `wordbooksDone` and `storiesRead` count distinct `ref` values of their kind in `finished`, so reading the same story ten times counts once.
- A word book or story writes its `finished` row (and checks milestones) when the last card or page shows, once per visit. Leaving the screen reloads the week, so home shows a trophy reached that way over the screen the child returns to (the word books list, the stories list or the day).
- `takeUnseen(weekId)` returns the ids of this week's awards that are not undone, are not `habits:done` rows and are newer than `seenAward`, then sets `seenAward` to the newest award id in the table, all in one transaction. It also leaves out an award given after its own day (its `given_at` date is later than the date of its week and weekday), so a backdated award never lands, drops the big day star or reveals; it is in the week at once. An award given on its own day lands as before. Home reads it once per load, so an award lands once, an undone award never lands, and a restart does not replay anything. The week provider reads the child row before it calls `takeUnseen`, so nothing that can fail runs after awards are marked seen.
- `album()` returns the sticker of every award that is not undone, newest first, repeats included.
- Home shows the stickers in `takeUnseen`'s result with `showStickerReveal` (`widgets/sticker_reveal.dart`), one after another by award id, after the landings and before `takeMoments`. The reveal is a dialog route with one controller over 3100 ms; it calls `Sfx.sticker` once and flies to the Stickers button's picture, found through a `GlobalKey` on the dock button, or shrinks in place when there is none. It is skipped when home is not on top, because `takeUnseen` has already marked those awards seen. A tap or back closes it; if another screen has opened over it, only the reveal's own route is removed.
- Each reveal on home also says one line. `_lineFor` (`home_screen.dart`) finds the award's task on the week's sheet (its day or the every-day tasks) and picks the line: the task's `cheer` (a string of 1 to 40 characters, optional, in the task's `language` else the sheet's), else the next entry of `_iconLines` for the task's `icon` (23 lines over the ten icons, spoken as `en-IN`), else "A sticker for you!". The turn for an icon is held in a top-level map for the app run and starts from the award id, then adds one for each later sticker of that icon, so nothing is stored. A timer starts the line 1.5 s after the reveal opens, which is after the sticker's own sound of at most 1.5 s, through `Speaker.speakSentence` with no check of the Sounds setting. It is cancelled if the reveal closes first, and nothing is spoken once home is gone. After each reveal home waits for the read, 4 s at most, before the next sticker or `takeMoments`. The same lines are in `APP_PHRASES` in `tool/voice/render.py`, so the Heart pack has a clip for each (revision 8); a `cheer` or an icon line in a pack without a clip goes to the phone voice.
- `takeDayMoment(weekId, day, {home})` returns true the first time it is asked for that week, weekday and place (`home` for the big star on home, else the day screen) and writes the mark to `seenDays`, in one transaction. It drops the marks of other weeks, so only the current week is kept. Home asks for each day whose big star drops on this load (`_starDrops`: an award not seen yet finishes the day, so a backdated award, which is never unseen, asks for nothing), before the sticker reveals, and speaks `dayDoneLine` (`days.dart`, "You finished Monday!") with `speakSentence` and no check of the Sounds setting, waiting for it 4 s at most. When another screen is on top (the day screen, the gate, parent today, a restore), home names no day: the line is skipped for that load, and since the star has already dropped (its awards count as seen) it does not come back on home. The day screen asks once when it opens on a finished day and speaks the same line. The star drop plays the fifth star note through `Sfx`. The mark is written before the line is spoken, so a line that is cut off is not repeated and a restart does not replay it. The seven lines are in `APP_PHRASES` in `tool/voice/render.py`. Restore checks `seenDays` as a JSON list of strings.
- `takeDoneCard(weekId, day)` is the same once-only mark for the done-for-today card's line: it writes `weekId/weekday/done` to `seenDays` through the same private `_takeMark` as `takeDayMoment` (one transaction, other weeks' marks dropped) and returns true the first time. No setting, table or restore check was added, and a phone that has no `/done` mark speaks the line once the first time today is done after the update. Home shows the card in `_Week` when `_doneToday` finds today's sheet day and `dayDone` is true for it (every task of the day and every every-day task that is not a bonus has a live award, so a bonus task never hides the card and a day of only bonus tasks is done at once); a play day, a rest day or a day not on the sheet has none, and a past day never does. `_HomeScreenState._afterLoad` runs `_celebrate` for the load, sets `_played` to the load, and then, only while `ModalRoute.isCurrentOf` is true and today is done, calls `takeDoneCard` and speaks "All done for today. Time to play!" (`en-IN`, no check of the Sounds setting). When home is not on top nothing is taken, so the next home load speaks it. `_card` holds the card back (null) only on a load where `_starDrops` is true for today until `_played` is that load; on any other load it shows from the first frame. The card is a `_DoneCard` in an `AnimatedSize` over `Motion.long` (zero with remove animations on), in `dayColour` with `onColour` words, with the `StickerView` (64) of the week's `habitsDoneTask` award for today when there is one. A past-day habit tick gives a `habits:done` row for another weekday, so it never shows. The line is in `APP_PHRASES`, so Heart has a clip (revision 8).
- `takeMoments(weekId)` returns whether the week is done and its moment not shown yet (`seenWeek` is not that week), the newest trophy ref not in `seenTrophies`, and `allDone`: the sticker of the award in the `allDoneMoment` setting, only when that award is not undone and was given today. It then sets `seenWeek`, marks every trophy so far as seen and removes `allDoneMoment`, in one transaction, so an all-done moment not played the day it was given is dropped. Several new trophies make one celebration: only the newest is returned. Home calls it after the landings and the sticker reveals, plays the `allDone` moment first (the spoken line, `showMoment` "All done!" and `showStickerReveal`, as the habit screen does, but flying to the Stickers button), then the week and trophy moments. The week moment has no timer: it plays `Sound.trophy`, shows sparks, and 1 s later speaks "You did the whole week!" and then the typed reward (`hi-IN` when it has Devanagari letters, else `en-IN`; no line when none is typed), and stays until a tap or back. The trophy moment waits for that reading, 10 s at most. It does not call it while the gate or parent today is open, or when a screen is over home: for a load that started with home on top it checks `ModalRoute.isCurrentOf` just before the call, and for a load that started under a closing word book or story it needs the router path to be `/`, `/words` or `/stories`. So it tries again on the next load, and the All done!, week and trophy moments never open over another screen. A screen that opens during the All done! moment skips only its sticker reveal. A moment (`showMoment`, `widgets/moment.dart`) closes on a tap or its timer; if another screen has opened over it, only the moment's own route is removed.
- `tickHabit(weekId, habitId, {day})` inserts the row for `day` (today when null) in `habit_ticks`, once a day: a second tick returns `Right(false)` and changes nothing. It fails for a day outside `markableDays`, a day that is not in that week, or a habit not on the week's sheet. When the habit has ticks on 5 days of that week, Monday to Sunday, it inserts the trophy `pack-id/sheet-id/habit-id` into `trophies`, also when the fifth tick is for a day of last week. The insert is skipped when the trophy is already there: `trophyKey` (`progress.dart`) makes `pack-id/sheet-id/habit-id` and the same habit on another sheet of that pack the same trophy. The trophy room (`shelfOf`) lists a habit once, from the first sheet that has it, and finds its earned time by that key. That row is never removed, even when `undoHabit(habitId, {day})` deletes a tick later. `ticksOn(day)` returns the habits ticked on a date.
- `takeHabitSticker(weekId, {day, byParent})` returns one new book sticker, or null. It gives one when `day` (today when null) is in `markableDays` and in that week, every habit of the week's sheet has a tick on that day and that week and weekday have no `habits:done` award, live or undone. The sticker is the surprise pick (`nextSticker` over the default set and the live album, as for an award with no list). The record is one `awards` row with the day's weekday, task id and award ref `habits:done` and 0 stars, and milestones are checked after it, in the same transaction. When `byParent` is true and `day` is today, the new row's id is also written to the `allDoneMoment` setting. The habit screen and parent today call it only after a tick that saved, so a day finished before the update never fires, and an untick and a new tick that day gives nothing more. Because the row is never deleted, undoing a tick does not take the sticker back. The row is in every backup.
- Habit ticks reach no counter and no milestone. The `habits:done` row does count: it is in the album, in the sticker counter and towards full pages, and it adds no stars. `takeUnseen` leaves it out so the landings and reveals on home never include it. The habit screen shows it instead: after the last tick it waits for the habit's reading to end (at least 700 ms, at most 4 s) with Back off, speaks "All done! A new sticker for you!" (en-IN, even with Sounds off), shows the `showMoment` "All done!" with the party popper for 2.5 s, then `showStickerReveal`, which has no Stickers button to fly to and so shrinks in place. After a parent's tick on today, parent today shows the toast "All habits done for today. A new sticker is in the book." and plays nothing; home plays the same moment once through `takeMoments`. A parent's tick for a past day gives its sticker and no moment.

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

Export writes one JSON file: `{ "starbookBackup": 2, "made": "<ISO time>", "packs": [...], "child": [...], "weeks": [...], "awards": [...], "trophies": [...], "finished": [...], "habit_ticks": [...], "settings": [...] }`. The version is the store version, and each table is a plain list of its rows (the `voices` table is left out, its clips are files). A day's `habits:done` award is one of the `awards` rows, so a restore brings it back and that day's sticker does not come again. The parent saves it with the system save dialog or shares it through the share sheet.

`check` reads a file and writes nothing. It refuses a file that is not JSON or not a backup ("the file is not a Starbook backup"), one with a newer version ("the backup is from a newer Starbook"), and one with a missing table, a row with a wrong column or type, a bad setting value, a weekday that does not exist, a pack that does not parse or whose id differs from its row, or a sheet that does not parse ("the backup is damaged"). A good file returns what it holds: the date, the child's name, the live stars and the pack count, shown in the "Restore this backup?" sheet.

`restore` runs the same checks, then deletes and refills every table in one transaction, so a failure part way changes nothing. It then reloads the packs and the voices; a pack added since the backup is gone, and an active voice that is not installed falls back to the first voice of its language. The screen applies the restored sound and reading speed settings at once.

## Android

- minSdk 24. Read-along highlighting needs 26; on 24 and 25 the first sentence reads unlit and the word-by-word fallback runs after it.
- No permissions. The release manifest has no internet permission.
- App icon: the hibiscus sticker, an adaptive icon (paper background colour and a foreground mipmap) and legacy mipmaps for Android 7. See [`design.md`](design.md).
- Reduced motion: when the phone asks for it (`MediaQuery.disableAnimationsOf`), screen changes are instant, landings fade in where they sit, the sticker reveal is a plain fade of the still sticker, and sticker animations and the trophy rise and sparks are skipped. Sounds keep their timing.
- `MainActivity` is `singleTask` and takes shared or opened files, see "Packs at runtime".
- `<queries>` entry for the text-to-speech service so flutter_tts can find the engine on Android 11 and later.
- Portrait and landscape both work; tablets get the same layout with more space.

## Tests

Few, and each one pins a rule, a boundary, a bug that once happened or a flow across layers. `flutter test` runs everything under `test/`. Grouped by file, with what each pins.

`test/assets_test.dart`
- every picture listed in `pictures.md` is bundled as an svg.
- every sticker in `stickers.md` has its files and sits on exactly one page, and the pages in `stickerPages` are the sticker list in order.
- every default pack names only library pictures, listed stickers (a habit `sticker` included) and bundled icons.
- every task that opens something in the default packs opens a word book or story in them.
- every asset folder the app ships (listed in `pubspec.yaml`, `packs/` included) has a `CREDITS.md`.

`test/domain_is_pure_dart_test.dart`
- `lib/domain` imports nothing from Flutter.

`test/domain/progress_test.dart`
- a day needs every non-bonus task (every-day tasks included), a week needs every day, an undone award does not count.
- a sticker award picks only stickers not yet earned until the list is complete, then any.
- the 40 stickers from before the set grew are all still in it and fill no page.
- a child who had all 120 stickers from before the set grew gets only new ones, from every new page, and the five old pages stay full.

`test/data/pack/pack_test.dart`
- the validator rejects, one test per rule: a pack without an id, a weekday that does not exist, an id used twice (awards, and a task id within a sheet), an award of an unknown kind, a `retired` that is not true or false, a revision that is not a whole number (but 2.0 counts as 2), and a habit list with a missing id or text, a repeated id, a bad picture or a `sticker` that is not in the sticker set, and a word card `count` that is not a whole number from 1 to 10 or has no picture (a count of 10 loads).
- `parsePack` gives a failure and never throws for text that is not a pack, and accepts a BOM.
- every default pack loads from the bundle and passes.
- a story page ask must be text of one line, 45 characters at most after trimming; every default story page has an ask, and each story has one ask that points to a word on its page.

`test/data/store_test.dart`
- revisions: a higher one replaces, the same or a lower one asks, a started week keeps its copy of the sheet.
- a switched sheet starts next week and the week in progress keeps its own; when the active sheet's pack is removed, the first installed sheet is used.
- a new week starts from the sheet the parent picked; with none picked, from the sheet of the newest week; with no week yet, from the first installed sheet. A fresh install starts the sample pack's Little learner week, and a phone with weeks keeps its sheet after the sample pack update.
- default packs: one installs once, a removed one stays removed, a higher bundled revision replaces.
- milestones are inserted once and never removed after undo.
- a page trophy comes with the award that fills the page, once, and stays after undo; stickers stored before count (Animal friends, for a child who had the whole old set).
- a week starts on Monday local time, and a week never opened has no record.
- an unseen award is taken once, also on a new repository on the same store, and an undone award is never unseen.
- a replacing award undoes the old one in the same write, and undo brings the old one back, already seen.
- a finished week and the newest new trophy are each taken once, also after undo and redo and on a new repository.
- the album lists live stickers newest first; a replaced sticker leaves it and a restored one returns.
- a habit is ticked once a day, undo removes the tick and it can be ticked again.
- the all-habits sticker comes once a day: only when every habit is ticked, not again after an untick and re-tick or from a new repository, kept after an untick, never unseen on home, and again the next day.
- five days of one week earn the habit trophy once, undo keeps it, and ticks reach no counter or milestone.
- the same habit id on two sheets of one pack gives one trophy and one shelf entry.
- the 7 day window by the store's clock: a tick, an untick and a give work from the 6th day back to today, and the day before that and tomorrow are refused, as is undoing an award of a day outside it.
- a tick on a day of last week counts in that week's habit trophy, Monday to Sunday.
- a past-day award is not unseen on home, counts toward the stars and stickers like one given that day, and pays once after an undo and a new give; one given on its own day is unseen as before.
- a day moment is taken once for each week, day and place, and stays taken after a restart.
- a past day's all-habits sticker comes once for that day, is kept after an untick, and gives home no moment.
- a parent tick that finishes today's habits gives home its All done! moment once, not again after a restart; a child's own all-done gives none, and one left from an earlier day does not play.
- a week edit changes this week only: a removed task's award stays in this week, a day keeps one task that is not a bonus, a done day takes no new task, and next week starts from the sheet as imported.
- a backup restores every table into another store, with habit ticks, the active voice and settings, and a day's all-habits sticker, which does not come again, and replaces what that store had.
- a refused restore changes nothing: not a backup, a newer backup, a backup that fails part way, a missing table, wrong column types, a bad weekday, and a bad `seenAward`, `allDoneMoment`, `seenTrophies`, `seenDays` or `defaultsOffered` setting; a `seenSticker` row is not checked and restores.
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
- an ask shows as one line under the picture, is never read, and leaves the sentence at the same size and place.

`test/presentation/week_and_day_test.dart`
- home shows the week and the rest message today, with no reward box when none is typed; a finished day opens with one open bar and the banner.
- new awards land once on home with a rising star note and their sounds; the big star drops with the top note, the day is named before the new sticker opens big with its sound, and the day screen names it the first time only; seen awards and the day screen play nothing else.
- today's card: with today's jobs done (a bonus job left open) home shows the done-for-today card with the sticker today's habits gave and speaks its line once; a reload of home shows it again and says nothing.
- a day and a week finished by a backdated tick: home names no day, the week moment chimes, shows sparks, says the week line and then the reward, and stays until a tap; the day screen names the day once.
- a tap anywhere ends the sticker reveal at once and home works again.
- with remove animations on, a new sticker fades in and out in the middle without moving, and a book page plays nothing.
- each new sticker on home says one line 1.5 s after it opens: the task's `cheer`, else a line for its icon (two stickers of one icon differ), else "A sticker for you!", and the next sticker waits for the line.
- an award that lands while the day screen is open plays no sound.
- a full page trophy celebrates over home with the page picture and name.
- the sticker book opens on the newest sticker's page, counts each sticker once and shows a More stickers page for a sticker outside the set.
- tapping an earned sticker plays its call (lion) or the twinkle (heart), and tapping a grey one plays nothing.
- a book page plays each earned sticker once when it opens, later ones after earlier ones, and grey shapes have no animation.
- a moment that comes due while the gate is open shows after the gate.
- a moment never closes the gate a file opens over it: the All done! moment is open, the gate opens over it, and the gate stays open.
- tapping a task reads its `say` with the row lit until the read ends, gives no award, and leaving the day stops the read.

`test/presentation/parent_test.dart`
- the gate: opens parent today only for the right answer to the question, shows a new question after a wrong try, and three wrong tries lock it for 60 seconds, a wait that outlasts closing and reopening the gate.
- the toast after an award has a second line that names the child, or says "your child" until a name is set.
- an award can be replaced and undone in parent today, and after Done the home lands only the live one, once, with the typed reward.
- a give the store refuses shows the calm line and never the store's text.
- an award given under the old default pack ("Well done!", Star or "Very good!", now retired) still shows with its own label after the new pack installs, and parent today does not offer it.
- a trophy and a finished week reached in parent today show on home after the landings, the day line, then week first, once each, and not again after the award is replaced; today's card waits for them and says its line once.
- a ticked habit presses in its own sticker or its own picture with the peel and press sounds and no star note, the last habit of the day plays All done! and reveals one new book sticker, and a parent Undo and a re-tick give nothing more and take nothing back.
- Back does nothing in the wait after the last tick, and the All done! moment still opens.
- a parent Tick on the last habit of today shows the all-done toast and plays nothing in parent today; home then plays All done! and reveals the new sticker once.
- the word book flow: a book read to its last card writes one `finished` row per visit, `wordbooksDone` counts distinct books, and the trophy shows once over the word books list.
- the story flow: the same for a story, with `storiesRead`, the trophy over the stories list, and the credit on the last page.
- the open-with flow: a file opened with Starbook waits for the gate, leaving the gate drops it, and after the gate the preview shows before anything is added.
- the packs screen: a bad file changes nothing, the same revision asks before it replaces, and remove asks first while the pack with the only awards cannot be removed.
- home with its five dock buttons shows no overflow on 320, 360 and 430 wide phones, the Stickers button opens the sticker book and back returns home.
- every screen fits a 360 x 640 phone and an 800 x 1280 tablet with no overflow, and every control has a screen-reader label.
- a count card with 10 pictures fits a 360 x 640 phone at the largest font size with no overflow, and a word card that fits keeps its full size (the picture stays 230).
- the parent changes a task for this week and names the child; today and home show both, and a task with a star has no Remove.

Not tested yet: the midnight guards in parent today and the habit screen (no test under `test/` overrides `clockProvider` yet). The README screenshots and the Play store images are made by `tool/screenshots/screens_test.dart`, which is not part of `flutter test`; see the README.

## Gates

```
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```
