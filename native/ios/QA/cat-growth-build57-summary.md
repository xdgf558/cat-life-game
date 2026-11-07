# iOS 0.16.0 (57) — growth, companionship, careers and shop layout

One combined PR, as requested. The web game remains independent and unchanged. PR #20 was merged and this version was uploaded to TestFlight; no physical-device install was performed in this pass.

## Delivered behavior

- Furniture and equipment cards share each row's natural height, with bottom-aligned purchase buttons. Smaller art panels, two-line summaries and an ownership badge over the art make the grid more compact; full descriptions remain in product details. Accessibility sizes use one column with unabridged text. Locked buttons use a short level label in two-column mode and keep the full accessibility label.
- Cat profiles have a compact entry to a separate growth/companionship page: game age, life stage, sex, bond stage, next thresholds and individual history. Returning home selects the intended companion without consuming supplies. Room and cat scale are unchanged.
- Schema 9 stores per-cat growth anchors. Schemas 1–8 start records at migration and preserve existing intimacy; an unknown historical adoption date stays unknown. Current-schema missing or malformed growth data is rejected. Native disk saves, backups and file imports share the migration, and new dates participate in future-time import validation.
- Game age advances at 10 game days per real day; displayed months have 30 game days and years have 12 months. Ages below 12 months show months/days; older cats show years/months in all three languages. Initial catalog ages are 90 days (orange/silver), 180 (cow/Siamese) and 365 (blue). Life stages begin at 0/180/365 game days. Existing cats explicitly start from those preset game ages on update, not an inferred birthday. Companionship counts elapsed real days. Bond stages reuse existing intimacy thresholds 0/25/50/75. This adds no rewards, decay penalty, breeding behavior or additional save timer.
- Explicit male pregnancy is rejected on decode, runtime validation, save and export. Schemas 1–8 without growth data retain existing pregnancy and infer female only when creating that missing record; already recorded sex is never rewritten. Growth/companionship saturation uses its own unchanged 1,000,000,000-day limit.
- Two higher-level jobs use the existing quote, equipment, durable settlement and paged-directory paths. Existing five jobs retain their values.

| New job | Level | Minutes | Stamina | Mood | Gold | XP |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Pet Photographer | 15 | 45 | 65 | 24 | 1,400 | 320 |
| Pet Brand Designer | 20 | 60 | 80 | 28 | 2,000 | 450 |

## Verification

- Core: 371 tests / 38 suites passed after review fixes, including pre-growth schemas, strict schema 9 decoding, durable migration/relaunch, separate cats, clock rollback, future import dates, equipment quotes, once-only offline settlement, pregnancy compatibility and independent growth saturation.
- App: 205 tests passed after review fixes, including year/month boundaries in all three languages, pregnancy supply selection, growth/career content and latest-three-release expectations (57/56/55).
- Initial candidate integrated UI: six large-screen and three small-screen scenarios passed, covering both growth pages and history, largest English accessibility text, companion selection/relaunch, career filtering/paging, new-job quotes/start/relaunch, release history and shop purchases.
- Shop layout first passed four targeted executions across both sizes (mixed descriptions, ownership, insufficient gold, Traditional Chinese locks and largest English accessibility text). The final extra English non-accessibility XXXL mixed unlocked/locked-button regression passed on both sizes with exact frame-alignment and minimum 44pt checks. These checks cover eight distinct UI scenarios overall.
- Representative screenshots were visually inspected. Runtime asset preflight passed with 164 hydrated resources; new runtime art uses Git LFS. `git diff --check` passed.
- Review-fixed Release archive `CatLife-0.16.0-57-review-p3.xcarchive` supersedes `CatLife-0.16.0-57-final.xcarchive`. Version/bundle verification, strict/deep signature validation, matching binary/dSYM UUIDs, privacy-manifest presence and exclusion of new DEBUG fixtures passed. Executable SHA-256: `a93604174caf72e49103c5ba414e43efa8cdb8cb1dc4175f3e4ef0915ab6f814`.

Full logs, result bundles, screenshots, source hashes and art-generation prompts are retained outside Git. Review fixes reran the complete Core/App suites and Release archive; the earlier UI scenarios were not rerun for this text/validation-only follow-up. The update link remains TestFlight for the beta and must change before an App Store release. Physical-device play, actual VoiceOver use, long-session battery behavior and iPad/landscape were not exercised in this pass. Upload succeeded on 2026-11-08 at 02:42 GMT+8. Apple processing completion, beta review and tester distribution are not confirmed; testing groups remain under user control.

## Runtime art

Both 1254×1254 transparent PNGs were generated with built-in `image_gen`, using `job-it-cartoon` as the style reference, then copied into the app's asset catalog with alpha preserved:

- `CatLife/Assets.xcassets/job-photographer-cartoon.imageset/job-photographer-cartoon.png`: warm 3D chibi male photographer, brown hair, sage vest and cream/teal paw-emblem camera; half-body, no text or background.
- `CatLife/Assets.xcassets/job-designer-cartoon.imageset/job-designer-cartoon.png`: matching female designer, chestnut bob, lilac clip, blue cardigan and mint paw-emblem drawing tablet/stylus; half-body, no text or background.

## Delivery

PR #20 merged at `70ce3bfdfef87a3ee34c0fe3587c0e757fd792dd`, with the same source tree as reviewed head `7e8b475c0ba291aa53ef64187ec07b44ae5d1c26`. The review-p3 archive uploaded successfully: Xcode reported `Upload succeeded`, `EXPORT SUCCEEDED`, and `Uploaded package is processing`. All 146 source/config fingerprints and the archive hash matched before/after upload. This is upload confirmation, not confirmation of completed Apple processing or available testing. No groups, invitations or beta-review submission were changed.
