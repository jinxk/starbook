import unittest

import render


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
            ["M", "Read it", "A star!", "Sticker", "First star", "W", "kat", "dog", "A new trophy!"],
        )

    def test_sheet_lines_and_habits(self):
        p = pack(
            sheets=[
                sheet(
                    [{"id": "a", "text": "Task"}],
                    intro="Hi",
                    restMessage="Rest",
                    weekGoal="Goal",
                    habits=[{"text": "Brush", "say": "Brush it"}, {"text": "Bath"}],
                )
            ]
        )
        self.assertEqual(
            render.collect([p], "en"),
            ["M", "Task", "Hi", "Rest", "Goal", "Brush it", "Bath", "A new trophy!"],
        )

    def test_app_phrases_english_only(self):
        self.assertIn("A new trophy!", render.collect([], "en"))
        self.assertNotIn("A new trophy!", render.collect([], "hi"))

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
        self.assertEqual(render.collect([p], "en"), ["M", "Kept", "Kept card", "A new trophy!"])

    def test_duplicates_render_once_in_first_order(self):
        first = pack(awards=[{"id": "a", "kind": "star", "label": "One"}, {"id": "b", "kind": "star", "label": "Two"}])
        second = pack(awards=[{"id": "c", "kind": "star", "label": "Three"}, {"id": "d", "kind": "star", "label": "One "}])
        self.assertEqual(render.collect([first, second], "en"), ["One", "Two", "Three", "A new trophy!"])

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
            ["M", "Task", "Book", "cat", "Tale", "aa-jee has a bit.", "aa-jee", "has", "a", "bit", "A new trophy!"],
        )


if __name__ == "__main__":
    unittest.main()
