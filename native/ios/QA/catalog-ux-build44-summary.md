# 0.12.1 (44) — catalog, adoption and arrangement UX

## Scope

Implements the supplied `design_handoff_catlife_0.12.zip` on top of 0.12.0 / PR #11. The collection has breed segments, filter counts and four cards per page; adoption has live requirement rows with useful destinations, a compact confirmation sheet, a saved-success screen and a persisted bring-home action. Arrangement adds clamped floating flip/store controls, direction segments, explanatory wall/bowl feedback and an unsaved badge. Eligible adoption reminders appear only after saved foreground level/room upgrades, once per offer, and are kept in local preferences rather than the game save.

Core gameplay, adoption prices/requirements, schema 6, room/cat dimensions, physics and the web app are unchanged. Existing bag/tray, resources HUD and cartoon art remain available. The new UserDefaults access is declared with CA92.1 in the privacy manifest.

## Validation

The App suite passed 119 tests, including six reminder-policy cases, four saved/foreground integration cases and three arrangement geometry/animation cases. Runtime asset validation passed for 122 hydrated resources, plus 20 resource-validator tests. Simplified Chinese, Traditional Chinese and English contain the same 876 unique localization keys.

Eleven distinct targeted UI methods have passing latest runs across 375×667, 390×844 and 402×874 simulators: three-language confirmation; full adoption/bring-home/empty state; missing-condition destinations; nine-cat pagination and independent rename; save-failure retries without duplicate charges; saved upgrade reminders with no relaunch replay; Town/bag navigation; latest-three release history; quick actions and bag return; every supported furniture kind plus wall/bowl explanations; expanded-room mirror, storage, upward drag and relaunch. The final SE all-furniture selection run passed after adapting the test to tap the exposed artwork rather than the floating toolbar. Relevant result bundles are `release-candidate-app`, `final-small`, `catalog-small-fixed`, `final-responsive`, `furniture-large`, `furniture-large-fixed`, `final-design`, `final-furniture-390`, `final-furniture-small`, and `final-small-selection`; earlier failures remain as iteration evidence, not deleted or reported as successful runs.

Release archive: 0.12.1 (44), 144.6 MB including symbols. Local signature verification, dSYM UUID, bundled privacy manifest, bundle/version and absence of DEBUG fixture flags passed. Executable SHA256: `e3a8e77533f5a473775d6a462007d72b493586c07cce159f378ce7f78689f993`. Project regeneration is byte-stable, and `git diff --check` passes.

Raw xcresults, screenshots, recording frames and build logs stay outside Git under the build44 external build cache and local temporary QA directories. No original user save was modified and no device installation or TestFlight upload was performed.

## Iterations retained

- Accessibility identifiers on plain parent containers propagated to child buttons. Success/empty-state markers now belong to leaf headings; interactive controls retain distinct button identities.
- Unselected orientation segments now expose their entire 44pt target. Scene pause resets the arrangement frame sampler so returning from the bag can republish unchanged selection bounds.
- Visual comparison found duplicated text shadows and an unnecessarily tall confirmation sheet. Shadows now belong only to backgrounds; confirmation starts at 480pt, supports expansion, and keeps confirmation/cancel actions visible while long content scrolls.
- An old pagination test assumed the filter remained onscreen after visiting all four cards. It now scrolls back before choosing the filter, preserving the same assertions.
- On the small screen, one old fixed furniture tap landed on the new toolbar. The test now chooses a visible point on the actual sprite, retaining the same real tap, selected-ID and cancel-restoration assertions.
- iOS 26 exposed a DEBUG pinch-test accessibility surface above floating buttons, while iOS 27 did not. That test-only layer now precedes real interactive overlays; hit-testing assertions remain. This helper is absent from Release.

## Art provenance

The user-supplied handoff ZIP SHA256 is `91b473eb7283c7623e099a6bdcd4195268b94f9e351f994bf3bf0ae6f6d5ac2a`. Its screenshot placeholders are replaced with existing game cat/furniture art as requested. One new decorative asset, `adoption-success-rays.png`, was generated with the built-in Image Gen tool for this implementation: muted blue/cream radial rays, no words, characters or icons. The inspected 1024×1536 PNG is included unmodified through Git LFS; SHA256 `08af07c70fe89d91e59f4fb3515b98a3b0c68205ff7f550ee300eca0b17cc028`. No full handoff ZIP, source prompt dump or raw QA media is added to the repository.

## Delivery boundaries

This version is a separate review PR based on PR #11. No PR is merged and no TestFlight distribution is performed. Physical-device touch/haptics and extreme accessibility text sizes still need acceptance. The unchanged Core suite's previous 286-test result is not represented as a new run.
