#!/usr/bin/env python3
"""Original offline arrangements for the 0.11 handoff, using the reviewed build-23 synth.
Only this local score is executed; no design-package JavaScript is imported.
"""
from pathlib import Path
import argparse
import importlib.util
import hashlib
import json
import subprocess
import tempfile
import numpy as np

SOURCE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('catlife_audio23', SOURCE.parent / 'build23/render_audio.py')
synth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(synth)
RATE = synth.RATE

# The two-bar motif references the supplied design; eight phrase variations
# make a complete 16-bar arrangement instead of looping the browser preview.
SCORES = {
 'cover': dict(title='Way Back Home', bpm=84, lead='pluck', chords=[[48,55,60,64,67],[43,50,55,62,67]], melody=[[0,67,1],[1,72,1],[2,76,2],[4,74,1],[5,72,1],[6,67,2]]),
 'night': dict(title='Lamp-lit Room', bpm=66, lead='keys', chords=[[41,48,52,55,60],[43,50,53,57,62]], melody=[[0,72,1.5],[2,69,1],[3,67,1],[4,69,2],[6.5,72,1.5]]),
 'town': dict(title='Town Stroll', bpm=88, lead='pluck', chords=[[53,60,64,67,69],[48,55,60,64,67]], melody=[[0,77,.5],[.5,79,.5],[1,81,1],[2,84,.5],[3,81,1],[4,79,.5],[4.5,77,.5],[5,76,1],[6,72,1.5]]),
 'hospital': dict(title='Gentle Checkup', bpm=70, lead='bell', chords=[[53,60,65,69,72],[50,57,62,65,69]], melody=[[0,84,1],[1,81,1],[2,77,2],[4,79,1],[5,77,1],[6,72,2]]),
 'shop': dict(title='Bell Over the Door', bpm=104, lead='marimba', chords=[[48,55,60,64,67],[53,60,65,69,72]], melody=[[0,79,.3],[.5,84,.3],[1,88,.5],[2,86,.3],[2.5,84,.3],[3,79,.8],[4,81,.3],[4.5,84,.3],[5,89,.5],[6,88,1]])
}

def music(name, score):
    frames = round((64 * 60 / score['bpm'] * RATE) / 64) * 64
    beat = frames / RATE / 64
    value = np.zeros((frames, 2))
    quiet = name in ('night', 'hospital')
    for phrase in range(8):
        base = phrase * 8
        for bar, chord in enumerate(score['chords']):
            start = base + bar * 4
            synth.place(value, synth.pan(synth.tone(chord[0]-12, 3.6*beat, 'bass')*.045, 0), start*beat, True)
            for i, pitch in enumerate(chord[1:]):
                synth.place(value, synth.pan(synth.tone(pitch, 4.5*beat, 'pad')*.018, (i-1.5)*.18), start*beat, True)
            for i, pitch in enumerate(chord[1:] * (1 if quiet else 2)):
                synth.place(value, synth.pan(synth.tone(pitch+12, 1.2*beat, 'pluck')*(.012 if quiet else .025), .25), (start+i*(1 if quiet else .5))*beat, True)
        for at, pitch, held in score['melody']:
            # The answering phrases soften the melody without changing its harmony.
            gain = .055 if quiet else .085
            if phrase in (3, 7): gain *= .7
            synth.place(value, synth.pan(synth.tone(pitch, held*beat+.35, score['lead'])*gain, -.12), (base+at)*beat, True)
            if name in ('cover', 'town') and phrase % 2 == 0 and at in (0, 4):
                synth.place(value, synth.pan(synth.tone(pitch+12, 1.1*beat, 'bell')*.014, .4), (base+at)*beat, True)
        if name == 'shop':
            rng=np.random.default_rng(4040+phrase)
            for at in range(8):
                brush=synth.filtered_noise(.12,rng,2600,1100)
                t=np.arange(len(brush))/RATE
                brush *= np.sin(np.pi*t/.12)**2*.008
                synth.place(value,synth.pan(brush,.35),(base+at+.5)*beat,True)
    value = synth.ambience(value, True, .24 if quiet else .16)
    value -= np.mean(value, axis=0)
    value *= 10**(-23/20) / np.sqrt(np.mean(value**2))
    value *= min(1, .53/np.max(np.abs(value)))
    edge=round(.003*RATE); taper=np.sin(np.linspace(0,np.pi/2,edge))**2
    value[:edge]*=taper[:,None]; value[-edge:]*=taper[::-1,None]
    return value

# One-shots are deliberately soft; success is resolved upwards, errors downwards.
CUES = {
 'back': [(0,79,.09),(.06,74,.13)], 'sheet': [(0,72,.12),(.06,79,.18)],
 'toggle': [(0,88,.08)], 'soft-error': [(0,64,.2),(.12,61,.25)],
 'pet': [(0,76,.25)], 'coins': [(0,84,.12),(.06,88,.12),(.12,91,.12),(.18,96,.4)],
 'short-gold': [(0,72,.16),(.12,67,.3)],
 'level-up': [(0,72,.15),(.08,76,.15),(.16,79,.15),(.24,84,.15),(.32,88,.15),(.42,91,.8)],
 'sick-alert': [(0,76,.4),(.28,72,.5)], 'treat-start': [(0,84,.6),(.2,88,.7)],
 'treat-done': [(0,72,.3),(.15,79,.3),(.3,84,.5),(.5,91,.7),(.62,96,.7)],
 'shield': [(0,84,1),(0,91,1)], 'task-done': [(0,88,.15),(.08,93,.3)],
 'claim': [(0,79,.15),(.08,84,.15),(.16,88,.15),(.24,91,.6)],
 'daily-reset': [(0,72,.4),(.18,77,.4),(.36,81,.6)],
 'pin': [(0,72,.08),(.06,84,.16)], 'knock': [(0,50,.10),(.16,50,.10)],
 'remind': [(0,91,1),(.25,86,1.2)]
}
CAT_VOICES = {
 'happy': [(0,520,700,.35)], 'hungry': [(0,620,420,.75)],
 'coax': [(0,560,680,.24),(.32,600,520,.38)],
 'unwell': [(0,380,330,.5)], 'sleepy': [(0,460,300,.85)]
}

def edge_safe(value, rms_dbfs):
    value -= np.mean(value)
    value *= 10**(rms_dbfs/20) / max(1e-9, np.sqrt(np.mean(value**2)))
    value *= min(1, .48/max(1e-9,np.max(np.abs(value))))
    edge=min(round(.008*RATE),len(value)//4)
    window=np.sin(np.linspace(0,np.pi/2,edge))**2
    value[:edge]*=window; value[-edge:]*=window[::-1]
    return value


def effects():
    for name, notes in CUES.items():
        length=max(at+held for at,_,held in notes)+.14
        value=np.zeros(round(length*RATE))
        for at,pitch,held in notes:
            voice='bell' if name in ('treat-start','shield','remind') else 'keys'
            synth.place(value,synth.tone(pitch,held,voice),at)
        yield 'sfx-'+name, edge_safe(synth.ambience(value,False,.08),-17)
    for name, calls in CAT_VOICES.items():
        value=np.zeros(round((max(at+duration for at,_,_,duration in calls)+.12)*RATE))
        for at,f0,f1,duration in calls:
            t=np.arange(round(duration*RATE))/RATE
            freq=np.interp(t,[0,duration*.35,duration],[f0,f1*1.06,f1])
            phase=2*np.pi*np.cumsum(freq)/RATE
            formant=np.interp(t,[0,duration*.4,duration],[900,1500,720])
            voice=np.zeros(len(t))
            for h in range(1,9):
                strength=.5*np.exp(-.5*((freq*h-formant)/300)**2)+(.2 if h==1 else 0)
                voice+=np.sin(phase*h)*strength/(h**.8)
            voice*=synth.attack_release(t,duration,.045,min(.18,duration*.35))
            synth.place(value,voice,at)
        yield 'cat-'+name,edge_safe(synth.ambience(value,False,.04),-15 if name!='unwell' else -19)
    t=np.arange(round(2.2*RATE))/RATE
    purr=(np.sin(2*np.pi*46*t)+.18*np.sin(2*np.pi*92*t))*(.65+.35*np.sin(2*np.pi*24*t))
    purr*=synth.attack_release(t,2.2,.08,.3)
    yield 'cat-purr',edge_safe(purr,-19)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=SOURCE.parents[1]/'CatLife/Audio')
    parser.add_argument('--preview-dir',type=Path)
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    if args.preview_dir: args.preview_dir.mkdir(parents=True,exist_ok=True)
    entries=[]
    # Sequential rendering bounds peak memory to a single music loop.
    content=((f'bgm-{name}',music(name,score),True) for name,score in SCORES.items())
    import itertools
    with tempfile.TemporaryDirectory(prefix='catlife-audio40-') as directory:
        temporary=Path(directory)
        for name,signal,loop in itertools.chain(content,((n,v,False) for n,v in effects())):
            pcm=temporary/(name+'.wav'); target=args.output/(name+'.caf'); decoded=temporary/(name+'-decoded.wav')
            synth.wav(pcm,signal)
            subprocess.run(['afconvert','-f','caff','-d','ima4',str(pcm),str(target)],check=True)
            subprocess.run(['afconvert','-f','WAVE','-d','LEI16',str(target),str(decoded)],check=True)
            result,rate,channels=synth.read_wav(decoded); metrics=synth.metrics(result)
            assert rate==RATE and channels==(2 if loop else 1)
            assert np.isfinite(result).all() and metrics['clippedSamples']==0 and metrics['peakDBFS'] < -4
            if loop:
                assert len(result)==len(signal) and metrics['silent100msWindows']==0
                assert metrics['seamStepAmplitude']<max(.018,2*metrics['sampleStepP99Amplitude'])
            else:
                assert abs(result[0])<.002 and abs(result[-1])<.002
            entries.append(dict(file=target.name,loop=loop,bytes=target.stat().st_size,sha256=hashlib.sha256(target.read_bytes()).hexdigest(),**metrics))
            if args.preview_dir:
                import shutil
                shutil.copyfile(decoded,args.preview_dir/(name+'.wav'))
            print(name,metrics['rmsDBFS'],metrics['durationSeconds'],flush=True)
    (SOURCE/'score.json').write_text(json.dumps(dict(music=SCORES,cues=CUES,cats=CAT_VOICES),indent=2)+'\n')
    (SOURCE/'manifest.json').write_text(json.dumps(dict(build=40,version='0.11.0',files=entries,source='Original offline synthesis; no recordings or third-party samples. Motif direction from user-supplied handoff; build-23 synthesis primitives.',validation='Decoded CAF: rates, channels, finite PCM, clipping, music continuity and effect edge silence. Subjective listening not claimed.'),indent=2)+'\n')
    print('Generated',len(entries),'files;',sum(e['bytes'] for e in entries),'bytes')

if __name__=='__main__': main()
