# Product

Starbook turns a preschool homework sheet into a sticker book on a phone. A parent loads the week's sheet, the child does the work on paper as usual, and the parent hands out stars in the app. The child watches the week fill up, collects stickers, and puts trophies on a shelf. Between homework days the child can flip through picture word books and read very short stories that read themselves aloud.

It is built for children aged 3 to 6 and the adults around them. Nothing in it is tied to one school: every sheet, word book, story and reward is a JSON pack that anyone can write, share and import.

## Who uses it

| Who | What they do |
|---|---|
| Child (3 to 6, pre-reader or early reader) | Looks at this week's page, sees stars land, opens the sticker album and trophy shelf, flips word books, listens to and reads stories. Never awards anything. |
| Parent | Opens the parent area behind a gate, marks tasks done and picks the award, imports packs, edits the week, sets the special weekly reward. |
| Pack author (a parent, a teacher, a contributor) | Writes a pack JSON by hand or by copying a sample, shares the file. |

## The week

A sheet is a weekly plan: some school days, each with a short list of tasks and a title ("Alphabet Adventure"), optional every-day items (story time), and rest days. When a new week starts the app opens a fresh page from the active sheet. Last week's page goes into the album as it was, empty slots and all.

The child's home screen is this week's page. Each school day is a big slot. Tasks inside a day show as small pictures with their text read aloud on tap. When the parent marks a task done, a star drops into that day. When every task in a day is done, the day gets its day star. When every school day is done, the week earns the big reward the parent typed in ("Ice cream on Sunday").

A missed day stays an empty outline. Nothing is lost, nothing turns red, nothing is taken away.

## Awards

The parent picks what a finished task earns. The default set:

| Award | What the child sees | Counts as |
|---|---|---|
| Star | A star drops into the day | 1 star |
| Very good! | A stamp with the words, spoken aloud | 1 star |
| Well done! | A stamp with the words, spoken aloud | 1 star |
| Sticker | A sticker peels off and goes into the album | 1 star and 1 sticker |

Awards are defined in packs, so a family can rename them, add "Excellent!" or "Superstar!", or change which sticker set is used. One task always gives one award. There are no random prizes, rarity levels or currencies.

## Milestones and trophies

Milestones turn totals into trophies: first star, 10 stars, first full week, first word book finished, five stories read, and so on. They are defined in packs with simple rules (`stars >= 10`). A trophy is never taken back, even if a parent undoes an award later. The child can open the trophy shelf any time; locked trophies show as pale outlines with no numbers.

No streaks. A sick day must not break anything.

## Word books

A word book is a deck of picture cards: one big picture, one word, tap to hear it. The default books follow how many preschools teach vowels: one short vowel at a time with word families ("a": cat, bat, hat, mat, van, fan, cap, map). A second set uses initial sounds ("A for apple"). Topic books cover the usual sheet items: fruits, vegetables, flowers, animals, body parts, shapes, transport, community helpers, days, months, numbers with spellings, and Hindi letters.

A task can link to a word book, so "Learn vowel A" on Monday opens the "a" book.

## Stories

Short stories for children who are just starting to read: 8 to 10 pages, one sentence per page, large type, a picture per page. Words are mostly short-vowel words plus a few sight words (I, see, a, the, is, can, my, go).

- Tap any word to hear it.
- Tap play to hear the sentence, with each word lighting up as it is spoken.
- A slower reading speed is available.

Reading a story does not give stars by itself. The sheet can have a story-time task the parent marks done, like any other task.

## Parent area

Behind a gate a pre-reader cannot pass: three numbers written as words ("seven, two, nine"), typed as digits on a keypad, new numbers each time, a short lockout after three wrong tries.

Inside:
- Today and this week: mark tasks done, pick the award, undo.
- Packs: import from a file or from a share (WhatsApp, email, Files), see what is installed, update a pack by importing a newer revision, remove a pack.
- This week's sheet: switch the active sheet, edit task text, add or remove a task for this week only, set the special weekly reward.
- Child: name and picture shown on the home page.
- Backup: export everything to one JSON file and import it back.
- Voice: pick the active voice pack, import more (`.starbook-voice` files), check the phone's own voice for text without clips.
- Sound and reading speed.

## Principles

- Offline only. No account, no network permission, no analytics, no ads.
- The parent gives every reward. The app never rewards on its own.
- Praise the effort, not the child ("You finished Tuesday!", not "You are so smart").
- Nothing is ever taken away. No streaks, no loss messages, no sad characters.
- Calm by default. Motion and sound are saved for the moment a reward lands.
- Content is data. Anything school-specific lives in a pack, never in code.

## Version 1 scope

In: the week page, awards, stickers, milestones and trophies, word books, stories with read-along, the parent gate, pack import from file and share, pack update by revision, the default packs, backup export and import, English and Hindi text (Devanagari).

Out of version 1, possibly later: several children on one phone, parent-recorded voice per card, an in-app pack editor beyond editing this week's tasks, packs with bundled images (zip), letter-by-letter "sound it out", Marathi interface text, iOS builds.
