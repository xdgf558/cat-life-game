# CatLife audio handoff — 0.11.0 (40)

This collection implements the supplied sound direction with native CAF playback. Five new 16-bar stereo arrangements and 24 mono one-shots were rendered locally using the reviewed build-23 synthesis primitives. The motif/pitch direction was transcribed from the user-supplied design; no JavaScript from that package was executed. All voices are synthetic, with no recordings of people, cats or third-party samples. The project license is unchanged.

The original `bgm-home`, `bgm-work`, `bgm-sleep` and eleven non-cat build-23 effects are reused byte-for-byte. `cat-happy` replaces the original `sfx-cat-meow`. The new `cat-*` family has its own saved channel. New scene files are `bgm-cover`, `bgm-night`, `bgm-town`, `bgm-hospital` and `bgm-shop`.

Run `render_audio.py` with the existing audio-authoring environment (Python, numpy, scipy and macOS afconvert). It imports only the repository's reviewed build-23 renderer for instruments and PCM checks. Rendering is sequential and has no app runtime dependency. `--preview-dir` optionally retains decoded WAVs outside the bundle. On macOS the system codecs may require running afconvert outside a process sandbox; the script does not fall back to another codec silently.

`score.json` records the arrangement and cue parameters. `manifest.json` records the 29 newly rendered CAF files, hashes and decoded measurements. All files use 44,100 Hz IMA4 CAF; music is stereo and effects are mono. New music targets −23 dBFS RMS; the retained sleep music targets −27. Effects target approximately −17 dBFS and cat voices approximately −15, with softer unwell/purr cues and a safety peak ceiling. These are signal measurements rather than perceived loudness claims.

The render checks decoded channel/rate, finite samples, clipping, one-shot edge silence, exact loop frame counts, no silent 100 ms music windows and bounded repeat-boundary discontinuity. These checks passed for all 29 files. Subjective speaker/headphone listening, haptic feel and physical silent-mode/route/interruption tests remain device acceptance work.

## Playback integration

The native controller keeps the existing ambient session, other-app music handling, background suspension and interruption/route recovery. Scene transitions use 1.2-second crossfades. Cat voices and major reward cues lower music by approximately 6 dB, beginning over 80 ms and recovering after 1.2 seconds. At most three effects play simultaneously; a higher-priority cue can replace the lowest-priority current cue. Repeated effects have a 120 ms interval and all cat voices share a four-second interval.

The existing persisted audio-settings queue is unchanged. New fields decode individually and normalize safely; absent cat settings inherit the old effects mute/volume so an upgrade cannot unexpectedly unmute a player's cat. Scene music, quiet nights and haptics default on. Quiet nights apply from 22:00 through 06:59, use the night track at home and reduce music by 30%. Turning scene music off chooses the home track everywhere. Existing player sleep remains the authoritative sleep-music state.

The sound page previews the actual saved channels. A music preview pause is temporary and is cleared when leaving the page. Pending/failed preferences never masquerade as an applied preview. `pet`, `knock` and `remind` resources have no gameplay triggers yet: this change does not add petting, neighbour visits or notifications.
