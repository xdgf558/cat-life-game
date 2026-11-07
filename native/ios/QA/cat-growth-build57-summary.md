# iOS 0.16.0 (57) — growth, companionship, careers and shop layout

One combined PR, as requested. The native web game remains independent and unchanged. This is a review candidate; it has not been uploaded to TestFlight or installed on a physical device.

## Delivered behavior

- Furniture and equipment cards share each row's natural height, with bottom-aligned purchase buttons. Smaller art panels, two-line summaries and an ownership badge over the art make the grid more compact; full descriptions remain in product details. Accessibility sizes use one column with unabridged text. Locked buttons use a short level label in two-column mode and keep the full accessibility label.
- Cat profiles have a compact entry to a separate growth/companionship page: game age, life stage, sex, bond stage, next thresholds and individual history. Returning home selects the intended companion without consuming supplies. Room and cat scale are unchanged.
- Schema 9 stores per-cat growth anchors. Schemas 1–8 start records at migration and preserve existing intimacy; an unknown historical adoption date stays unknown. Current-schema missing or malformed growth data is rejected. Native disk saves, backups and file imports share the migration, and new dates participate in future-time import validation.
- Game age advances at 10 game days per real day; displayed months have 30 game days. Initial catalog ages are 90 days (orange/silver), 180 (cow/Siamese) and 365 (blue). Life stages begin at 0/180/365 game days. Existing cats explicitly start from those preset game ages on update, not an inferred birthday. Companionship counts elapsed real days. Bond stages reuse existing intimacy thresholds 0/25/50/75. This adds no rewards, decay penalty, breeding behavior or additional save timer.
- Two higher-level jobs use the existing quote, equipment, durable settlement and paged-directory paths. Existing five jobs retain their values.

| New job | Level | Minutes | Stamina | Mood | Gold | XP |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Pet Photographer | 15 | 45 | 65 | 24 | 1,400 | 320 |
| Pet Brand Designer | 20 | 60 | 80 | 28 | 2,000 | 450 |

## Verification

- Core: 368 tests / 38 suites passed, including pre-growth schemas, strict schema 9 decoding, durable migration/relaunch, separate cats, clock rollback, future import dates, equipment quotes and once-only offline settlement.
- App: 204 tests passed, including three-language growth/career content and latest-three-release expectations (57/56/55).
- Integrated UI: six large-screen and three small-screen scenarios passed, covering both growth pages and history, largest English accessibility text, companion selection/relaunch, career filtering/paging, new-job quotes/start/relaunch, release history and shop purchases.
- Shop layout first passed four targeted executions across both sizes (mixed descriptions, ownership, insufficient gold, Traditional Chinese locks and largest English accessibility text). The final extra English non-accessibility XXXL mixed unlocked/locked-button regression passed on both sizes with exact frame-alignment and minimum 44pt checks. These checks cover eight distinct UI scenarios overall.
- Representative screenshots were visually inspected. Runtime asset preflight passed with 164 hydrated resources; new runtime art uses Git LFS. `git diff --check` passed.
- Final Release archive `CatLife-0.16.0-57-final.xcarchive` supersedes the earlier review archive. Version/bundle verification, strict/deep signature validation, matching binary/dSYM UUIDs, privacy-manifest presence and exclusion of new DEBUG fixtures passed. Executable SHA-256: `3ad78f12e5f651ea2d6f4238e4f1045ec3d86dfe4da4705cc4d3eb799b9f6047`.

Full logs, result bundles, screenshots, source hashes and art-generation prompts are retained outside Git. Physical-device play, actual VoiceOver use, long-session battery behavior and iPad/landscape were not exercised in this pass. Upload, Apple processing, beta review and tester distribution remain pending user approval.

## Runtime art

Both 1254×1254 transparent PNGs were generated with built-in `image_gen`, using `job-it-cartoon` as the style reference, then copied into the app's asset catalog with alpha preserved:

- `CatLife/Assets.xcassets/job-photographer-cartoon.imageset/job-photographer-cartoon.png`: warm 3D chibi male photographer, brown hair, sage vest and cream/teal paw-emblem camera; half-body, no text or background.
- `CatLife/Assets.xcassets/job-designer-cartoon.imageset/job-designer-cartoon.png`: matching female designer, chestnut bob, lilac clip, blue cardigan and mint paw-emblem drawing tablet/stylus; half-body, no text or background.
