"""Korean female narration with Chatterbox Multilingual (MIT license, runs locally).

Reads narration.json, writes out/voice/<id>.wav per line and prints each clip's length
against its slot, plus a rough pitch estimate to confirm the voice.
"""
import json
import os

import numpy as np
import soundfile as sf
import torch
from chatterbox.mtl_tts import ChatterboxMultilingualTTS

device = "mps" if torch.backends.mps.is_available() else "cpu"
model = ChatterboxMultilingualTTS.from_pretrained(device=device)
os.makedirs("out/voice", exist_ok=True)

ref = os.environ.get("VOICE_REF")  # optional reference clip for the speaker


def pitch_hz(x, sr):
    """Median F0 of voiced 40 ms frames via autocorrelation (rough)."""
    f0 = []
    w = int(0.04 * sr)
    for i in range(0, len(x) - w, w):
        fr = x[i : i + w] - x[i : i + w].mean()
        if np.sqrt((fr**2).mean()) < 0.02:
            continue
        ac = np.correlate(fr, fr, "full")[w - 1 :]
        lo, hi = int(sr / 400), int(sr / 70)
        lag = lo + np.argmax(ac[lo:hi])
        if ac[lag] > 0.3 * ac[0]:
            f0.append(sr / lag)
    return float(np.median(f0)) if f0 else 0.0


for line in json.load(open("narration.json")):
    kwargs = dict(language_id="ko", exaggeration=0.6, cfg_weight=0.45, temperature=0.7)
    if ref:
        kwargs["audio_prompt_path"] = ref
    wav = model.generate(line["text"], **kwargs)
    audio = wav.squeeze(0).cpu().numpy()
    sf.write(f"out/voice/{line['id']}.wav", audio, model.sr)
    dur = len(audio) / model.sr
    print(f"{line['id']}: {dur:.2f}s (slot {line['slot']}s) pitch≈{pitch_hz(audio, model.sr):.0f}Hz  {line['text']}")
