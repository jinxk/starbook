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
| ink-soft | `#6B6872` | secondary text (parent area only) |
| tomato | `#E8553D` | sticker colour, vowel a |
| sunflower | `#F5B82E` | stars, vowel e |
| leaf | `#2E7D4F` | sticker colour, vowel i, "done" |
| sky | `#3C8DD6` | sticker colour, vowel o |
| plum | `#8A4FA3` | sticker colour, vowel u |
| sand | `#C9774B` | sticker colour, wood of the shelf |

Text on paper is always `ink`. White text sits only on tomato, leaf, sky and plum, at 24sp bold or larger. Every pair is checked with a contrast tool before release (target 4.5:1 for text, 3:1 for large text and shapes).

## Type

| Role | Font | Size |
|---|---|---|
| Child headings, day names, buttons | Baloo 2, SemiBold (600) or Bold (700) | 28 to 40sp |
| Story sentences | Andika, Regular | 40sp, and never below 32sp |
| Word card word | Andika, Bold | 64sp |
| Big letter on a word book cover | Andika, Bold | 160sp |
| Hindi (Devanagari) anywhere | Baloo 2 | same sizes as above |
| Parent area | Hind | Material type scale |

Andika is made by SIL for beginning readers and draws "a" and "g" the way children learn to write them. Check the single-storey a and g on the type sample before bundling. All three fonts are SIL Open Font License and are bundled in the app (no font downloads at runtime).

Story text: one sentence per page, left aligned, line height 1.4, words spaced a little wider than normal so each one is easy to tap. If a sentence does not fit at 40sp on a small phone it steps down to 32sp; below that the pack author has to split the sentence.

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
- Feedback starts on finger down, not on release, within 100ms.
- Tap works everywhere. Swipe is a shortcut, never the only way (page turns also have big arrow buttons).
- No long press, no double tap, no hidden gestures on child screens.
- State-changing taps ignore repeats within 300ms.

## Screens

### Child

1. **This week.** The child's name and picture at the top, with the week's dates under the name. Until a name is set, the title is the sheet title and there is no picture. Below, a star chart on a slightly tilted card: one row per school day, on plain paper with no grain. Each row has a tilted tile in the day colour (short day name and "3 jobs"), a small circle for each task that is not a bonus (dashed until it has an award, then the star, stamp or sticker), and on the right a big star once the day is done (a dashed star before). Today's row has a small TODAY tag. Tapping a row opens the day. Rest days have no row. Under the chart, a reward box with the special reward the parent typed, else the week goal. Under the box, when the sheet has rest days, one quiet line about them. Bottom: a dock of three big round buttons, Trophies, Words, Stories, with no fade behind it. The parent lock sits in the top corner as a 72dp target with a small icon.
2. **A day.** A back button, the weekday name in the day colour, and the day title ("Alphabet adventure") under it. Its tasks as large rows: icon, text, and the award once given (a dashed circle until then). A bonus task is marked BONUS. Tapping a row reads it aloud. A task that opens a word book or story has a full-width bar under its row, "Practise" for a word book and "Pick a story" for a story. When every task is done, a box in the day colour with a big star and "You finished Monday!" ends the list.
3. **Trophy room.** A wooden shelf with trophies standing on it and pale outlines for the ones still to come, no numbers, no progress bars. Below the shelf, the sticker album: pages of stickers in a grid, newest first. Tapping a trophy shows it big with its name read out ("10 stars!") and the date it was earned.
4. **Word books.** Covers as big coloured books with the letter or topic picture. Inside, one card at a time: the picture large, the word under it, tap anywhere to hear the word. Big arrows to turn, a dot row showing how many cards are left. The last card shows a small "All done!" and counts the book as finished.
5. **Stories.** Covers with title and level dots. Inside, one page at a time: the picture on top, the sentence below at 40sp. Tap a word to hear it; it lights up while spoken. A play button reads the sentence, lighting each word in turn. A turtle button switches to slow reading. Pages never turn by themselves.

### Parent

6. **Gate.** "Grown-ups only" and three number words, for example "seven, two, nine". A digit keypad. New numbers each time, a 60 second wait after three wrong tries. Nothing is read aloud here.
7. **Parent home.** Today's tasks with an award button each (Star, Very good!, Shabash!, Sticker), and undo for the last award. Links to the full week, packs, child, backup and settings. The parent area uses the same paper colour but plain type and smaller controls, so it looks like a different place.
8. **Week.** All days and tasks, with awards given so far. Edit task text for this week, add or remove a task for this week, set the special reward.
9. **Packs.** Installed packs with title, author, revision, and what they contain. Import button. Switch the active sheet. Remove a pack (asks first, stars already given stay).
10. **Backup and settings.** Export and import everything. Sound on or off, reading speed, read-aloud voice check (shows whether English and Hindi voices are installed and offline, with a button to open the phone's voice settings).

## Motion

- Default: 150 to 250ms ease-out for page and screen changes. Nothing loops on its own.
- Star landing: the star drops into its circle on the day row with a small bounce (spring), the circle glows once. An award lands the first time home shows it. When several are new, the first lands at once and the rest follow 800ms apart. No sound or haptic plays while the day screen is open on top.
- Sticker: lifts off, wobbles, presses down with a short squash, then settles at its tilt.
- Trophy: slides onto the shelf, a few paper sparkles for under a second.
- Day complete: the big star drops into the day row after the last award has landed.
- Week complete: a short full-screen moment with the special reward text, then back to the page.
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
| Home, dock | Trophies, Words, Stories |
| Home, lock (screen reader) | Grown-ups |
| Day, back button (screen reader) | Back |
| Day, bonus task | BONUS |
| Day, open bar | Practise, Pick a story |
| Day, all done | You finished Monday! |
| Star landing (spoken) | A star for you! |
| Week complete | You did the whole week! |
| Trophy arrives | A new trophy! |
| Word book end | All done! |
| Story end | The end. |
| Home, rest line when today is a rest day | No homework today. Play, draw, dance! (the sheet's rest message replaces it) |
| Empty trophy shelf | Your trophies will stand here. |
| Gate title | Grown-ups only |
| Gate hint | Type the numbers |
| Gate locked | Please wait a minute |
| Import ok | Added: (pack title) |
| Import error | This file could not be added. (what is wrong) |

Award labels and spoken praise come from the award pack and can be changed there.
