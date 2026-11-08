# iOS 0.18.0 (59) — shared cat rooms and care fixes

Prepared for PR review. Not installed on a physical device and not uploaded to TestFlight. The independent web game is unchanged.

## Behavior

- Task destination buttons now have the missing neighbor translation in Simplified Chinese, Traditional Chinese and English. A catalog-driven test checks every reachable task destination against every language dictionary, including keys absent from all three dictionaries.
- Food empties at the last-bite milestone, before withdrawal and the return walk. The overall action completion remains separate. Cancelled generations cannot emit a late meal milestone; Reduce Motion empties after the brief stationary response.
- Home level 4 unlocks shared rooms for already adopted cats. Below level 4, only the selected companion is rendered. Both unlocked floors display the owned cats when visited. Room, furniture and cat sizes are unchanged.
- Tap a resident to open that cat's existing profile and select a companion. Feeding, cleaning, play and durable furniture rest still apply to the selected cat. Shared rendering does not duplicate care, spending, rewards, adoption or save records.
- Other cats breathe/look around and take short turns walking. Only one cat travels at a time; care waits for that short walk, then uses stationary-cat obstacles throughout approach, meal docking, pouncing and furniture entry. The planner runs off the main thread and preserves feeding routes for every cat and reachable rest routes for the companion.
- Routine refreshes retain actors and positions. Switching companions preserves safe positions instead of redistributing housemates. Floor/layout changes invalidate old planning results; queued care resumes when returning from a paused page. Decoration temporarily hides the other residents and rebuilds their safe positions afterward.
- A crowded or unreachable floor never forces cats into furniture or each other. A notice asks the player to clear floor space if some residents cannot fit; all owned cats remain available in the collection. The Store remembers up to 64 warned saved layouts across floor travel and cold starts; a changed layout or roster can produce a new hint. No save schema change is needed: positions are presentation state, while ownership and selected companion use existing saved fields.
- Autonomous furniture rest keeps its original priority, 40-second cooldown and one-in-three roll before choosing a shared-room stroll. Only the selected cat starts a durable rest and recovers energy.
- Resident position preparation blocks floor travel and need bubbles; ordinary strolling does not. Feeding still queues behind a moving cat for collision safety. Leaving the room cancels a stroll or its pending worker; returning revalidates stopped positions before draining queued care.

## Verification

- 245 App tests passed in the full run, including four real-SpriteKit meal timeline tests and the task destination translation test. Six additional resident lifecycle tests passed in the final focused run (251 distinct App tests in total).
- All four geometry/planning tests passed again after the final position-preservation fix: five cats across home levels 4–8, two viewport sizes and both available floors; safe paths to the bowl, preserved furniture entry, movement around other cats, and refusal to force an unsafe position.
- iPhone 16 Pro simulator: shared-room selection/feeding/relaunch and upstairs/downstairs/cancelled arrangement passed. iPhone SE simulator: both flows, feeding during ambient movement and Reduce Motion passed. The SE selection/feeding/relaunch flow passed again after the final companion-position fix.
- The interaction checks inspect actual SpriteKit actors, open profiles by tapping their screen positions, verify one food deduction per meal and unchanged gold, and observe an empty bowl while the feeding action is still withdrawing. Debug-only frame samples found no resident footprint intersections during the SE checks.
- The six resident lifecycle checks cover the level-3/4 boundary, stable refreshes, unique identities and preserved positions across companion changes, cancellation of stale planning, queued care after background completion, and one-time insufficient-space feedback without mutating ownership.
- Runtime asset preflight passes (171 hydrated files); project generation remains deterministic. Final generic-iOS Release build succeeds with code signing disabled. DEBUG fixtures/diagnostics are checked separately from the shipping configuration.

Raw logs, result bundles and screenshots are kept outside Git in the build-59 QA artifact directory. Early test-driver and numeric-format expectation failures were fixed before the successful runs; the role-switch regression also caught and drove the position-preservation fix.

## PR review follow-up

- The existing 251 App tests passed again after the review fixes. All six new checks passed in the focused rerun (257 distinct App tests): real SpriteKit automatic rest through Store/repository persistence and energy recovery; preparation versus strolling UI gates; cancellation during stroll planning and playback followed by exactly one queued meal; notice suppression across floor travel/cold launch; saved-layout versus harmless state changes; and failed/successful import handling.
- iPhone SE simulator: both floor-travel/cancelled-arrangement and ambient-walk/feeding flows passed. After the final return-order correction, all 16 affected scene tests plus the ambient-walk/feeding UI flow passed again. The pause matrix covers both planning and an accepted walk, with feeding submitted either before leaving the room or while away.
- The first run caught two test-fixture defects: a level-6 seed omitted the upstairs bowl, and the fake import repository did not declare the transfer protocol. Both fixtures were corrected to use the production contracts; success assertions were retained. The targeted walking UI fixture stores its rest furniture so random automatic rest cannot replace the specific stroll being tested.
- No physical iPhone SE was connected for this review. Simulator timing is not a physical-device performance measurement. The level-8 dense-furniture performance and power checks remain pending before TestFlight delivery.

## Remaining validation

Physical-device performance, prolonged play in a densely furnished level-8 home, battery use, VoiceOver operation, iPad and landscape are not verified here. This PR does not introduce cat-to-cat social animations or persistent per-floor cat assignments. TestFlight upload remains pending review; tester distribution is handled by the user.
