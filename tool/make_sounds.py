# Builds assets/sounds/*.mp3 from the Kenney packs in tool/sounds_raw (needs ffmpeg + numpy):
#     python tool/make_sounds.py
import subprocess, numpy as np, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = ROOT + '/tool/sounds_raw'
OUT = ROOT + '/assets/sounds'
SR = 44100
C = RAW + '/kenney_casino-audio/Audio/'
I = RAW + '/kenney_interface-sounds/Audio/'
J = RAW + '/kenney_music-jingles/Audio/'
# name -> (source, peak, max seconds)
plan = {
  'play_1': (C + 'card-place-1.ogg', 0.95, 0.45), 'play_2': (C + 'card-place-2.ogg', 0.95, 0.45),
  'play_3': (C + 'card-place-3.ogg', 0.95, 0.45), 'play_4': (C + 'card-place-4.ogg', 0.95, 0.45),
  'deal_1': (C + 'card-slide-1.ogg', 0.7, 0.4), 'deal_2': (C + 'card-slide-2.ogg', 0.7, 0.4),
  'deal_3': (C + 'card-slide-3.ogg', 0.7, 0.4), 'deal_4': (C + 'card-slide-5.ogg', 0.7, 0.4),
  'capture_1': (C + 'card-shove-1.ogg', 0.95, 0.7), 'capture_2': (C + 'card-shove-4.ogg', 0.95, 0.7),
  'shuffle_1': (C + 'card-shuffle.ogg', 0.8, 1.6),
  'pastra_1': (J + 'Pizzicato jingles/jingles_PIZZI04.ogg', 0.8, 2.0),
  'win_1': (J + 'Steel jingles/jingles_STEEL02.ogg', 0.8, 2.0),
  'lose_1': (J + 'Pizzicato jingles/jingles_PIZZI01.ogg', 0.7, 2.0),
  'turn_1': (I + 'pluck_001.ogg', 0.5, 0.4),
  'tick_1': (I + 'tick_001.ogg', 0.6, 0.2),
}
def load(p):
    raw = subprocess.run(['ffmpeg','-v','quiet','-i',p,'-ac','1','-ar',str(SR),'-f','s16le','-'],capture_output=True,check=True).stdout
    return np.frombuffer(raw,dtype=np.int16).astype(np.float32)/32768
for name,(src,peak,maxs) in plan.items():
    x = load(src)
    thr = np.max(np.abs(x)) * 0.02
    idx = np.nonzero(np.abs(x) > thr)[0]
    x = x[max(0, idx[0] - int(0.004*SR)): idx[-1] + int(0.03*SR)]
    n = min(len(x), int(maxs*SR)); x = x[:n].copy()
    fade = min(n//3, int(0.08*SR)); x[-fade:] *= np.linspace(1,0,fade)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    pcm = (x*32767).astype(np.int16).tobytes()
    out = f'{OUT}/{name}.mp3'
    subprocess.run(['ffmpeg','-v','error','-y','-f','s16le','-ar',str(SR),'-ac','1','-i','-','-c:a','libmp3lame','-b:a','96k',out],input=pcm,check=True)
    print(name, round(n/SR,2), os.path.getsize(out))
