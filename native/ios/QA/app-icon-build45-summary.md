# 0.12.2 (45) — App icon replacement

## Change

Uses the final C “work cap + orange cat” AppIcon.appiconset from the user’s design handoff, copied byte-for-byte. Default, dark and tinted images are 1024×1024 opaque RGB PNGs. Package/file hashes and provenance are in `ArtSource/app-icon-build45/README.md`; only the three runtime images and a short provenance note are added, not the ZIP, alternate candidates or generator scripts.

The artwork importer now leaves the authoritative AppIcon assetset unchanged instead of regenerating the legacy icon. Runtime inventory and sandbox inputs include both new appearance images (124 resources total). Info.plist, recent releases, three-language notes and existing version-page test expectations use 0.12.2 (45). Gameplay, saves, room/cat sizes and the web app are unchanged; no project regeneration was required.

## Verification

- All four assetset files match the supplied bytes; all three PNGs decode as 1024×1024 RGB with no transparency. Compiled Release Assets.car contains AppIcon.png, AppIcon-dark.png / UIAppearanceDark, and AppIcon-tinted.png / ISAppearanceTintable for phone and pad, with the primary icon named AppIcon.
- Runtime preflight: 124 hydrated resources. Existing resource-validator suite: 20 tests passed. New release keys are present in all three languages with equal key sets.
- Isolated importer fixture: all three icons and Contents.json remain byte-identical; ordinary game art imports correctly and the legacy icon master is ignored. No real batch import or image regeneration was performed.
- Debug build-for-testing and Release archive passed. Two existing small-screen UI regressions passed: latest-three-release/settings navigation (`icon-version-ui.xcresult`) and English version navigation followed by resuming a meal (`settings-meal-ui.xcresult`). Each bundle contains one passing test. Other unchanged gameplay/Core/App suites were not rerun.
- Local archive `CatLife-0.12.2-45.xcarchive`: 142.0 MB including symbols. Bundle/version, signature, dSYM UUID, privacy manifest and absence of DEBUG fixture flags passed. Binary SHA256: `695322da65e21bdf32fbbef42fc2be397b96818fb580b8a69e1ce7d557489d69`.

## Desktop check and limitations

A simulator overwrite install reports 0.12.2 (45), and the installed AppIcon60x60@2x.png visibly contains the new design. Its initial SpringBoard screenshot still showed the old icon, consistent with icon caching. The simulator was rebooted without uninstalling or deleting its data, but the icon’s page and appearance customization could not be reached through Device Hub computer-control gestures; post-reboot SpringBoard replacement and actual dark/tinted switching are therefore **not claimed as verified**. Compiled appearance mappings and installed image decoding are verified separately.

Raw screenshots, xcresults and logs remain outside Git. No real device was installed or modified, and Spotlight/notification thumbnails were not inspected. Physical-device update/cache refresh and light/dark/tinted system display remain acceptance items. No PR merge or TestFlight upload is included; the version awaits review under the existing release workflow.
