# plans.md

## Milestones

### Milestone 1: MVP Foundation
Status: completed
- Static local-open project structure
- Core pages: home, work, cats, shop, tasks, settings
- Local save initialization, autosave, import/export/reset

### Milestone 2: Realtime Progression
Status: completed
- Computer-time based clock
- Realtime work completion with offline sync
- Realtime stamina recovery
- Cat stat decay over realtime

### Milestone 3: Midgame Systems Expansion
Status: completed
- Cat unlock conditions
- Disease and hospital system
- Item variety and furniture comfort loop
- Mobile-friendly layout
- Arcade slot module
- Version update notes in UI

### Milestone 4: Room, Collection, Breeding
Status: completed
- Standalone room module
- Visible room scene and roaming cats
- Collection/encyclopedia page
- Breeding, pregnancy, and generated kittens
- Free furniture placement

### Milestone 5: Player Condition And Life Simulation
Status: completed
- Player stamina and mood are now first-class state
- Mood affects realtime work duration and can trigger money penalties
- Sleep restores stamina and mood
- Shop now includes player food and drinks
- Player consumables can be stored and used from inventory

### Milestone 6: Stabilization And Browser QA
Status: next
- Verify room drag on desktop and touch devices
- Verify work completion, sleep flow, and player-item consumption in browser
- Verify import/export compatibility with old saves and generated kittens
- Tune balance for mood pressure, sleep recovery, and consumable pricing

### Milestone 7: Bank And Interface Refresh
Status: completed
- Top navigation moved above the game shell
- Cozy village-style UI refresh
- Bank module with deposit, withdraw, loan, and repayment
- Loan interest accrual by in-game day
- Work income auto-deduction toward active loans
- Savings-interest preview and payout visibility
- Dynamic loan limit based on repayment behavior
- One-tap full payoff flow

### Milestone 8: Arcade Lottery Expansion
Status: completed
- Local single-player lottery added inside the Arcade
- Manual 6-digit ticket entry and random ticket generation
- UTC daily draw handling and pending draw states
- Bitcoin block-hash-based winning number resolution
- Jackpot rollover, reset, and prize-tier payouts
- Lottery save/load compatibility for old saves

### Milestone 9: Community And NPC Neighbors
Status: completed
- Former Room entry upgraded into Community
- Player Home preserves the existing room scene, renovation, furniture placement, and roaming player cats
- Community main screen upgraded from a card list into a clickable Cat Town map
- Four NPC neighbors added:
  - Mira
  - Ken
  - Luna
  - Grace
- NPC homes display each neighbor's personality, home style, and cats
- NPC cats now use the imported cat sticker sheet with different poses and color-filtered coat variants
- Visiting NPC homes gives first-visit daily friendship once per in-game day
- NPC gifting supports favorite, neutral, and unwanted gift reactions
- NPC item exchange supports relationship requirements, inventory requirements, and daily limits
- Community state saves and loads through the existing localStorage save object

## Current Milestone
- Current milestone: `Milestone 9: Community And NPC Neighbors`
- State: `completed`

## Current Focus After This Milestone
- Run targeted browser QA on Community navigation, Player Home access, gifting, exchange, and daily visit limits
- Run targeted browser QA on the refreshed interface, bank flow, and new lottery flow
- Verify UTC date rollover and delayed draw resolution behavior for the lottery system
- Tune debt pressure, savings payout, credit-tier loan limits, lottery excitement, hunger pacing, player recovery values, and community friendship pacing if playtests feel harsh

## Stop Conditions Before The Next Feature Batch
- Old saves must continue loading without missing-field crashes
- Existing home, room, and furniture layout data must remain intact after Room becomes Community
- Community relationship values, visit limits, gift counts, and exchange counts must persist correctly
- Work summary, sleep recovery, and bank auto-repayment must behave correctly after reload
- Player consumable counts must persist correctly across save/export/import
- Bank balances, loan principal, accrued interest, and manual repayment must persist correctly
- Savings payout previews, loan-interest previews, and full payoff must behave correctly after reload
- Lottery tickets, pending draws, history, and jackpot pool must persist correctly across reload and import/export
- No cat-care regression should appear while testing the new player-life loop
