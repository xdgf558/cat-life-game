# iOS 0.19.0 (60) — Cat Town daily community events

Prepared for a single PR against main after 0.18.0 (59). Not merged, installed on a physical device, archived for distribution or uploaded to TestFlight. The independent web game is unchanged. Tester groups and review distribution remain under the user's control.

## Behavior

- The map noticeboard, central plaza and header bell open one compact board with Today, Letters and Memento tabs. Eight local NPC stories rotate by forward local calendar day. This is single-player content, not an online message board.
- Each request offers explicit help or contribution choices. Help costs stamina and is unavailable during work or sleep; contributions consume the specified ordinary supply or one gift. Premium supplies are never silently consumed.
- A completion atomically saves its costs, friendship, relationship-stage awards and receipt. The page only shows a reply after successful persistence. It displays actual credited amounts after wallet and inventory caps, including any stage awards, separately from the contribution. Leaving the page falls back to a global notice; sound and haptics are emitted once by the Store.
- The current day cannot move backward. Date rollback and westbound timezone changes retain the current request; a stale card after midnight cannot spend resources. Duplicate taps and repeat completions cannot issue another receipt or reward.
- The board retains the latest 64 letters; normal text shows at most four per page and accessibility text at most two. Tabs remain pinned and accessible while scrolling long content. Unknown retired content IDs remain readable with an archived-reply fallback.
- Seven cumulative participations unlock one exclusive wall picture, `town-event-memory`. It is awarded to the furniture bag even when the room has no placement capacity, cannot be mirrored, is not sold in the shop and does not count as a furniture purchase. Claiming requires a durable save and cannot repeat after reload or backup import.
- The new picture is an Image Gen asset matching the existing handcrafted room art. Only the optimized transparent runtime PNG and a compact provenance note enter Git; originals remain outside the repository.
- The map no longer displays a floating adoption reminder over the header/bell. Existing map adoption markers remain available; home and upgrade pages retain the banner.

## Save compatibility

- Schema 11 adds the event ledger and receipts. Schemas 1–10 receive an empty participation history, without invented past events. Existing cats, tasks, neighbors, exchange records, growth and both furniture floors are preserved.
- Current-schema missing or malformed event fields are rejected. Structurally valid retired event/choice/neighbor/milestone IDs do not invalidate an otherwise readable save. The historical seven-participation claim threshold is frozen for validation rather than tied to future catalog balancing.
- Event time cannot lead the task calendar; a lagging ledger can synchronize forward. The existing independent v7/v8/v10 migration fixtures and roster guard are retained at schema 11.
- Receipt timestamps participate in backup future-time validation. Failed import keeps the board and original progress; successful import closes the board and rebuilds its navigation using the new save generation. Late results from the previous generation are ignored.

## Verification

- Core: a full run passed 392 tests in 41 suites. After the final busy-reason and frozen-claim-threshold fixes, all 15 event/migration tests passed in two suites. This is 393 distinct cases with passing results, not a single final 393-test run.
- App: the full 262-test run passed. Focused checks then passed the five event Store tests and three furniture geometry tests; the final large-screen run also passed the two affected import tests and all five event Store tests.
- Store checks cover failed save without spending or publishing, successful retry, duplicate clicks while saving, leaving the board, background completion, stale cards, actual relationship rewards, milestone persistence, archive round-trip and three-language/catalog coverage.
- Geometry checks include the keepsake as wall furniture across all home levels, both unlocked floors and two viewport sizes. It does not obstruct floor paths and has localized metadata and a hydrated transparent asset.
- iPhone 16 Pro and iPhone SE simulators passed the event/reply, letter pagination, seven-participation keepsake, furniture bag and cold-relaunch duplicate-prevention journey. The large-screen journey enters through the actual map plot; header-bell entry is also exercised.
- Both sizes passed the maximum accessibility-text journey, retaining at most two letters per page and a reachable action. The small-screen three-language and injected-save-failure/retry journey passed again after the paper-shadow and short-detail-title adjustments, together with all five event Store tests. Final visual inspection also shortened the English detail back label to avoid wrapping the last letter onto a third line.
- Runtime assets and final unsigned generic-iOS Release checks passed as detailed below. Release validation does not imply a signed upload-ready archive or physical-device acceptance.

Early regressions caught a map reminder covering the bell, inaccessible tabs with maximum text and an accessibility identifier propagated into letter rows. Those product issues were corrected before the successful reruns. One English test expectation was corrected to the existing “Cats” tab label; page-count and persistence assertions were retained.

Raw logs, screenshots, result bundles and original art remain outside Git in the build-60 artifact directory. This summary is the only new QA record committed for this version.

## Final checks

- iPhone SE three-language/save-failure/retry UI journey: passed; all five event Store tests passed in the same run. The final back-label adjustment passed a further three-language UI rerun (125.092 seconds).
- Runtime preflight: 172 hydrated files, no LFS placeholders. Final generic-iOS Release build: succeeded with code signing disabled.
- Release metadata: 0.19.0 (60), expected Bundle ID. Compiled assets and the existing UserDefaults privacy declaration (`CA92.1`) are present; UI-testing, event-fixture and save-outage launch markers and test class names are absent from the Release binary.

## Remaining validation and next work

Physical-device performance, prolonged play in a densely furnished level-8 home, battery use, actual VoiceOver operation, iPad and landscape have not been verified. Simulator timing is not a physical-device measurement. The existing TestFlight update link still needs an App Store destination before a public App Store release. No player replenishment system, multiplayer, cloud storage or unrelated gameplay system is included here. Next: user PR review, then upload only after explicit approval.
