# Voice packs

Everything the child hears is spoken from a voice pack when the pack has a clip for that text, and by the phone's own text-to-speech when it does not. Voice packs make the default content sound warm and consistent, and the phone voice keeps imported packs working on day one.

The app ships two voice packs: **Heart**, a warm female English voice (Kokoro `af_heart`), covering the English lines in the default packs, and **Divya**, a Hindi voice (Indic Parler-TTS, speaker Divya), covering every Hindi line. More voice packs can be made with the renderer in [`tool/voice/`](../tool/voice) and imported like content packs.

## What is in a voice pack

A voice pack is a zip file with the extension `.starbook-voice`:

```
voice.json
clips/
  6314d0c7e4.ogg
  77af778b51.ogg
  ...
```

Clips are mono Ogg Opus, 24 kHz, about 28 kbit/s.

`voice.json`:

```json
{
  "starbookVoice": 1,
  "id": "starbook.voice.heart",
  "revision": 1,
  "title": "Heart",
  "language": "en",
  "engine": "kokoro",
  "voice": "af_heart",
  "speed": 0.9,
  "license": "CC0-1.0",
  "credit": "Voice made with Kokoro-82M (Apache-2.0), voice af_heart.",
  "clips": [
    {
      "text": "I see a red mango.",
      "file": "clips/6314d0c7e4.ogg",
      "words": [[0.33, 0.49], [0.49, 0.69], [0.69, 0.78], [0.78, 1.03], [1.03, 1.78]]
    },
    { "text": "cat", "file": "clips/77af778b51.ogg" }
  ]
}
```

| Field | Notes |
|---|---|
| `starbookVoice` | Format version, `1`. |
| `id`, `revision`, `title` | Same rules as content packs: a higher revision replaces an installed voice pack with the same id. |
| `language` | The language part only (`en`, `hi`). A clip is used for any item whose language starts with it, so `en` covers `en-IN` and `en-GB`. |
| `engine`, `voice`, `speed` | How the clips were made, for the parent area and for re-rendering. `engine` is the renderer's `--engine` name. |
| `clips[].text` | The exact text spoken: the item's `say` if it has one, otherwise its shown text. For a story page it is the sentence with the story's `say` words replaced, for example `aa-jee has a bit.`. The clip file name is the first 10 hex characters of the SHA-256 of this text. |
| `clips[].words` | Optional. Start and end time in seconds of each word, in the order the words appear in `text` (punctuation is not a word). Needed for read-along highlighting. A clip without `words` still plays; highlighting then uses the even-split fallback. |

### Matching text to a clip

The app trims the text and collapses runs of spaces to one before comparing. Case and punctuation are kept, because "Rain!" and "rain" sound different. The renderer stores the clip text in Unicode NFC and the app does not convert, so save content packs in NFC too, or accented and Devanagari text may not match. Single words on word cards are looked up by the card's spoken text (`say` or `word`). If two installed voice packs have a clip for the same text and language, the one the parent picked as the active voice for that language wins.

## Making a voice pack

The renderer reads content packs, collects every line a child can hear (task text, day titles, the sheet's intro, rest message and week goal, a task's `cheer`, habits, award phrases, milestone titles, word book titles, card words, story titles, story sentences, single story words, `say` overrides), renders each one with an engine, and writes the zip. It also renders the few phrases the app itself says aloud, listed in `APP_PHRASES` in `render.py`: "A new trophy!", "All done! A new sticker for you!", "A sticker for you!", "You did the whole week!", "All done for today. Time to play!", the 7 lines "You finished Monday!" to "You finished Sunday!" and the 23 lines home says on a new sticker by task icon. The bundled Heart pack is at revision 8 with these, 710 clips. Sheet titles are not collected yet; the phone voice speaks them.

```
cd tool/voice
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python render.py --engine kokoro --voice af_heart --language en --speed 0.9 --id starbook.voice.heart --title Heart --credit "Voice made with Kokoro-82M (Apache-2.0), voice af_heart." --packs ..\..\packs --out ..\..\assets\voices\heart.starbook-voice
```

`--revision` defaults to 1 and `--license` to `CC0-1.0`.

It runs on the CPU. Rendering the default packs takes about 4 minutes.

The Hindi pack uses the `parler` engine. The model is gated: accept its terms on its Hugging Face page and log in with `hf auth login`. The engine needs its own venv, because parler-tts pins transformers 4.46.1:

```
cd tool/voice
python -m venv .venv-parler
.venv-parler\Scripts\pip install -r requirements-parler.txt
.venv-parler\Scripts\python render.py --engine parler --voice "Divya speaks in a warm, gentle, teaching tone at a slightly slow pace. The recording is very clear with no background noise." --language hi --speed 1.0 --id starbook.voice.divya --title Divya --credit "Voice made with Indic Parler-TTS by AI4Bharat (Apache-2.0), speaker Divya." --packs ..\..\packs --out ..\..\assets\voices\divya.starbook-voice
```

For `parler`, `--voice` is the Parler description, and it names the speaker. `--speed` is required but not used; the pace comes from the description. The Hindi pack takes about 15 to 20 minutes on the CPU.

### Engines

An engine is one Python module in `tool/voice/engines/` with a single function:

```python
def render(text: str, voice: str, language: str, speed: float) -> tuple[numpy.ndarray, int, list[tuple[float, float]] | None]:
    """Returns audio samples, the sample rate, and word timings if the engine has them."""
```

| Engine | Status | Word timings |
|---|---|---|
| `kokoro` | Default. Kokoro-82M, Apache-2.0, CPU. English and Hindi voices. | Yes, from the model. |
| `parler` | Built. AI4Bharat Indic Parler-TTS (`ai4bharat/indic-parler-tts`), Apache-2.0, CPU. Indian languages. Output resampled to 24 kHz; silence before and after speech is trimmed. | No; highlighting uses the even split. |

## In the app

- Default voice packs live in `assets/voices/` and are installed on first start, like the default content packs.
- Parents import more from Packs, Import a pack (a `.starbook-voice` file, or one opened with Starbook from another app) and pick the active voice on the Packs screen, under Voices: one active voice for each language.
- A voice file over 50 MB is refused, and so is one that unpacks to more than 100 MB.
- When no clip matches, the phone's text-to-speech speaks the text, at the rates in [`architecture.md`](architecture.md). Settings shows whether the English and Hindi phone voices are ready and works offline, and the Slow reading switch there slows both the clips and the phone voice.
