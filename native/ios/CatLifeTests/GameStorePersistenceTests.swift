import Foundation
import XCTest
import CatGameCore
@testable import CatLife

/// App-level persistence tests use only an actor-backed, in-memory repository.
/// No test opens Application Support or uses the app's UI-test save fixtures.
final class GameStorePersistenceTests: XCTestCase {
    @MainActor
    func testSuccessfulLoadRemainsUsableWhenReconciliationCannotSave() async throws {
        await RoomScene.preloadWelcomeResources()
        let startedAt = Date().addingTimeInterval(-121)
        var seed = mutedSnapshot(now: startedAt)
        XCTAssertTrue(GameEngine.startWork(&seed, now: startedAt).succeeded)
        let repository = MemorySaveRepository(seed, writesFailing: true)
        let store = GameStore(repository: repository)

        await store.load()

        XCTAssertEqual(store.snapshot, seed, "A failed reconciliation must retain the successfully read save.")
        XCTAssertFalse(store.loadFailed)
        XCTAssertFalse(store.isLoading)
        XCTAssertFalse(store.isBusy)
        XCTAssertEqual(store.startupProgress, 1)
        XCTAssertEqual(store.startupPhase, "welcome.ready")
        let reads = await repository.readCount
        XCTAssertEqual(reads, 1)
        store.enterHome()
        XCTAssertTrue(store.hasEnteredHome)

        // An explicit retry may fail too, without turning a write error into a load error.
        let firstCount = await repository.attempts.count
        store.retrySaving()
        try await eventually("The failed manual retry should finish") {
            let count = await repository.attempts.count
            return count == firstCount + 1 && !store.isBusy
        }
        XCTAssertEqual(store.snapshot, seed)
        XCTAssertFalse(store.loadFailed)
        XCTAssertTrue(store.hasEnteredHome)

        await repository.setWritesFailing(false)
        store.retrySaving()
        try await eventually("The same loaded save should recover without reloading") {
            store.snapshot?.player.activeWork == nil && !store.isBusy
        }
        XCTAssertEqual(store.snapshot?.player.gold, seed.player.gold + 60)
        let finalReads = await repository.readCount
        XCTAssertEqual(finalReads, 1)
    }

    @MainActor
    func testRestExitFailuresUnlockUIKeepCapturedTimeAndSlowAfterThreeAttempts() async throws {
        var seed = mutedSnapshot()
        seed.cats[0].energy = 40
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        try await startRest(store, sessionID: "rest-bounded-retry")
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)

        store.setRestingFurniture(id: nil, sessionID: "rest-bounded-retry")
        try await eventually("A failed exit must release the busy lock promptly", timeout: 1) {
            let count = await repository.attempts.count
            return count == baseline + 1 && !store.isBusy
        }
        XCTAssertNil(store.restingFurnitureID)
        XCTAssertNotNil(store.cat?.activeRest, "The published save remains durable until a retry succeeds.")
        XCTAssertTrue(store.showSaveError)
        store.showSaveError = false // The player dismisses the one error alert.
        let firstExit = await repository.attempts[baseline].snapshot.cats[0]
        XCTAssertNil(firstExit.activeRest)

        // This is the sole wall-clock retry-window test: initial failure, +2s, then +5s.
        try await eventually("Automatic retries should finish the three-attempt burst", timeout: 9) {
            let count = await repository.attempts.count
            return count == baseline + 3 && !store.isBusy
        }
        let failedExits = Array(await repository.attempts.dropFirst(baseline))
        XCTAssertEqual(failedExits.count, 3)
        XCTAssertTrue(failedExits.allSatisfy { !$0.succeeded })
        for attempt in failedExits {
            // The decay tracker carries the paused rest duration, so comparing the
            // complete cat also detects replaying the exit with a newer timestamp.
            XCTAssertEqual(attempt.snapshot.cats[0], firstExit)
        }
        XCTAssertGreaterThanOrEqual(failedExits[1].startedAt.timeIntervalSince(failedExits[0].startedAt), 1.9)
        XCTAssertGreaterThanOrEqual(failedExits[2].startedAt.timeIntervalSince(failedExits[1].startedAt), 4.9)
        XCTAssertFalse(store.showSaveError, "Automatic retries must not reopen the dismissed alert.")

        // Foreground/background sync is also automatic and must respect the low-frequency retry interval.
        store.setForeground(false)
        await Task.yield()
        let exhaustedCount = await repository.attempts.count
        XCTAssertEqual(exhaustedCount, baseline + 3)
        XCTAssertFalse(store.isBusy)

        await repository.setWritesFailing(false)
        store.retrySaving()
        try await eventually("An explicit retry must work after the automatic budget is exhausted") {
            store.cat?.activeRest == nil && !store.isBusy
        }
        XCTAssertEqual(store.cat, firstExit)
        XCTAssertEqual(store.snapshot?.player.gold, seed.player.gold)
        XCTAssertEqual(store.snapshot?.inventory.food, seed.inventory.food)
        let recovered = await repository.attempts
        XCTAssertEqual(recovered.count, baseline + 4)
        XCTAssertTrue(try XCTUnwrap(recovered.last).succeeded)
    }

    @MainActor
    func testExplicitRenameRecoversPendingRestExitAfterWriteFailure() async throws {
        var seed = mutedSnapshot()
        seed.cats[0].energy = 40
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        try await startRest(store, sessionID: "rest-rename-recovery")
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)
        store.setRestingFurniture(id: nil, sessionID: "rest-rename-recovery")
        try await eventually("The failed exit should release navigation") {
            let count = await repository.attempts.count
            return count == baseline + 1 && !store.isBusy
        }
        let firstExit = await repository.attempts[baseline].snapshot.cats[0]
        store.showSaveError = false

        await repository.setWritesFailing(false)
        let saved = await store.renamePlayer(to: "团子🐾")

        XCTAssertTrue(saved)
        XCTAssertEqual(store.playerDisplayName, "团子🐾")
        XCTAssertEqual(store.cat, firstExit, "An explicit edit must commit the captured pending exit too.")
        XCTAssertFalse(store.isBusy)
        XCTAssertFalse(store.showSaveError)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, store.snapshot)
        let count = await repository.attempts.count
        XCTAssertEqual(count, baseline + 2)
    }

    @MainActor
    func testFailedRenameDoesNotPublishDraftOrRaiseGlobalAlert() async throws {
        var seed = mutedSnapshot()
        seed.player.profile.name = "原来的名字"
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        let before = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)

        let saved = await store.renamePlayer(to: "新名字🐈")

        XCTAssertFalse(saved)
        XCTAssertEqual(store.snapshot, before)
        XCTAssertEqual(store.playerDisplayName, "原来的名字")
        XCTAssertFalse(store.isBusy)
        XCTAssertFalse(store.showSaveError, "The name editor handles its error inline.")
        let attempts = await repository.attempts
        XCTAssertEqual(attempts.count, baseline + 1)
        XCTAssertEqual(attempts.last?.snapshot.player.profile.name, "新名字🐈")
        let unchanged = await repository.savedSnapshot
        XCTAssertEqual(unchanged, before)

        await repository.setWritesFailing(false)
        let retried = await store.renamePlayer(to: "新名字🐈")
        XCTAssertTrue(retried)
        XCTAssertEqual(store.playerDisplayName, "新名字🐈")
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, store.snapshot)
    }

    @MainActor
    func testTimestampOnlyForegroundSynchronizationDoesNotWrite() async throws {
        let repository = MemorySaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let before = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count

        for _ in 0..<4 {
            store.setForeground(true)
            store.setForeground(false)
            await Task.yield()
        }

        let count = await repository.attempts.count
        XCTAssertEqual(count, baseline, "Passive metadata-only synchronization should not touch storage.")
        XCTAssertEqual(store.snapshot, before)
        XCTAssertFalse(store.isBusy)
    }

    @MainActor
    func testDueWorkSettlementPersistsOnceAfterTimestampOnlyRequests() async throws {
        // Warm texture loading before making a real job nearly due; no clock or
        // production fault-injection parameter is needed for this store test.
        await RoomScene.preloadWelcomeResources()
        let startedAt = Date().addingTimeInterval(-118)
        var seed = mutedSnapshot(now: startedAt)
        XCTAssertTrue(GameEngine.startWork(&seed, now: startedAt).succeeded)
        let work = try XCTUnwrap(seed.player.activeWork)
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        XCTAssertNotNil(store.snapshot?.player.activeWork)
        let baseline = await repository.attempts.count
        store.setForeground(false)
        let passiveCount = await repository.attempts.count
        XCTAssertEqual(passiveCount, baseline)

        try await Task.sleep(for: .seconds(max(0, work.endsAt.timeIntervalSinceNow) + 0.03))
        store.setForeground(false)
        try await eventually("A due work reward must still be committed") {
            store.snapshot?.player.activeWork == nil && !store.isBusy
        }

        let settled = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(settled.player.gold, seed.player.gold + work.goldReward)
        XCTAssertEqual(settled.player.completedWorkCount, seed.player.completedWorkCount + 1)
        XCTAssertEqual(settled.player.lastWorkResult?.id, work.id)
        XCTAssertEqual(store.pendingWorkResultID, work.id)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, settled)
        store.setForeground(false)
        await Task.yield()
        let finalCount = await repository.attempts.count
        XCTAssertEqual(finalCount, baseline + 1)
        XCTAssertEqual(store.snapshot, settled, "Repeated lifecycle requests must not pay the reward twice.")
    }

    @MainActor
    func testLoadKeepsExclusiveSaveOwnershipAcrossSuspensionPoints() async throws {
        let repository = MemorySaveRepository(mutedSnapshot(), readDelay: .milliseconds(100),
                                               saveDelay: .milliseconds(150))
        let store = GameStore(repository: repository)
        let loading = Task { await store.load() }
        try await eventually("The fake read should begin") {
            await repository.readCount == 1
        }
        XCTAssertTrue(store.isBusy)
        XCTAssertTrue(store.isLoading)
        store.setForeground(true)
        store.retrySaving()
        let renamedWhileReading = await store.renamePlayer(to: "不能抢先保存")
        XCTAssertFalse(renamedWhileReading)

        try await eventually("The successful read should reach its delayed reconciliation save") {
            await repository.activeSaveCalls == 1
        }
        XCTAssertNotNil(store.snapshot)
        XCTAssertTrue(store.isBusy)
        store.setForeground(false)
        store.retrySaving()
        let renamedWhileSaving = await store.renamePlayer(to: "也不能并发保存")
        XCTAssertFalse(renamedWhileSaving)
        await store.load() // A second load must be ignored while the first is suspended.
        await loading.value
        try await eventually("Load and pending lifecycle synchronization should settle") { !store.isBusy }

        let reads = await repository.readCount
        let maximumConcurrentSaves = await repository.maximumConcurrentSaveCalls
        let attempts = await repository.attempts
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(maximumConcurrentSaves, 1)
        XCTAssertEqual(attempts.count, 1)
        XCTAssertNil(store.snapshot?.player.profile.name)
        XCTAssertFalse(store.isLoading)
        XCTAssertFalse(store.loadFailed)
    }

    func testSaveRetryPolicySlowsToOneMinuteAndResetsAfterSuccess() {
        var retry = SaveRetryState()
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(retry.permitsAutomaticAttempt(at: first))
        XCTAssertTrue(retry.failed(at: first), "Only the first failure requests an alert.")
        XCTAssertEqual(retry.failures, 1)
        XCTAssertEqual(retry.nextAttempt, first.addingTimeInterval(2))
        XCTAssertFalse(retry.permitsAutomaticAttempt(at: first.addingTimeInterval(1.99)))
        XCTAssertTrue(retry.permitsAutomaticAttempt(at: first.addingTimeInterval(2)))

        let second = first.addingTimeInterval(2)
        XCTAssertFalse(retry.failed(at: second))
        XCTAssertEqual(retry.nextAttempt, second.addingTimeInterval(5))
        XCTAssertFalse(retry.permitsAutomaticAttempt(at: second.addingTimeInterval(4.99)))
        XCTAssertTrue(retry.permitsAutomaticAttempt(at: second.addingTimeInterval(5)))

        let third = second.addingTimeInterval(5)
        XCTAssertFalse(retry.failed(at: third))
        XCTAssertEqual(retry.failures, SaveRetryState.maximumAutomaticAttempts)
        XCTAssertFalse(retry.permitsAutomaticAttempt(at: third.addingTimeInterval(59.99)))
        XCTAssertTrue(retry.permitsAutomaticAttempt(at: third.addingTimeInterval(60)))
        XCTAssertFalse(retry.failed(at: third.addingTimeInterval(60)))
        XCTAssertEqual(retry.nextAttempt, third.addingTimeInterval(120))
        XCTAssertTrue(retry.hasReportedFailure)

        retry.succeeded()
        XCTAssertEqual(retry.failures, 0)
        XCTAssertFalse(retry.hasReportedFailure)
        XCTAssertTrue(retry.permitsAutomaticAttempt(at: third))
        XCTAssertTrue(retry.failed(at: third), "A new outage may present a fresh error after recovery.")
    }

    @MainActor
    func testEveryManualFailureReportsAndPersistentRecoveryDoesNotReplayActions() async throws {
        let repository = MemorySaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let before = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)
        for (offset, action) in [store.feed, store.buyFood, store.retrySaving].enumerated() {
            store.showSaveError = false
            action()
            try await eventually("Each manual failure must finish and report itself") {
                let count = await repository.attempts.count + repository.probeCount
                return count == baseline + offset + 1 && !store.isBusy
            }
            XCTAssertTrue(store.showSaveError)
            XCTAssertTrue(store.hasSaveFailure, "Closing the alert must not hide the recovery entry.")
            XCTAssertEqual(store.snapshot, before)
        }
        store.showSaveError = false
        XCTAssertTrue(store.saveRetryIsSlow)
        await repository.setWritesFailing(false)
        store.retrySaving()
        try await eventually("A retry with no gameplay differences must still probe storage") {
            !store.isBusy && !store.hasSaveFailure
        }
        XCTAssertFalse(store.showSaveError)
        let durableWrites = await repository.attempts.count
        let probes = await repository.probeCount
        XCTAssertEqual(durableWrites, baseline + 2, "Retries with no gameplay changes must not rewrite saves.")
        XCTAssertEqual(probes, 2)
        XCTAssertEqual(store.snapshot, before)
        XCTAssertEqual(store.snapshot?.player.gold, before.player.gold)
        XCTAssertEqual(store.snapshot?.inventory, before.inventory)
        XCTAssertEqual(store.snapshot?.cats, before.cats)
        store.feed()
        try await eventually("The next explicit action should save once") {
            !store.isBusy && store.snapshot?.inventory.food == before.inventory.food - 1
        }
    }

    @MainActor
    func testFullStaminaClockDoesNotCausePassiveWritesOrBankExtraRecovery() async throws {
        // Isolate stamina timestamps from a legitimate daily reset when this test runs near midnight.
        let date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        var seed = mutedSnapshot(now: date)
        seed.player.stamina = 100
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        let baseline = await repository.attempts.count
        for _ in 0..<3 {
            store.setForeground(false)
            await Task.yield()
        }
        let count = await repository.attempts.count
        XCTAssertEqual(count, baseline)
        var later = seed
        _ = GameEngine.synchronize(&later, now: date.addingTimeInterval(120))
        XCTAssertNotEqual(later.player.staminaUpdatedAt, seed.player.staminaUpdatedAt)
        XCTAssertFalse(requiresDurableSave(later, comparedTo: seed))
        let workDate = date.addingTimeInterval(125)
        XCTAssertTrue(GameEngine.startWork(&later, now: workDate).succeeded)
        XCTAssertTrue(requiresDurableSave(later, comparedTo: seed))
        XCTAssertEqual(later.player.staminaUpdatedAt, workDate)
        _ = GameEngine.synchronize(&later, now: workDate.addingTimeInterval(3599))
        XCTAssertEqual(later.player.stamina, 90, "Full idle time is not banked toward recovery after spending.")
        _ = GameEngine.synchronize(&later, now: workDate.addingTimeInterval(3600))
        XCTAssertEqual(later.player.stamina, 95)
    }

    @MainActor
    func testDailyRolloverStillRequiresADurableSaveAtFullStamina() {
        let midnight = Calendar.current.startOfDay(for: Date())
        let date = midnight.addingTimeInterval(-60)
        var original = mutedSnapshot(now: date)
        original.player.stamina = 100
        var next = original
        XCTAssertTrue(GameEngine.synchronize(&next, now: date.addingTimeInterval(120)).succeeded)
        XCTAssertNotEqual(next.tasks.dailyDayKey, original.tasks.dailyDayKey)
        XCTAssertTrue(requiresDurableSave(next, comparedTo: original), "A daily reset is meaningful even when stamina is already full.")
    }

    @MainActor
    func testBackupRestAndWorkNoticesSurviveStartupAndEntry() async throws {
        let date = Date().addingTimeInterval(-130)
        var seed = mutedSnapshot(now: date)
        XCTAssertTrue(GameEngine.startWork(&seed, now: date).succeeded)
        XCTAssertTrue(GameEngine.startCatRest(&seed, catID: seed.cats[0].id,
            furnitureID: "catBed", sessionID: "startup-rest", now: date).succeeded)
        let repository = MemorySaveRepository(seed, disposition: .recoveredBackup)
        let store = GameStore(repository: repository)
        await store.load()
        let workMessage = GameStrings.format("action.workFinished", 60)
        for expected in [workMessage, GameStrings.text("save.recovered"), GameStrings.text("rest.loadEnded")] {
            XCTAssertTrue(store.startupNotice?.contains(expected) == true)
        }
        store.enterHome()
        for expected in [workMessage, GameStrings.text("save.recovered"), GameStrings.text("rest.loadEnded")] {
            XCTAssertTrue(store.toast?.contains(expected) == true)
        }
    }

    @MainActor
    func testWorkNoticeSurvivesConcurrentPurchaseNotice() async throws {
        await RoomScene.preloadWelcomeResources()
        let date = Date().addingTimeInterval(-118)
        var seed = mutedSnapshot(now: date)
        XCTAssertTrue(GameEngine.startWork(&seed, now: date).succeeded)
        let endsAt = try XCTUnwrap(seed.player.activeWork).endsAt
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        store.enterHome()
        try await Task.sleep(for: .seconds(max(0, endsAt.timeIntervalSinceNow) + 0.03))
        store.buyFood()
        try await eventually("Purchase and work settlement must commit together") {
            !store.isBusy && store.snapshot?.player.activeWork == nil
        }
        XCTAssertTrue(store.toast?.contains(GameStrings.format("action.workFinished", 60)) == true)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("action.purchase")) == true)
        XCTAssertEqual(store.snapshot?.player.gold, seed.player.gold + 60 - 20)
    }

    @MainActor
    func testNewerSchemaHasAnUpdatePromptInsteadOfCorruptionOrReset() async throws {
        let repository = NewerSchemaRepository()
        let store = GameStore(repository: repository)
        await store.load()
        XCTAssertTrue(store.loadFailed)
        XCTAssertTrue(store.needsNewerVersion)
        XCTAssertNil(store.snapshot)
        XCTAssertFalse(store.isBusy)
        XCTAssertFalse(store.hasEnteredHome)
        let writes = await repository.writes
        XCTAssertEqual(writes, 0)
    }

    private func mutedSnapshot(now: Date = Date()) -> GameSnapshot {
        var snapshot = GameSnapshot.fresh(now: now)
        snapshot.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        return snapshot
    }

    @MainActor
    func testShopAndUpgradePublishOnlyAfterDurableWrite() async throws {
        var seed = mutedSnapshot()
        seed.player.level = 4
        seed.player.gold = 5000
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        await repository.setWritesFailing(true)
        let actions: [() -> Void] = [
            { store.buyEquipment(itemID: "advanced_cap") },
            { store.buyFurniture(offerID: "potted_plant") },
            { store.upgradeHome(toLevel: 2) }
        ]
        for action in actions {
            store.showSaveError = false
            let baseline = await repository.attempts.count
            action()
            try await eventually("A rejected write must release the UI and report the failure") {
                let count = await repository.attempts.count
                return count > baseline && !store.isBusy
            }
            XCTAssertEqual(store.snapshot, original)
            XCTAssertTrue(store.showSaveError)
            let durable = await repository.savedSnapshot
            XCTAssertEqual(durable, original)
        }
        await repository.setWritesFailing(false)
        store.buyEquipment(itemID: "advanced_cap")
        store.buyEquipment(itemID: "advanced_cap") // A rapid second tap cannot spend twice.
        try await eventually("The equipment purchase should commit") {
            !store.isBusy && store.snapshot?.player.profile.ownedEquipmentIDs.contains("advanced_cap") == true
        }
        store.buyFurniture(offerID: "potted_plant")
        try await eventually("Purchased furniture should be stored rather than placed") {
            !store.isBusy && store.snapshot?.inventory.furniture.count == seed.inventory.furniture.count + 1
        }
        store.upgradeHome(toLevel: 2)
        try await eventually("Room level and its cost should commit together") {
            !store.isBusy && store.snapshot?.home.roomLevel == 2
        }
        XCTAssertEqual(store.snapshot?.player.gold, 5000 - 360 - 120 - 450)
        XCTAssertEqual(store.snapshot?.home.furniture, original.home.furniture)
        XCTAssertEqual(store.snapshot?.home.bowlPosition, original.home.bowlPosition)
        XCTAssertNil(store.snapshot?.player.profile.equipped[.head], "Buying does not silently equip.")
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, store.snapshot)
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.home, store.snapshot?.home)
        XCTAssertEqual(reopened.snapshot?.inventory, store.snapshot?.inventory)
        XCTAssertEqual(reopened.snapshot?.player.profile, store.snapshot?.player.profile)
    }

    @MainActor
    func testUpgradeKeepsDecoratingDraftAndCapacityPreventsNewPlacement() async throws {
        var seed = mutedSnapshot()
        seed.player.level = 4
        seed.player.gold = 5000
        XCTAssertTrue(GameEngine.purchaseFurniture(&seed, offerID: "potted_plant", now: Date()).succeeded)
        let repository = MemorySaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        let extra = try XCTUnwrap(store.storedFurniture.first)
        XCTAssertFalse(store.canPlaceMoreFurniture)
        store.placeFurniture(id: extra.id)
        XCTAssertFalse(store.isDecorating, "A full room must not enter a dead-end placement flow.")
        store.beginDecorating()
        let draftPoint = NormalizedPoint(x: 0.65, y: 0.74)
        store.moveFurniture(id: "floorCushion", to: draftPoint)
        let draft = store.draftFurniture
        store.openHomeUpgrade()
        store.upgradeHome(toLevel: 2)
        try await eventually("The room upgrade should retain the layout session") {
            !store.isBusy && store.snapshot?.home.roomLevel == 2
        }
        XCTAssertTrue(store.isDecorating)
        XCTAssertEqual(store.draftFurniture, draft)
        XCTAssertEqual(store.snapshot?.home.furniture, seed.home.furniture)
        XCTAssertTrue(store.canPlaceMoreFurniture)
        store.placeFurniture(id: extra.id)
        XCTAssertEqual(store.placingFurnitureID, extra.id)
        store.cancelDecorating()
        XCTAssertEqual(store.snapshot?.home.roomLevel, 2, "Cancelling a layout must not undo a paid upgrade.")
        XCTAssertEqual(store.snapshot?.home.furniture, seed.home.furniture)
        let maximumLevel = try XCTUnwrap(HomeCatalog.all.last)
        var maximumSeed = try XCTUnwrap(store.snapshot)
        maximumSeed.home.roomLevel = maximumLevel.level
        maximumSeed.player.level = maximumLevel.requiredPlayerLevel
        maximumSeed.home.upperBowlPosition = maximumLevel.floors.contains(.upper) ? HomeState.defaultBowlPosition : nil
        let maximumFloorCapacity = maximumLevel.capacity(on: .ground)
        while maximumSeed.home.placements(on: .ground).count < maximumFloorCapacity {
            let id = "maximum-capacity-\(maximumSeed.home.furniture.count)"
            maximumSeed.inventory.furniture.append(FurnitureItem(id: id, kind: .plant))
            maximumSeed.home.furniture.append(FurniturePlacement(itemID: id, position: .init(x: 0.6, y: 0.7)))
        }
        XCTAssertNoThrow(try NativeSaveTransfer.encode(snapshot: maximumSeed))
        XCTAssertTrue(maximumSeed.home.placements(on: .upper).isEmpty)
        let maximumStore = GameStore(repository: MemorySaveRepository(maximumSeed))
        await maximumStore.load()
        XCTAssertFalse(maximumStore.canUpgradeHome)
        XCTAssertFalse(maximumStore.canPlaceMoreFurniture)
        XCTAssertEqual(maximumStore.placedFurnitureCount, maximumFloorCapacity)
        maximumStore.placeFurniture(id: extra.id)
        XCTAssertFalse(maximumStore.isDecorating, "Unused upstairs capacity must not allow placement on a full ground floor.")
        XCTAssertEqual(maximumStore.furnitureCapacityNotice, GameStrings.format("homeInventory.space.upper", maximumFloorCapacity))
    }

    @MainActor
    private func startRest(_ store: GameStore, sessionID: String) async throws {
        store.setRestingFurniture(id: "catBed", sessionID: sessionID)
        try await eventually("Rest entry should commit before testing its exit") {
            store.cat?.activeRest?.id == sessionID && !store.isBusy
        }
    }

    @MainActor
    private func eventually(_ message: String, timeout: TimeInterval = 2,
                            file: StaticString = #filePath, line: UInt = #line,
                            condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail(message, file: file, line: line)
        throw WaitFailure.timedOut
    }
}

private enum WaitFailure: Error { case timedOut }

private actor MemorySaveRepository: GameSaveRepository {
    struct SaveAttempt: Sendable {
        let snapshot: GameSnapshot
        let startedAt: Date
        let succeeded: Bool
    }

    private enum SimulatedWriteError: Error { case unavailable }

    let lastLoadDisposition: SaveLoadDisposition
    private(set) var savedSnapshot: GameSnapshot
    private(set) var readCount = 0
    private(set) var attempts: [SaveAttempt] = []
    private(set) var probeCount = 0
    private(set) var activeSaveCalls = 0
    private(set) var maximumConcurrentSaveCalls = 0
    private var writesFailing: Bool
    private let readDelay: Duration
    private let saveDelay: Duration

    init(_ snapshot: GameSnapshot, writesFailing: Bool = false,
         readDelay: Duration = .zero, saveDelay: Duration = .zero,
         disposition: SaveLoadDisposition = .loaded) {
        lastLoadDisposition = disposition
        savedSnapshot = snapshot
        self.writesFailing = writesFailing
        self.readDelay = readDelay
        self.saveDelay = saveDelay
    }

    func setWritesFailing(_ failing: Bool) { writesFailing = failing }

    func loadOrCreate(now: Date) async throws -> GameSnapshot {
        readCount += 1
        if readDelay > .zero { try await Task.sleep(for: readDelay) }
        return savedSnapshot
    }

    func checkWritable() throws {
        probeCount += 1
        if writesFailing { throw SimulatedWriteError.unavailable }
    }

    func save(_ snapshot: GameSnapshot) async throws {
        let fails = writesFailing
        activeSaveCalls += 1
        maximumConcurrentSaveCalls = max(maximumConcurrentSaveCalls, activeSaveCalls)
        defer { activeSaveCalls -= 1 }
        attempts.append(SaveAttempt(snapshot: snapshot, startedAt: Date(), succeeded: !fails))
        if saveDelay > .zero { try await Task.sleep(for: saveDelay) }
        if fails { throw SimulatedWriteError.unavailable }
        savedSnapshot = snapshot
    }
}

private actor NewerSchemaRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var writes = 0
    func loadOrCreate(now: Date) throws -> GameSnapshot {
        throw SaveRepositoryError.unsupportedSchemaVersion(GameSnapshot.currentSchemaVersion + 1)
    }
    func save(_ state: GameSnapshot) throws { writes += 1 }
    func checkWritable() throws { throw SaveRepositoryError.unsupportedSchemaVersion(GameSnapshot.currentSchemaVersion + 1) }
}
