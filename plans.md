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

## Current Milestone
- Current milestone: `Milestone 7: Bank And Interface Refresh`
- State: `completed`

## Current Focus After This Milestone
- Run targeted browser QA on the refreshed interface and new bank flow
- Verify in-game day progression for sleep, work completion, savings interest, and loan interest accrual
- Tune debt pressure, savings payout, credit-tier loan limits, hunger pacing, and player recovery values if playtests feel harsh

## Stop Conditions Before The Next Feature Batch
- Old saves must continue loading without missing-field crashes
- Work summary, sleep recovery, and bank auto-repayment must behave correctly after reload
- Player consumable counts must persist correctly across save/export/import
- Bank balances, loan principal, accrued interest, and manual repayment must persist correctly
- Savings payout previews, loan-interest previews, and full payoff must behave correctly after reload
- No cat-care regression should appear while testing the new player-life loop
