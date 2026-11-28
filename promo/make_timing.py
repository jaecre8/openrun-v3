"""Builds the review video's timeline from the real narration lengths.

Each line starts after the previous one (plus a short gap) and each scene is kept at
least as long as its animation needs. Writes timing.json (for bgm.py / mix.py) and
timing.js (for review.html), with subtitles split into short chunks.
"""
import json
import re

import soundfile as sf

GAP = 0.35
SCENES = ["intro", "p1", "p2", "p3", "con", "end"]          # one scene per narration line
MIN_SCENE = {"intro": 3.2, "p1": 4.6, "p2": 3.6, "p3": 5.2, "con": 2.6, "end": 3.6}
TAIL = 1.4  # music/end card after the last word

# Subtitle chunks per line (** ** = highlighted); timed in proportion to their length.
SUBS = {
    "r1": ["오픈런 **만든 사람이 직접**,", "솔직하게 장점 **세 가지**만", "알려드릴게요."],
    "r2": ["첫째, 여러 커뮤니티 핫딜이", "**한 화면에** 모여요.", "같은 딜은 **하나로 묶여서**", "중복도 없어요."],
    "r3": ["둘째, 글을 안 열어도", "**가격**이랑 **쇼핑몰**, **배송비**가", "바로 보여요."],
    "r4": ["셋째, 키워드에", "**최대 가격**까지 걸어두면,", "조건에 맞는 딜이 뜰 때", "**바로 알림**이 와요."],
    "r5": ["아쉬운 점은,", "아직 **안드로이드만** 된다는 거예요."],
    "r6": ["구글 플레이스토어에서", "**오픈런** 검색해 보세요!"],
}


def voiced_span(path, thresh=0.01):
    x, sr = sf.read(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    idx = (abs(x) > thresh).nonzero()[0]
    return (len(x) / sr) if len(idx) == 0 else (idx[-1] - idx[0]) / sr + 0.1


lines = json.load(open("narration.json"))
t = 0.3
placed, scenes, subs = [], {}, []
for i, line in enumerate(lines):
    name = SCENES[i]
    scene_start = 0.0 if i == 0 else t - 0.1
    dur = voiced_span(f"out/voice/{line['id']}.wav")
    start, end = t, t + dur
    placed.append({"id": line["id"], "start": round(start, 3), "dur": round(dur, 3)})

    chunks = SUBS[line["id"]]
    weights = [len(re.sub(r"\*\*", "", c)) for c in chunks]
    a = start
    for c, w in zip(chunks, weights):
        b = a + dur * w / sum(weights)
        subs.append({"a": round(a, 3), "b": round(b + 0.15, 3), "text": c})
        a = b

    next_t = max(end + GAP, scene_start + MIN_SCENE[name] + 0.1)
    scenes[name] = [round(scene_start, 3), round(next_t - 0.1, 3)]
    t = next_t

duration = round(max(placed[-1]["start"] + placed[-1]["dur"] + TAIL, scenes["end"][0] + MIN_SCENE["end"]), 2)
scenes["end"][1] = duration
# last subtitle chunk of each line runs to the next line, but never past the video
for s in subs:
    s["b"] = min(s["b"], duration)

timing = {"duration": duration, "scenes": scenes, "lines": placed, "subs": subs}
json.dump(timing, open("timing.json", "w"), ensure_ascii=False, indent=1)
open("timing.js", "w").write("window.TIMING = " + json.dumps(timing, ensure_ascii=False) + ";\n")
for p in placed:
    print(f"{p['id']}: {p['start']:6.2f}s  +{p['dur']:.2f}s")
print("scenes:", scenes)
print("duration:", duration)
