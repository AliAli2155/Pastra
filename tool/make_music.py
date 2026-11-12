# Synthesises the background music loop assets/sounds/music_1.m4a.
# Pure Python plus macOS `afconvert` (no samples, so no licence questions):
#     python3 tool/make_music.py [out.wav]
#
# A slow hasapiko-like tune in D minor (with the raised seventh C#), played on
# plucked strings made with the Karplus–Strong method: a bouzouki-like double
# course for the melody, a baglama/guitar for the "oom-pah" chords and a bass.
# Two passes of 16 bars; the second one adds tremolo, an octave string and
# off-beat chords. The reverb tail is wrapped onto the start, so it loops
# without a seam.
import math, os, random, struct, subprocess, sys, tempfile, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 32000
BPM = 88
BEAT = 60 / BPM
E8 = BEAT / 2
BAR = 4 * BEAT

NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def midi(name):
    pc = NAMES[name[0]]
    rest = name[1:]
    if rest[0] == '#':
        pc += 1; rest = rest[1:]
    elif rest[0] == 'b':
        pc -= 1; rest = rest[1:]
    return pc + 12 * (int(rest) + 1)


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def pluck(freq, dur, t60, tone, smooth=0.5, pick=0.14, gain=1.0, rng=random):
    """One plucked string (Karplus–Strong with an all-pass for exact tuning).

    tone: 0 = bright excitation … 0.9 = dark; smooth: loop filter weight
    (0.5 = classic averaging, lower = brighter, longer ringing highs)."""
    total = int((dur + 0.05) * SR)
    d = SR / freq - smooth
    n = int(d)
    frac = d - n
    if frac < 0.15:
        n -= 1; frac += 1
    c = (1 - frac) / (1 + frac)
    # Excitation: filtered noise with a pick-position notch.
    e = []
    lp = 0.0
    for _ in range(n):
        lp = tone * lp + (1 - tone) * rng.uniform(-1, 1)
        e.append(lp)
    m = max(1, int(n * pick))
    buf = [e[i] - (e[i - m] if i >= m else 0) for i in range(n)]
    mean = sum(buf) / n
    buf = [v - mean for v in buf]
    g = 10 ** (-3 / (freq * t60))
    out = [0.0] * total
    idx = 0
    last = 0.0
    ax = ay = 0.0
    a, b = 1 - smooth, smooth
    for i in range(total):
        x = buf[idx]
        out[i] = x
        y = g * (a * x + b * last)
        last = x
        ap = c * y + ax - c * ay
        ax = y; ay = ap
        buf[idx] = ap
        idx += 1
        if idx == n:
            idx = 0
    # Damp at the end of the note (a finger on the string).
    rel = min(int(0.05 * SR), total // 2)
    for i in range(rel):
        out[total - rel + i] *= (1 - i / rel) ** 2
    if gain != 1.0:
        out = [v * gain for v in out]
    return out


class Track:
    def __init__(self, seconds):
        self.y = [0.0] * int(seconds * SR)

    def add(self, x, t, gain):
        o = int(t * SR)
        y = self.y
        for i, v in enumerate(x):
            j = o + i
            if j >= len(y):
                break
            y[j] += v * gain


# ---------------------------------------------------------------- the tune
CHORDS = ['Dm', 'Dm', 'Gm', 'Dm', 'Bb', 'A', 'Dm', 'A',
          'F', 'C', 'Gm', 'Dm', 'Bb', 'A', 'Dm', 'Dm']
VOICING = {  # bass root, bass fifth, chord tones
    'Dm': ('D2', 'A2', ['D3', 'A3', 'D4', 'F4']),
    'Gm': ('G2', 'D3', ['G3', 'D4', 'G4', 'Bb4']),
    'Bb': ('Bb1', 'F2', ['Bb3', 'D4', 'F4', 'Bb4']),
    'A': ('A1', 'E2', ['A3', 'E4', 'A4', 'C#5']),
    'F': ('F2', 'C3', ['F3', 'C4', 'F4', 'A4']),
    'C': ('C2', 'G2', ['C3', 'G3', 'C4', 'E4']),
}
# Eight eighth notes per bar; '-' holds the note before, '.' is a rest.
MELODY = [
    'A4 - D5 E5 F5 - E5 D5',
    'E5 - C#5 D5 A4 - . .',
    'Bb4 - D5 G5 F5 - E5 D5',
    'F5 - E5 D5 A4 - . A4',
    'D5 - F5 D5 Bb4 - C5 D5',
    'C#5 - E5 C#5 A4 - Bb4 C#5',
    'D5 - F5 A5 G5 F5 E5 D5',
    'E5 - - - C#5 - A4 -',
    'A5 - G5 F5 C5 - F5 A5',
    'G5 - E5 C5 G4 - C5 E5',
    'D5 - G5 Bb5 A5 G5 F5 E5',
    'F5 - A5 F5 D5 - - .',
    'F5 - D5 F5 Bb5 A5 G5 F5',
    'E5 - C#5 E5 A5 G5 F5 E5',
    'D5 - A4 D5 F5 E5 C#5 E5',
    'D5 - - - - - - -',
]


def notes_of(bars):
    """[(start, length, midi)] in seconds from the start of the passage."""
    flat = []
    for b, bar in enumerate(bars):
        for k, tok in enumerate(bar.split()):
            flat.append((b * BAR + k * E8, tok))
    out = []
    for t, tok in flat:
        if tok == '-':
            if out and out[-1][2] is not None:
                s, l, m = out[-1]
                out[-1] = (s, l + E8, m)
            continue
        out.append((t, E8, None if tok == '.' else midi(tok)))
    return [n for n in out if n[2] is not None]


def render(path):
    rng = random.Random(7)
    passes = 2
    length = passes * len(MELODY) * BAR
    tail = 6.0
    melody = Track(length + tail)
    chords = Track(length + tail)
    bass = Track(length + tail)

    def jitter():
        return rng.uniform(0, 0.012)

    for p in range(passes):
        base = p * len(MELODY) * BAR
        notes = notes_of(MELODY)
        last_bar = len(MELODY) - 1
        for i, (t, l, m) in enumerate(notes):
            start = base + t
            final = p == passes - 1 and t >= last_bar * BAR
            dur = l + (4.0 if final else 0.03)
            vel = (1.0 if (t / E8) % 2 == 0 else 0.8) * rng.uniform(0.9, 1.05)
            f = hz(m)
            tremolo = p == 1 and l >= 2 * E8 and not final
            if tremolo:
                # Bouzouki tremolo: quick repeated picking on a long note.
                step = E8 / 4
                k = 0
                while k * step < l - 0.02:
                    v = vel * (0.78 if k % 2 == 0 else 0.62)
                    seg = min(step + 0.03, l - k * step + 0.03)
                    for det in (-2.5, 2.5):
                        melody.add(pluck(f * 2 ** (det / 1200), seg, 2.2, 0.25, 0.42, rng=rng),
                                   start + k * step + jitter(), v * 0.5)
                    k += 1
            else:
                for det in (-2.5, 2.5):
                    melody.add(pluck(f * 2 ** (det / 1200), dur, 6.0 if final else 2.4, 0.25, 0.42, rng=rng),
                               start + jitter(), vel * 0.5)
            if p == 1:  # octave string of the course, softly
                melody.add(pluck(f / 2, dur, 2.0, 0.4, 0.45, rng=rng), start + jitter(), vel * 0.18)
        for b, name in enumerate(CHORDS):
            root, fifth, tones = VOICING[name]
            t0 = base + b * BAR
            end = b == len(CHORDS) - 1
            if end and p == passes - 1:
                bass.add(pluck(hz(midi(root)), 5.5, 6.0, 0.85, 0.5, rng=rng), t0, 0.9)
                for k, tone in enumerate(tones):
                    chords.add(pluck(hz(midi(tone)), 5.0, 5.0, 0.6, 0.5, rng=rng), t0 + 0.02 + k * 0.03, 0.42)
                continue
            bass.add(pluck(hz(midi(root)), BEAT * 0.95, 1.6, 0.85, 0.5, rng=rng), t0 + jitter(), 0.9)
            bass.add(pluck(hz(midi(fifth)), BEAT * 0.95, 1.6, 0.85, 0.5, rng=rng), t0 + 2 * BEAT + jitter(), 0.8)
            hits = [(1, 0.55), (3, 0.5)]
            if p == 1:
                hits += [(3.5, 0.32)]
            if end:
                hits = [(1, 0.55), (2, 0.45), (3, 0.4)]
            for beat, v in hits:
                tb = t0 + beat * BEAT + jitter()
                down = rng.random() < 0.8
                order = tones if down else list(reversed(tones))
                for k, tone in enumerate(order):
                    chords.add(pluck(hz(midi(tone)), BEAT * 0.42, 1.0, 0.6, 0.5, rng=rng),
                               tb + k * 0.011, v * (1 - 0.08 * k) * 0.5)

    n = len(melody.y)
    dry = [melody.y[i] * 0.62 + chords.y[i] * 0.40 + bass.y[i] * 0.55 for i in range(n)]
    wet = reverb(dry)
    mixed = [dry[i] * 0.85 + wet[i] * 0.3 for i in range(n)]
    # Wrap the tail onto the start: a seamless loop.
    L = int(length * SR)
    out = mixed[:L]
    for i in range(L, n):
        out[i - L] += mixed[i]
    # Gentle high cut (a warmer, quieter background) and normalise.
    lp = 0.0
    for i in range(L):
        lp += 0.55 * (out[i] - lp)
        out[i] = lp
    peak = max(abs(v) for v in out)
    out = [v / peak * 0.8 for v in out]
    pcm = struct.pack('<%dh' % L, *(int(v * 32767) for v in out))
    if path.endswith('.wav'):
        with wave.open(path, 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)
    else:
        with tempfile.TemporaryDirectory() as tmp:
            src = tmp + '/m.wav'
            with wave.open(src, 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)
            subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '64000', src, path], check=True)
    print(path, round(length, 2), 's', os.path.getsize(path), 'bytes')


def reverb(x):
    """A small mono Freeverb (4 damped combs + 2 all-passes)."""
    scale = SR / 44100
    combs = [int(v * scale) for v in (1116, 1188, 1277, 1356)]
    out = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        store = 0.0
        for i, v in enumerate(x):
            o = buf[idx]
            store = o * 0.75 + store * 0.25
            buf[idx] = v + store * 0.8
            idx += 1
            if idx == d:
                idx = 0
            out[i] += o * 0.25
    for d in (int(556 * scale), int(441 * scale)):
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(out):
            b = buf[idx]
            buf[idx] = v + b * 0.5
            out[i] = b - v
            idx += 1
            if idx == d:
                idx = 0
    return out


if __name__ == '__main__':
    render(sys.argv[1] if len(sys.argv) > 1 else ROOT + '/assets/sounds/music_1.m4a')
