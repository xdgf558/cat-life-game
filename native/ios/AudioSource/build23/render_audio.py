#!/usr/bin/env python3
"""Render CatLife's original build-23 score and designed SFX, without samples.

Offline authoring only. Runtime playback uses the resulting bundled CAF files.
Requires Python 3.9+, numpy, scipy, and macOS afconvert. Seed/score are explicit.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

RATE = 44100
ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / 'CatLife' / 'Audio'
SOURCE = Path(__file__).resolve().parent


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def attack_release(t, duration, attack=0.008, release=0.15):
    attack_curve = np.minimum(1, t / attack) ** 0.7
    end_curve = np.clip((duration - t) / release, 0, 1)
    return attack_curve * np.sin(end_curve * np.pi / 2) ** 2


def tone(midi, duration, voice='keys'):
    t = np.arange(round(duration * RATE)) / RATE
    frequency = hz(midi)
    if voice == 'keys':
        # Tine-like electric piano: mellow fundamental, rapidly fading upper
        # partials, no square/saw oscillator or external instrument recording.
        signal = np.sin(2 * np.pi * frequency * t + 0.28 * np.exp(-t / 0.12) * np.sin(2 * np.pi * frequency * 2 * t)) * np.exp(-t / 1.25)
        signal += 0.21 * np.sin(2 * np.pi * frequency * 2.001 * t) * np.exp(-t / 0.43)
        signal += 0.07 * np.sin(2 * np.pi * frequency * 3.003 * t) * np.exp(-t / 0.19)
        signal *= attack_release(t, duration, 0.007, 0.18)
    elif voice == 'pluck':
        signal = sum(amplitude * np.sin(2 * np.pi * frequency * harmonic * t) * np.exp(-t / decay)
                     for harmonic, amplitude, decay in [(1, 1, 0.53), (2, .32, .25), (3, .13, .13), (4, .04, .08)])
        signal *= attack_release(t, duration, 0.004, 0.10)
    elif voice == 'marimba':
        signal = np.sin(2 * np.pi * frequency * t) * np.exp(-t / .43)
        signal += .15 * np.sin(2 * np.pi * frequency * 3.98 * t) * np.exp(-t / .10)
        signal += .04 * np.sin(2 * np.pi * frequency * 9.1 * t) * np.exp(-t / .035)
        signal *= attack_release(t, duration, .004, .12)
    elif voice == 'bell':
        signal = np.sin(2 * np.pi * frequency * t) * np.exp(-t / 2.1)
        signal += .09 * np.sin(2 * np.pi * frequency * 2.002 * t) * np.exp(-t / .83)
        signal += .025 * np.sin(2 * np.pi * frequency * 3.99 * t) * np.exp(-t / .25)
        signal *= attack_release(t, duration, .012, .5)
    elif voice == 'bass':
        signal = np.sin(2 * np.pi * frequency * t) * np.exp(-t / 1.1)
        signal += .18 * np.sin(2 * np.pi * frequency * 2 * t) * np.exp(-t / .30)
        signal *= attack_release(t, duration, .012, .22)
    elif voice == 'pad':
        signal = .76 * np.sin(2 * np.pi * frequency * t)
        signal += .09 * np.sin(2 * np.pi * (frequency + .31) * t)
        signal += .09 * np.sin(2 * np.pi * (frequency - .29) * t)
        signal += .045 * np.sin(2 * np.pi * frequency * 2 * t)
        signal *= attack_release(t, duration, .55, .9)
    else:
        raise ValueError(voice)
    return signal


def pan(signal, position):
    angle = (position + 1) * math.pi / 4
    return np.column_stack((signal * math.cos(angle), signal * math.sin(angle)))


def place(buffer, signal, start, loop=False):
    sample = round(start * RATE)
    if loop:
        start = sample % len(buffer)
        first = min(len(signal), len(buffer) - start)
        buffer[start:start + first] += signal[:first]
        if first < len(signal):
            buffer[:len(signal) - first] += signal[first:]
    else:
        start = max(0, sample)
        length = min(len(signal), len(buffer) - start)
        if length > 0:
            buffer[start:start + length] += signal[:length]


def filtered_noise(seconds, rng, cutoff=2800, highpass=180):
    value = rng.normal(0, 1, round(seconds * RATE))
    value = sosfilt(butter(2, cutoff, fs=RATE, output='sos'), value)
    value = sosfilt(butter(1, highpass, btype='highpass', fs=RATE, output='sos'), value)
    return value


def ambience(signal, loop, wet=.18):
    # Finite stereo room taps. Circular tails make the beginning contain the
    # previous loop's reverb, avoiding an artificial gap at the repeat point.
    output = signal.copy()
    taps = [(0.047, .33), (.089, .25), (.137, .18), (.211, .12), (.293, .08), (.419, .04), (.631, .02)]
    for index, (seconds, gain) in enumerate(taps):
        n = round(seconds * RATE)
        tap = np.roll(signal, n, axis=0)
        if not loop:
            tap[:n] = 0
        if signal.ndim == 2 and index % 2 == 0:
            tap = tap[:, ::-1]
        output += tap * gain * wet
    return output


# Concert pitches are MIDI numbers. Each tuple is (beat, MIDI, held beats).
# These melodies and voicings are newly authored for this game, not a cover.
HOME_CHORDS = [
    [48, 55, 59, 62, 64], [45, 52, 55, 59, 60], [41, 48, 52, 55, 57], [43, 50, 55, 57, 62],
    [48, 55, 59, 62, 64], [45, 52, 55, 59, 60], [41, 48, 52, 55, 57], [43, 50, 55, 59, 62],
    [50, 57, 60, 64, 65], [43, 50, 55, 59, 62], [52, 55, 60, 64, 67], [45, 52, 55, 59, 60],
    [41, 48, 52, 55, 57], [43, 50, 55, 57, 62], [48, 55, 59, 62, 64], [43, 50, 55, 59, 62],
]
HOME_MELODY = [
    [(0, 76, 1.2), (1.5, 74, .6), (2.5, 72, 1.0)], [(0.5, 71, .6), (1.5, 72, 1.0), (3, 76, .7)],
    [(0, 77, 1.4), (2, 76, .8), (3, 74, .7)], [(0.5, 74, 1.2), (2, 71, 1.0)],
    [(0, 72, .8), (1, 76, .7), (2.5, 79, 1)], [(0.5, 76, 1.1), (2, 74, .6), (3, 72, .7)],
    [(0, 69, 1.3), (2, 72, .7), (3, 74, .6)], [(0, 71, 2.0)],
    [(0.5, 77, 1.0), (2, 76, .7), (3, 74, .6)], [(0.5, 74, 1), (2, 71, .7), (3, 67, .6)],
    [(0, 76, 1.3), (2, 79, 1.1)], [(0.5, 76, 1.2), (2.5, 72, 1)],
    [(0, 69, .8), (1.5, 72, .8), (3, 76, .7)], [(0, 74, 1.1), (2, 71, 1.2)],
    [(0, 72, 2.2), (3, 76, .7)], [(0.5, 74, 1), (2, 71, 1.2)],
]
WORK_CHORDS = [
    [50, 57, 61, 64, 66], [47, 54, 57, 61, 62], [43, 50, 54, 57, 59], [45, 52, 57, 59, 64],
] * 4
WORK_MELODY = [
    [(0, 74, .6), (1, 78, .6), (2.5, 81, .6), (3.25, 78, .5)],
    [(.5, 78, .6), (1.5, 76, .6), (2.5, 74, .8)],
    [(0, 71, .7), (1, 74, .6), (2, 78, .7), (3, 76, .6)],
    [(.5, 76, .8), (2, 73, 1.1)],
    [(0, 78, .6), (.75, 81, .6), (2, 83, .7), (3, 81, .6)],
    [(.5, 78, 1), (2, 76, .6), (3, 74, .6)],
    [(0, 74, .6), (1.5, 71, .7), (3, 69, .6)],
    [(.5, 73, 1.2), (2.5, 76, .7)],
    [(0, 78, .7), (1, 76, .6), (2.5, 74, .8)],
    [(.5, 71, .7), (1.5, 74, .6), (3, 78, .6)],
    [(0, 79, 1), (1.5, 78, .6), (2.5, 76, .8)],
    [(.5, 76, .8), (2, 73, 1.0)],
    [(0, 74, .7), (1, 78, .6), (2.5, 81, .8)],
    [(.5, 78, .8), (2, 76, .6), (3, 74, .6)],
    [(0, 71, .8), (1.5, 74, .8), (3, 78, .6)],
    [(0, 76, .8), (1.5, 73, 1.1)],
]
SLEEP_CHORDS = [
    [41, 48, 52, 57, 60], [48, 55, 59, 62, 64], [45, 52, 55, 59, 60], [43, 50, 55, 59, 62],
    [41, 48, 52, 57, 60], [48, 55, 59, 62, 64], [50, 57, 60, 64, 65], [43, 50, 55, 57, 62],
] * 2
SLEEP_MELODY = [
    [(0.5, 72, 2)], [(1, 71, 1.6), (3, 67, .8)], [(0.5, 69, 2.2)], [(1, 67, 2.2)],
    [(0.5, 69, 1.7), (2.5, 72, 1)], [(1, 76, 2)], [(0.5, 74, 2.2)], [(1, 71, 2)],
    [(0.5, 72, 2.2)], [(1, 76, 1.6), (3, 74, .8)], [(0.5, 72, 2.2)], [(1, 71, 2.2)],
    [(0.5, 69, 2.2)], [(1, 67, 2.1)], [(0.5, 65, 2.2)], [(1, 67, 2)],
]
SCORES = {
    'home': {'title': 'Sunlit Little Home', 'bpm': 78, 'seed': 2301, 'chords': HOME_CHORDS, 'melody': HOME_MELODY, 'lead': 'keys', 'rms_dbfs': -23},
    'work': {'title': 'Little Steps to Payday', 'bpm': 96, 'seed': 2302, 'chords': WORK_CHORDS, 'melody': WORK_MELODY, 'lead': 'marimba', 'rms_dbfs': -23},
    'sleep': {'title': 'Paws at Rest', 'bpm': 60, 'seed': 2303, 'chords': SLEEP_CHORDS, 'melody': SLEEP_MELODY, 'lead': 'bell', 'rms_dbfs': -27},
}


def music(name):
    score = SCORES[name]
    rng = np.random.default_rng(score['seed'])
    frames = round((16 * 4 * 60 / score['bpm'] * RATE) / 64) * 64
    output = np.zeros((frames, 2), dtype=np.float64)
    beat = frames / RATE / 64
    def note(pitch, at, held, voice, gain, position, human=True):
        jitter = rng.uniform(-.006, .006) if human else 0
        velocity = rng.uniform(.93, 1.06) if human else 1
        length = held * beat + (.9 if voice in ('keys', 'bell', 'pad') else .25)
        value = tone(pitch, length, voice) * gain * velocity
        place(output, pan(value, position), at * beat + jitter, loop=True)
    for bar, (chord, melody) in enumerate(zip(score['chords'], score['melody'])):
        base = bar * 4
        root = chord[0] - 12
        note(root, base, 2.8, 'bass', .085 if name != 'sleep' else .045, 0)
        if name != 'sleep':
            note(root + 7, base + 2, 1.5, 'bass', .055, 0)
            arp = [chord[1], chord[2], chord[3], chord[2], chord[1], chord[3], chord[4], chord[2]]
            for index, pitch in enumerate(arp):
                if name == 'home' and index == 6 and bar % 4 == 3:
                    continue
                offbeat = .025 if name == 'work' and index % 2 else 0
                note(pitch + 12, base + index * .5 + offbeat, .48,
                     'pluck', .025 if name == 'home' else .032, .25)
            for pitch in chord[1:4]:
                note(pitch, base + .03, 3.5, 'pad', .018, -.18)
        else:
            for index, pitch in enumerate(chord[1:]):
                note(pitch, base + index * .04, 4.4, 'pad', .025, -.35 + index * .23)
            for i, pitch in enumerate((chord[2], chord[3], chord[4])):
                note(pitch + 12, base + .75 + i, 1.4, 'pluck', .014, -.24)
        for at, pitch, held in melody:
            note(pitch, base + at, held, score['lead'], .105 if name != 'sleep' else .070, -.08)
        if name == 'work':
            for half in range(8):
                seconds = .10
                n = filtered_noise(seconds, rng, 3500, 1400)
                t = np.arange(len(n)) / RATE
                n *= np.exp(-t / .025) * attack_release(t, seconds, .003, .03)
                place(output, pan(n * (.009 if half % 2 else .005), .30), (base + half * .5 + .03) * beat, True)
            for at in (0, 2):
                seconds = .18
                t = np.arange(round(seconds * RATE)) / RATE
                phase = 2 * np.pi * (65 * t + 25 * .035 * (1 - np.exp(-t / .035)))
                kick = np.sin(phase) * np.exp(-t / .045) * attack_release(t, seconds, .004, .04)
                place(output, pan(kick * .023, -.1), (base + at) * beat, True)
    output = ambience(output, True, .28 if name == 'sleep' else .19)
    output -= np.mean(output, axis=0)
    rms = np.sqrt(np.mean(output ** 2))
    output *= 10 ** (score['rms_dbfs'] / 20) / rms
    output *= min(1, .53 / np.max(np.abs(output)))
    # A three-millisecond safety taper makes decoded packet resets meet at
    # digital zero. No samples or silent lead-in are inserted into the loop.
    edge = round(.003 * RATE)
    taper = np.sin(np.linspace(0, np.pi / 2, edge)) ** 2
    output[:edge] *= taper[:, None]
    output[-edge:] *= taper[::-1, None]
    return output


def effects():
    rng = np.random.default_rng(2340)
    result = {}
    def buffer(seconds):return np.zeros(round(seconds * RATE))
    def chime(name, notes, duration, gain=.27):
        value = buffer(duration)
        for time, pitch, held in notes:
            place(value, tone(pitch, held, 'keys'), time)
        result[name] = (ambience(value, False, .10), gain)
    chime('tap', [(0, 79, .12)], .18, .15)
    chime('enter', [(0, 72, .32), (.11, 76, .35), (.22, 79, .50)], .86, .26)
    chime('purchase', [(0, 84, .22), (.10, 88, .32), (.22, 91, .30)], .65, .25)
    chime('work-start', [(0, 69, .20), (.13, 74, .28)], .51, .23)
    chime('work-complete', [(0, 72, .28), (.13, 76, .30), (.26, 79, .33), (.42, 84, .68)], 1.25, .27)
    chime('sleep', [(0, 76, .80), (.28, 72, .90)], 1.40, .18)
    chime('wake', [(0, 72, .4), (.18, 76, .5)], .9, .21)
    # Soft wooden settling sound; no loud collision or scraping during a drag.
    t = np.arange(round(.35 * RATE)) / RATE
    place_sound = (np.sin(2*np.pi*160*t) + .22*np.sin(2*np.pi*280*t)) * np.exp(-t/.035)
    place_sound += filtered_noise(.35, rng, 1200, 80) * np.exp(-t/.020) * .18
    place_sound *= attack_release(t, .35, .003, .08)
    result['place'] = (place_sound, .20)
    # A tiny bowl contact and three short dry chewing/crunch gestures.
    value=buffer(.90)
    place(value, tone(88,.21,'bell') * .12, 0)
    for at in (.14,.34,.54):
        t=np.arange(round(.11*RATE))/RATE
        grains=filtered_noise(.11,rng,3600,500) * np.exp(-t/.018) * attack_release(t,.11,.002,.035)
        place(value,grains*.4,at)
    result['feed']=(value,.23)
    value=buffer(.83)
    for at,length in [(0,.22),(.23,.24),(.48,.29)]:
        t=np.arange(round(length*RATE))/RATE
        brush=filtered_noise(length,rng,2600,450) * np.sin(np.pi*t/length)**2
        place(value,brush,at)
    result['clean']=(value,.18)
    value=buffer(.67)
    t=np.arange(round(.29*RATE))/RATE
    freq=440+330*np.sin(np.pi*t/.29)
    boing=np.sin(2*np.pi*np.cumsum(freq)/RATE)*np.exp(-t/.14)*attack_release(t,.29,.006,.07)
    place(value,boing*.3,0)
    place(value,tone(86,.35,'marimba')*.5,.24)
    result['play']=(value,.22)
    # A clearly stylized synthesized meow: gliding voiced source plus moving
    # vowel resonances. This is not a recording of a real animal or a person.
    duration=.72
    t=np.arange(round(duration*RATE))/RATE
    f0=np.interp(t,[0,.08,.21,.40,.72],[260,340,435,355,235])
    f0*=1+.012*np.sin(2*np.pi*6*t)
    phase=2*np.pi*np.cumsum(f0)/RATE
    f1=np.interp(t,[0,.18,.72],[700,1150,540])
    f2=np.interp(t,[0,.25,.72],[1500,1850,1050])
    voice=np.zeros(len(t))
    for harmonic in range(1,10):
        freq=f0*harmonic
        strength=.55*np.exp(-.5*((freq-f1)/270)**2)+.28*np.exp(-.5*((freq-f2)/390)**2)
        strength+=(.18 if harmonic==1 else 0)
        voice+=np.sin(phase*harmonic)*strength/(harmonic**.7)
    breath=filtered_noise(duration,rng,3000,650)*.022
    envelope=attack_release(t,duration,.045,.23)*np.sin(np.pi*t/duration)**.65
    result['cat-meow']=(ambience((voice+breath)*envelope,False,.045),.26)
    for name,(value,peak) in list(result.items()):
        value -= np.mean(value)
        value *= peak / max(np.max(np.abs(value)),1e-9)
        # Short one-shots begin and end at digital silence with a smooth taper.
        fade=min(round(.004*RATE),len(value)//4)
        window=np.sin(np.linspace(0,np.pi/2,fade))**2
        value[:fade]*=window
        value[-fade:]*=window[::-1]
        result[name]=value
    return result


def wav(path, signal):
    data = np.rint(np.clip(signal, -1, 1) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(signal.shape[1] if signal.ndim==2 else 1)
        f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data.tobytes())


def read_wav(path):
    # afconvert may emit WAVE_FORMAT_EXTENSIBLE for stereo PCM; scipy handles
    # that standard header, whereas Python 3.9's wave reader does not.
    rate, raw = wavfile.read(str(path))
    assert raw.dtype == np.int16
    data = raw.astype(np.float64) / 32768
    channels = data.shape[1] if data.ndim == 2 else 1
    return data, rate, channels


def metrics(signal):
    rms=float(np.sqrt(np.mean(signal**2)))
    peak=float(np.max(np.abs(signal)))
    windows=[np.sqrt(np.mean(signal[i:i+RATE//10]**2)) for i in range(0,len(signal),RATE//10)]
    seam=float(np.max(np.abs(signal[-1]-signal[0])))
    differences=np.abs(np.diff(signal,axis=0))
    return {'durationSeconds':round(len(signal)/RATE,6),'frames':len(signal),'sampleRate':RATE,
            'channels':signal.shape[1] if signal.ndim==2 else 1,'peakDBFS':round(20*math.log10(max(peak,1e-10)),2),
            'rmsDBFS':round(20*math.log10(max(rms,1e-10)),2),'clippedSamples':int(np.count_nonzero(np.abs(signal)>=.9999)),
            'dcOffset':round(float(np.max(np.abs(np.mean(signal,axis=0)))),8),
            'silent100msWindows':int(sum(x<10**(-65/20) for x in windows)),'total100msWindows':len(windows),
            'seamStepAmplitude':round(seam,8),'sampleStepP99Amplitude':round(float(np.percentile(differences,99)),8)}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=DESTINATION)
    parser.add_argument('--codec',choices=['ima4','LEI16','alac'],default='ima4')
    parser.add_argument('--preview-dir',type=Path,help='Optional WAV previews, outside the shipped app resources.')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    if args.preview_dir:args.preview_dir.mkdir(parents=True,exist_ok=True)
    entries=[]
    score_json={k:{**v,'chords':v['chords'],'melody':v['melody']} for k,v in SCORES.items()}
    (SOURCE/'score.json').write_text(json.dumps(score_json,indent=2)+'\n')
    with tempfile.TemporaryDirectory(prefix='catlife-audio23-') as temporary:
        work=Path(temporary)
        content=[('bgm-'+name,music(name),True) for name in SCORES]
        content.extend(('sfx-'+name,value,False) for name,value in effects().items())
        for name,signal,is_loop in content:
            input_file=work/(name+'.wav');output_file=args.output/(name+'.caf')
            wav(input_file,signal)
            subprocess.run(['afconvert','-f','caff','-d',args.codec,str(input_file),str(output_file)],check=True)
            decoded=work/(name+'-decoded.wav')
            subprocess.run(['afconvert','-f','WAVE','-d','LEI16',str(output_file),str(decoded)],check=True)
            decoded_signal,rate,channels=read_wav(decoded)
            assert rate==RATE and channels==(2 if is_loop else 1)
            data=metrics(decoded_signal)
            assert data['clippedSamples']==0 and data['peakDBFS'] < -4
            if is_loop:
                assert len(decoded_signal)==len(signal), (name,len(decoded_signal),len(signal))
                assert data['silent100msWindows']==0, name
                assert data['seamStepAmplitude'] < max(.018, 2*data['sampleStepP99Amplitude']), (name,data)
            entry={'file':output_file.name,'purpose':'background loop' if is_loop else 'interaction one-shot',
                   'codec':args.codec,'loop':is_loop,'bytes':output_file.stat().st_size,
                   'sha256':hashlib.sha256(output_file.read_bytes()).hexdigest(),**data}
            entries.append(entry)
            if args.preview_dir:
                import shutil
                shutil.copy2(decoded,args.preview_dir/(name+'.wav'))
            print(name, json.dumps(data), flush=True)
    manifest={'build':23,'version':'0.5.0','sampleRate':RATE,'source':'New original offline synthesis and original score; no third-party samples or recordings.',
              'license':'Project-original assets; no third-party attribution or sample-license obligations are introduced. No license for the rest of the repository is changed.',
              'reproducibility':{'script':'render_audio.py','score':'score.json','randomSeeds':[2301,2302,2303,2340],
                                 'dependencies':['numpy 2.0.2','scipy 1.13.1','macOS afconvert'],
                                 'pcmDeterminism':'Fixed sample rate, seeds and note tables; container headers may vary across codec/OS versions.'},
              'totalRuntimeBytes':sum(e['bytes'] for e in entries),'files':entries,
              'validation':'Decoded every CAF back to PCM; checked channel/rate, finite amplitudes, clipping, silence, exact music frame counts and repeat-boundary sample steps.',
              'audition':'Signal quality metrics checked; subjective speaker/headphone listening remains a separate acceptance step.'}
    (SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Total runtime bytes:',manifest['totalRuntimeBytes'])

if __name__=='__main__':main()
