import os

os.environ["CUDA_VISIBLE_DEVICES"] = ""

import numpy as np
import torch
from kokoro import KPipeline

torch.set_num_threads(4)

SAMPLE_RATE = 24000
_pipelines: dict[str, KPipeline] = {}


def _words(tokens, offset: float):
    """Groups tokens into written words; returns (start, end) pairs or None if a time is missing."""
    words = []
    group = []
    for i, token in enumerate(tokens):
        group.append(token)
        if token.whitespace or i == len(tokens) - 1:
            spoken = [t for t in group if any(c.isalnum() for c in t.text)]
            group = []
            if not spoken:
                continue
            start, end = spoken[0].start_ts, spoken[-1].end_ts
            if start is None or end is None:
                return None
            words.append((offset + start, offset + end))
    return words


def render(text: str, voice: str, language: str, speed: float):
    lang_code = voice[0]
    if lang_code not in _pipelines:
        _pipelines[lang_code] = KPipeline(lang_code=lang_code, repo_id="hexgrad/Kokoro-82M", device="cpu")
    chunks = []
    words: list[tuple[float, float]] | None = []
    length = 0
    for result in _pipelines[lang_code](text, voice=voice, speed=speed):
        audio = result.audio.numpy()
        if words is not None:
            found = None if result.tokens is None else _words(result.tokens, length / SAMPLE_RATE)
            words = None if found is None else words + found
        chunks.append(audio)
        length += len(audio)
    return np.concatenate(chunks), SAMPLE_RATE, words
