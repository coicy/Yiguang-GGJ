"""Measure decoded runtime assets; does not certify subjective sound quality."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/audio/tools'))
import numpy as np
import soundfile as sf
out=ROOT/'assets/runtime/audio/designed'
results=[]
failures=[]
for p in sorted(out.iterdir()):
    if p.suffix not in ['.wav','.ogg']: continue
    x,sr=sf.read(p,dtype='float32',always_2d=True)
    peak=float(np.max(np.abs(x))); rms=float(np.sqrt(np.mean(x*x)))
    finite=bool(np.all(np.isfinite(x))); clip=int(np.sum(np.abs(x)>=.999))
    step=float(np.max(np.abs(x[-1]-x[0])))
    kind='music' if p.stem.startswith('music') else ('loop' if p.stem.startswith('amb_') or p.stem.endswith('_loop') else 'sfx')
    row=dict(file=p.name,kind=kind,seconds=round(len(x)/sr,3),sample_rate=sr,peak_db=round(20*np.log10(max(peak,1e-9)),3),rms_db=round(20*np.log10(max(rms,1e-9)),3),dc=float(abs(x.mean())),clip_samples=clip,wrap_delta=step)
    if not finite or clip or peak>.9 or rms<.00001 or sr!=44100: failures.append(p.name)
    if kind=='sfx' and (np.max(abs(x[0]))>.01 or np.max(abs(x[-1]))>.01): failures.append(p.name+' edit boundary')
    if kind in ['music','loop'] and step>.03: failures.append(p.name+' loop discontinuity')
    results.append(row)
# Same event variations should not be exact copies.
recipes=json.loads((ROOT/'assets/source/audio/recipes.json').read_text())
for name,spec in recipes.items():
    waves=[sf.read(out/(name+'_'+str(v+1)+'.wav'))[0] for v in range(spec['variants'])]
    for a,b in zip(waves,waves[1:]):
        if np.array_equal(a,b): failures.append(name+' identical variations')
record=ROOT/'build/audio/in_game_mix.wav'
if record.exists():
    x,sr=sf.read(record,dtype='float32',always_2d=True)
    peak=float(abs(x).max()); rms=float(np.sqrt(np.mean(x*x)))
    clips=int(np.sum(abs(x)>=.999))
    row=dict(file=record.name,kind='captured_mix',seconds=round(len(x)/sr,2),peak_db=round(20*np.log10(max(peak,1e-9)),2),rms_db=round(20*np.log10(max(rms,1e-9)),2),clip_samples=clips)
    if clips or rms<.0001:failures.append('captured mix clipping/silent')
    results.append(row)
report=dict(assets=len(results),failures=failures,subjective_listening='Not performed by the agent. Signal checks cannot certify timbre, fatigue or musical phrasing.',results=results)
(ROOT/'build/audio/decoded_quality.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(dict(assets=len(results),failures=failures,music=[r for r in results if r['kind'] in ['music','captured_mix']]),indent=2))
sys.exit(1 if failures else 0)
