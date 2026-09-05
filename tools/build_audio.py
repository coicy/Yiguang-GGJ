"""Rebuild authored sample layers and listening catalog. See docs/audio_design.md.
Offline only: numpy, scipy, soundfile, imageio-ffmpeg. No inference service used.
"""
from pathlib import Path
import sys, json, io, subprocess, zipfile
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/audio/tools'))
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, resample_poly
import imageio_ffmpeg
SRC=ROOT/'assets/source/audio'
OUT=ROOT/'assets/runtime/audio/designed'
OUT.mkdir(parents=True, exist_ok=True)
SR=44100
rng=np.random.default_rng(906)
cache={}
recipes={}
report=[]
def source(key):
    if key in cache: return cache[key].copy()
    pack, name=key.split(':')
    p=ROOT/'assets/runtime/audio'/name if pack=='old' else SRC/pack/(('sfx100v2_' if pack=='foley' else '')+name+'.ogg')
    x,sr=sf.read(p,always_2d=True,dtype='float32')
    x=x.mean(axis=1)
    if sr!=SR: x=resample_poly(x,SR,sr)
    # Remove empty pre-roll so gameplay transient follows its event.
    active=np.flatnonzero(abs(x)>max(.0006,float(abs(x).max())*.004))
    if len(active): x=x[max(0,active[0]-220):min(len(x),active[-1]+660)]
    x=x-np.mean(x)
    peak=max(.0001,float(abs(x).max()))
    x=x/peak
    cache[key]=x
    return x.copy()
def layer(key,gain=1,rate=1,delay=0,low=10000,high=65,reverse=False):
    return dict(source=key,gain=gain,rate=rate,delay=delay,low=low,high=high,reverse=reverse)
def cue(name,layers,db=-2,priority=1,cooldown=.07,variants=3,duration=1.2):
    recipes[name]=dict(layers=layers,db=db,priority=priority,cooldown=cooldown,variants=variants,duration=duration)
def R(n,**kw): return layer('rpg:'+n,**kw)
def F(n,**kw): return layer('foley:'+n,**kw)
def W(n,**kw): return layer('water:'+n,**kw)
def O(n,**kw): return layer('old:'+n+'.ogg',**kw)
# Player: leaf/fibre attack + close transient + quiet sap tail.
for form,rate,body in [('humanoid',1.15,.24),('mature',.79,.48)]:
    for i,(attack,blade) in enumerate([('light_1','blade_01'),('light_2','blade_02'),('light_3','blade_03'),('heavy','blade_03'),('air','blade_02')]):
        heavy=attack in ['heavy','light_3']
        cue(form+'_'+attack,[R(blade,rate=rate*(.88 if heavy else 1),low=7000),R('wood_0'+str(1+i%3),gain=body,delay=.02,rate=.85),W('slime_0'+str(1+i%4),gain=.15,rate=1.5,delay=.05)],db=0 if heavy else -2,duration=.55 if heavy else .38)
cue('swing',[R('blade_01'),R('wood_01',gain=.2)],duration=.4)
cue('hit',[R('wood_02',gain=.85,rate=1.3),W('slime_03',gain=.45,rate=1.5)],duration=.35)
cue('heavy_hit',[F('hit_02',rate=.8),R('wood_03',gain=.65,rate=.8),W('slime_07',gain=.35,delay=.025)],db=0,priority=2,duration=.7)
cue('guard',[R('metal_01',rate=1.1),R('chain_01',gain=.25)],priority=2,duration=.42)
cue('block',[R('metal_02',rate=.8),F('metal_hit_01',gain=.3)],priority=2,duration=.5)
cue('parry',[R('metal_03',rate=1.5),R('item_gem_01',gain=.75,delay=.018),F('hit_01',gain=.3)],db=1,priority=3,duration=.9)
cue('parry_ready',[R('blade_02',gain=.6,rate=1.5),O('cloth1',gain=.2)],db=-6,duration=.22)
cue('dash',[F('air_01',rate=1.6),R('book_02',gain=.35,rate=1.3)],duration=.32)
cue('hurt',[R('wood_04'),W('slime_02',gain=.4)],priority=3,duration=.38)
cue('jump',[R('book_01',rate=1.6),O('footstep_grass_001',gain=.3,rate=1.1)],db=-5,duration=.24)
cue('land',[O('footstep_grass_000'),F('hit_01',gain=.28,low=2000)],db=-5,duration=.25)
cue('land_heavy',[F('hit_03',rate=.8),O('footstep_grass_002',gain=.65),R('wood_01',gain=.18)],db=-1,duration=.48)
for name,base in [('step_grass','footstep_grass'),('step_hard','footstep_concrete')]:
    cue(name,[O(base+'_000')],db=-10,priority=0,cooldown=.15,duration=.22)
cue('step_wood',[F('footstep_wood_01')],db=-10,priority=0,cooldown=.15,duration=.22)
cue('step_metal',[F('metal_hit_01',rate=1.5,low=5000),O('footstep_concrete_001',gain=.6)],db=-12,priority=0,cooldown=.15,duration=.2)
cue('grow',[R('spell_01',rate=1.15,low=6500),R('wood_03',gain=.3,rate=.7),W('bubble_02',gain=.2,delay=.16)],priority=3,variants=1,duration=1.5)
cue('wither',[R('spell_02',rate=.65,low=5000),R('wood_05',gain=.4,reverse=True)],priority=3,variants=1,duration=1.5)
cue('absorb',[W('bubble_01',rate=1.3),R('item_gem_02',gain=.18)],db=-12,cooldown=.6,duration=.48)
cue('absorb_toxin',[W('slime_12',rate=.8),W('bubble_03',gain=.5,rate=.7)],db=-11,cooldown=.6,duration=.6)
cue('root',[R('wood_04',rate=.7),F('stones_01',gain=.3)],db=-4,duration=.55)
cue('unroot',[R('wood_01',reverse=True,rate=1.3),W('slime_06',gain=.4)],db=-5,duration=.35)
cue('extend',[R('wood_05',rate=.8),R('book_03',gain=.4)],db=-7,duration=.65)
cue('retract',[R('wood_05',rate=1.3,reverse=True)],db=-7,duration=.5)
cue('vine_launch',[R('blade_02',rate=1.2),W('slime_05',gain=.4,rate=1.3)],db=-2,duration=.38)
cue('vine',[R('wood_03',rate=1.1),R('chain_02',gain=.12)],db=-4,duration=.35)
cue('vine_release',[R('wood_02',rate=1.5),R('book_04',gain=.4,reverse=True)],db=-6,duration=.3)
cue('glide',[R('book_04',rate=.8),F('air_02',gain=.5)],db=-7,duration=.7)
cue('glide_end',[R('book_01',rate=1.2,reverse=True)],db=-9,duration=.25)
cue('vine_climb',[R('wood_01',gain=.6,rate=1.3),R('chain_01',gain=.08)],db=-12,priority=0,cooldown=.32,duration=.2)
cue('death',[R('wood_05',rate=.65),R('spell_02',gain=.45,rate=.6),W('slime_15',gain=.2)],db=0,priority=3,variants=1,duration=1.5)
# Creatures: each family keeps a recognisable material and envelope.
profiles={
'beetle': ('creature_misc_03','creature_hurt_01','creature_die_01','wood_02',1.35),
'spore': ('creature_slime_01','creature_slime_03','creature_slime_04','spell_02',.9),
'pruner': ('chain_03','metal_02','metal_03','blade_03',.85),
'warden': ('creature_roar_03','creature_monster_03','creature_roar_02','wood_05',.63)}
for family,(voice,hurt,death,material,rate) in profiles.items():
    cue(family+'_notice',[R(voice,rate=rate),R(material,gain=.35,rate=rate)],db=-3,cooldown=.8,duration=1.05)
    cue(family+'_warning',[R(voice,rate=rate*1.15),R(material,gain=.5,rate=rate,reverse=True)],db=-1,priority=2,cooldown=.18,duration=.5)
    cue(family+'_danger',[R(voice,rate=rate*.85),R(material,gain=.7,rate=rate)],db=1,priority=3,cooldown=.18,duration=.8)
    cue(family+'_attack',[R(material,rate=rate),R(voice,gain=.25,rate=rate*1.3)],db=-1,duration=.48)
    cue(family+'_hurt',[R(hurt,rate=rate),R(material,gain=.25,rate=1.2)],db=-4,cooldown=.12,duration=.4)
    cue(family+'_death',[R(death,rate=rate),R(material,gain=.7,rate=rate),F('stones_03',gain=.25,delay=.15)],db=-1,priority=2,variants=2,duration=1.25)
    cue(family+'_step',[R(material,rate=rate*1.3,low=3300),O('footstep_grass_001',gain=.5)],db=-14,priority=0,cooldown=.2,duration=.18)
cue('beetle_charge',[R('creature_monster_01',rate=1.5),R('wood_01',gain=.5)],duration=.55)
cue('beetle_bite',[R('wood_03',rate=1.8),R('creature_misc_02',gain=.5,rate=1.5)],duration=.3)
cue('spore_lash',[W('slime_04'),R('blade_01',gain=.4)],duration=.5)
cue('spore_shot',[W('bubble_03',rate=1.4),W('splash_03',gain=.5,rate=1.4)],duration=.36)
cue('spore_burst',[W('slime_11'),W('splash_07',gain=.6)],duration=.42)
cue('spore_reflect',[W('bubble_02',rate=1.7),R('item_gem_03',gain=.4)],priority=2,duration=.45)
cue('pruner_slash',[R('blade_03'),R('chain_02',gain=.45)],duration=.42)
cue('pruner_lunge',[R('blade_01',rate=.85),R('chain_03',gain=.5)],duration=.55)
cue('pruner_slam',[F('metal_hit_02',rate=.8),F('hit_02',gain=.7),R('chain_01',gain=.25,delay=.06)],priority=2,duration=.65)
cue('warden_slash',[R('blade_03',rate=.66),R('wood_04',gain=.6,rate=.7)],duration=.65)
cue('warden_charge',[R('creature_monster_04',rate=.72),R('wood_05',gain=.45,rate=.65)],duration=.75)
cue('warden_slam',[F('hit_03',rate=.58),R('wood_05',gain=.75,rate=.6),F('stones_02',gain=.6,delay=.08)],db=1,priority=3,duration=1.0)
cue('warden_phase',[R('creature_roar_01',rate=.63),F('metal_05',gain=.35,rate=.7),R('wood_04',gain=.6)],db=1,priority=3,variants=1,duration=1.7)
cue('warning',[R('creature_misc_03',rate=1.3)],priority=2,duration=.5)
cue('danger',[R('creature_roar_03',rate=.75)],priority=3,duration=.8)
cue('enemy_death',[R('creature_die_01')],priority=2,duration=1)
# Functional modules and lifecycle/UI confirmations.
cue('button',[F('switch_01'),R('lock_01',gain=.25)],db=-3,duration=.3)
cue('mechanism_start',[F('door_01',rate=.8),R('chain_02',gain=.5)],db=-5,duration=.8)
cue('mechanism_stop',[F('wood_hit_02'),R('lock_03',gain=.5)],db=-5,duration=.4)
cue('gate_open',[F('door_02',rate=.7),R('chain_03',gain=.5)],db=-3,duration=1)
cue('gate_close',[F('door_03',rate=.8),F('metal_hit_01',gain=.4)],db=-3,duration=.6)
cue('tank_start',[W('bubble_02'),R('lock_01',gain=.2)],db=-9,duration=.45)
cue('tank_stop',[W('bubble_01',rate=.8),F('switch_02',gain=.3)],db=-10,duration=.35)
cue('toxin_enter',[W('slime_10',rate=.7),F('air_03',gain=.4)],db=-7,duration=.7)
cue('thorn',[R('wood_03',rate=1.8),W('slime_08',gain=.4)],db=-2,priority=2,duration=.35)
cue('checkpoint',[R('item_gem_02'),R('spell_01',gain=.3,rate=1.3)],db=-4,priority=3,variants=1,duration=1.15)
cue('encounter_clear',[R('spell_01',rate=1.2),R('item_gem_04',gain=.5,delay=.12)],db=-3,priority=3,variants=1,duration=1.4)
cue('victory',[R('spell_01',rate=.85),R('item_gem_02',gain=.55),R('item_gem_04',gain=.6,delay=.32)],db=-1,priority=3,variants=1,duration=2)
cue('ui_open',[F('switch_01',rate=.85),R('book_02',gain=.15)],db=-7,variants=1,duration=.2)
cue('ui_confirm',[F('switch_02'),R('item_gem_01',gain=.15)],db=-7,variants=1,duration=.22)
cue('ui_focus',[F('switch_02',rate=1.6,low=4000)],db=-15,priority=0,cooldown=.09,variants=1,duration=.1)
cue('respawn',[R('spell_02',rate=1.4,reverse=True),W('bubble_02',gain=.2)],db=-6,priority=3,variants=1,duration=.8)
def render(spec,v):
    length=int(spec['duration']*SR); y=np.zeros(length,dtype=np.float32)
    for j,l in enumerate(spec['layers']):
        key=l['source']
        if key.startswith('old:footstep_grass_'): key='old:footstep_grass_00'+str(v%3)+'.ogg'
        if key.startswith('old:footstep_concrete_'): key='old:footstep_concrete_00'+str(v%2)+'.ogg'
        if key=='foley:footstep_wood_01': key='foley:footstep_wood_0'+str(v+1)
        x=source(key)
        if l['reverse']: x=x[::-1].copy()
        rate=l['rate']*(1+(v-1)*.035 if spec['variants']>1 else 1)
        x=np.interp(np.arange(0,len(x)-1,rate),np.arange(len(x)),x).astype(np.float32)
        x=sosfilt(butter(2,[l['high'],l['low']],fs=SR,btype='bandpass',output='sos'),x)
        start=int((l['delay']+v*.002*j)*SR); n=min(len(x),length-start)
        if n>0: y[start:start+n]+=x[:n]*l['gain']
    y-=np.mean(y)
    # Short fades remove edit clicks; preserve the initial transient.
    n=min(100,len(y));y[:n]*=np.linspace(0,1,n)
    n=min(int(.045*SR),len(y));y[-n:]*=np.linspace(1,0,n)
    y=np.tanh(y*1.12)
    y*=10**(-3/20)/max(1e-6,float(abs(y).max()))
    # Trim silent tail, leaving 20 ms of release, never pad every cue with silence.
    active=np.flatnonzero(abs(y)>.001)
    if len(active): y=y[:min(len(y),active[-1]+882)]
    y[-100:]*=np.linspace(1,0,min(100,len(y)))
    return y.astype(np.float32)
def save(name,y,kind='sfx'):
    sf.write(OUT/(name+'.wav'),y,SR,subtype='PCM_16')
    peak=float(abs(y).max());rms=float(np.sqrt(np.mean(y*y)))
    assert np.isfinite(y).all() and peak<.95 and rms>.00001,name
    report.append(dict(file=name+'.wav',kind=kind,seconds=round(len(y)/SR,3),peak_db=round(20*np.log10(peak),2),rms_db=round(20*np.log10(rms),2)))
for name,spec in recipes.items():
    print('Rendering',name,flush=True)
    for v in range(spec['variants']): save(name+'_'+str(v+1),render(spec,v))
# Quiet continuous textures from recorded CC0 sources, overlapped at the wrap.
def loopify(x,seconds=None,fade=.2):
    if seconds:
        while len(x)<seconds*SR: x=np.concatenate([x,x])
        x=x[:int(seconds*SR)]
    n=min(int(fade*SR),len(x)//4)
    blend=np.linspace(0,1,n)
    if x.ndim==2: blend=blend[:,None]
    seam=x[-n:]*(1-blend)+x[:n]*blend
    return np.concatenate([x[n:-n],seam])
for name,key in [('amb_greenhouse','foley:loop_ambient_01'),('amb_canopy','foley:air_02'),('amb_machine','foley:loop_machine_02'),('amb_water','water:loop_water_01'),('amb_toxin','water:loop_bubbles_02'),('glide_loop','foley:air_01'),('mechanism_loop','foley:loop_machine_01')]:
    x=source(key);x=sosfilt(butter(2,4200,fs=SR,output='sos'),x)
    x=loopify(x,seconds=9,fade=.5);x*=.32/max(.0001,float(abs(x).max()))
    save(name,x,kind='loop')
# The soundtrack has its own manifest and can also be rebuilt independently.
from build_music import build as build_music, music_catalog, tracks
report.extend(build_music())
# Static preloads make exported dependencies explicit and avoid loading on attack.
lines=['class_name AudioPalette','extends RefCounted','## Generated by tools/build_audio.py. Recipes are the editable source.','const CUES := {']
for name,spec in recipes.items():
    files=', '.join('preload("res://assets/runtime/audio/designed/'+name+'_'+str(v+1)+'.wav")' for v in range(spec['variants']))
    bus='UI' if name.startswith('ui_') or name in ['victory','checkpoint','encounter_clear','respawn'] else 'SFX'
    lines.append('	&"'+name+'": {"files": ['+files+'], "db": '+str(float(spec['db']))+', "priority": '+str(spec['priority'])+', "cooldown": '+str(spec['cooldown'])+', "bus": &"'+bus+'"},')
lines+=['}','']
(ROOT/'features/audio/audio_palette.gd').write_text('\n'.join(lines),encoding='utf8')
(SRC/'recipes.json').write_text(json.dumps(recipes,indent=2),encoding='utf8')
(ROOT/'build/audio/quality_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
# Browsable audition artifact, same gain offsets as the in-game emitter.
rows=[]
for name,spec in recipes.items():
    controls=''.join('<audio controls preload="none" src="../../assets/runtime/audio/designed/'+name+'_'+str(v+1)+'.wav" data-gain="'+str(-10+spec['db'])+'"></audio>' for v in range(spec['variants']))
    rows.append('<article data-key="'+name+'"><h3>'+name+'</h3>'+controls+'</article>')
rows.append(music_catalog())
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>失控温室 · 音频试听</title><style>body{background:#111d1b;color:#dfecd2;font:16px system-ui;margin:32px auto;max-width:1100px}h1{font-size:30px}input{padding:12px;width:95%;background:#22342e;color:white;border:1px solid #789b72}article{padding:14px 0;border-bottom:1px solid #34493e}audio{width:320px;max-width:100%;margin:4px}p{color:#b4c6b8}h3{font:16px monospace}</style><h1>失控温室 · 音频试听</h1><p>植物动作 / 四类敌人 / 机关 / 音乐。每行是同一事件的变体。按游戏基础增益播放；这里不含距离衰减及总线压限。</p><p>客观信号检测通过不等于主观听感验收。搜索 humanoid、mature、beetle、spore、pruner、warden、music。</p><input placeholder="筛选声音" oninput="document.querySelectorAll('article').forEach(e=>e.hidden=!e.dataset.key.includes(this.value.toLowerCase()))">'''+''.join(rows)+'''<script>document.querySelectorAll('audio').forEach(a=>{a.volume=Math.pow(10,Number(a.dataset.gain)/20);a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()}))})</script></html>'''
(ROOT/'build/audio/listen.html').write_text(html,encoding='utf8')
print(f'Built {len(recipes)} cue identities; {sum(s["variants"] for s in recipes.values())} SFX variations; 7 loops; {len(tracks())} music tracks.')
