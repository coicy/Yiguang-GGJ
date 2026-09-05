"""Build the licensed soundtrack without regenerating sound effects."""
from pathlib import Path
import html, json, re, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/audio/tools'))
import imageio_ffmpeg
import numpy as np
import soundfile as sf
SRC = ROOT / 'assets/source/audio'
OUT = ROOT / 'assets/runtime/audio/designed'
SR = 44100

def tracks():
    return json.loads((SRC / 'music_manifest.json').read_text(encoding='utf8'))

def music_catalog():
    return ''.join('<article data-key="music"><h3>Music / '+html.escape(t['title'])+' · '+html.escape(t['author'])+'</h3><audio controls preload="none" src="../../assets/runtime/audio/designed/music_'+t['id']+'.ogg" data-gain="-3"></audio></article>' for t in tracks()).replace('<article data-key="music">','<article id="music" data-key="music">',1)

def make_preview():
    excerpts = []
    timeline = []
    for index, track in enumerate(t for t in tracks() if t['id'] != 'explore'):
        x, _ = sf.read(OUT/('music_'+track['id']+'.ogg'),dtype='float32',always_2d=True)
        x = x[16*SR:28*SR].copy() * 10**(-3/20)
        n = int(.2*SR)
        x[:n] *= np.linspace(0,1,n)[:,None]
        x[-n:] *= np.linspace(1,0,n)[:,None]
        excerpts.append(x)
        timeline.append(dict(start_seconds=index*12,title=track['title'],author=track['author'],source_start_seconds=16))
    sf.write(ROOT/'build/audio/battle_music_preview.wav',np.concatenate(excerpts),SR,subtype='PCM_16')
    (ROOT/'build/audio/battle_music_preview.json').write_text(json.dumps(timeline,indent=2),encoding='utf8')

def build():
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    report = []
    for track in tracks():
        name = track['id']
        tmp = ROOT / 'build/audio' / ('music_'+name+'.wav')
        subprocess.run([ffmpeg,'-y','-v','error','-i',str(SRC/track['file']),'-af','loudnorm=I=-23:TP=-3:LRA=11','-ar',str(SR),'-ac','2',str(tmp)],check=True)
        x, _ = sf.read(tmp, dtype='float32', always_2d=True)
        if not track['loop']:
            # Non-looping compositions retain the original 1.2 s wrap treatment.
            active = np.flatnonzero(np.max(abs(x),axis=1)>.001)
            x = x[max(0,active[0]-441):min(len(x),active[-1]+441)]
            n = int(1.2*SR)
            blend = np.linspace(0,1,n)[:,None]
            seam = x[-n:]*(1-blend)+x[:n]*blend
            x = np.concatenate([x[n:-n],seam])
        # Preserve author loop duration and meter; correct only the final 3 ms
        # endpoint after loudness processing, without shortening the loop.
        n = 132
        ramp = np.linspace(0,1,n)[:,None]
        x[-n:] += (x[0]-x[-1])*ramp*ramp*(3-2*ramp)
        peak = float(abs(x).max())
        if peak > .7: x *= .7/peak
        out = OUT / ('music_'+name+'.ogg')
        subprocess.run([ffmpeg,'-y','-v','error','-f','f32le','-ar',str(SR),'-ac','2','-i','pipe:0','-c:a','libvorbis','-q:a','5',str(out)],input=x.astype('<f4').tobytes(),check=True)
        report.append(dict(file=out.name,kind='music',title=track['title'],seconds=round(len(x)/SR,3),author_loop=track['loop'],peak_db=round(20*np.log10(float(abs(x).max())),2)))
        print('Built', name, report[-1]['seconds'], 'seconds', flush=True)
        tmp.unlink()
    (ROOT/'build/audio/music_quality_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    make_preview()
    return report

if __name__ == '__main__':
    build()
    catalog = ROOT/'build/audio/listen.html'
    if catalog.exists():
        content = catalog.read_text(encoding='utf8')
        content = re.sub(r'<article(?: id="music")? data-key="music">.*?</article>', '', content, flags=re.S)
        content = content.replace('<script>',music_catalog()+'<script>',1)
        catalog.write_text(content,encoding='utf8')
