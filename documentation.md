# documentation.md

## What Is Already Finished
- Static single-player browser architecture is in place and directly runnable from `index.html`.
- Save creation, autosave, export, import, and reset are implemented with `localStorage`.
- Main page flow exists:
  - Home
  - Room
  - Work
  - Cats
  - Collection
  - Arcade
  - Hospital
  - Shop
  - Tasks
  - Save
  - Settings
- Realtime work system is implemented, including offline completion sync.
- Realtime stamina recovery is implemented.
- Cat realtime stat decay is implemented.
- Hunger reaching zero causes cat death.
- Cat diseases, worsening, contagious spread checks, and hospital treatment are implemented.
- Item and furniture shop loops are implemented.
- Furniture affects comfort and is visible in the room scene.
- Room module exists with room themes and draggable furniture placement.
- Base cat art now uses imported sprite assets, and generated kittens inherit randomized sprite/color variants from the existing cat art pool.
- Cat collection and breeding systems exist.
- Pregnancy exists and produces kittens after realtime delay.
- Slot machine arcade exists with animated reel display and payouts.
- Background music exists with built-in scene music plus local custom BGM import.
- Chinese, English, and Japanese language modes exist, with Japanese falling back to English when needed.
- Player condition system is now implemented:
  - player stamina
  - player mood
  - sleep recovery
  - mood-based work slowdown
  - low-mood money penalty chance
  - player food/drink purchases and consumption
  - player item inventory persistence
- Current JS syntax is valid based on `node --check`.

## What Is Partially Finished
- Room customization is present, but it is still a scene-level system rather than a full custom interior editor.
- Furniture free placement exists, but there is no richer furniture management UI beyond purchase and drag placement.
- Collection/breeding exists, but the long-term meta around rare collection, breeding strategy, and progression depth is still light.
- Pregnancy exists, but there is no deeper lifecycle layer such as cooldowns, partner history, nursery UI, or broader cross-page pregnancy surfacing.
- Mobile support exists at the layout level, but interaction quality still needs real device verification.
- Japanese support exists, but newly added strings may still fall back to English rather than having dedicated Japanese phrasing everywhere.
- Player life simulation is now connected to work/shop/sleep, but balance still needs browser playtesting before treating the numbers as final.

## What Is Broken
- Browser interaction testing has not been completed.
  - Work completion after reload, sleep flow, supply consumption, room drag, and multilingual page behavior have syntax-level confidence but not a full manual browser QA pass in this review cycle.

## What Should Be Done Next
- Run a focused browser QA pass on the new player condition loop.
- Verify browser-level behavior for:
  - work duration changes at different mood ranges
  - low-mood money penalty feedback
  - sleep recovery and follow-up save/load
  - player consumable purchase/use/save/import/export
  - room drag on mouse
  - room drag on touch
- Tune balance for:
  - work mood loss
  - sleep recovery strength
  - player food/drink prices and recovery values
- After QA and balancing, decide whether the next milestone should be:
  - deeper room/furniture customization
  - richer breeding/collection progression
  - broader life-sim systems around the player
