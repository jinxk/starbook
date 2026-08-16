# Voice packs

Everything the child hears is spoken from a voice pack when the pack has a clip for that text, and by the phone's own text-to-speech when it does not. Voice packs make the default content sound warm and consistent, and the phone voice keeps imported packs working on day one.

The app ships one voice pack: **Heart**, a warm female English voice (Kokoro `af_heart`), covering every line in the default packs. More voice packs can be made with the renderer in [`tool/voice/`](../tool/voice) and imported like content packs.

## What is in a voice pack

A voice pack is a zip file with the extension `.starbook-voice`:

```
voice.json
clips/
  0b6f2c9e1d.ogg
  4a1d77c03b.ogg
  ...
```

Clips are mono Ogg Opus, 24 kHz, about 24 kbit/s.

`voice.json`:

```json
{
  "starbookVoice": 1,
  "id": "starbook.voice.heart",
  "revision": 1,
  "title": "Heart",
  "language": "en",
  "engine": "kokoro-82m",
  "voice": "af_heart",
  "speed": 0.9,
  "license": "CC0-1.0",
  "credit": "Voice made with Kokoro-82M (Apache-2.0), voice af_heart.",
  "clips": [
    {
      "text": "I see a red mango.",
      "file": "clips/0b6f2c9e1d.ogg",
      "words": [[0.33, 0.49], [0.49, 0.69], [0.69, 0.78], [0.78, 1.03], [1.03, 1.78]]
    },
    { "text": "cat", "file": "clips/4a1d77c03b.ogg" }
  ]
}
```

| Field | Notes |
|---|---|
| `starbookVoice` | Format version, `1`. |
| `id`, `revision`, `title` | Same rules as content packs: a higher revision replaces an installed voice pack with the same id. |
| `language` | The language part only (`en`, `hi`). A clip is used for any item whose language starts with it, so `en` covers `en-IN` and `en-GB`. |
| `engine`, `voice`, `speed` | How the clips were made, for the parent area and for re-rendering. |
| `clips[].text` | The exact text spoken: the item's `say` if it has one, otherwise its shown text. |
| `clips[].words` | Optional. Start and end time in seconds of each word, in the order the words appear in `text` (punctuation is not a word). Needed for read-along highlighting. A clip without `words` still plays; highlighting then uses the even-split fallback. |

### Matching text to a clip

The app normalises both sides the same way before comparing: Unicode NFC, trim, collapse runs of spaces to one. Case and punctuation are kept, because "Rain!" and "rain" sound different. Single words on word cards are looked up by the card's spoken text (`say` or `word`). If two installed voice packs have a clip for the same text and language, the one the parent picked as the active voice wins.

## Making a voice pack

The renderer reads content packs, collects every line a child can hear (task text, award phrases, milestone titles, card words, story sentences, `say` overrides), renders each one with an engine, and writes the zip.

```
cd tool/voice
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python render.py --engine kokoro --voice af_heart --language en --packs ..\..\packs --out ..\..\assets\voices\heart.starbook-voice
```

It runs on the CPU. Rendering the default packs takes a few minutes.

### Engines

An engine is one Python module in `tool/voice/engines/` with a single function:

```python
def render(text: str, voice: str, language: str, speed: float) -> tuple[numpy.ndarray, int, list[tuple[float, float]] | None]:
    """Returns audio samples, the sample rate, and word timings if the engine has them."""
```

| Engine | Status | Word timings |
|---|---|---|
| `kokoro` | Default. Kokoro-82M, Apache-2.0, CPU. English and Hindi voices. | Yes, from the model. |
| `indic-parler` | Planned. AI4Bharat Indic Parler-TTS, Apache-2.0, Indian English and Indian languages. Needs a Hugging Face login to download. | No; the renderer will add a forced-alignment step. |

## In the app

- Default voice packs live in `assets/voices/` and are installed on first start, like the default content packs.
- Parents import more from Packs, Import (a `.starbook-voice` file) and pick the active voice in Settings.
- When no clip matches, the phone's text-to-speech speaks the text, at the rates in [`architecture.md`](architecture.md).
