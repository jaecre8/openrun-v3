"""Mixes narration over the BGM (with ducking) and muxes it into the video.

out/voice/*.wav + out/bgm.wav + out/review_video.mp4 → out/openrun_review_shorts.mp4
A line longer than its slot is sped up with ffmpeg atempo (at most 1.25x).
"""
import json
import subprocess

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

SR = 44100
MAX_TEMPO = 1.25

bgm, sr = sf.read("out/bgm.wav")
assert sr == SR
N = len(bgm)
voice = np.zeros(N)


def load_mono(path):
    x, sr = sf.read(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g)
    return x


def trim_silence(x, thresh=0.01):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(0.02 * SR))
    b = min(len(x), idx[-1] + int(0.08 * SR))
    return x[a:b]


starts = {l["id"]: l["start"] for l in json.load(open("timing.json"))["lines"]}
for line in json.load(open("narration.json")):
    line["start"] = starts[line["id"]]
    line["slot"] = 99  # scenes were sized to the voice; no time-stretching needed
    x = trim_silence(load_mono(f"out/voice/{line['id']}.wav"))
    dur = len(x) / SR
    if dur > line["slot"]:
        tempo = min(MAX_TEMPO, dur / line["slot"])
        sf.write("out/_tmp.wav", x, SR)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "out/_tmp.wav",
                        "-filter:a", f"atempo={tempo:.3f}", "out/_tmp2.wav"], check=True)
        x = load_mono("out/_tmp2.wav")
        print(f"{line['id']}: {dur:.2f}s → {len(x) / SR:.2f}s (x{tempo:.2f}) for a {line['slot']}s slot")
    else:
        print(f"{line['id']}: {dur:.2f}s fits {line['slot']}s")
    i = int(line["start"] * SR)
    x = x[: N - i]
    voice[i : i + len(x)] += x

# normalize the voice, then duck the music under it
voice *= 0.9 / max(1e-9, np.max(np.abs(voice)))
level = np.convolve(np.abs(voice), np.ones(int(0.03 * SR)) / int(0.03 * SR), "same")
active = (level > 0.02).astype(float)
# smooth: ~80 ms attack, ~350 ms release
duck = np.zeros(N)
a_att, a_rel = 1 / (0.08 * SR), 1 / (0.35 * SR)
g = 0.0
for k in range(0, N, 64):  # control rate
    target = active[k]
    g += (target - g) * min(1.0, 64 * (a_att if target > g else a_rel))
    duck[k : k + 64] = g
music_gain = 0.55 * (1 - 0.6 * duck)  # music at -5 dB, ducked a further ~8 dB under speech

mix = bgm * music_gain[:, None] + voice[:, None] * 1.0
mix = np.tanh(mix * 1.1) / np.tanh(1.1)
sf.write("out/mix.wav", mix.astype(np.float32), SR)

subprocess.run([
    "ffmpeg", "-y", "-loglevel", "error",
    "-i", "out/review_video.mp4", "-i", "out/mix.wav",
    "-filter:a", "loudnorm=I=-14:TP=-1.5:LRA=11",
    "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "44100",
    "-shortest", "-movflags", "+faststart", "out/openrun_review_shorts.mp4",
], check=True)
print("wrote out/openrun_review_shorts.mp4")
