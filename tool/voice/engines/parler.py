import os

os.environ["CUDA_VISIBLE_DEVICES"] = ""

import soxr
import torch
from parler_tts import ParlerTTSForConditionalGeneration
from transformers import AutoTokenizer

from render import trim_silence

torch.set_num_threads(4)

SAMPLE_RATE = 24000
_model = ParlerTTSForConditionalGeneration.from_pretrained("ai4bharat/indic-parler-tts").to("cpu")
_text_tokenizer = AutoTokenizer.from_pretrained("ai4bharat/indic-parler-tts")
_description_tokenizer = AutoTokenizer.from_pretrained(_model.config.text_encoder._name_or_path)


def render(text: str, voice: str, language: str, speed: float):
    """voice is the Parler description, which names the speaker. The description sets the pace, so speed is not used."""
    description = _description_tokenizer(voice, return_tensors="pt")
    prompt = _text_tokenizer(text, return_tensors="pt")
    with torch.no_grad():
        generated = _model.generate(
            input_ids=description.input_ids,
            attention_mask=description.attention_mask,
            prompt_input_ids=prompt.input_ids,
            prompt_attention_mask=prompt.attention_mask,
        )
    audio = generated.cpu().numpy().squeeze()
    samples = soxr.resample(audio, _model.config.sampling_rate, SAMPLE_RATE)
    return trim_silence(samples, SAMPLE_RATE), SAMPLE_RATE, None
