# CatLife original audio — 0.5.0 / build 23

This collection was newly composed and synthesized for the native game. It does not contain downloaded tracks, third-party samples, recordings of people, or recordings of animals. The `cat-meow` cue is a short stylized voiced synthesizer sound, not a real cat recording. No third-party sample attribution or music license requirement is introduced, and this collection does not change the license of the rest of the repository.

The previous web client's `src/js/systems/musicSystem.js` informed the distinction between home and work moods. These new melodies, harmony, instrument envelopes and 16-bar arrangements were authored separately for the warmer native art direction. They do not reuse its square/sawtooth patterns.

## Background music

| Resource | Original title | Arrangement |
| --- | --- | --- |
| `bgm-home.caf` | Sunlit Little Home | 16 bars, 78 BPM, about 49.23 seconds. Soft tine-style keys, light nylon-like plucks, warm bass and quiet chord pads. |
| `bgm-work.caf` | Little Steps to Payday | 16 bars, 96 BPM, 40 seconds. Muted marimba, plucks, rounded bass, restrained shakers and a gentle low pulse. |
| `bgm-sleep.caf` | Paws at Rest | 16 bars, 60 BPM, 64 seconds. Sparse bell melody, longer soft chord pads, plucked ornaments and less bass. |

All music is stereo at 44,100 Hz. Note timing varies by up to 6 ms and note gain varies slightly, using fixed seeds; there is no real-time synthesis cost in the app. The tracks use deliberately quiet dynamics (home/work target about −23 dBFS RMS, sleep about −27 dBFS RMS before app volume controls). These RMS values are signal measurements, not LUFS or perceived loudness claims.

Notes and finite room-reverb tails wrap across the loop boundary. There is no whole-track fade, silent gap, or inserted lead-in at each repeat. A 3 ms sample-edge safety taper brings codec packet resets together at zero, without adding any silent frames. Frame counts are aligned to the CAF codec packet size, with the beat duration derived from that exact count. The score returns musically to its first harmony.

## Interaction sounds

| Resource | Cue and suggested event |
| --- | --- |
| `sfx-tap.caf` | Very short soft key tone, for an accepted navigation tap. |
| `sfx-enter.caf` | Three ascending warm tones, once when entering the home. |
| `sfx-purchase.caf` | Small bright coin-like notes, after a successful purchase. |
| `sfx-work-start.caf` | Two purposeful soft notes, after work starts. |
| `sfx-work-complete.caf` | Short resolved four-note reward phrase, once after committed completion. |
| `sfx-place.caf` | Muted wooden settling sound; play once when furniture placement is committed, not every drag update. |
| `sfx-feed.caf` | A tiny bowl-contact tick and three short dry crunches, triggered when the cat actually reaches food contact at the bowl. |
| `sfx-clean.caf` | Three gentle filtered brush swishes. |
| `sfx-play.caf` | A rounded pitch bounce followed by a light wooden note. |
| `sfx-cat-meow.caf` | A short synthetic cartoon meow with a pitch glide and moving vowel resonances. |
| `sfx-sleep.caf` | Quiet descending notes for beginning rest. |
| `sfx-wake.caf` | A soft rising pair for waking up. |

Effects are mono, short and tapered to digital silence at their start and end. They should be rate-limited in the audio service and emitted after the corresponding action succeeds. Background restoration must not replay old transaction or completion sounds.

## Reproduction

`render_audio.py` contains the complete additive/FM-style instrument synthesis, deterministic arrangement, reverb and one-shot sound design. `score.json` is an inspectable export of the MIDI note numbers, chord voicings, timing and seeds.

An example offline authoring environment is Python 3.9 with `numpy==2.0.2`, `scipy==1.13.1`, plus the macOS `afconvert` command. These are not app dependencies.

```sh
python render_audio.py
```

The output folder defaults correctly relative to the script when `--output` is omitted. `--preview-dir` can retain decoded WAV copies in a temporary folder for listening; WAV copies are not bundled in the application. The script writes the final `manifest.json`, which records duration, bytes, hash, channels, format, peak/RMS levels, silence checks, decoded loop frame count, and repeat-boundary sample-step measurements for every CAF file. Different OS codec implementations may produce different container bytes even from the same source score.

## Validation and limits

Every CAF is decoded back to PCM, then checked for correct rate/channels, no clipped samples, expected frame counts, and a non-abrupt loop boundary. The music must contain no silent 100 ms windows. These checks establish file integrity and signal bounds, not a claim that an automated system heard the tracks. Speaker/headphone listening, musical preference, balance against in-game effects, and real-device silent-mode/interruption behavior remain listening and integration checks.

Delivery verification completed for all 15 runtime CAF IMA4 files, totaling 7,457,664 bytes (about 7.11 MiB). The three decoded music loops measure 49.230658, 39.999274 and 64 seconds, with respectively −23, −23 and −27 dBFS RMS. All have zero clipped samples, zero silent 100 ms windows, and zero sample-amplitude discontinuity between their decoded last and first samples. All sound effects decode correctly at 44,100 Hz mono. File SHA-256 values and exact decoded metrics are in `manifest.json`.

CAF container metadata was also inspected: only approximate duration and source PCM bit depth are stored as info fields, with normal audio format/channel/packet/data chunks. No author, device identifier, local username or filesystem path is embedded. All file inventories and manifest hashes match. Subjective musical quality and real-device listening are intentionally not marked as completed by these numerical checks.
