#!/usr/bin/env python3
"""Plinky audio generator. Everything is synthesised from scratch with numpy: no samples, no third-party
audio, so there is nothing to license. Output: assets/audio/{sfx,music,amb}/*.ogg (Vorbis, via ffmpeg).

    python3 tools/audio/gen_audio.py            # all
    python3 tools/audio/gen_audio.py sfx        # just sfx (also: music, amb, world, cinder)
    python3 tools/audio/gen_audio.py --wav      # keep wav next to ogg (for quick listening)

Style: "soft synth" (sines, light harmonics, gentle reverb). Pitches stay on C major pentatonic so
rapid pad presses never clash. Deterministic: seeded RNG, same bytes every run.
"""
import subprocess, sys, wave, os
import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")
SFX_GAIN = 0.55   # one-shots overlap heavily in play; keep each one modest
KEEP_WAV = "--wav" in sys.argv
rng = np.random.default_rng(22112026)

def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12)
def t_(d): return np.arange(int(d * SR)) / SR
def env_exp(n, attack=0.004, decay=0.2):
    t = np.arange(n) / SR
    a = np.minimum(t / max(attack, 1e-4), 1.0)
    return a * np.exp(-t / decay)
def fade(x, ms=8):
    n = min(int(ms / 1000 * SR), len(x) // 2)
    if n > 0:
        x[:n] *= np.linspace(0, 1, n); x[-n:] *= np.linspace(1, 0, n)
    return x

def fft_filter(x, lo=None, hi=None):
    """Brickwall-ish band filter in the frequency domain (smoothed edges)."""
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR); g = np.ones_like(f)
    if hi: g *= 1 / (1 + (f / hi) ** 4)
    if lo: g *= 1 - 1 / (1 + (f / lo) ** 4)
    return np.fft.irfft(X * g, len(x))

def reverb(x, secs=1.6, wet=0.25, damp=3500):
    n = int(secs * SR); t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t * (6.9 / secs))
    ir = fft_filter(ir, hi=damp); ir[0] = 0
    size = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    y *= np.max(np.abs(x)) / (np.max(np.abs(y)) + 1e-9) * 0.9
    out = np.zeros(size); out[:len(x)] += x * (1 - wet * 0.5); out += y * wet
    return out

def plink(midi, dur=0.5, bright=1.0, decay=0.16):
    """The signature sound: a soft glassy pluck. Fundamental + inharmonic-ish overtones that die faster."""
    t = t_(dur); f = hz(midi)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    x += 0.30 * bright * np.sin(2 * np.pi * f * 2.003 * t) * np.exp(-t / (decay * 0.55))
    x += 0.12 * bright * np.sin(2 * np.pi * f * 3.97 * t) * np.exp(-t / (decay * 0.25))
    x += 0.05 * bright * np.sin(2 * np.pi * f * 5.43 * t) * np.exp(-t / (decay * 0.12))
    x *= np.minimum(t / 0.002, 1)
    return fade(x, 3)

def pad_tone(midi, dur, att=1.2, rel=1.5, det=0.12):
    t = t_(dur); f = hz(midi); x = 0
    for d in (-det, 0, det):
        x = x + np.sin(2 * np.pi * f * 2 ** (d / 12 / 10) * t + rng.uniform(0, 6.28))
    x += 0.25 * np.sin(2 * np.pi * f * 2 * t)
    e = np.minimum(t / att, 1) * np.minimum((dur - t) / rel, 1)
    return x * np.clip(e, 0, 1) / 3.2

def place(buf, x, at):
    i = int(at * SR)
    if i >= len(buf): return
    m = min(len(x), len(buf) - i); buf[i:i + m] += x[:m]

def fold(buf, n):
    """Wrap everything past n back onto the start so a looped file has no seam."""
    out = buf[:n].copy(); i = n
    while i < len(buf):
        seg = buf[i:i + n]; out[:len(seg)] += seg; i += n
    return out

def norm(x, peak=0.7):
    return x / (np.max(np.abs(x)) + 1e-9) * peak

def write(path, x, stereo=None, q=5):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.asarray(x, dtype=float)
    if x.ndim == 1:
        x = fft_filter(x - x.mean(), lo=28)          # no DC offset, no sub-bass rumble
        if "/sfx/" in path.replace("\\", "/"): x = x * SFX_GAIN
        x = x[:, None]
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    wavp = path[:-4] + ".wav"
    with wave.open(wavp, "wb") as w:
        w.setnchannels(pcm.shape[1]); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wavp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    if not KEEP_WAV: os.remove(wavp)

PENT = [0, 2, 4, 7, 9]  # C major pentatonic, semitones

# ---------------------------------------------------------------- SFX
def sfx():
    d = os.path.join(ROOT, "sfx")
    # Pad press: ONE base note (C5). Audio.gd shifts pitch_scale up the pentatonic ladder with hold combo.
    write(f"{d}/pad_press.ogg", norm(reverb(plink(72, 0.45), 0.5, 0.12), 0.65))
    # Big / crit press: chord plink, low thump, sparkle on top
    t = t_(0.9)
    big = plink(60, 0.9, decay=0.3) + 0.8 * plink(67, 0.9, decay=0.28) + 0.7 * plink(76, 0.9, decay=0.26)
    thump = np.sin(2 * np.pi * (70 * np.exp(-t * 9) + 40) * t) * np.exp(-t / 0.12) * 0.8
    spark = np.zeros(len(t))
    for i, m in enumerate((88, 91, 95)): place(spark, plink(m, 0.3, decay=0.1) * 0.35, 0.05 + i * 0.045)
    write(f"{d}/pad_big.ogg", norm(reverb(big + thump + spark, 0.9, 0.2), 0.8))
    # Popup tick: tiny bright blip
    t = t_(0.05); tick = np.sin(2 * np.pi * 1760 * t) * np.exp(-t / 0.012) + 0.4 * np.sin(2 * np.pi * 3520 * t) * np.exp(-t / 0.006)
    write(f"{d}/popup_tick.ogg", norm(fade(tick, 2), 0.45))
    # Relic drops: arpeggio gets longer, higher and shimmerier per rarity
    tiers = [  # name, notes (midi), step, shimmer
        ("common",    [72, 76],                          0.07, 0.0),
        ("uncommon",  [72, 76, 79],                      0.07, 0.0),
        ("rare",      [72, 76, 79, 84],                  0.07, 0.1),
        ("epic",      [67, 72, 76, 79, 84],              0.075, 0.2),
        ("legendary", [60, 67, 72, 76, 79, 84, 88],      0.08, 0.35),
        ("mythic",    [60, 64, 67, 72, 76, 79, 84, 88, 91], 0.075, 0.5),
        ("divine",    [48, 60, 67, 72, 76, 79, 84, 88, 91, 96], 0.085, 0.7),
        ("special",   [60, 63, 67, 70, 75, 79, 82, 87, 91, 94], 0.07, 0.7),
    ]
    for i, (name, notes, step, shim) in enumerate(tiers):
        dur = 0.5 + step * len(notes) + i * 0.15
        buf = np.zeros(int(dur * SR))
        for k, m in enumerate(notes): place(buf, plink(m, 0.9, decay=0.2 + i * 0.03), k * step)
        if shim:
            last = len(notes) * step
            for k in range(int(6 + i * 3)):
                place(buf, plink(int(rng.choice([84, 88, 91, 96, 100])) + (0 if name != "special" else 1), 0.25, decay=0.07) * shim * 0.5,
                      last * 0.5 + rng.uniform(0, 0.5 + i * 0.1))
        if name in ("legendary", "mythic", "divine", "special"):
            buf += 0.35 * np.pad(pad_tone(notes[0], dur, 0.05, dur * 0.8), (0, len(buf) - int(dur * SR)))[:len(buf)]
        write(f"{d}/relic_{name}.ogg", norm(reverb(buf, 1.0 + i * 0.12, 0.18 + i * 0.015), 0.7 + i * 0.01))
    # Gate open: low stone rumble sliding up, then a chime
    dur = 2.2; t = t_(dur)
    rumble = fft_filter(rng.standard_normal(len(t)), lo=40, hi=260) * (np.minimum(t / 0.4, 1) * np.exp(-np.maximum(t - 0.8, 0) / 0.6))
    sweep = np.sin(2 * np.pi * np.cumsum(55 + 65 * np.minimum(t / 1.2, 1)) / SR) * np.minimum(t / 0.3, 1) * np.exp(-np.maximum(t - 1.0, 0) / 0.5) * 0.5
    chime = np.zeros(len(t))
    for k, m in enumerate((72, 79, 84, 88)): place(chime, plink(m, 1.2, decay=0.4), 1.0 + k * 0.1)
    write(f"{d}/gate_open.ogg", norm(reverb(rumble * 1.2 + sweep + chime * 0.8, 1.6, 0.25), 0.8))
    # Rebirth: inhale whoosh upward, then a big warm chord swell
    dur = 3.6; t = t_(dur)
    sh = fft_filter(rng.standard_normal(len(t)), lo=300, hi=6000)
    whoosh = sh * np.minimum(t / 1.6, 1) ** 2 * (t < 1.7) * 0.5
    sw = np.sin(2 * np.pi * np.cumsum(180 * 2 ** (np.minimum(t, 1.7) * 1.4)) / SR) * (t < 1.7) * np.minimum(t / 1.5, 1) ** 2 * 0.25
    buf = whoosh + sw
    for m in (48, 60, 64, 67, 72, 76, 79, 84): place(buf, pad_tone(m, 2.4, 0.15, 1.8) * 1.4, 1.7)
    for k, m in enumerate((72, 79, 84, 88, 91, 96)): place(buf, plink(m, 1.4, decay=0.5) * 0.6, 1.7 + k * 0.05)
    write(f"{d}/rebirth.ogg", norm(reverb(buf, 2.4, 0.3), 0.85))
    # UI
    t = t_(0.09); hov = np.sin(2 * np.pi * 1320 * t) * np.exp(-t / 0.02)
    write(f"{d}/ui_hover.ogg", norm(fade(hov, 3), 0.28))
    c = plink(79, 0.2, decay=0.05) * 0.8; t = t_(0.2)
    c += 0.5 * np.sin(2 * np.pi * 400 * t) * np.exp(-t / 0.03)
    write(f"{d}/ui_click.ogg", norm(fade(c, 3), 0.55))
    t = t_(0.2); back = np.sin(2 * np.pi * np.cumsum(900 - 400 * t / 0.2) / SR) * np.exp(-t / 0.05)
    write(f"{d}/ui_back.ogg", norm(fade(back, 3), 0.4))
    # Footsteps: soft grass/dirt thuds, 4 variants
    for i in range(4):
        t = t_(0.14)
        n = fft_filter(rng.standard_normal(len(t)), lo=200 + 80 * i, hi=1400 + 250 * i) * np.exp(-t / 0.03)
        th = np.sin(2 * np.pi * (95 + 7 * i) * t) * np.exp(-t / 0.035) * 0.6
        write(f"{d}/step_{i}.ogg", norm(fade(n + th, 3), 0.35))
    # Loading screen: soft looping arpeggio bubble (1.6s, seamless)
    notes = [72, 76, 79, 76, 74, 79, 83, 79]; dur = 1.6; buf = np.zeros(int((dur + 1.2) * SR))
    for k, m in enumerate(notes): place(buf, plink(m, 0.8, decay=0.18) * (0.9 if k % 2 == 0 else 0.6), k * dur / len(notes))
    buf = reverb(buf, 1.0, 0.25); loop = fold(buf, int(dur * SR))
    write(f"{d}/loading_loop.ogg", norm(loop, 0.5))

# ---------------------------------------------------------------- MUSIC
SECTION = [0.35, 1.0, 0.6, 1.0]   # melody density per chord group: verse/bridge feel, not a flat wall

def music(name, key, prog, bpm, bars, melody_p, seed):
    """prog: list of (root_midi, chord_intervals) one per 4-bar... per bar group; scale: pentatonic from key."""
    r = np.random.default_rng(seed)
    beat = 60 / bpm; bar = 4 * beat; dur = bars * bar
    buf = np.zeros(int((dur + 6) * SR))
    per = bars // len(prog)
    for gi, (root, ch) in enumerate(prog):
        at = gi * per * bar; span = per * bar
        for iv in ch: place(buf, pad_tone(root + 12 + iv, span + 2.5, 1.6, 2.2) * (0.35 + 0.3 * SECTION[gi % 4]), at)
        for b in range(per):  # soft bass: root on 1, fifth on 3
            place(buf, np.sin(2 * np.pi * hz(root - 12) * t_(bar * 0.5)) * env_exp(int(bar * 0.5 * SR), 0.03, 0.9) * 0.55, at + b * bar)
            place(buf, np.sin(2 * np.pi * hz(root - 5) * t_(bar * 0.4)) * env_exp(int(bar * 0.4 * SR), 0.03, 0.7) * 0.35, at + b * bar + 2 * beat)
        # arpeggio harp, 8ths, quiet
        for b in range(per):
            for s in range(8):
                if r.random() < 0.7:
                    m = root + 12 + ch[s % len(ch)] + (12 if s % 4 == 3 else 0)
                    place(buf, plink(m, 0.9, 0.5, 0.3) * 0.16, at + b * bar + s * beat / 2)
        # melody: pentatonic plucks, sparse, stepwise-ish
        cur = 7
        scale = [key + o + p for o in (12, 24) for p in PENT]
        for b in range(per):
            for s in range(8):
                if r.random() < melody_p * SECTION[gi % 4] * (1.0 if s % 2 == 0 else 0.45):
                    cur = int(np.clip(cur + r.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(scale) - 1))
                    place(buf, plink(scale[cur], 1.4, 0.8, 0.42) * 0.34, at + b * bar + s * beat / 2 + r.uniform(0, 0.012))
    buf = reverb(buf, 2.6, 0.38, damp=3000)
    loop = fold(buf, int(dur * SR))  # fold tail => seamless loop
    loop = fft_filter(loop, lo=35, hi=9000)
    tt = np.arange(len(loop)) / len(loop)
    loop *= 0.72 + 0.28 * np.cos(2 * np.pi * 2 * tt + 0.6)   # slow breathing swell, periodic so the loop stays seamless
    write(f"{ROOT}/music/{name}.ogg", norm(loop, 0.5) * 0.7, q=4)

def music_all():
    # Meadow: bright, slow, C major. Am7 / Fmaj7 / Cmaj7 / G6
    music("meadow", 48, [(48, [0, 4, 7, 11]), (45, [0, 3, 7, 10]), (41, [0, 4, 7, 11]), (43, [0, 4, 7, 9])], 76, 16, 0.55, 1)
    # Quarry: darker, sparser, D dorian-ish minor, lower pitched
    music("quarry", 50, [(50, [0, 3, 7, 10]), (46, [0, 4, 7, 11]), (48, [0, 4, 7, 11]), (45, [0, 3, 7, 10])], 64, 16, 0.38, 2)

# ---------------------------------------------------------------- AMBIENCE
def amb():
    dur = 24.0; n = int(dur * SR); t = np.arange(n) / SR
    wind = fft_filter(rng.standard_normal(n), lo=120, hi=900)
    lfo = 0.55 + 0.45 * np.sin(2 * np.pi * t / dur * 3 + 1) * np.sin(2 * np.pi * t / dur * 2)
    wind = wind * lfo * 0.5
    buf = wind.copy()
    for _ in range(14):  # bird chirps: quick rising/falling sine glides
        at = rng.uniform(0.5, dur - 1.5); base = rng.uniform(2400, 4200)
        for k in range(int(rng.integers(2, 5))):
            tt = t_(0.09); f = base * (1 + 0.25 * np.sin(np.pi * tt / 0.09)) * (1 + 0.1 * k)
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.09) ** 2
            place(buf, c * 0.05, at + k * 0.13)
    for _ in range(10):  # rustle
        at = rng.uniform(0, dur - 1); m = int(rng.uniform(0.2, 0.6) * SR)
        r_ = fft_filter(rng.standard_normal(m), lo=2000, hi=7000) * np.hanning(m) * 0.05
        place(buf, r_, at)
    # seamless: crossfade end into start
    xf = int(2 * SR); out = buf[:n - xf].copy(); out[:xf] = out[:xf] * np.linspace(0, 1, xf) + buf[n - xf:] * np.linspace(1, 0, xf)
    write(f"{ROOT}/amb/meadow_amb.ogg", norm(out, 0.2), q=3)
    # Quarry: hollow low wind + sparse drips
    wind = fft_filter(rng.standard_normal(n), lo=60, hi=420) * (0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 2)) * 0.6
    for _ in range(9):
        at = rng.uniform(0.5, dur - 1.5); tt = t_(0.35)
        place(wind, np.sin(2 * np.pi * (rng.uniform(900, 1500)) * tt) * np.exp(-tt / 0.04) * 0.12, at)
    wind = reverb(wind, 1.5, 0.35)[:n]
    out = wind[:n - xf].copy(); out[:xf] = out[:xf] * np.linspace(0, 1, xf) + wind[n - xf:] * np.linspace(1, 0, xf)
    write(f"{ROOT}/amb/quarry_amb.ogg", norm(out, 0.2), q=3)

# ---------------------------------------------------------------- WORLD (footsteps by surface, shore, birds)
# Own RNG so adding or changing these never shifts the bytes of the sounds above.
wrng = np.random.default_rng(23112026)

def world():
    d = os.path.join(ROOT, "sfx")
    for i in range(4):
        # Grass: soft low swish, a muffled thud underneath. Quietest of the three.
        t = t_(0.15)
        sw = fft_filter(wrng.standard_normal(len(t)), lo=260 + 40 * i, hi=1900 + 200 * i) * np.minimum(t / 0.012, 1) * np.exp(-t / 0.045)
        th = np.sin(2 * np.pi * (78 + 5 * i) * t) * np.exp(-t / 0.04) * 0.5
        write(f"{d}/step_grass_{i}.ogg", norm(fade(sw + th, 3), 0.3))
        # Sand: grainy crunch. Bright band noise broken into a few tiny grains, then a soft thud.
        t = t_(0.18); x = np.zeros(len(t))
        for k in range(int(wrng.integers(5, 9))):
            m = int(wrng.uniform(0.004, 0.011) * SR)
            g = fft_filter(wrng.standard_normal(m), lo=1500, hi=6500) * np.hanning(m)
            place(x, g * wrng.uniform(0.5, 1.0), wrng.uniform(0, 0.09))
        x += fft_filter(wrng.standard_normal(len(t)), lo=500, hi=2600) * np.exp(-t / 0.05) * 0.35
        x += np.sin(2 * np.pi * (88 + 6 * i) * t) * np.exp(-t / 0.035) * 0.45
        write(f"{d}/step_sand_{i}.ogg", norm(fade(x, 3), 0.32))
        # Wood: hollow knock, two resonances from the pentatonic set (G3, D4 area) and a tiny tick.
        t = t_(0.22)
        f0 = hz(55 + [0, 2, 4, 2][i])
        k_ = np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.07) + 0.45 * np.sin(2 * np.pi * f0 * 2.76 * t) * np.exp(-t / 0.035)
        k_ += 0.3 * fft_filter(wrng.standard_normal(len(t)), lo=1200, hi=4200) * np.exp(-t / 0.008)
        write(f"{d}/step_wood_{i}.ogg", norm(fade(k_, 3), 0.38))
    # Birdsong one-shots: soft sine chirps, five different phrases (played sparsely, random pitch).
    phrases = [  # (base Hz, notes, gap, glide)
        (3000, 2, 0.12, 0.30), (2500, 4, 0.09, 0.20), (3600, 3, 0.10, -0.25), (2200, 1, 0.0, 0.45), (3300, 6, 0.07, 0.10)]
    for i, (base, n, gap, gl) in enumerate(phrases):
        buf = np.zeros(int(1.2 * SR))
        for k in range(n):
            tt = t_(0.1); f = base * (1 + 0.04 * k) * (1 + gl * np.sin(np.pi * tt / 0.1))
            c = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.1) ** 2
            c += 0.2 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR) * np.sin(np.pi * tt / 0.1) ** 2
            place(buf, c * (1 - 0.08 * k), 0.02 + k * (gap + 0.1))
        write(f"{d}/bird_{i}.ogg", norm(reverb(buf, 0.7, 0.2), 0.3))
    # Shore: 20 s seamless loop of water lapping. Slow swells of low-passed noise plus a few soft bubbles.
    dur = 20.0; n = int(dur * SR); t = np.arange(n) / SR
    base = fft_filter(wrng.standard_normal(n), lo=180, hi=1500)
    swell = np.zeros(n)
    for c0 in np.arange(0.0, dur, 5.0):
        c = c0 + wrng.uniform(0.0, 1.2)
        swell += np.exp(-((t - c) / 1.0) ** 2) * wrng.uniform(0.7, 1.0)
    swell += 0.25
    wave = base * swell
    for _ in range(26):
        tt = t_(0.09); f = wrng.uniform(500, 1300) * (1 + 0.8 * tt / 0.09)
        place(wave, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.025) * wrng.uniform(0.02, 0.06) * np.max(np.abs(wave)), wrng.uniform(0, dur - 0.2))
    xf = int(2 * SR); out = wave[:n - xf].copy(); out[:xf] = out[:xf] * np.linspace(0, 1, xf) + wave[n - xf:] * np.linspace(1, 0, xf)
    write(f"{ROOT}/amb/shore_amb.ogg", norm(out, 0.2), q=3)

# ---------------------------------------------------------------- CINDER (Ember Quarry footsteps)
# Own RNG again, so these never shift the bytes of anything above.
crng = np.random.default_rng(23112027)

def cinder():
    d = os.path.join(ROOT, "sfx")
    for i in range(4):
        # Cinder: loose, dry rock. Fewer, harder grains than sand (lower band, longer), a clink or two, a dull thud.
        t = t_(0.2); x = np.zeros(len(t))
        for k in range(int(crng.integers(4, 7))):
            m = int(crng.uniform(0.006, 0.016) * SR)
            g = fft_filter(crng.standard_normal(m), lo=900, hi=4200) * np.hanning(m)
            place(x, g * crng.uniform(0.4, 1.0), crng.uniform(0, 0.1))
        for k in range(int(crng.integers(1, 3))):   # small stones knocking together
            tt = t_(0.03); f = crng.uniform(1900, 3400)
            place(x, np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.006) * crng.uniform(0.15, 0.3), crng.uniform(0.01, 0.09))
        x += fft_filter(crng.standard_normal(len(t)), lo=300, hi=1800) * np.exp(-t / 0.04) * 0.3
        x += np.sin(2 * np.pi * (72 + 5 * i) * t) * np.exp(-t / 0.04) * 0.5
        write(f"{d}/step_cinder_{i}.ogg", norm(fade(x, 3), 0.34))

if __name__ == "__main__":
    what = [a for a in sys.argv[1:] if not a.startswith("--")] or ["sfx", "music", "amb", "world", "cinder"]
    if "cinder" in what: cinder()
    if "sfx" in what: sfx()
    if "music" in what: music_all()
    if "amb" in what: amb()
    if "world" in what: world()
    print("done ->", os.path.normpath(ROOT))
