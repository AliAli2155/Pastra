# Builds the newer sounds in assets/sounds from the Kenney packs in tool/sounds_raw.
# Pure Python plus macOS `afconvert` (no ffmpeg/numpy needed):
#     python3 tool/make_sounds_extra.py
# Short table sounds are written as .wav (no decoder delay, plays everywhere),
# jingles as .m4a (AAC).
import os, struct, subprocess, tempfile, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = ROOT + '/tool/sounds_raw'
OUT = ROOT + '/assets/sounds'
C = RAW + '/kenney_casino-audio/Audio/'
J = RAW + '/kenney_music-jingles/Audio/'
SR = 32000


def load(path, sr=SR):
    with tempfile.TemporaryDirectory() as tmp:
        out = tmp + '/x.wav'
        subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@%d' % sr, '-c', '1', path, out], check=True)
        with wave.open(out) as w:
            n = w.getnframes()
            return [v / 32768 for v in struct.unpack('<%dh' % n, w.readframes(n))]


def trim(x, max_s, sr=SR, fade_s=0.08):
    peak = max(abs(v) for v in x)
    idx = [i for i, v in enumerate(x) if abs(v) > peak * 0.02]
    x = x[max(0, idx[0] - int(0.004 * sr)): idx[-1] + int(0.03 * sr)]
    x = x[: int(max_s * sr)]
    fade = min(len(x) // 3, int(fade_s * sr))
    for i in range(fade):
        x[len(x) - fade + i] *= 1 - i / fade
    return x


def mix(*parts, sr=SR):
    """parts: (samples, start seconds, gain)."""
    n = max(int(t * sr) + len(s) for s, t, _ in parts)
    y = [0.0] * n
    for s, t, g in parts:
        o = int(t * sr)
        for i, v in enumerate(s):
            y[o + i] += v * g
    return y


def norm(x, peak):
    m = max(abs(v) for v in x) or 1
    return [v / m * peak for v in x]


def write(name, x, sr=SR):
    pcm = struct.pack('<%dh' % len(x), *(max(-32767, min(32767, int(v * 32767))) for v in x))
    if name.endswith('.wav'):
        path = OUT + '/' + name
        with wave.open(path, 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(pcm)
    else:
        with tempfile.TemporaryDirectory() as tmp:
            src = tmp + '/x.wav'
            with wave.open(src, 'wb') as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes(pcm)
            path = OUT + '/' + name
            subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '96000', src, path], check=True)
    print(name, round(len(x) / sr, 2), 's', os.path.getsize(path), 'bytes')


# More variants of the table sounds.
write('capture_3.wav', norm(trim(load(C + 'card-shove-2.ogg'), 0.7), 0.95))
write('capture_4.wav', norm(trim(load(C + 'card-shove-3.ogg'), 0.7), 0.95))
write('deal_5.wav', norm(trim(load(C + 'card-slide-4.ogg'), 0.4), 0.7))
write('deal_6.wav', norm(trim(load(C + 'card-slide-6.ogg'), 0.4), 0.7))
# Chips for rewards (end of game, store, quests).
write('coins_1.wav', norm(trim(load(C + 'chips-stack-3.ogg'), 0.45, fade_s=0.05), 0.8))
write('coins_2.wav', norm(trim(load(C + 'chips-handle-1.ogg'), 0.6, fade_s=0.08), 0.8))
# Pastra with a jack: the usual pastra pluck, then a rising sax run (both in D).
SJ = 44100
pastra = trim(load(J + 'Pizzicato jingles/jingles_PIZZI04.ogg', SJ), 2.0, SJ)
run = trim(load(J + 'Sax jingles/jingles_SAX10.ogg', SJ), 2.0, SJ)
write('jackpastra_1.m4a', norm(mix((pastra, 0, 1.0), (run, 0.16, 0.85), sr=SJ), 0.85), SJ)
# Level up: a rising steel-drum figure.
write('levelup_1.m4a', norm(trim(load(J + 'Steel jingles/jingles_STEEL10.ogg', SJ), 2.0, SJ), 0.8), SJ)
