"""Renders the lines in the content packs into a .starbook-voice file.

See docs/voice-packs.md for the format and the command line.
"""

import argparse
import hashlib
import importlib
import io
import json
import pathlib
import re
import sys
import unicodedata
import zipfile

import numpy as np
import soundfile as sf


# Phrases the app itself speaks, with their language. Keep in step with the app.
APP_PHRASES = [
    ("A new trophy!", "en"),
    ("All done! A new sticker for you!", "en"),
    ("A sticker for you!", "en"),
    ("You did your writing!", "en"),
    ("You wrote it all!", "en"),
    ("You did your numbers!", "en"),
    ("You wrote your numbers!", "en"),
    ("You practised your numbers!", "en"),
    ("You learned your letters!", "en"),
    ("You worked on your letters!", "en"),
    ("You practised your letters!", "en"),
    ("You did your reading!", "en"),
    ("You read your words!", "en"),
    ("You learned new words!", "en"),
    ("You read a story together!", "en"),
    ("You shared a story!", "en"),
    ("You told your story!", "en"),
    ("You said it out loud!", "en"),
    ("You did your shapes!", "en"),
    ("You named the shapes!", "en"),
    ("You made music!", "en"),
    ("You did your music!", "en"),
    ("You did your drawing!", "en"),
    ("You drew a picture!", "en"),
    ("You learned about good habits!", "en"),
    ("You practised a good habit!", "en"),
    ("You finished Monday!", "en"),
    ("You finished Tuesday!", "en"),
    ("You finished Wednesday!", "en"),
    ("You finished Thursday!", "en"),
    ("You finished Friday!", "en"),
    ("You finished Saturday!", "en"),
    ("You finished Sunday!", "en"),
    ("You did the whole week!", "en"),
    ("All done for today. Time to play!", "en"),
]


def normalise(text: str) -> str:
    return re.sub(r" {2,}", " ", unicodedata.normalize("NFC", text).strip())


def split_punct(token: str) -> tuple[str, str, str]:
    """Splits a token into leading punctuation, core and trailing punctuation."""
    start = 0
    while start < len(token) and unicodedata.category(token[start]).startswith("P"):
        start += 1
    end = len(token)
    while end > start and unicodedata.category(token[end - 1]).startswith("P"):
        end -= 1
    return token[:start], token[start:end], token[end:]


def apply_say_map(sentence: str, say: dict[str, str]) -> str:
    words = []
    for token in sentence.split(" "):
        lead, core, trail = split_punct(token)
        words.append(lead + say.get(core, core) + trail)
    return " ".join(words)


def word_count(text: str) -> int:
    return sum(1 for token in text.split(" ") if split_punct(token)[1])


def _lines(pack: dict, pack_language: str):
    """Yields (spoken text, language) for every hearable line, in walk order."""
    for sheet in pack.get("sheets", []):
        sheet_language = sheet.get("language", pack_language)
        for day in sheet["days"]:
            yield day["title"], sheet_language
            for task in day["tasks"]:
                yield task.get("say", task["text"]), task.get("language", sheet_language)
                if "cheer" in task:
                    yield task["cheer"], task.get("language", sheet_language)
        for task in sheet.get("everyDay", []):
            yield task.get("say", task["text"]), task.get("language", sheet_language)
            if "cheer" in task:
                yield task["cheer"], task.get("language", sheet_language)
        for key in ("intro", "restMessage", "weekGoal"):
            if key in sheet:
                yield sheet[key], sheet_language
        for habit in sheet.get("habits", []):
            yield habit.get("say", habit["text"]), sheet_language
    for award in pack.get("awards", []):
        yield award.get("say", award["label"]), award.get("language", pack_language)
    for milestone in pack.get("milestones", []):
        yield milestone["title"], pack_language
    for book in pack.get("wordbooks", []):
        book_language = book.get("language", pack_language)
        yield book["title"], book_language
        for card in book["cards"]:
            yield card.get("say", card["word"]), card.get("language", book_language)
    for story in pack.get("stories", []):
        story_language = story.get("language", pack_language)
        say = story.get("say", {})
        yield story["title"], story_language
        sentences = [apply_say_map(normalise(page["text"]), say) for page in story["pages"]]
        for sentence in sentences:
            yield sentence, story_language
        for sentence in sentences:
            for token in sentence.split(" "):
                yield split_punct(token)[1], story_language


def collect(packs: list[dict], language: str) -> list[str]:
    """Distinct normalised spoken texts in the given language, in first-seen order."""
    texts: dict[str, None] = {}
    for pack in packs:
        for text, line_language in _lines(pack, pack.get("language", "en-IN")):
            if line_language.split("-")[0].lower() != language:
                continue
            text = normalise(text)
            if text:
                texts.setdefault(text)
    for text, phrase_language in APP_PHRASES:
        if phrase_language == language:
            texts.setdefault(normalise(text))
    return list(texts)


def clip_name(text: str) -> str:
    return "clips/" + hashlib.sha256(text.encode("utf-8")).hexdigest()[:10] + ".ogg"


def trim_silence(samples: np.ndarray, rate: int) -> np.ndarray:
    """Cuts quiet samples (under 0.01) from both ends, keeping 0.15 s on each side."""
    loud = np.flatnonzero(np.abs(samples) > 0.01)
    if loud.size == 0:
        return samples
    pad = int(0.15 * rate)
    return samples[max(loud[0] - pad, 0) : loud[-1] + pad + 1]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Render content pack lines into a .starbook-voice file.")
    ap.add_argument("--engine", required=True)
    ap.add_argument("--voice", required=True)
    ap.add_argument("--language", required=True)
    ap.add_argument("--speed", type=float, required=True)
    ap.add_argument("--id", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--credit", required=True)
    ap.add_argument("--packs", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--revision", type=int, default=1)
    ap.add_argument("--license", default="CC0-1.0")
    args = ap.parse_args()

    files = sorted(pathlib.Path(args.packs).glob("*.json"), key=lambda p: p.name)
    packs = [json.loads(f.read_text(encoding="utf-8")) for f in files]
    texts = collect(packs, args.language)

    names: dict[str, str] = {}
    for text in texts:
        name = clip_name(text)
        if name in names:
            sys.exit(f"clip name clash {name}: {names[name]!r} and {text!r}")
        names[name] = text

    engine = importlib.import_module(f"engines.{args.engine}")
    clips = []
    audio_files = []
    for n, text in enumerate(texts, 1):
        print(f"{n}/{len(texts)} {text}")
        samples, rate, timings = engine.render(text, args.voice, args.language, args.speed)
        buf = io.BytesIO()
        sf.write(buf, samples, rate, format="OGG", subtype="OPUS", compression_level=0.9)
        clip = {"text": text, "file": clip_name(text)}
        if timings is not None:
            if len(timings) == word_count(text):
                clip["words"] = [[round(s, 2), round(e, 2)] for s, e in timings]
            else:
                print(f"warning: word count differs, no words for {text!r}")
        clips.append(clip)
        audio_files.append(buf.getvalue())

    voice = {
        "starbookVoice": 1,
        "id": args.id,
        "revision": args.revision,
        "title": args.title,
        "language": args.language,
        "engine": args.engine,
        "voice": args.voice,
        "speed": args.speed,
        "license": args.license,
        "credit": args.credit,
        "clips": clips,
    }
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for clip, data in zip(clips, audio_files):
            z.writestr(clip["file"], data)
        z.writestr("voice.json", json.dumps(voice, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
