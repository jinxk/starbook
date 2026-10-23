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

The child's home screen is this week's page. Each school day is a big slot. Tasks inside a day show as small pictures with their text read aloud on tap. When the parent marks a task done, a star drops into that day. When every task in a day is done, the day gets its day star. When every school day is done, the week earns the reward the parent typed in, for example "Park with Papa on Sunday". With no reward typed, home shows none.

A missed day stays an empty outline. Nothing is lost, nothing turns red, nothing is taken away.

## Awards

The parent gives an award for a finished task. The default set has one:

| Award | What the child sees | Counts as |
|---|---|---|
| Sticker | A sticker peels off and goes into the album | 1 star and 1 sticker |

Awards are defined in packs, so a family can rename it, add "Excellent!" or "Superstar!", or change which sticker set is used. One task always gives one award. A sticker award is a surprise among the stickers the child does not have yet, so the book fills up page by page; once the set is complete the surprise comes from the whole set. There are no timers, no lost stickers, no purchases, rarity levels or currencies.

Earlier versions also offered Star, "Very good!" and "Well done!". They are no longer offered, but a week that already holds one still shows it. A pack marks an award like this as retired (see [Pack format](pack-format.md)).

## Milestones and trophies

Milestones turn totals into trophies: first star, 10 stars, first full week, first word book finished, five stories read, and so on. They are defined in packs with simple rules (`stars >= 10`). Filling a page of the sticker book earns a trophy too. A trophy is never taken back, even if a parent undoes an award later. The child can open the trophy shelf any time; locked trophies show as pale outlines with no numbers.

No streaks. A sick day must not break anything.

## Word books

A word book is a deck of picture cards: one big picture (or, on a counting card, that many), one word, tap to hear it. The default books follow how many preschools teach vowels: one short vowel at a time with word families ("a": cat, bat, hat, mat, van, fan, cap, map). A second set uses initial sounds ("A for apple"). Topic books cover the usual sheet items: fruits, vegetables, flowers, animals, body parts, shapes, transport, community helpers, days, months, numbers with spellings, "Count with me 1 to 5" and "Count with me 1 to 10" (each card shows the numeral and that many pictures), and Hindi letters.

A task can link to a word book, so "Learn vowel A" on Monday opens the "a" book.

## Stories

Short stories for children who are just starting to read: 8 to 10 pages, one sentence per page, large type, a picture per page. Words are mostly short-vowel words plus a few sight words (I, see, a, the, is, can, my, go).

- Tap any word to hear it.
- Tap play to hear the sentence, with each word lighting up as it is spoken.
- A slower reading speed is available.

Reading a story does not give stars by itself. The sheet can have a story-time task the parent marks done, like any other task.

## Parent area

Behind a gate a pre-reader cannot pass: one question with a two-digit answer (a sum such as "23 + 15", a difference such as "42 − 17", or a times question such as "3 × 4"), never the same one twice in a row, the answer typed on a keypad, a new question after a wrong answer, and a short lockout after three wrong answers in a row.

Inside:
- Today and the 6 days before it: mark tasks done, pick the award, tick the good habits, undo. No other day can be marked.
- Packs: import from a file or from a share (WhatsApp, email, Files), see what is installed, update a pack by importing a newer revision, remove a pack.
- This week's sheet: switch the active sheet on Packs. On Whole week, edit task text and add or remove a task for this week only; next week starts from the sheet again. A task that already has an award cannot be removed. The special weekly reward is set on Today.
- Child: name and picture shown on the home page.
- Backup: save everything to one JSON file or share it, and restore it later. A restore shows what the file holds and replaces what is on the phone. Voice packs you added are not in the file.
- Settings: sounds on or off, slow reading, and a check of the phone's own voice for English and Hindi (the voice used for text without a clip). The recorded voice is picked on Packs.
- Voice: pick the active voice pack and import more (`.starbook-voice` files) on Packs.
- Credits for the fonts, pictures, sounds, voices and any story that carries a credit.

If the phone's store cannot be opened, the app shows a plain "Starbook could not open just now." screen instead of crashing. When a save fails, the parent sees "That did not save. Please try again." and the child "Please try that again."; nothing is shown as raw error text.

## App icon

A pink hibiscus drawn as a sticker (white outline, soft shadow, slight tilt) on warm paper, as an Android adaptive icon with a legacy icon for Android 7.

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
