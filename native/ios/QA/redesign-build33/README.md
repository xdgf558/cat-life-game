# iOS 0.8.0 (33) UI/UX redesign

Implements the supplied Cat Life iOS design handoff in the existing SwiftUI + SpriteKit app. The web game is unchanged.

Five fixed destinations replace the horizontal navigation strip. More opens bag, player profile, arrangement and settings. Existing care, work, purchases, equipment, adoption, names, language and audio continue to use GameStore / CatGameCore. Prototype prices, demo timers and example names are not runtime data. Neighbor visits, affection, save import/export/reset and other unimplemented prototype features are explicitly deferred at the user's request.

The home HUD includes three floating care actions, prioritized cat needs and a status card. The card switches to a compact upper position when it would cover the cat; controls and the furniture tray can also be hidden without resizing the SpriteKit canvas. Room/cat scaling algorithms and saved furniture positions remain unchanged. The welcome illustration was recomposed for the new frame so the player and cat remain visible on small screens.

New runtime art: `town-map` and `welcome-homecoming`, generated for this update with the built-in image generator. Existing cat, player, furniture and room assets are reused. New images are tracked with Git LFS. Runtime inventory: 70 hydrated media files.

Validation is complete: 189 Core tests, 72 App tests and 16 latest device/scenario UI executions passed. 0.8.0 (33) was installed in place; all 4,225 prelaunch save bytes matched, and the installed process plus stable save fields were verified after the user opened the app. See `verification.json`, `device-delivery.json` and `design-qa.md`. Raw build logs, device identifiers, test save files and xcresult bundles remain outside the repository.
