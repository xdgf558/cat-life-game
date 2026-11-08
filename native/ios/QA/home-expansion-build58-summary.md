# iOS 0.17.0 (58) — two-floor homes, compact shop, town map v2 and music

Prepared for review, not uploaded to TestFlight. This version covers the requested house expansion and shop browsing, followed by the town-map v2 design handoff. Community events/message-board gameplay remains deferred. The independent web game is unchanged.

## Behavior

- Work Street, Home and Cat Collection use matching transparent cartoon art. A fourth staircase illustration forms a fixed room-side landing, outside the furniture canvas so it cannot displace an existing layout. Tapping the stairs takes the companion between floors; it does not add an animated stair-climbing path.
- Home levels now run from 1 to 8. Existing levels 1–3 retain prices, requirements, capacity and scale. Level 6 adds an empty upper floor with its own bowl; floors are decorated separately. Floor switching does not shrink the room, cat or furniture. A cold launch starts downstairs, retaining both saved layouts.
- Every successful, durable upgrade presents a celebration; failed or repeated purchases and cold loading never replay it. Reduce Motion uses a static presentation. Decoration must be finished/cancelled before changing floors. Care animations must finish; an active furniture rest ends durably before changing floors, and write failure leaves the original floor/rest intact.
- Backpack furniture labels include the placed floor. Jumping to an already placed item opens that floor and selects it. Each instance can exist on only one floor; put it away before placing it elsewhere. Floor capacities are independent even when the other floor has spare space.
- After buying furniture, the shop prefers the current floor, then another unlocked floor with spare capacity. A full ground floor with empty upstairs offers **Arrange upstairs**, including the remaining slot count; only a fully occupied home suggests an upgrade or putting furniture away. Travel must finish durably before the purchased item is selected in the expanded tray. It is not placed automatically. Failed rest saves keep the purchase banner and original floor; leaving the shop, opening settings, or dismissing the purchase while saving prevents stale navigation.
- Shop categories have bounded pages (6 items normally, 2 at accessibility sizes). Supplies filter by standard/premium; furniture filters by floor/wall. Category/filter changes return to the first page and top. Details, prices, ownership, purchase validation and existing card alignment remain intact.

| Home level | Per-floor items | Floors | World scale per floor | Upgrade gold | Player level |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 9 | 1 | 1.00 | 0 | 1 |
| 2 | 12 | 1 | 1.25 | 450 | 2 |
| 3 | 16 | 1 | 1.50 | 900 | 4 |
| 4 | 20 | 1 | 1.65 | 1,600 | 6 |
| 5 | 24 | 1 | 1.80 | 2,400 | 8 |
| 6 | 24 | 2 | 1.80 | 3,600 | 10 |
| 7 | 28 | 2 | 1.90 | 5,000 | 13 |
| 8 | 32 | 2 | 2.00 | 7,000 | 16 |

- Two additional scene tracks were created in Suno: Cat Town Promenade for the map, and Sunlit Upstairs for the upper floor. Existing town music remains in neighbor, market and collection views. Muting, saved volumes, scene-music preference, quiet nights, background suspension and crossfades reuse the audio controller. Sources and detailed audio processing evidence are outside Git.

- Town map v2 replaces the grid with a vertically explored landscape, fixed place details, home positioning, time-of-day atmosphere and live work/health/adoption/visit/exchange badges. Existing routes and save-error handling remain. Future places stay unavailable; no fake notification subscriptions, new-shop badges or cafe level rules are introduced. Map coordinates are presentation only.

## Save compatibility

Schema 10 adds an explicit floor to furniture placements and an upper-floor bowl. Schemas 1–9 keep their existing furniture/bowl downstairs; current-schema missing/invalid floors and locked upstairs data are rejected. Rendering gets a current-floor projection; purchasing, export, import and persistence use the complete snapshot. Commits merge only the edited floor and reject duplicate item placement or changes to another floor's orientation. Import resets transient floor selection, old scene callbacks and celebrations.

## Verification

- Core: 378 tests passed across 39 suites, including old-schema migration, locked/invalid floors, capacity, cross-floor item ownership and preservation of the other floor.
- Review-fix App run: 236 tests passed, including floor travel/save failure, all-cat rest completion on cold launch, UI projections, map geometry/status and shop filters. This includes the two new decoded audio resources, map/subpage/floor music routing, night preferences and failed-rest-exit music preservation.
- Camera projection and furniture placement/feeding geometry now traverse every `HomeCatalog.all` level and its unlocked floors (11 level/floor combinations), on both test viewports. Purchase-routing tests cover both directions at levels 6 and 8, full-home upgrade/storage fallbacks, failed rest-save retry, busy care, navigation/settings changes during saving, and legacy total-capacity limits.
- Review-fix SE UI checks passed for the new full-downstairs → upstairs purchase shortcut (correct remaining-slot count, selected new item, no automatic placement, cancelled draft preserves downstairs) and the existing full single-floor → upgrade route. Exported screenshots were visually checked for readable text and controls. The review-fix Release archive passed version/build, strict signature, dSYM matching and DEBUG-fixture isolation checks.
- Targeted UI regression passed on iPhone 16 Pro and SE simulators for floor unlock/travel, independent placement and cold relaunch, upstairs feeding with no contact violations, camera/meal-bubble bounds, compact shop/category paging and largest text shop browsing. Map destinations/return selection, future places, night appearance, save-failure alerts, adoption upgrade reminders and existing bag/care flows passed. The final SE English maximum accessibility-size/night test passed for hospital, cafe, adoption and home positioning.
- Map building and wooden-label frames do not overlap. The map uses more vertical space than the mockup to preserve readable 3D artwork. Accessibility sizes use a large-text location list, scrollable details and an intrinsic-height action button.
- One large-screen test failure was traced to Simulator loading a stale UITest Runner from its retired container. Reinstalling only the test runner made the unchanged test/build pass; game data and DerivedData were not removed.
- All 171 runtime assets passed preflight. The 0.17.0 (58) Release archive passed strict signature verification, dSYM UUID matching, bundled-new-audio hash matching and absence of DEBUG UI-test flags; final diff checks passed. No raw QA result bundles, logs, screenshots or art/audio source files are added to Git; new runtime PNG/CAF files use LFS.

## Not included

No community events, message board, player consumables, web-game changes or TestFlight distribution. Physical-device play, subjective music transitions/speaker/headphone listening, long-session battery behavior, actual VoiceOver and iPad/landscape require separate validation. The existing beta update link still targets TestFlight and must change before an App Store release.
