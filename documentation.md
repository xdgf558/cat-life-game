# documentation.md

## What Is Already Finished
- Static single-player architecture is in place and directly runnable from `index.html`.
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
  - Settings
- Realtime work system is implemented, including offline completion sync.
- Realtime stamina recovery is implemented.
- Cat realtime stat decay is implemented.
- Hunger reaching zero causes death.
- Cat diseases, worsening, contagious spread checks, and hospital treatment are implemented.
- Item and furniture shop loops are implemented.
- Furniture affects comfort and is visible in the room scene.
- Room module exists with room themes and draggable furniture placement.
- Generated cat artwork exists via inline SVG generation.
- Cat collection and breeding systems exist.
- Pregnancy exists and produces kittens after realtime delay.
- Slot machine arcade exists with animated reel display and payouts.
- Background music system exists using Web Audio.
- Chinese and English language modes both exist.
- Current JS syntax is valid based on `node --check`.

## What Is Partially Finished
- Room customization is present, but it is still a scene-level system rather than a full custom interior editor.
- Furniture free placement exists, but there is no furniture inventory management UI beyond purchase and drag placement.
- Collection/breeding exists, but the overall meta loop around rare collection, breeding strategy, and long-term progression is still light.
- Pregnancy exists, but there is no richer lifecycle layer such as cooldowns, partner history, nursery UI, or explicit pregnancy indicators on every relevant screen.
- Mobile support exists at the layout level, but interaction quality still needs real device verification.
- English support exists, but not every renderer is fully localized consistently.
- Version notes exist, but there is no separate changelog/documentation process yet.

## What Is Broken
- Browser interaction testing has not been completed.
  - Dragging, pregnancy completion after reload, and slot animation behavior have syntax-level confidence but not full browser-level verification in this review pass.

## What Should Be Done Next
- Stabilize and finish the current feature set before adding more content.
- Run a targeted browser QA pass on multilingual mode, drag placement, pregnancy completion, and generated-cat lifecycle.
- Run browser-level verification for:
  - room drag on mouse
  - room drag on touch
  - import/export with generated kittens
  - pregnancy completion after offline time
  - slot animation clipping
- After stabilization, decide whether the next milestone is:
  - deeper room/furniture customization
  - richer breeding/collection progression
  - more content balancing and polish
