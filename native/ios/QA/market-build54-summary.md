# 0.15.0 (54) — Neighbor exchange market

Status: implemented and verified; local signed archive built. PR review is required before TestFlight upload. No upload, test-group change or tester invitation was performed.

## Scope

- Four local NPC neighbors, eight exchange offers, two exchanges per neighbor per day. Stage 3 unlocks advanced offers. Previewing/cancelling spends nothing; material and output-capacity checks run before committing the whole trade. Successful exchanges add up to two friendship points and retain the existing once-only stage rewards.
- Market entry from the town map, neighbor detail and task shortcuts. Normal text shows four offers per page; accessibility text shows two. The confirmation shows inputs, outputs, owned quantities and remaining exchanges.
- Premium food: 40 gold, shop level 2, fullness +55 / mood +5 / bond +3. Premium litter: 45 gold, shop level 3, cleanliness +65 / health +5. Both are independently stocked, can also be exchanged, and are explicitly chosen from the backpack. Home actions with only premium stock navigate to that selection without consuming anything.
- Oak bookcase, rattan chair, rounded side table and sunrise wall art. Purchased furniture enters storage; floor pieces support mirroring and collision-aware placement; wall art stays on the wall. New decorative pieces do not add climbing/rest actions. Starter room, existing furniture and cat scale are unchanged.
- Four exchange goals reuse the existing level gates, claim receipts and hide-after-claim behavior.

## Save compatibility

Schema 8 adds premium stocks and per-neighbor exchange counters. Only absent fields in older schemas receive defaults; explicit malformed values and missing current-schema fields are rejected. Existing cats, furniture, friendship, stage receipts, supplies and task claims are retained. Daily exchange limits share the existing monotonic day ledger; clock rollback cannot reset them. Schema-7 roster preservation and the schema-8 neighbor migration guard are tested. Web code and browser saves are untouched.

## Verification

- Core: 356 tests passed, including premium care, all offers, full output stock, daily/relaunch/timezone limits, migration, transfer round-trip and task claims.
- App: 184 unique tests verified. The full run passed 183; the new furniture geometry test initially used an unrealistically thin bowl. After matching production bowl dimensions, all three new furniture geometry tests passed in a focused rerun. No production geometry workaround was needed.
- Runtime asset checker: 20 tests passed; all 159 runtime media files hydrated and validated. Six new transparent PNGs use Git LFS.
- UI: large-screen exchange preview/cancel/lock/commit/relaunch/neighbor entry passed; save-failure rollback passed; bookcase purchase/place/mirror/store/relaunch passed; premium supply purchase/use/relaunch passed on large and small screens. Small-screen accessibility-font pagination and confirmation were verified in Simplified/Traditional Chinese during the combined run and in English in the passing focused retest. There are six passing UI executions across five distinct methods (premium supplies ran on both screens); the combined multilingual run supplied the two Chinese-language checkpoints.
- A total-food HUD assertion was updated to include premium stock. The accessibility-market check exposed an over-tall fixed pager and a test drag that started on that pager; the page size, text layout and actual scroll viewport were corrected without weakening the visibility assertions. English maximum-size text required a scoped 14-drag budget and a real horizontal scroll to reveal its neighbor filter; the focused English scenario then passed.
- Release archive built successfully and passed `codesign --verify --deep --strict`; metadata is 0.15.0 (54), bundle `com.stationcat.catlife.native`. Binary SHA-256: `81e089cc43ff506ea47bb9452ff1517144f645ba27c194bef74b80fde28c447d`.

Full logs, result bundles, screenshots, original art prompts and archives remain outside Git history or in ignored distribution output. This PR keeps the tests, runtime assets and this compact summary only. Physical-device feel and audio remain for the user's TestFlight acceptance after review; no real-device install was performed in this task.
