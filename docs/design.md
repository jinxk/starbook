# Design

## Idea: a sticker book on the table

The app should feel like a real sticker book: warm paper pages, die-cut stickers with a white border and a soft shadow, a shelf where trophies stand. It is calm most of the time. The fun happens when a reward lands: a star drops, a sticker peels and presses down, a trophy arrives on the shelf.

Restraint does most of the work. One thing to do per screen, lots of space, very large type, few colours, and motion only where it means something.

What it is not: no gradients, no glass blur, no grid of white cards with emoji on them, no purple, no mascot that talks all the time, no confetti on every tap.

## Colour

Paper and ink, plus six sticker colours. Colour only means something on stickers, day rows and word book covers. Backgrounds are never gradients.

| Token | Hex | Use |
|---|---|---|
| paper | `#FBF6EA` | page background |
| paper-deep | `#F1E8D3` | shelf, empty slots, pressed state |
| ink | `#2B2A33` | all text on paper |
| ink-soft | `#67646E` | secondary text (parent area, the word card hint, the story credit) |
| tomato | `#E8553D` | sticker colour, vowel a |
| sunflower | `#F5B82E` | stars, vowel e |
| leaf | `#2E7D4F` | sticker colour, vowel i, "done" |
| sky | `#3C8DD6` | sticker colour, vowel o |
| plum | `#8A4FA3` | sticker colour, vowel u |
| sand | `#C9774B` | sticker colour, wood of the shelf |

Text on paper is always `ink`. White text sits only on tomato, leaf, sky and plum, at 24sp bold or larger; on sunflower and sand the text and icons are ink. Sunflower is too pale as text on a white card, so a letter coloured in sunflower uses the darker `#9A6A00`. Every pair is checked with a contrast tool before release (target 4.5:1 for text, 3:1 for large text and shapes). The day tile's job count sits on a small white pill in ink, because white or ink text straight on tomato or sky is under 4.5:1.

## Type

| Role | Font | Size |
|---|---|---|
| Child headings, day names, buttons | Baloo 2, SemiBold (600) or Bold (700) | 28 to 40sp |
| Story sentences | Andika, Regular | 40sp, and never below 32sp |
| Word card word | Andika, Bold | 72sp, shrinks to fit a long word |
| Big letter on a word book cover | Andika, Bold | 92sp (Hindi 80sp), shrinks to fit |
| Hindi (Devanagari) anywhere | Baloo 2 | same sizes as above |
| Parent area | Hind | Material type scale |

Andika is made by SIL for beginning readers and draws "a" and "g" the way children learn to write them. Check the single-storey a and g on the type sample before bundling. All three fonts are SIL Open Font License and are bundled in the app (no font downloads at runtime).

Story text: one sentence per page, left aligned, line height 1.4, words spaced a little wider than normal so each one is easy to tap. A sentence that needs more than 3 lines at 40sp steps down by 2sp until it fits in 3 lines, and never goes below 32sp; below that the pack author has to split the sentence.

## Pictures

Pictures come from Microsoft Fluent Emoji (MIT). The library and its names are in [`pictures.md`](pictures.md). 58 things children here know well have no fair emoji (chikoo, guava, okra, marigold, yak, bullock cart and more); those are drawn for this project in the same Flat style and bundled at `assets/pictures/<name>.svg` like the rest.

Two styles exist in that set: Flat (vector, crisp at any size, small) and 3D (soft rendered images). The mockup shows both. The choice is recorded here once made:

- Style: Flat (SVG through flutter_svg). Drawn pictures follow the Fluent Flat look: flat fills, no outlines, soft single-tone shading shapes.

## Stickers

Stickers are the collectible reward, so they look richer than the word book pictures. Each sticker is a Google Noto animated emoji (Lottie, CC BY 4.0) that plays once when the sticker arrives and again every time the child taps it in the album. Stickers with no animated version (elephant, for one) use the Fluent Emoji 3D image (MIT) with a short wobble on tap. The default set is 120 stickers on five album pages of 24: Animals, Sea and garden, Food, Sky and space, Fun things (listed in [`stickers.md`](stickers.md)). The credits screen in the parent area names both sources.

## Icons

Controls (back, play, lock, arrows, settings, import, share, undo) use Phosphor Icons, Fill weight (MIT), bundled as SVG. Pack task icons (pencil, book, story, numbers, letters, shapes, music, draw, talk, habit) are Phosphor Fill too. Each icon is one file, `assets/icons/<name>.svg`, and a pack's `"icon"` value is that name. The slow-reading button uses the Fluent Flat turtle picture, since Phosphor has no turtle. Icons sit on round paper-deep buttons at least 72dp wide on child screens, except the word card arrows and the sticker book arrows (book or page colour, 80dp), Read to me (ink) and Slow reading (leaf while on).

## App icon

The Fluent Flat hibiscus (`assets/pictures/hibiscus.svg`, pink with a yellow centre) as a sticker: the white outline, soft shadow and slight tilt of the sticker treatment, on paper `#FBF6EA`. The Android adaptive icon has a paper background and the sticker inside the safe zone. The legacy icon for Android 7 is the sticker on a paper circle.

## Sticker treatment

Every picture shown as a sticker gets the sticker treatment: a 6dp white outline that follows the shape, a soft shadow, and a slight random tilt (between -4 and 4 degrees, fixed per sticker so it does not jump around).

## Sizes

- Anything the child taps: at least 72dp, with at least 16dp between targets. Day rows on home are 16dp apart; tasks on a day are 24dp apart, with 16dp between a task and its open bar.
- Feedback starts on finger down, not on release, within 100ms. Stickers in the album are the exception: they play when the finger lifts, so scrolling never starts one.
- Tap works everywhere. Swipe is a shortcut, never the only way (page turns also have big arrow buttons).
- No long press, no double tap, no hidden gestures on child screens.
- State-changing taps ignore repeats within 300ms.
- Every screen fits a small phone (360 by 640 dp) and a tablet (800 by 1280 dp) with no overflow, and every control has a name a screen reader can say.

## Screens

### Child

1. **This week.** The child's name and picture at the top, with the week's dates under the name. Until a name is set, the title is the sheet title and there is no picture. Below, a star chart on a slightly tilted card: one row per school day, on plain paper with no grain. Each row has a tilted tile in the day colour (short day name, and under it the job count, "3 jobs", in ink on a small white pill), a small circle for each task that is not a bonus (dashed until it has an award, then the star, stamp or sticker), and on the right a big star once the day is done (a dashed star before). An award given on a bonus task shows as one more mark after the circles and lands like the others; a bonus task has no empty circle. Today's row has a small TODAY tag. Tapping a row opens the day. Rest days have no row. Under the chart, a reward box with the special reward the parent typed, else the week goal. Under the box, when the sheet has rest days, one quiet line about them. Bottom: a dock of four round buttons, Trophies, Words, Stories, Habits, each 72dp, with no fade behind it. The parent lock sits in the top corner as a 72dp target with a small icon.
2. **A day.** A back button, the weekday name in the day colour, and the day title ("Alphabet adventure") under it. Its tasks as large rows: icon, text, and the award once given (a dashed circle until then). A bonus task is marked BONUS. Tapping a row reads it aloud and lights the row until the read ends. A task that opens a word book or story has a full-width bar under its row, "Practise" for a word book and "Pick a story" for a story. When every task is done, a box in the day colour with a big star and "You finished Monday!" ends the list.
3. **Trophy room.** A back button and the title "My trophies". A wooden shelf, three trophies to a plank, with every trophy the installed packs offer: the ones earned in full colour, the rest pale, no numbers, no progress bars. A pack's milestones come first, then the habit trophies of its sheets. Until the first trophy is earned, "Your trophies will stand here." sits under the shelf. Tapping an earned trophy reads its name aloud and shows it big with its name and "Earned on Tuesday, 14 October". Five page trophies stand after the pack trophies and work like the others: "Full animal page", "Full sea and garden page", "Full food page", "Full sky and space page" and "Full fun things page", each with its page's picture (lion, butterfly, mango, rocket, balloon). Below the shelf, one white "My stickers" card: the title in Baloo 2 Bold 22, under it the total such as "12 of 120" in Baloo 2 SemiBold 18 ink-soft, the four newest stickers (62, each shown once) and a round 72dp paper-deep button with the next arrow. A child with fewer than four stickers sees empty room, no dashed places. The whole card is one tap target that opens the sticker book; a screen reader hears "My stickers, 12 of 120" as a button.
   **Sticker book.** A back button, the title "My stickers" in Baloo 2 Bold 30 and under it the total "12 of 120" in Baloo 2 SemiBold 17 (ink at 75%). The total counts each sticker of the set once. Then one page at a time on a white card with rounded corners and the album shadow: the page name top left in Baloo 2 Bold 26, and on the right a paper-deep pill with the page count, "7 of 24", in Baloo 2 Bold 18 ink. On a full page the page trophy's picture (40) sits left of the pill. Under them a grid four across of the page's 24 stickers in the fixed order of `stickers.md`. An earned sticker is drawn as a sticker (62) and plays when the finger lifts; a screen reader hears its name. A sticker not earned yet is a flat silhouette of its own shape in `#D8CCB0`, with no outline or shadow and the same tilt; tapping it does nothing and a screen reader hears "Not yet". A sticker given twice shows once. The book opens on the page of the newest sticker, else the first page. A sticker that is not in the set (a library picture or an emoji from an imported pack) goes on a last page, "More stickers", shown only when there is one, with no count and no trophy; the book opens there when the newest sticker is one of these. Under the card: a round Back arrow and a round Next arrow, 80dp, labelled "Back" and "Next" for a screen reader and 25% at the ends, with a dot (9dp) for each page between them, the current one ink and the rest `#D8CCB0`. The arrows take the page colour: Animals leaf, Sea and garden sky, Food tomato, Sky and space plum, Fun things sand with an ink arrow, and the More stickers page leaf. Swipe is a shortcut. Pages slide over 250ms with the paper flip, or change at once with "remove animations" on. The grid scrolls on a small phone and the arrows stay at the bottom. The first time the child sees the newest sticker in the book it plays once (not with "remove animations" on); turning a page ends that.
4. **Word books.** A back button and the title "Word books", then covers two across, each a big coloured book with a darker spine strip on the left. The colour is the book's own, sky when the pack names none. The big letter sits at the top left, and the book's title at the bottom in Baloo 2 Bold 19sp. A book with a picture shows it as a sticker at the bottom right, smaller (64) beside a letter and larger (96) alone. A book with no letter and no card with a picture (the days, months and numbers) shows its first card's big text where the letter goes. Text on a cover is white, and ink on sunflower and sand. Tapping a cover opens the book.
   **Word card.** A back button and the book's title, then one card at a time on a white card with rounded corners that fills the page. The picture is large (230), else the card's big text in ink at 140, so a card with both shows only the picture. Under it the word at 72sp in ink, with the book's letter coloured in the book colour (not in Hindi books). A card with a `group` has the group as a small tag at the top right. Under the word, a small "Tap to hear" in ink-soft; on the last card, "All done!" takes its place and the book counts as finished. Tapping anywhere on the card reads the word. A card is read 250ms after it first shows. After a turn, the paper flip plays and the read waits 450ms so the flip ends first. Cards slide over 250ms. Below the card: a round back arrow and a round next arrow, 80dp, in the book colour, each labelled "Back" and "Next" for a screen reader, with a dot row between them (the current card dark). The arrows fade to 25% at the ends. Leaving the screen stops the read.
5. **Stories.** A back button and the title "Stories", then one tile for each story, level 1 first, then 2 and 3, in pack order inside a level. A tile has an 84dp tinted box with the story's cover picture (else the first page picture, else nothing) at 66, the title in Baloo 2 Bold 22sp and three level dots. The tint is pink, green or blue by the story's place in its pack. Tapping a tile opens the story.
   **Story reader.** A back button, the title and "1 of 8". The page is a tinted box in the story's tint with the page's one picture (210, shrinks to fit; no picture leaves the box empty), and the sentence below it, left aligned, at 40sp or the step down that fits (see Type). Each word lights in sunflower while it is spoken. Tapping a word reads it. Below, four round buttons spread evenly across the row: Back page, Read to me (larger, ink, white play triangle, a white square while reading), Slow reading (the turtle, leaf green when on) and Next page. Back page and Next page fade to 25% at the ends. Read to me reads the sentence and lights each word in turn; tapping it again, tapping a word or turning the page stops the read. Pages slide over 250ms. Nothing is read when a page shows, and pages never turn by themselves. The last page ends with "The end." under the sentence, and under it, for a story with a credit, the credit text and then "source, licence" (for example "StoryWeaver, CC-BY-4.0") in ink-soft. No link is shown. Reaching the last page counts the story as finished.
   A trophy reached by finishing a word book or a story is shown when the child leaves it, over the screen they return to (the word books list, the stories list or the day).
5a. **My good habits.** A back button and the title "My good habits". One row for each habit on the sheet: the habit's picture, its text, and on the right a dashed circle until it is ticked today, then a star. Tapping a row reads the habit aloud and ticks it, and the star drops in with the star note. A second tap reads it again and ticks nothing; only the parent can undo a tick. Habits give no homework stars, and any day of the week counts.

### Parent

6. **Gate.** A back button, "Grown-ups only", the hint "Type the answer" and a times sum, for example "6 × 7" (each number from 4 to 9, so the answer is always two digits). The same sum is never shown twice in a row. Under it two boxes that fill as the parent types, and a keypad with the digits 0 to 9 and a delete key that removes the last digit. The second digit checks the answer. A wrong try clears the digits and shows a new sum, with no shake. Three wrong tries in a row lock the keypad for 60 seconds, and the sum and the hint give way to "Please wait a minute" with the seconds left. The wait is kept for the app run: leaving the gate and coming back does not end it. A right answer resets the count of wrong tries. A screen reader hears the sum as "6 times 7" and the delete key as "Delete". Nothing is read aloud here.
7. **Parent home.** Opens on today: a header "Today, Tuesday" with a Done button that goes back to home. Under it today's tasks and the every-day tasks, then the bonus tasks, each as a card with the task text and one chip for each award the installed packs offer (Star, Very good!, Sticker), all the same width, the label shrinking to fit. A retired award (see [`pack-format.md`](pack-format.md)) has no chip. The chip of the award given is filled dark. Tapping another chip replaces the award. Tapping the filled one does nothing. After each award a toast at the bottom, "Star given for (task)" with Undo, stays about 4 seconds; Undo takes the award away, or puts back the one it replaced. Then, when the sheet has habits, a Good habits list: one card for each habit with its picture and text, a dashed circle until it is ticked today, then a star and an Undo button that removes today's tick. Then a field for this week's reward (blank clears it). Last, a More list: Packs, Whole week, Child, Backup, Settings and Credits, each with a short note on the right, and each opens its screen. The parent area uses the same paper colour but plain type and smaller controls, so it looks like a different place. A parent area screen left open past midnight shows the new day when it next shows, and never writes to the old day. A failed write shows the toast line "That did not save. Please try again."
8. **Whole week.** A back button and the title "Whole week", the line "Changes here are for this week only. Next week starts from the sheet again.", then a heading for each school day ("MONDAY · ALPHABET ADVENTURE") with one white row for each task. A task with an award this week has a "done" tag, a bonus task a "bonus" tag. Tapping a row opens the bottom sheet "Change this task" with a text field (80 letters at most) and Save / Cancel. A ghost "Add a task" button under each day that is not done opens "New task for Monday" (hint "Practise letter B") with Add / Cancel. A small ghost "Remove" button on a row opens "Remove this task?", the task text, "Only this week. Stars already given stay." and Remove / Cancel. There is no Remove on a task that has an award, on a day's only task, or on a task that is a day's last one that is not a bonus. Blank text saves nothing. Under the days, a heading EVERY DAY with the every-day tasks (change and remove, no Add). The weekly reward stays on Today.
9. **Packs.** A back button and the title "Packs". One card for each installed pack: the title, then "author · revision · licence" as stored (for example "Ms Rao · revision 2 · CC0-1.0", a part left out when the pack has none), then small tags: the number of sheets, "active" on the pack that holds the active sheet, and what it holds (awards, milestones, stickers, word books, stories). The award count leaves out retired awards. A pack added during this visit has a leaf border until the parent leaves. A small ghost "Remove" button sits on the right of each card; it opens a bottom sheet "Remove this pack?" with the card, "Stars already given stay." and Remove / Cancel, and no toast follows. The pack that holds the only awards has no Remove and shows "Needed for the awards." under its tags; the pack that holds the only sheets has none and shows "Needed for the week."
   Under the cards, one "Import a pack" button for content packs and voice packs, and a line about opening a .json file with Starbook from another app. There is no Pack format button: the app has no internet permission and there is nothing in it to open.
   A picked or opened file first shows a bottom sheet with a preview card and Add / Cancel: "Add this pack?" (title, "file name · revision 2 · from author", a tag for each sheet with its days and tasks, and what the pack holds) or "Add this voice?" (title, "file name · revision 1 · en"). When the same pack or voice is installed at the same or a higher revision, the sheet is "Replace this pack?" or "Replace this voice?", with the line "This pack is already added at revision 3." and Replace / Cancel. After an add or replace a toast says "Added: (title)". A file that fails shows the sheet "This file could not be added." with one plain line and an OK button; nothing is written.
   Then the heading ACTIVE SHEET, the line "This week keeps its sheet. A new sheet starts next week.", and one card for each sheet with its title, the pack title under it and an "active" tag on the active one. A tap makes it active at once. Then the heading VOICES and one card for each voice pack with its title, "en · revision 1" under it and an "active" tag on the active voice of each language. A tap makes that voice active for its language. A section with nothing to show is left out. When a file was opened from another app, the app shows the gate first and then this screen with the preview already up; back goes to parent today. Leaving the gate drops the file.
10. **Child.** A back button and the title "Child". A NAME field (hint "Name", 20 letters at most) that saves as you type, and a PICTURE grid four across: twelve bundled pictures (cat, dog, rabbit, bear, lion, tiger, elephant, monkey, fox, owl, unicorn, butterfly) and a "No picture" tile. The chosen one has an ink border. Under it, "The picture shows on home once a name is set."
11. **Backup.** A back button and the title "Backup", the line "One file with the stars, stickers, trophies, habits, this week's tasks, the child, packs and settings.", then "Save a backup" (ink) and "Share a backup" (ghost). Saving shows the toast "Backup saved." Under the heading RESTORE, the line "Voice packs you added are not in the file. Add them again on Packs." and "Restore a backup" (ghost). A picked file opens the sheet "Restore this backup?" with a row "Made on 5 January 2026" and under it "Asha · 42 stars · 6 packs" (the name is left out when there is none), the line "It replaces what is on this phone now." and Restore / Cancel; a restore ends with the toast "Backup restored." A file that cannot be restored shows "This backup could not be restored." with one line (the file is not a Starbook backup, the backup is from a newer Starbook, the backup is damaged, the file is larger than 50 MB, the file could not be read) and OK. Nothing changes. A restore brings back the packs that were in the file and removes packs added since; a voice pack that is missing falls back to the first voice of its language.
12. **Settings.** A back button and the title "Settings". Under SOUND AND READING two switches, on in leaf green: "Sounds" ("Star, sticker and trophy sounds.") and "Slow reading" ("Stories, word cards and tasks read slower."). With Slow reading on, the story turtle starts on, and the child can still switch it for one story. Under PHONE VOICE, the line "Used for words that have no recorded clip." and a row each for English and Hindi with "Ready, works offline", "Needs internet" or "Not installed" and a ghost "Hear it"; a ghost "Phone voice settings" opens Android's text-to-speech settings. Under RECORDED VOICES, one row "Voices" with the active titles ("Heart, Divya ›", or "none ›") that opens Packs, where the voice is picked.
13. **Credits.** A plain list: the three fonts, Fluent Emoji, Noto Animated Emoji, Phosphor Icons, Kenney, Indic Parler-TTS and Kokoro-82M, each with its licence, then one row for each installed story that has a credit (title, the credit text, then "source, licence").

If the phone's store cannot be opened, the app shows one plain screen on paper: "Starbook could not open just now." (Baloo 2 Bold 28sp, ink) and "Please close it and open it again." (Hind 16, ink-soft), with no buttons.

## Motion

- Default: 150 to 250ms ease-out for page and screen changes. Nothing loops on its own.
- Star landing: the star drops into its circle on the day row with a small bounce (spring), the circle glows once. An award lands the first time home shows it. When several are new, the first lands at once and the rest follow 800ms apart. No sound or haptic plays while the day screen is open on top.
- Sticker: lifts off, wobbles, presses down with a short squash, then settles at its tilt. A new sticker lands on the day row and the day screen this way; there is no full-screen moment for it. The award that fills a sticker page earns that page's trophy, which celebrates like any trophy over home after the sticker has landed.
- Trophy: a full-screen celebration over the page with the trophy picture rising in, "A new trophy!" and the trophy name, and a few paper sparkles for under a second. "A new trophy!" is spoken, then the trophy name. The celebration is the arrival; the shelf does not animate. When several trophies are new at once, only the newest celebrates. A tap closes it.
- Day complete: the big star drops into the day row after the last award has landed.
- Week complete: a full-screen moment with a gift picture, "You did the whole week!" and the special reward text, else the sheet's week goal, else nothing under the title. No sound. It closes after 2.5 seconds or on a tap, and shows once per week. It waits until the last landing and the big star have finished; if a trophy comes at the same time, the week moment goes first.
- With the system "remove animations" setting on, screens change at once. Stars, stickers and the big day star fade in where they sit, a trophy or week moment fades in with no rising and no sparkles, stickers do not play or wobble, and the sounds keep their timing. Nothing is lost.

## Sound and touch

- Star: a single soft plucked note, rising one step for each star of the day, up to the fifth star; later stars repeat the top note.
- Sticker: a paper peel and a soft press.
- Trophy: a short four-note chime.
- Page turn: a paper flip.
- Words and sentences: the Heart voice pack (warm female voice, recorded clips, see [`voice-packs.md`](voice-packs.md)) for everything in the default packs; the phone's text-to-speech for anything without a clip, at a slower rate for children. A voice check in settings tells the parent when the phone voice is missing or needs internet.
- No background music. No sound on ordinary taps. One sound at a time.
- Haptics: a light tick when a sticker presses down, a stronger one when a trophy arrives, nothing else.

Sound effects come from CC0 packs (Kenney) and are listed in `assets/sounds/CREDITS.md`.

## Words on screen

Praise is about what the child did, never about the child being clever. Nothing compares, scolds or counts down.

| Where | Text |
|---|---|
| Home, title | (name)'s week, or the sheet title until a name is set |
| Home, dates under the title | 13 to 17 October, 29 September to 3 October, or 13 October for a one-day week |
| Home, star chart label | MY STAR CHART |
| Home, today's row | TODAY |
| Home, day tile | 1 job, 3 jobs |
| Home, week goal (default) | Finish all your days for a big reward! |
| Home, special reward label | This week's reward |
| Home, rest line on other days | Saturday and Sunday: play days! |
| Home, dock | Trophies, Words, Stories, Habits |
| Home, lock (screen reader) | Grown-ups |
| Day, back button (screen reader) | Back |
| Home, the big day star (screen reader) | Day done |
| An award mark (screen reader) | the award's label, Star for a star; a sticker in the album reads its name |
| Day, bonus task | BONUS |
| Day, open bar | Practise, Pick a story |
| Day, all done | You finished Monday! |
| Star landing (spoken) | A star for you! |
| Week complete | You did the whole week! |
| Trophy arrives | A new trophy! |
| Word books, title | Word books |
| Word card, hint | Tap to hear |
| Word book end | All done! |
| Word card, arrows (screen reader) | Back, Next |
| Stories, title | Stories |
| Story reader, page count under the title | 1 of 8 |
| Story reader, buttons (screen reader) | Back page, Read to me, Slow reading, Next page |
| Story end | The end. |
| Story end, credit | the credit text, then the source and licence, for example StoryWeaver, CC-BY-4.0 |
| Home, rest line when today is a rest day | No homework today. Play, draw, dance! (the sheet's rest message replaces it) |
| Empty trophy shelf | Your trophies will stand here. |
| Trophy room, title | My trophies |
| Trophy room, sticker card | My stickers, then the total, for example 12 of 120 (a screen reader hears My stickers, 12 of 120) |
| Trophy room, page trophies | Full animal page, Full sea and garden page, Full food page, Full sky and space page, Full fun things page |
| Sticker book, title and total | My stickers, 12 of 120 |
| Sticker book, page names | Animals, Sea and garden, Food, Sky and space, Fun things, More stickers |
| Sticker book, page count | 7 of 24 (none on More stickers) |
| Sticker book, a sticker not earned yet (screen reader) | Not yet |
| Sticker book, arrows (screen reader) | Back, Next |
| Trophy room, big view of an earned trophy | (trophy name)!, then Earned on (weekday), (day) (month), for example Earned on Tuesday, 14 October |
| Trophy room, a trophy not earned yet (screen reader) | Not yet |
| Habit screen, title | My good habits |
| Gate title | Grown-ups only |
| Gate hint | Type the answer |
| Gate question | 6 × 7 (a screen reader hears 6 times 7) |
| Gate, delete key (screen reader) | Delete |
| Gate locked | Please wait a minute (seconds left, for example 42) |
| Parent today, title | Today, Tuesday |
| Parent today, button | Done |
| Parent today, headings | the day title, Every day (bonus), This week's reward, More (shown in capitals) |
| Parent today, habit list heading | Good habits (shown in capitals), with Undo on a ticked habit |
| Parent today, award chips | ★ Star, Very good!, ◐ Sticker (a star award has ★ in front, a sticker award ◐, a stamp nothing) |
| Parent today, toast after an award | Star given for "(task text)", with Undo |
| Parent today, reward field hint | Ice cream on Sunday |
| Parent today, More rows | Packs (6 installed ›), Whole week (edit tasks ›), Child ((name) ›, or just ›), Backup (export, import ›), Settings (sound, reading speed, voices ›), Credits (fonts, pictures, sounds ›) |
| Parent, a failed save | That did not save. Please try again. |
| Child, a failed save (habit, finished book or story) | Please try that again. |
| Start-up, store will not open | Starbook could not open just now., then Please close it and open it again. |
| Whole week, title and line | Whole week, Changes here are for this week only. Next week starts from the sheet again. |
| Whole week, buttons and sheets | Add a task, Remove, Change this task (Save, Cancel), New task for Monday (Add, Cancel), Remove this task? with Only this week. Stars already given stay. |
| Whole week, tags | done, bonus |
| Child, title and fields | Child, NAME (hint Name), PICTURE (tile No picture), The picture shows on home once a name is set. |
| Backup, title and buttons | Backup, Save a backup, Share a backup, Restore a backup, Backup saved., Backup restored. |
| Backup, restore sheet | Restore this backup?, Made on 5 January 2026, Asha · 42 stars · 6 packs, It replaces what is on this phone now., Restore and Cancel |
| Backup, error | This backup could not be restored. with one line, and OK |
| Settings, title and rows | Settings, SOUND AND READING (Sounds, Slow reading), PHONE VOICE (English, Hindi, Hear it, Phone voice settings), RECORDED VOICES (Voices) |
| Settings, phone voice state | Ready, works offline, Needs internet, Not installed |
| Packs, title | Packs |
| Packs, card line | (author) · revision (number) · (licence), for example Ms Rao · revision 2 · CC0-1.0 |
| Packs, card tags | 2 sheets, active, 3 awards, 1 milestone, 6 stickers, 2 word books, 1 story |
| Packs, remove button | Remove |
| Packs, pack that holds the only awards | Needed for the awards. |
| Packs, pack that holds the only sheets | Needed for the week. |
| Packs, import button | Import a pack |
| Packs, line under the button | You can also open a .json file with Starbook from WhatsApp, Gmail or Files. |
| Packs, preview sheet | Add this pack?, or Add this voice?, with Add and Cancel |
| Packs, replace sheet | Replace this pack?, or Replace this voice?, with Replace and Cancel |
| Packs, replace line | This pack is already added at revision 3. (This voice is already added at revision 1. for a voice) |
| Packs, remove sheet | Remove this pack?, then Stars already given stay., with Remove and Cancel |
| Packs, active sheet heading and line | ACTIVE SHEET, This week keeps its sheet. A new sheet starts next week. |
| Packs, voices heading | VOICES |
| Packs, active tag | active |
| Import ok | Added: (pack or voice title) |
| Import error | This file could not be added. (what is wrong), with an OK button |
| Import error, the line | the checker's line (for example sheets[0].days[1].tasks[0]: text is missing), a voice check line (for example a clip has bad word timings), the file is not valid JSON, the file is larger than 50 MB, the voice pack is larger than 100 MB unpacked, the phone could not save it, or the file could not be read. A shared file with no name shows as "Shared file". |

Award labels and spoken praise come from the award pack and can be changed there.
