# Native iOS redesign — 0.8.0 (33)

final result: passed (simulator visual/interaction QA; installed phone process verified; user confirmed physical-device acceptance on 2026-11-03)

## Scope and source

The supplied ten-screen Cat Life iOS handoff is the layout and interaction reference. Its image slots are placeholders; runtime uses the existing room, cats, furniture, equipment and six player illustrations. Two generated images fill the arrival and town-map slots. The user explicitly deferred prototype-only gameplay: no neighbors/visits, affection, new economy, or save import/export/reset.

The five fixed tabs are Home, Work, Shop, Cats and More. More groups inventory, profile, arrangement and settings. Existing GameStore/Core actions own purchases, care, careers, equipment, adoption, naming and persistence. The web game and save schema are unchanged.

## Comparison method

The source screenshots and real XCTest captures were inspected side by side, rather than judging code or build success. Source: 390×844 logical points at 2×. Actual: SE 375×667 at 2× and Pro 402×874 at 3×. System safe areas are retained. Screens are normalized by logical width for comparison; the shorter SE is a deliberate compact-layout check. Real test-save values differ from the prototype, including prices, wages, levels and owned furniture.

Reference 04 uses the real completed-work fixture (60 gold, 22 XP). Most reference captures use the existing shop/room fixture, then select the female scholarly appearance and equip the free starter set through the UI. The final profile close-up uses a fresh save and selects the same appearance with empty equipment slots so all four entry controls can be checked independently. No actual phone save is altered for screenshots.

## Visual and interaction findings

- Typography and hierarchy: rounded system type, brown headings, small secondary labels and clearly separated primary actions. Names remain real saved/localized values. The profile portrait opens attributes instead of appending the entire attributes list.
- Layout: stable five-item navigation, a paged two-column career selector, two-column shop, three-column inventory with a fixed selected-item action, and four equipment slots around the profile portrait. Lists still scroll on smaller displays; actions do not become hidden behind the navigation bar.
- Color and surfaces: cream/paper surfaces, mint selection and primary buttons, gold prices, white card borders and restrained lower-edge shadows. Shadows are applied to surfaces rather than duplicated text.
- Artwork: existing in-game art is retained. Arrival art is composed to preserve the person and cat across both screen ratios. Town artwork exposes only real existing destinations. Player PNGs keep their alpha and full figures.
- Copy and behavior: three languages, real stock and prices, work settlement, audio persistence, home/character/cat names and the latest three release notes remain available. No prototype placeholder controls are presented as working features.

## Iterations

| Priority | Finding | Resolution and verification |
| --- | --- | --- |
| P2 | The arrival frame cropped the person's head when using the old portrait composition. | Generated a frame-appropriate composition; both size captures show the full person and cat. |
| P2 | The lower cat card covered the active cat on the taller room viewport. | Use the existing scene-to-view conversion to move the card to a compact upper position when needed; 10Hz sampling, safe-area bridging and entry/exit hysteresis have focused App tests. Care HUD can also be hidden. |
| P2 | Some parent accessibility identifiers replaced the IDs of child actions. | Added explicit accessibility containers at navigation, resource, work-start, language and inventory action groups. Real flow tests exercise the restored buttons. |
| P2 | The square transparent player PNG was fitted to the narrow center column, making the figure too small. | Fit by height while keeping its visible alpha bounds between the equipment slots. A focused UI journey checks the attribute action and all four slots. |
| P2 | Typing a home name applied keyboard-safe-area expansion twice, temporarily adding the 64pt tab height to the hidden SpriteKit canvas and cancelling a paused meal. | Separate keyboard-independent room geometry from the foreground form layout and remove the old inner keyboard-ignore modifier. The existing test reproduces this with real food contact, keyboard input, saved language/name changes and a return to finish the same meal. |
| P2 | A paused room's representable accessibility element remained queryable under another page. | Keep the SKView mounted with its native AX subtree hidden; expose a separate SwiftUI room action only while the scene is active. The fixed-tab regression retains a strict absence assertion. |
| Observed, not attributed | One initial SE More press showed a pressed state but did not open the menu. | A later unchanged run opened it correctly; no blind retries or coordinate changes were added. The failed run is retained in the private QA history. |

## Evidence and limits

`screens/` contains selected native captures. Verification counts and final delivery status are recorded in `verification.json`; raw XCTest results, logs, device identifiers and save contents remain private. Historical failures are not reported as passes. The original room/cat scaling rules and saved furniture coordinates are unchanged; hiding HUD/tray and moving between pages are checked for stable canvas geometry.

This is a native app; browser console checks do not apply. iPad, landscape, largest accessibility text sizes and a live VoiceOver session are outside this pass. Phone installation/launch and user acceptance are separate from simulator screenshot approval.

## Final execution

189 Core tests across 17 suites and 72 App tests passed. 16 latest device/scenario executions covering 13 distinct UI journeys passed. The keyboard regression now completes the original meal after saving a name, consumes exactly one portion and retains the expected gold. Selected evidence includes `comparison-04.png`, `comparison-09.png`, `overview.png` and the full-size captures under `screens/`.

Release 0.8.0 (33) passed signature verification and was installed in place. All 4,225 original save bytes matched before first launch. Initial launch was blocked by lock screen; after the user unlocked/opened the app, the exact installed process was verified and schema 2, identity, ownership and room layout remained intact. No reinstall or test fixture was used on the phone.

The user confirmed physical iPhone acceptance passed on 2026-11-03 and requested a review PR. This confirmation is additional to the recorded automated checks; no build or gameplay changes were made during PR preparation.
