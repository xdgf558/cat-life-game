# iOS 0.15.2 (56) — PR #19 review fixes

Scope: fix bounded market/neighbor navigation; focus the exact newly purchased furniture instance without automatic placement; route full rooms to upgrades or storage at maximum level; use wall metadata for placement hints; date-stamp native backup filenames consistently across preview, Files export, and sharing. The TestFlight update link remains appropriate for this beta channel. No Core balance, schema 8, save archive format, room/cat scale, or web changes.

The previous 0.15.1 (55) UI/art redesign is included. Build 55 was reviewed but was not uploaded separately. The user explicitly authorized these fixes, merging PR #19, and upload after validation; tester groups and distribution remain manual.

Validation in this pass:
- 201 App tests passed with zero failures, including durable purchase failure/retry, repeat-instance selection, full-room/maximum-level routing, transient-state cleanup, backup names, and export-cache cleanup.
- Five distinct UI scenarios passed across the large and small simulators (10 successful executions including focused retests): bounded market navigation, purchase/selection/placement/mirroring/storage/relaunch, full-room upgrade routing with unchanged layout/gold, dated Files export/import/recovery, and the latest-three-release page. Initial full-room automation needed an explicit scroll to the plant card. The next pass exposed a real stale ShopListing navigation path when switching to upgrades; the shared shop/bag/upgrade NavigationStack now resets its identity on destination changes. A subsequent test assertion was corrected to match the system-formatted 4,880 gold value. Final retests passed for the actual shortcut and preserved layout on both sizes. The only production change after the 201 App-test pass was the SwiftUI navigation identity reset, verified by these UI retests.
- Three-language shop keys align. The version and latest-three-release expectations now cover 56/55/54.
- Runtime asset preflight passed (162 hydrated files). `git diff --check` passed.
- Final `CatLife-0.15.2-56-final.xcarchive` (superseding the earlier reviewed candidate) reports 0.15.2 / 56 / com.stationcat.catlife.native. Strict/deep code signature validation passed; executable/dSYM UUIDs match; the privacy manifest is present; debug test entry points are absent.

Release executable SHA-256: `da65553a90f95662474b10d51963f2e1dfdc2252cbf5b7c6ac483ba868da92ad`.

Full logs, result bundles, screenshots, source hashes, and signing evidence remain outside Git. No physical-device installation or save modification was performed. Core/web tests were not rerun because neither runtime was modified. Upload success and Apple processing status will be recorded separately; no test group, invitation, or beta-review submission is authorized here.
