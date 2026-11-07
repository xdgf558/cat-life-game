# 0.15.1 (55) — Market, supplies and furniture design

Implements `design_handoff_catlife_0.15.zip` in the native app. This candidate is for a separate PR review; it has not been merged, installed on a physical device or uploaded to TestFlight.

## Changes

- Market: full-width trade cards, neighbor portraits and remaining-use filters, four cards per page (two at accessibility sizes), eligibility-specific visit/restock/bag actions, and a map badge counting eligible offers. Confirmation shows trade stock changes, friendship and remaining uses. The same sheet changes to a saved-result view, with the traded outputs and actual relationship rewards shown separately.
- Supplies: premium and everyday sections in the shop and bag, gold effect chips, motion-aware shine, and an initially unselected food/litter picker. Cancelling never consumes stock. Saving must succeed before the picker closes, actual care effects are reported, or the cat receives its room action. Pregnancy still uses the existing required serving count; basic supplies never silently switch to premium supplies.
- Furniture: four new items are highlighted with floor/mirror/wall badges. A durable purchase produces a banner that opens arrangement with the tray expanded; it does not place the item automatically. Owned counts and the existing ten-instance purchase limit are retained rather than turning furniture into single-purchase equipment.
- The arrangement tray now uses three newly generated transparent cartoon icons for furniture storage, home upgrades and the shop. The original 70-point buttons, actions and accessibility IDs remain. The 256-pixel PNGs preserve alpha and use Git LFS; source renders and prompts stay outside the repository.
- Simplified Chinese, Traditional Chinese and English share the same 60 new string keys. Room/cat geometry, Core rules, schema 8 and web files are unchanged. Existing home-care actions retain their normal basic-supply behavior.

## Verification

- App: 197 unique tests passed cumulatively. The initial full run passed 196; one new assertion referenced the obsolete `cat.satiety` key. Correcting it to the production `stat.satiety` key made all five new Store tests pass in focused reruns. These cover delayed/failed commits, retry, navigation away during a purchase, pregnancy servings, actual capped care effects and import cleanup. Three new market tests check every offer's inventory preview, stage-reward separation and localized eligibility actions.
- UI: market preview/cancel/commit/relaunch, locked-offer navigation, gift restock, result-to-bag navigation, save-failure ownership, ordinary/premium care and inventory persistence passed. Furniture purchase-to-tray, deliberate placement, mirroring, storage and cold launch passed on both screen sizes. Small-screen market pagination/filtering/confirmation passed in all three languages at the largest accessibility size; English supply-picker controls also passed at that size. The normal and English-accessibility shop/bag purchase flow also passed. Together with the new tray-icon test, 15 distinct UI methods passed. The tray test passed on both sizes and verifies all three actual destinations, unchanged room bounds/layout/currency, and cold-launch persistence.
- The first furniture runs retained an old assumption that entering the bag would already select its furniture category. Tests now explicitly select that category. The first small-screen filter run used one fixed horizontal swipe; wider portrait/count chips now use bounded real swipes until the entire chip is visible and hittable. Both failed scenarios passed their corrected reruns, without relaxing visibility assertions.
- Visual inspection found that card-level shadows also shaded their text. Shadows now belong only to background shapes. Final small-screen furniture and multilingual confirmation screenshots were inspected after the fix. The broad navigation run also emitted SwiftUI state/frame warnings while switching to work/profile; its interactions passed, and those pages were not changed in this design scope.
- The asset preflight verified all 162 runtime files; its 20 script tests passed. The three added icons are 256×256 RGBA PNGs with transparent corners, about 289 KiB combined. The three languages contain matching sets of 60 added keys. Core and web source have no diff, so their unchanged test suites were not rerun for this presentation update. `git diff --check` passed.

Full logs, screenshots and bundles are kept outside Git; only this summary and executable tests belong in the PR.

## Release boundary

The final local `CatLife-0.15.1-55-review-icons.xcarchive` includes the three tray icons and reports version 0.15.1, build 55, bundle `com.stationcat.catlife.native`, and passed strict deep code-signature verification. Executable SHA-256: `a85a429a015cb1e322284c3beb54dd7434ee3b51fb3f2a386ffd8f3ac17e4867`.

Physical-device appearance, touch feel and audio remain for user acceptance after PR review. No TestFlight upload or test-group changes were performed.
