# Pack format

Everything Starbook shows (homework sheets, awards, milestones, word books, stories) comes from packs. A pack is one UTF-8 JSON file. The app ships with a few default packs and a parent can import more from a file or a share.

The machine-readable schema is [`schema/pack.schema.json`](../schema/pack.schema.json). The default packs in [`packs/`](../packs) are working examples.

## Top level

```json
{
  "starbook": 1,
  "id": "in.example.superstar-week",
  "revision": 3,
  "title": "Superstar homework week",
  "language": "en-IN",
  "author": "Ms. Priya, Sunflower class",
  "license": "CC0-1.0",
  "sheets": [],
  "awards": [],
  "milestones": [],
  "wordbooks": [],
  "stories": []
}
```

| Field | Required | Notes |
|---|---|---|
| `starbook` | yes | Format version. Always `1` for now. The app refuses packs with a newer version than it knows. |
| `id` | yes | Stable id for the pack, lowercase letters, digits, dots and hyphens. Use a reversed domain or your name to avoid clashes (`in.kotkar.eurokids-week`). |
| `revision` | yes | Whole number. Importing a pack whose `id` is installed replaces it only when `revision` is higher. Same or lower asks the parent first. |
| `title` | yes | Shown in the parent area. |
| `language` | no | BCP 47 tag used for read-aloud (`en-IN`, `en-GB`, `hi-IN`). Default `en-IN`. Any item can override it. |
| `author`, `license` | no | Shown in the parent area. Default packs are CC0. |
| `sheets`, `awards`, `milestones`, `wordbooks`, `stories` | no | Any mix. A pack can hold just one story. |

Sheets, tasks, awards, milestones, word books and stories each have an `id` that is unique within its list in that pack. Task ids are unique across a whole sheet, day tasks and `everyDay` tasks together. Each also needs its text: `title`, or `text` for tasks and `label` for awards. Cards need `word`; days are keyed by `weekday`. Items from other packs are referred to as `pack-id/item-id`; items in the same pack by `item-id` alone.

## Pictures

Anywhere a `picture` appears it takes one of:

- a name from the built-in picture library: `"cat"`, `"mango"`, `"auto-rickshaw"`. The full list is in [`pictures.md`](pictures.md).
- an emoji, prefixed: `"emoji:🦚"`. Used when the library has no match.
- nothing. A card then shows its `big` text large where the picture goes, and a story page shows an empty tinted box.

Packs cannot carry their own image files in version 1.

## Read-aloud text

Anything shown to the child is read aloud: from a voice pack clip when one matches the text ([`voice-packs.md`](voice-packs.md)), otherwise with the phone's text-to-speech. When the written text does not sound right, add `say`:

```json
{ "word": "chikoo", "say": "chee-koo", "picture": "chikoo" }
```

`say` changes only what is spoken, never what is shown. `say` can be set on tasks, habits, awards, cards and stories (on a story it is a map of words, see Stories). `language` can be set on those and on sheets and word books.

## Sheets

```json
{
  "id": "superstar-week",
  "title": "My superstar week",
  "intro": "Finish your homework each day and fill your page with stickers!",
  "letters": ["a", "c", "t"],
  "next": "superstar-week-2",
  "days": [
    {
      "weekday": "monday",
      "title": "Alphabet adventure",
      "colour": "sky",
      "tasks": [
        { "id": "mon-capitals", "text": "Write capital letters A to Z", "icon": "pencil" },
        { "id": "mon-numbers", "text": "Write numbers 1 to 10 with spellings", "icon": "numbers", "opens": "en-numbers-1-10" },
        { "id": "mon-vowel", "text": "Learn vowel A", "icon": "book", "opens": "short-a" }
      ]
    }
  ],
  "everyDay": [
    { "id": "story-time", "text": "Read a story with Mumma or Papa", "icon": "story", "bonus": true }
  ],
  "restDays": ["saturday", "sunday"],
  "restMessage": "No homework today! Play, draw, dance.",
  "weekGoal": "Our week together",
  "habits": [
    { "id": "teeth-morning", "text": "I brushed my teeth this morning", "picture": "toothbrush" }
  ]
}
```

| Field | Notes |
|---|---|
| `days[].weekday` | `monday` to `sunday`. A weekday appears at most once. |
| `days[].colour` | One of the theme colours: `tomato`, `sunflower`, `leaf`, `sky`, `plum`, `sand`. Optional; the app picks one if missing. |
| `tasks[].icon` | A name from the icon set (`pencil`, `book`, `story`, `numbers`, `letters`, `shapes`, `music`, `draw`, `talk`, `habit`). Optional. |
| `tasks[].cheer` | Optional. A short line, 40 characters at most, that home says when this task's sticker opens, in place of the line for its icon. Name what the child did, for example "You read about trains!". Spoken in the task's language. |
| `tasks[].tip` | Optional. A short note for the grown-up, 80 characters at most and with no line breaks, on how to do the task together: one thing to say, ask or wait for, for example "Point to each spoon as you count. Then ask: how many? Say: three spoons!". Shown in small grey text under the task in parent today and in Whole week, about 2 lines on a phone. Never shown to the child and never spoken. Changing the task's text in Whole week drops its tip for that week. |
| `tasks[].opens` | Optional id of a word book or story. The task card gets an open button so the child can practise. `number-board` is reserved: it opens the 1 to 10 counting board, so a word book or story with that id cannot be opened by its bare id (a `pack-id/number-board` reference still opens it). A value this app does not know shows no button. |
| `everyDay` | Tasks that appear on every school day. `bonus: true` means the task gives an award but is not needed for the day to count as done. |
| `restDays` | Days shown as rest days with `restMessage`. Days that are neither listed in `days` nor `restDays` are left blank. |
| `weekGoal` | Optional. Kept for packs; home does not show it. The parent types the reward ("Park with Papa on Sunday") in the app; it is not part of the pack. |
| `habits` | Optional list of good habits the child ticks each day, on any day of the week (a parent can also tick them for today and the 6 days before). Each has an `id` (unique among the habits of the sheet), a `text`, a `picture`, an optional `sticker` (a sticker from the sticker set, shown when the habit is ticked; without it the habit's picture is shown as a sticker; it is never a book sticker) and an optional `say`. A habit ticked on five days of one calendar week (Monday to Sunday) earns its own trophy, once; it stays. A habit id used on two sheets of one pack is one trophy. Habits give no homework stars. |
| `letters` | Optional. The week's 2 or 3 letters for the child, each a single lowercase letter `a` to `z`, no repeats, for example `["m", "s", "t"]`. Match them to the sheet's writing tasks. Home shows them under the star chart, and a tap says the letter's Letter sounds card ("M. M says mmm. M for mango."), or the letter alone when no installed pack has that card. Older app versions refuse a pack with this field. |
| `next` | Optional. The `id` of the sheet in this pack that starts the week after this one, for example `"week-2"`. A sheet that is not in the pack is refused on import. A chain may loop back to an earlier sheet. With no `next` the sheet repeats. If the app stays closed for whole weeks it moves on one sheet, so no week is skipped. A parent who picks another sheet on Packs wins, and the chain goes on from that sheet. Older app versions refuse a pack with this field. |

A day is done when every task in it (not counting bonus tasks) has an award. A day whose tasks are all bonus counts as done with no award. The week is done when every day in `days` is done.

## Awards

What the parent can give for a finished task.

```json
{ "id": "very-good", "kind": "stamp", "label": "Very good!", "say": "Very good!", "colour": "leaf", "stars": 1 }
```

| `kind` | Child sees |
|---|---|
| `star` | A star drops into the day. |
| `stamp` | A round stamp with `label`, spoken aloud. |
| `sticker` | A sticker from `stickers` (or the default set, every sticker listed in [`stickers.md`](stickers.md)) peels off and goes into the sticker book. |

`stars` is how many stars the award counts as (default 1, at most 3). Sticker awards add `"stickers": ["lion", "mango", "rocket"]`, names from the sticker list in [`stickers.md`](stickers.md); the app gives a surprise pick among the ones the child does not have yet, and repeats one only when the child has them all.

`retired` is optional, `true` or `false` (default `false`). A retired award is no longer offered to the parent, but a task that already holds it keeps its stamp, label and star count, so a week in progress and old backups look the same as when the award was given. Retired awards are also left out of the pack's award count on the Packs screen. Use it instead of deleting an award from a pack you have shared:

```json
{ "id": "shabash", "kind": "stamp", "label": "Well done!", "say": "Well done!", "colour": "tomato", "stars": 1, "retired": true }
```

The parent area offers every installed award that is not retired. The default pack has Sticker, and keeps Star, "Very good!" and "Well done!" as retired awards.

## Milestones

```json
{ "id": "ten-stars", "title": "10 stars", "trophy": "cup-gold", "when": { "stars": 10 } }
```

`when` holds one counter and the number to reach. Counters:

| Counter | Counts |
|---|---|
| `stars` | stars from every award ever |
| `stickers` | stickers in the sticker book |
| `daysDone` | school days completed |
| `weeksDone` | full weeks completed |
| `wordbooksDone` | word books flipped to the last card |
| `storiesRead` | stories read to the last page |

`trophy` is a name from the trophy set (`cup-gold`, `cup-silver`, `medal`, `ribbon`, `crown`, `rocket`, `rainbow`, `star-big`, `book-gold`, `heart`). Once earned a trophy stays.

## Word books

```json
{
  "id": "short-a",
  "title": "a as in cat",
  "letter": "a",
  "colour": "tomato",
  "cards": [
    { "word": "cat", "picture": "cat", "group": "-at" },
    { "word": "bat", "picture": "cricket-bat", "group": "-at" },
    { "word": "van", "picture": "van", "group": "-an" }
  ]
}
```

`letter` is optional and shown big on the cover. A book with no `letter` and no card with a picture shows its first card's `big` text there. `colour` is optional; a book without one is sky. `group` is optional; cards with the same group sit next to each other and the group shows as a small tag (`-at`). Cards can also carry `say` and `language`.

`big` is optional large text for numerals and letters. It is shown large in place of the picture, so a card with both shows only the picture:

```json
{ "big": "7", "word": "seven" }
{ "big": "आ", "word": "आम", "picture": "mango", "say": "आ से आम", "language": "hi-IN" }
```

`count` is optional, a whole number from 1 to 10, for counting books. The card shows the numeral, then that many copies of its picture in rows of at most 5, then the word. A card with `count` needs a `picture`, and does not show `big`:

```json
{ "word": "three", "picture": "mango", "count": 3, "say": "One, two, three. Three mangoes!" }
```

A card needs at least one of `picture` or `big`.

## Stories

```json
{
  "id": "i-see-a-cat",
  "title": "I see a cat",
  "level": 1,
  "cover": "cat",
  "pages": [
    { "text": "I see a cat.", "picture": "cat" },
    { "text": "The cat is on a mat.", "picture": "cat" }
  ],
  "say": { "Aaji": "aa-jee" }
}
```

| Field | Notes |
|---|---|
| `level` | 1 to 3. Level 1 is short pattern sentences; level 3 has longer sentences. Used for sorting. |
| `pages` | One sentence per page, 8 to 12 pages works best. A sentence that needs more than 3 lines at 40sp is shown smaller, down to 32sp; split anything longer. |
| `pages[].ask` | Optional. A short question or prompt for the grown-up reading with the child, 45 characters at most and with no line breaks: about the picture or the story ("What is the hen doing?"), the child's own life ("Where have you seen a mango tree?"), or a word on the page ("Point to the word 'cat'."). Shown as one small grey line under the picture, starting "Ask: "; a line too wide for the screen gets smaller instead of wrapping. Never spoken, and the sentence keeps its size and place. |
| `say` | Optional word to pronunciation map, used when a single word is tapped or read in a sentence. |
| `credit` | Optional. For stories taken from openly licensed books: `{ "source": "StoryWeaver", "url": "...", "license": "CC-BY-4.0", "text": "Written by ..., illustrated by ..., published by ..." }`. `source` and `license` are required inside it. Shown on the last page and in the parent area. Required when the licence asks for attribution. |

## Importing

- From the parent area: Packs, Import a pack, pick a `.json` file.
- From another app: share or open a `.json` file with Starbook (WhatsApp, Gmail, Files).

The app checks the file against the schema before changing anything, and a file over 50 MB is refused. A good file shows a preview first ("Add this pack?") and is written only after the parent taps Add. A bad file changes nothing and the parent sees one plain line saying what is wrong and where (`sheets[0].days[1].tasks[0]: text is missing`). A pack with the same `id` and a higher `revision` replaces the old one; stickers already given stay, because they are stored against task ids, not the pack. A pack with the same or a lower `revision` than the installed one shows "Replace this pack?" and replaces it only when the parent taps Replace.

## Writing a pack

1. Copy the closest file from [`packs/`](../packs).
2. Change `id` to something of your own and set `revision` to 1.
3. Edit the text. Keep task text short; it is read aloud.
4. Check it with any JSON Schema validator against `schema/pack.schema.json`, or just import it: the app tells you what is wrong.
5. When you change it later, raise `revision` before sharing it again.

A small pack with two weeks you can copy and change:

```json
{
  "starbook": 1,
  "id": "in.example.two-weeks",
  "revision": 1,
  "title": "Two little weeks",
  "author": "Ms. Priya, Sunflower class",
  "sheets": [
    {
      "id": "week-1",
      "title": "Week 1",
      "letters": ["m", "a"],
      "next": "week-2",
      "days": [
        {
          "weekday": "monday",
          "title": "M and A",
          "tasks": [
            { "id": "w1-write-m", "text": "Write m five times", "icon": "pencil", "tip": "Hold the pencil with the child. Say: down, up and over, up and over." },
            { "id": "w1-count", "text": "Count to 10", "icon": "numbers", "opens": "number-board" }
          ]
        }
      ],
      "habits": [
        { "id": "teeth", "text": "I brushed my teeth", "picture": "toothbrush" }
      ]
    },
    {
      "id": "week-2",
      "title": "Week 2",
      "letters": ["s", "t"],
      "next": "week-1",
      "days": [
        {
          "weekday": "monday",
          "title": "S and T",
          "tasks": [
            { "id": "w2-write-s", "text": "Write s five times", "icon": "pencil" }
          ]
        }
      ],
      "habits": [
        { "id": "teeth", "text": "I brushed my teeth", "picture": "toothbrush" }
      ]
    }
  ]
}
```

- The top lines name the pack; keep `id` and raise `revision` each time you share a new copy.
- Each sheet is one week, and `next` says which sheet comes the week after, so week 1 leads to week 2 and week 2 goes back to week 1.
- `letters` are the 2 or 3 letters the child practises that week, shown on home.
- `tip` is a note for the grown-up under the task, never shown to the child.
- `opens` puts an open button on the task; `number-board` opens the 1 to 10 counting board, or use the `id` of a word book or story.
- The habit sits on both sheets with the same `id`, so the child keeps one habit and earns one trophy for it.
