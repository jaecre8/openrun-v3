"""Original upbeat BGM for the promo, synthesized from scratch (no samples, no licensed audio).

124 BPM, C-G-Am-F, four-on-the-floor. Light intro under the hook, full groove for the
app scenes, a drum break on "놓치면 품절", and a final hit for the store call-to-action.
Writes out/bgm.wav (44.1 kHz stereo).
"""
import json

import numpy as np
import soundfile as sf

# Scene times come from timing.json (make_timing.py), so the music follows the narration.
TIMING = json.load(open("timing.json"))
SC = TIMING["scenes"]

SR = 44100
DUR = TIMING["duration"]
BPM = 124
BEAT = 60 / BPM
N = int(SR * DUR)
rng = np.random.default_rng(7)

L = np.zeros(N)
R = np.zeros(N)


def add(sig, t, pan=0.0, gain=1.0):
    """Mix a mono signal at time t (seconds); pan -1..1."""
    i = int(t * SR)
    if i >= N:
        return
    sig = sig[: N - i] * gain
    L[i : i + len(sig)] += sig * np.sqrt((1 - pan) / 2) * 1.41
    R[i : i + len(sig)] += sig * np.sqrt((1 + pan) / 2) * 1.41


def env(n, attack=0.002, decay=0.2):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def freq(note):  # MIDI → Hz
    return 440.0 * 2 ** ((note - 69) / 12)


def kick():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18) * 0.9


def clap():
    n = int(0.22 * SR)
    noise = rng.standard_normal(n)
    # crude band-pass: difference of two smoothers
    hp = noise - np.convolve(noise, np.ones(8) / 8, "same")
    bp = np.convolve(hp, np.ones(3) / 3, "same")
    e = env(n, 0.001, 0.07) + 0.6 * env(n, 0.001, 0.012) * (np.arange(n) < SR * 0.02)
    return bp * e * 0.55


def hat(open_=False):
    n = int((0.18 if open_ else 0.05) * SR)
    noise = rng.standard_normal(n)
    hp = noise - np.convolve(noise, np.ones(4) / 4, "same")
    return hp * env(n, 0.0005, 0.06 if open_ else 0.015) * 0.22


def saw(f, n):
    t = np.arange(n) / SR
    return 2 * ((t * f) % 1.0) - 1


def lowpass(x, k):
    return np.convolve(x, np.ones(k) / k, "same")


def bass(note, length):
    n = int(length * SR)
    s = saw(freq(note), n) + 0.5 * np.sin(2 * np.pi * freq(note - 12) * np.arange(n) / SR)
    return lowpass(s, 24) * env(n, 0.004, length * 0.9) * 0.32


def pluck(note, length=0.22):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = freq(note)
    s = np.sign(np.sin(2 * np.pi * f * t)) * 0.5 + saw(f * 1.003, n) * 0.5
    return lowpass(s, 6) * env(n, 0.001, 0.09) * 0.16


def pad(notes, length):
    n = int(length * SR)
    t = np.arange(n) / SR
    s = sum(saw(freq(m), n) * 0.5 + saw(freq(m) * 1.006, n) * 0.5 for m in notes)
    a = np.clip(t / 0.25, 0, 1) * np.clip((length - t) / 0.3, 0, 1)
    return lowpass(s, 40) * a * 0.06


def riser(length=0.7):
    n = int(length * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    k = np.linspace(30, 2, n).astype(int)
    out = np.array([noise[max(0, i - k[i]) : i + 1].mean() for i in range(n)])
    hp = noise - out
    return hp * (t / length) ** 2 * 0.35


def impact():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (45 + 60 * np.exp(-t / 0.05)) * t) * np.exp(-t / 0.5)
    noise = rng.standard_normal(n) * np.exp(-t / 0.15) * 0.25
    return (boom + lowpass(noise, 4)) * 0.8


# C – G – Am – F, one chord per bar
CHORDS = [(48, [60, 64, 67, 72]), (43, [59, 62, 67, 71]), (45, [60, 64, 69, 72]), (41, [60, 65, 69, 72])]
BAR = BEAT * 4

GROOVE_START = SC["p1"][0]           # full groove from the app scenes
BREAK = (SC["con"][0], SC["end"][0])  # drums out on the honest downside
END_HIT = SC["end"][0]                # end card
CTA_HIT = END_HIT + 2.2               # "검색!" appears

t = 0.0
step = 0
while t < DUR:
    bar = int(t // BAR)
    root, chord = CHORDS[bar % 4]
    beat_in_bar = step % 16  # 16th notes
    in_break = BREAK[0] <= t < BREAK[1]
    full = GROOVE_START <= t < END_HIT and not in_break
    intro = t < GROOVE_START

    if beat_in_bar % 4 == 0 and (full or (intro and t > 0.9)):
        add(kick(), t, gain=1.0 if full else 0.7)
    if full and beat_in_bar in (4, 12):
        add(clap(), t, pan=0.05)
    if (full or intro) and beat_in_bar % 4 == 2:
        add(hat(open_=(beat_in_bar == 14)), t, pan=0.3)
    if full and beat_in_bar % 2 == 1:
        add(hat(), t, pan=-0.25, gain=0.6)
    if (full or in_break) and beat_in_bar % 2 == 0:
        add(bass(root + (12 if beat_in_bar % 4 == 2 else 0), BEAT / 2.2), t, gain=0.0 if in_break else 1.0)
    # arpeggiated plucks: 16ths in the groove, 8ths in the intro
    if full or (intro and beat_in_bar % 2 == 0) or in_break:
        note = chord[(step * 3) % 4] + (12 if beat_in_bar >= 8 else 0)
        add(pluck(note), t, pan=-0.35 if step % 2 else 0.35, gain=0.8 if intro else 1.0)
    if beat_in_bar == 0 and t < END_HIT:
        add(pad(chord, BAR), t, gain=0.8)
    t += BEAT / 4
    step += 1

# scene transitions: whoosh into each cut
for cut in (SC["p1"][0], SC["p2"][0], SC["p3"][0], SC["con"][0]):
    add(riser(0.7), cut - 0.7, gain=0.9)

# build-up out of the downside into the end card
add(riser(0.9), BREAK[1] - 0.9, gain=1.1)

# end card: big hit, a held bright chord, and a final hit on the call-to-action
add(impact(), END_HIT)
add(pad([60, 64, 67, 72, 76], DUR - END_HIT), END_HIT, gain=1.6)
for k, note in enumerate([72, 76, 79, 84]):
    add(pluck(note, 0.5), END_HIT + 0.15 + k * BEAT / 2, pan=(k - 1.5) / 3)
add(impact(), CTA_HIT, gain=0.7)
add(pluck(84, 1.2), CTA_HIT, gain=1.2)

# soft fade-in and fade-out, then normalize
fade = np.ones(N)
fade[: int(0.15 * SR)] = np.linspace(0, 1, int(0.15 * SR))
fade[-int(1.2 * SR) :] = np.linspace(1, 0, int(1.2 * SR))
mix = np.stack([L * fade, R * fade], axis=1)
mix = np.tanh(mix * 1.2)  # gentle saturation / limiter
mix *= 0.89 / np.max(np.abs(mix))
sf.write("out/bgm.wav", mix.astype(np.float32), SR)
print("wrote out/bgm.wav", mix.shape[0] / SR, "s")
