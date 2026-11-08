# Background music — build 58

Two project-specific instrumental tracks were generated through the Suno web UI
on 2026-11-08. The account's Pro plan was observed during generation/download.
The inputs were original text prompts; no music, voice recording or other
reference media was uploaded. The first candidate from each generation was used.
Suno documents subscription-created music rights in its [paid-plan guidance](https://help.suno.com/en/articles/9601665).

| Runtime asset | Source track |
| --- | --- |
| `bgm-promenade.caf` | [猫町慢步 · Cat Town Promenade](https://suno.com/song/5ca1e37d-0b5a-473d-8888-88f392167329) |
| `bgm-upstairs.caf` | [阁楼暖阳 · Sunlit Upstairs](https://suno.com/song/edfb7222-51b9-4e79-bd7d-282cedc40627) |

Both assets use 44,100 Hz stereo Apple IMA4 in CAF, normalized to approximately
−23 dBFS RMS to match the existing background music. Quiet ending sections were
trimmed and joined with continuous equal-power crossfades (2.609 s / 3.158 s).
The resulting loops are 160.641 s and 125.092 s. No silence or forced zero samples
were inserted at the loop boundaries, and playback speed was not changed.

Apple's decoder verified the effective frame counts, no clipped/non-finite
samples, no silent 100 ms windows, and bounded sample discontinuities at the
crossfade and file boundaries. The decoded peaks are −7.25 and −8.21 dBFS.
Signal checks do not substitute for listening to the musical transitions.

Original downloads, complete prompts, the reproducible processing script,
numerical/spectral reports and listening previews are retained with the external
0.17.0 (58) release artifacts. Only the runtime CAF files and this provenance
note belong in Git; the CAF files use the repository's existing LFS rule.
