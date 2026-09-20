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
| ink-soft | `#6B6872` | secondary text (parent area, the word card hint, the story credit) |
| tomato | `#E8553D` | sticker colour, vowel a |
| sunflower | `#F5B82E` | stars, vowel e |
| leaf | `#2E7D4F` | sticker colour, vowel i, "done" |
| sky | `#3C8DD6` | sticker colour, vowel o |
| plum | `#8A4FA3` | sticker colour, vowel u |
| sand | `#C9774B` | sticker colour, wood of the shelf |

Text on paper is always `ink`. White text sits only on tomato, leaf, sky and plum, at 24sp bold or larger; on sunflower and sand the text and icons are ink. Sunflower is too pale as text on a white card, so a letter coloured in sunflower uses the darker `#9A6A00`. Every pair is checked with a contrast tool before release (target 4.5:1 for text, 3:1 for large text and shapes).

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

Pictures come from Microsoft Fluent Emoji (MIT). The library and its names are in [`pictures.md`](pictures.md). A few things children here know well have no emoji (chikoo, guava, okra, marigold and a few more); those are drawn for this project in the same style.

Two styles exist in that set: Flat (vector, crisp at any size, small) and 3D (soft rendered images). The mockup shows both. The choice is recorded here once made:

- Style: Flat (SVG through flutter_svg). Drawn pictures follow the Fluent Flat look: flat fills, no outlines, soft single-tone shading shapes.

## Stickers

Stickers are the collectible reward, so they look richer than the word book pictures. Each sticker is a Google Noto animated emoji (Lottie, CC BY 4.0) that plays once when the sticker arrives and again every time the child taps it in the album. Stickers with no animated version (elephant, for one) use the Fluent Emoji 3D image (MIT) with a short wobble on tap. The credits screen in the parent area names both sources.

## Icons

Controls (back, play, lock, arrows, settings, import, share, undo) use Phosphor Icons, Fill weight (MIT), bundled as SVG. Pack task icons (pencil, book, story, numbers, letters, shapes, music, draw, talk, habit) are Phosphor Fill too. Each icon is one file, `assets/icons/<name>.svg`, and a pack's `"icon"` value is that name. The slow-reading button uses the Fluent Flat turtle picture, since Phosphor has no turtle. Icons sit on round paper-deep buttons at least 72dp wide on child screens.

## Sticker treatment

Every picture shown as a sticker gets the sticker treatment: a 6dp white outline that follows the shape, a soft shadow, and a slight random tilt (between -4 and 4 degrees, fixed per sticker so it does not jump around).

## Sizes

- Anything the child taps: at least 72dp, with at least 16dp between targets. Day rows on home are 16dp apart; tasks on a day are 24dp apart, with 16dp between a task and its open bar.
- Feedback starts on finger down, not on release, within 100ms. Stickers in the album are the exception: they play when the finger lifts, so scrolling never starts one.
- Tap works everywhere. Swipe is a shortcut, never the only way (page turns also have big arrow buttons).
- No long press, no double tap, no hidden gestures on child screens.
- State-changing taps ignore repeats within 300ms.

## Screens

### Child

1. **This week.** The child's name and picture at the top, with the week's dates under the name. Until a name is set, the title is the sheet title and there is no picture. Below, a star chart on a slightly tilted card: one row per school day, on plain paper with no grain. Each row has a tilted tile in the day colour (short day name and "3 jobs"), a small circle for each task that is not a bonus (dashed until it has an award, then the star, stamp or sticker), and on the right a big star once the day is done (a dashed star before). Today's row has a small TODAY tag. Tapping a row opens the day. Rest days have no row. Under the chart, a reward box with the special reward the parent typed, else the week goal. Under the box, when the sheet has rest days, one quiet line about them. Bottom: a dock of four round buttons, Trophies, Words, Stories, Habits, each 72dp, with no fade behind it. The parent lock sits in the top corner as a 72dp target with a small icon.
2. **A day.** A back button, the weekday name in the day colour, and the day title ("Alphabet adventure") under it. Its tasks as large rows: icon, text, and the award once given (a dashed circle until then). A bonus task is marked BONUS. Tapping a row reads it aloud and lights the row until the read ends. A task that opens a word book or story has a full-width bar under its row, "Practise" for a word book and "Pick a story" for a story. When every task is done, a box in the day colour with a big star and "You finished Monday!" ends the list.
3. **Trophy room.** A back button and the title "My trophies". A wooden shelf, three trophies to a plank, with every trophy the installed packs offer: the ones earned in full colour, the rest pale, no numbers, no progress bars. A pack's milestones come first, then the habit trophies of its sheets. Until the first trophy is earned, "Your trophies will stand here." sits under the shelf. Tapping an earned trophy reads its name aloud and shows it big with its name and "Earned on Tuesday, 14 October". Below the shelf, "My stickers": one grid of every sticker given, newest first, then dashed empty places up to eight. A sticker plays when the finger lifts.
4. **Word books.** A back button and the title "Word books", then covers two across, each a big coloured book with a darker spine strip on the left. The colour is the book's own, sky when the pack names none. The big letter sits at the top left, and the book's title at the bottom in Baloo 2 Bold 19sp. A book with a picture shows it as a sticker at the bottom right, smaller (64) beside a letter and larger (96) alone. A book with no letter and no card with a picture (the days, months and numbers) shows its first card's big text where the letter goes. Text on a cover is white, and ink on sunflower and sand. Tapping a cover opens the book.
   **Word card.** A back button and the book's title, then one card at a time on a white card with rounded corners that fills the page. The picture is large (230), else the card's big text in ink at 140, so a card with both shows only the picture. Under it the word at 72sp in ink, with the book's letter coloured in the book colour (not in Hindi books). A card with a `group` has the group as a small tag at the top right. Under the word, a small "Tap to hear" in ink-soft; on the last card, "All done!" takes its place and the book counts as finished. Tapping anywhere on the card reads the word. A card is read 250ms after it first shows. After a turn, the paper flip plays and the read waits 450ms so the flip ends first. Cards slide over 250ms. Below the card: a round back arrow and a round next arrow, 80dp, in the book colour, each labelled "Back" and "Next" for a screen reader, with a dot row between them (the current card dark). The arrows fade to 25% at the ends. Leaving the screen stops the read.
5. **Stories.** A back button and the title "Stories", then one tile for each story, level 1 first, then 2 and 3, in pack order inside a level. A tile has an 84dp tinted box with the story's cover picture (else the first page picture, else nothing) at 66, the title in Baloo 2 Bold 22sp and three level dots. The tint is pink, green or blue by the story's place in its pack. Tapping a tile opens the story.
   **Story reader.** A back button, the title and "1 of 8". The page is a tinted box in the story's tint with the page's one picture (210, shrinks to fit; no picture leaves the box empty), and the sentence below it, left aligned, at 40sp or the step down that fits (see Type). Each word lights in sunflower while it is spoken. Tapping a word reads it. Below, four round buttons spread evenly across the row: Back page, Read to me (larger, ink, white play triangle, a white square while reading), Slow reading (the turtle, leaf green when on) and Next page. Back page and Next page fade to 25% at the ends. Read to me reads the sentence and lights each word in turn; tapping it again, tapping a word or turning the page stops the read. Pages slide over 250ms. Nothing is read when a page shows, and pages never turn by themselves. The last page ends with "The end." under the sentence, and under it, for a story with a credit, the credit text and then "source, licence" (for example "StoryWeaver, CC-BY-4.0") in ink-soft. No link is shown. Reaching the last page counts the story as finished.
   A trophy reached by finishing a word book or a story is shown when the child leaves it, over the screen they return to (the word books list, the stories list or the day).
5a. **My good habits.** A back button and the title "My good habits". One row for each habit on the sheet: the habit's picture, its text, and on the right a dashed circle until it is ticked today, then a star. Tapping a row reads the habit aloud and ticks it, and the star drops in with the star note. A second tap reads it again and ticks nothing; only the parent can undo a tick. Habits give no homework stars, and any day of the week counts.

### Parent

6. **Gate.** A back button, "Grown-ups only", and three number words, for example "seven, two, nine" (three digits from 1 to 9). Under them three boxes that fill as the parent types, and a keypad with the digits 0 to 9 and a delete key that removes the last digit. The third digit checks the answer. A wrong try clears the digits and shows new numbers, with no shake. Three wrong tries in a row lock the keypad for 60 seconds, and the numbers and the hint give way to "Please wait a minute" with the seconds left. The wait is kept for the app run: leaving the gate and coming back does not end it. A right answer resets the count of wrong tries. Nothing is read aloud here.
7. **Parent home.** Opens on today: a header "Today, Tuesday" with a Done button that goes back to home. Under it today's tasks and the every-day tasks, then the bonus tasks, each as a card with the task text and one chip for each award in the installed packs (Star, Very good!, Well done!, Sticker), all the same width, the label shrinking to fit. The chip of the award given is filled dark. Tapping another chip replaces the award. Tapping the filled one does nothing. After each award a toast at the bottom, "Star given for (task)" with Undo, stays about 4 seconds; Undo takes the award away, or puts back the one it replaced. Then, when the sheet has habits, a Good habits list: one card for each habit with its picture and text, a dashed circle until it is ticked today, then a star and an Undo button that removes today's tick. Then a field for this week's reward (blank clears it). Last, a More list: Packs, Whole week, Child, Backup and Settings, each with a short note on the right. These rows open nothing yet. The parent area uses the same paper colour but plain type and smaller controls, so it looks like a different place.
8. **Week.** All days and tasks, with awards given so far. Edit task text for this week, add or remove a task for this week, set the special reward.
9. **Packs.** Installed packs with title, author, revision, and what they contain. Import button. Switch the active sheet. Remove a pack (asks first, stars already given stay).
10. **Backup and settings.** Export and import everything. Sound on or off, reading speed, read-aloud voice check (shows whether English and Hindi voices are installed and offline, with a button to open the phone's voice settings).

## Motion

- Default: 150 to 250ms ease-out for page and screen changes. Nothing loops on its own.
- Star landing: the star drops into its circle on the day row with a small bounce (spring), the circle glows once. An award lands the first time home shows it. When several are new, the first lands at once and the rest follow 800ms apart. No sound or haptic plays while the day screen is open on top.
- Sticker: lifts off, wobbles, presses down with a short squash, then settles at its tilt.
- Trophy: a full-screen celebration over the page with the trophy picture rising in, "A new trophy!" and the trophy name, and a few paper sparkles for under a second. "A new trophy!" is spoken, then the trophy name. The celebration is the arrival; the shelf does not animate. When several trophies are new at once, only the newest celebrates. A tap closes it.
- Day complete: the big star drops into the day row after the last award has landed.
- Week complete: a full-screen moment with a gift picture, "You did the whole week!" and the special reward text, else the sheet's week goal, else nothing under the title. No sound. It closes after 2.5 seconds or on a tap, and shows once per week. It waits until the last landing and the big star have finished; if a trophy comes at the same time, the week moment goes first.
- With the system "remove animations" setting on, everything is an instant cross-fade.

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
| Trophy room, album heading | My stickers |
| Trophy room, big view of an earned trophy | (trophy name)!, then Earned on (weekday), (day) (month), for example Earned on Tuesday, 14 October |
| Trophy room, a trophy not earned yet (screen reader) | Not yet |
| Habit screen, title | My good habits |
| Gate title | Grown-ups only |
| Gate hint | Type the numbers |
| Gate locked | Please wait a minute (seconds left, for example 42) |
| Parent today, title | Today, Tuesday |
| Parent today, button | Done |
| Parent today, headings | the day title, Every day (bonus), This week's reward, More (shown in capitals) |
| Parent today, habit list heading | Good habits (shown in capitals), with Undo on a ticked habit |
| Parent today, award chips | ★ Star, Very good!, Well done!, ◐ Sticker (a star award has ★ in front, a sticker award ◐, a stamp nothing) |
| Parent today, toast after an award | Star given for "(task text)", with Undo |
| Parent today, reward field hint | Ice cream on Sunday |
| Parent today, More rows | Packs (6 installed ›), Whole week (edit tasks ›), Child ((name) ›, or just ›), Backup (export, import ›), Settings (sound, reading speed, voices ›) |
| Import ok | Added: (pack title) |
| Import error | This file could not be added. (what is wrong) |

Award labels and spoken praise come from the award pack and can be changed there.
