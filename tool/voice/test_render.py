import json
import pathlib
import sys
import tempfile
import types
import unittest
import zipfile
from unittest import mock

import numpy as np

import render

APP_EN = [text for text, language in render.APP_PHRASES if language == "en"]


def pack(**parts):
    return {"id": "t", **parts}


def sheet(tasks, **extra):
    return {"id": "s", "title": "S", "days": [{"weekday": "mon", "title": "M", "tasks": tasks}], **extra}


class RenderTest(unittest.TestCase):
    def test_spoken_text_prefers_say(self):
        p = pack(
            sheets=[sheet([{"id": "a", "text": "Read", "say": "Read it"}])],
            awards=[
                {"id": "x", "kind": "star", "label": "Star", "say": "A star!"},
                {"id": "y", "kind": "star", "label": "Sticker"},
            ],
            milestones=[{"id": "m", "title": "First star"}],
            wordbooks=[
                {
                    "id": "w",
                    "title": "W",
                    "cards": [{"word": "cat", "say": "kat"}, {"word": "dog", "big": "D"}],
                }
            ],
        )
        self.assertEqual(
            render.collect([p], "en"),
            ["M", "Read it", "A star!", "Sticker", "First star", "W", "kat", "dog"] + APP_EN,
        )

    def test_sheet_lines_and_habits(self):
        p = pack(
            sheets=[
                sheet(
                    [{"id": "a", "text": "Task", "cheer": "You wrote A!"}],
                    intro="Hi",
                    restMessage="Rest",
                    weekGoal="Goal",
                    habits=[{"text": "Brush", "say": "Brush it"}, {"text": "Bath"}],
                )
            ]
        )
        self.assertEqual(
            render.collect([p], "en"),
            ["M", "Task", "You wrote A!", "Hi", "Rest", "Goal", "Brush it", "Bath"] + APP_EN,
        )

    def test_app_phrases_english_only(self):
        for text, _ in render.APP_PHRASES:
            self.assertIn(text, render.collect([], "en"))
            self.assertNotIn(text, render.collect([], "hi"))

    def test_story_say_map_keeps_punctuation(self):
        say = {"Aaji": "aa-jee"}
        self.assertEqual(render.apply_say_map("Aaji has a bit.", say), "aa-jee has a bit.")
        self.assertEqual(render.apply_say_map("Hello, Aaji!", say), "Hello, aa-jee!")
        self.assertEqual(render.apply_say_map("Aajis ran.", say), "Aajis ran.")

    def test_language_filter_and_inheritance(self):
        p = pack(
            sheets=[
                sheet([{"id": "a", "text": "Kept"}]),
                sheet([{"id": "b", "text": "Dropped"}], language="hi-IN"),
            ],
            wordbooks=[
                {
                    "id": "w",
                    "title": "W",
                    "language": "hi-IN",
                    "cards": [
                        {"word": "dropped card", "big": "x"},
                        {"word": "Kept card", "big": "y", "language": "en-GB"},
                    ],
                }
            ],
        )
        self.assertEqual(render.collect([p], "en"), ["M", "Kept", "Kept card"] + APP_EN)

    def test_duplicates_render_once_in_first_order(self):
        first = pack(awards=[{"id": "a", "kind": "star", "label": "One"}, {"id": "b", "kind": "star", "label": "Two"}])
        second = pack(awards=[{"id": "c", "kind": "star", "label": "Three"}, {"id": "d", "kind": "star", "label": "One "}])
        self.assertEqual(render.collect([first, second], "en"), ["One", "Two", "Three"] + APP_EN)

    def test_normalise_and_word_count(self):
        self.assertEqual(render.normalise("e\u0301"), "\u00e9")
        self.assertEqual(render.normalise("  Rain!   now "), "Rain! now")
        self.assertNotEqual(render.normalise("Rain!"), render.normalise("rain"))
        self.assertEqual(render.word_count("Write Hindi letters a, aa, i"), 6)
        self.assertEqual(render.word_count("Yum - yum!"), 2)
        self.assertEqual(render.word_count("aa-jee"), 1)

    def test_titles_and_story_words(self):
        p = pack(
            sheets=[sheet([{"id": "a", "text": "Task"}])],
            wordbooks=[{"id": "w", "title": "Book", "cards": [{"word": "cat", "big": "c"}]}],
            stories=[
                {
                    "id": "st",
                    "title": "Tale",
                    "level": 1,
                    "say": {"Aaji": "aa-jee"},
                    "pages": [{"text": "Aaji has a bit."}],
                }
            ],
        )
        self.assertEqual(
            render.collect([p], "en"),
            ["M", "Task", "Book", "cat", "Tale", "aa-jee has a bit.", "aa-jee", "has", "a", "bit"] + APP_EN,
        )

    def test_trim_silence_cuts_quiet_ends_only(self):
        rate = 1000
        clip = np.concatenate(
            [np.zeros(1000), np.full(500, 0.5), np.full(3000, 0.001)]
        ).astype(np.float32)
        trimmed = render.trim_silence(clip, rate)
        self.assertEqual(len(trimmed), 800)
        self.assertEqual(int(np.sum(trimmed == 0.5)), 500)
        loud = np.full(900, 0.5, dtype=np.float32)
        self.assertEqual(len(render.trim_silence(loud, rate)), 900)
        silent = np.zeros(900, dtype=np.float32)
        self.assertEqual(len(render.trim_silence(silent, rate)), 900)

    def test_main_uses_named_engine_and_one_language(self):
        description = "Divya speaks slowly."
        calls = []

        def fake_render(text, voice, language, speed):
            calls.append((text, voice))
            return np.zeros(2400, dtype=np.float32), 24000, None

        with tempfile.TemporaryDirectory() as tmp:
            p = pack(
                language="en-IN",
                sheets=[
                    sheet([{"id": "a", "text": "Cat"}]),
                    sheet([{"id": "b", "text": "बिल्ली"}], language="hi-IN"),
                ],
            )
            pathlib.Path(tmp, "p.json").write_text(json.dumps(p), encoding="utf-8")
            out = pathlib.Path(tmp, "v.starbook-voice")
            argv = [
                "render.py", "--engine", "parler", "--voice", description,
                "--language", "hi", "--speed", "1.0", "--id", "t", "--title", "T",
                "--credit", "c", "--packs", tmp, "--out", str(out),
            ]
            engine = types.SimpleNamespace(render=fake_render)
            with mock.patch.dict(sys.modules, {"engines.parler": engine}):
                with mock.patch.object(sys, "argv", argv):
                    render.main()
            with zipfile.ZipFile(out) as z:
                meta = json.loads(z.read("voice.json"))

        self.assertEqual([c["text"] for c in meta["clips"]], ["M", "बिल्ली"])
        self.assertEqual({voice for _, voice in calls}, {description})
        self.assertTrue(all("words" not in c for c in meta["clips"]))
        self.assertEqual(meta["engine"], "parler")
        self.assertEqual(meta["voice"], description)

    def test_spoken_lines_are_pack_lines_and_keep_their_clip_text(self):
        packs_dir = pathlib.Path(__file__).parent.parent.parent / "packs"
        packs = [json.loads(f.read_text(encoding="utf-8")) for f in packs_dir.glob("*.json")]
        lines = render.collect(packs, "en")
        for key in render.SPOKEN:
            self.assertIn(key, lines)

        key = next(iter(render.SPOKEN))
        heard = []

        def fake_render(text, voice, language, speed):
            heard.append(text)
            return np.zeros(2400, dtype=np.float32), 24000, None

        with tempfile.TemporaryDirectory() as tmp:
            p = pack(
                language="en-IN",
                wordbooks=[{"id": "w", "title": "W", "cards": [{"word": "Aa", "say": key}]}],
            )
            pathlib.Path(tmp, "p.json").write_text(json.dumps(p), encoding="utf-8")
            out = pathlib.Path(tmp, "v.starbook-voice")
            argv = [
                "render.py", "--engine", "kokoro", "--voice", "af_heart",
                "--language", "en", "--speed", "0.9", "--id", "t", "--title", "T",
                "--credit", "c", "--packs", tmp, "--out", str(out),
            ]
            engine = types.SimpleNamespace(render=fake_render)
            with mock.patch.dict(sys.modules, {"engines.kokoro": engine}):
                with mock.patch.object(sys, "argv", argv):
                    render.main()
            with zipfile.ZipFile(out) as z:
                meta = json.loads(z.read("voice.json"))

        self.assertEqual([c["text"] for c in meta["clips"]][:2], ["W", key])
        self.assertIn(render.SPOKEN[key], heard)
        self.assertNotIn(key, heard)


if __name__ == "__main__":
    unittest.main()
