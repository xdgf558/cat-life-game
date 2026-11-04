import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreTaskTests: XCTestCase {
    @MainActor
    func testFailedClaimKeepsEarnedProgressUntilRetryAndRemainsClaimedAfterReload() async throws {
        let repository = TaskSaveRepository(mutedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        store.feed()
        try await eventually("Feeding should commit its task progress") {
            !store.isBusy && store.snapshot?.tasks.totalFeedCount == 1
        }
        let original = try XCTUnwrap(store.snapshot)
        let task = try XCTUnwrap(GameTaskCatalog.task(id: "tutorial_feed"))
        XCTAssertTrue(GameTaskCatalog.isClaimable(task, in: original))
        XCTAssertTrue(GameTaskCatalog.remainingTasks(in: original, category: .tutorial).contains { $0.id == task.id })
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)

        let failed = await store.claimTask(id: task.id)

        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, original, "A rejected save cannot publish the reward or its claim receipt.")
        XCTAssertFalse(store.isBusy)
        XCTAssertTrue(store.hasSaveFailure)
        XCTAssertTrue(store.showSaveError)
        let stillDurable = await repository.savedSnapshot
        XCTAssertEqual(stillDurable, original)
        XCTAssertTrue(GameTaskCatalog.remainingTasks(in: stillDurable, category: .tutorial).contains { $0.id == task.id },
                      "A failed reward must remain visible and claimable.")
        let failedAttempts = await repository.attempts
        XCTAssertEqual(failedAttempts.count, baseline + 1)
        let rejected = try XCTUnwrap(failedAttempts.last)
        XCTAssertEqual(rejected.player.gold, original.player.gold + task.goldReward)
        XCTAssertEqual(rejected.player.exp, original.player.exp + task.expReward)
        XCTAssertTrue(GameTaskCatalog.isClaimed(task, in: rejected),
                      "The test must fail the reward write, not an earlier eligibility check.")

        await repository.setWritesFailing(false)
        let retried = await store.claimTask(id: task.id)
        XCTAssertTrue(retried)
        let rewarded = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(rewarded.player.gold, original.player.gold + task.goldReward)
        XCTAssertEqual(rewarded.player.exp, original.player.exp + task.expReward)
        XCTAssertEqual(rewarded.player.level, original.player.level)
        XCTAssertEqual(rewarded.tasks.claimedTaskIDs, [task.id])
        XCTAssertEqual(rewarded.tasks.totalFeedCount, 1)
        XCTAssertEqual(rewarded.inventory, original.inventory)
        XCTAssertFalse(store.hasSaveFailure)
        XCTAssertFalse(store.showSaveError)
        let durableReward = await repository.savedSnapshot
        XCTAssertEqual(durableReward, rewarded)
        XCTAssertFalse(GameTaskCatalog.remainingTasks(in: rewarded, category: .tutorial).contains { $0.id == task.id })

        let duplicate = await store.claimTask(id: task.id)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.snapshot?.player.gold, rewarded.player.gold)
        XCTAssertEqual(store.snapshot?.player.exp, rewarded.player.exp)
        XCTAssertEqual(store.snapshot?.tasks.claimedTaskIDs, [task.id])

        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertEqual(reopened.snapshot?.player.gold, rewarded.player.gold)
        XCTAssertEqual(reopened.snapshot?.player.exp, rewarded.player.exp)
        XCTAssertEqual(reopened.snapshot?.tasks.totalFeedCount, 1)
        XCTAssertEqual(reopened.snapshot?.tasks.claimedTaskIDs, [task.id])
        let repeatedAfterLoad = await reopened.claimTask(id: task.id)
        XCTAssertFalse(repeatedAfterLoad)
        let afterReload = await repository.savedSnapshot
        XCTAssertEqual(afterReload.player.gold, rewarded.player.gold)
        XCTAssertEqual(afterReload.player.exp, rewarded.player.exp)
        XCTAssertEqual(afterReload.tasks.claimedTaskIDs, [task.id])
        XCTAssertFalse(GameTaskCatalog.remainingTasks(in: afterReload, category: .tutorial).contains { $0.id == task.id })
    }

    @MainActor
    func testFailedRewardDoesNotPublishLevelUnlocksUntilSuccessfulRetry() async throws {
        var seed = try fedSnapshot()
        seed.player.exp = 99
        seed.player.completedWorkCount = 2
        seed.tasks.dailyWorkCount = 2
        let repository = TaskSaveRepository(seed)
        let store = GameStore(repository: repository)
        await store.load()
        let before = try XCTUnwrap(store.snapshot)
        let day = try XCTUnwrap(before.tasks.dailyDayKey)
        let advanced = try XCTUnwrap(GameTaskCatalog.task(id: "daily_work2"))
        XCTAssertFalse(GameTaskCatalog.isUnlocked(advanced, in: before))
        await repository.setWritesFailing(true)
        let failed = await store.claimTask(id: "daily_feed", expectedDayKey: day)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, before)
        XCTAssertFalse(GameTaskCatalog.isUnlocked(advanced, in: try XCTUnwrap(store.snapshot)))

        await repository.setWritesFailing(false)
        let recovered = await store.claimTask(id: "daily_feed", expectedDayKey: day)
        XCTAssertTrue(recovered)
        let saved = await repository.savedSnapshot
        XCTAssertEqual(saved.player.level, 2)
        XCTAssertEqual(saved.player.exp, 3)
        XCTAssertEqual(saved.player.gold, before.player.gold + 15)
        XCTAssertTrue(GameTaskCatalog.isClaimable(advanced, in: saved),
                      "Earlier activity today counts toward goals unlocked by the committed level gain.")
        let visible = GameTaskCatalog.remainingTasks(in: saved, category: .daily).map(\.id)
        XCTAssertTrue(visible.contains("daily_work2"))
        XCTAssertFalse(visible.contains("daily_feed"))
        XCTAssertEqual(saved.tasks.dailyClaimedTaskIDs, ["daily_feed"])
    }

    @MainActor
    func testConcurrentClaimsPublishOnlyOneRewardAfterTheHeldWriteCompletes() async throws {
        let repository = TaskSaveRepository(try fedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let task = try XCTUnwrap(GameTaskCatalog.task(id: "tutorial_feed"))
        let baseline = await repository.attempts.count
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }

        let first = Task { await store.claimTask(id: task.id) }
        try await eventually("The first claim should be suspended in storage") {
            await repository.isSaveBlocked
        }
        XCTAssertTrue(store.isBusy)
        let duplicate = await store.claimTask(id: task.id)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.snapshot, original)
        let heldDurable = await repository.savedSnapshot
        XCTAssertEqual(heldDurable, original)
        let heldAttempts = await repository.attempts.count
        XCTAssertEqual(heldAttempts, baseline + 1)

        await repository.releaseSave()
        let saved = await first.value
        XCTAssertTrue(saved)
        XCTAssertFalse(store.isBusy)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold + task.goldReward)
        XCTAssertEqual(store.snapshot?.player.exp, original.player.exp + task.expReward)
        XCTAssertEqual(store.snapshot?.tasks.claimedTaskIDs, [task.id])
        let durable = await repository.savedSnapshot
        XCTAssertEqual(store.snapshot, durable)
        let maximumConcurrentSaves = await repository.maximumConcurrentSaves
        let finalAttempts = await repository.attempts.count
        XCTAssertEqual(maximumConcurrentSaves, 1)
        XCTAssertEqual(finalAttempts, baseline + 1)
    }

    @MainActor
    func testClaimCommitsPendingWorkSettlementAndKeepsItsResultAndNotice() async throws {
        await RoomScene.preloadWelcomeResources()
        let start = Date().addingTimeInterval(-125)
        var seed = mutedSnapshot(now: start)
        seed.player.exp = 90
        XCTAssertTrue(GameEngine.startWork(&seed, now: start).succeeded)
        let work = try XCTUnwrap(seed.player.activeWork)
        let task = try XCTUnwrap(GameTaskCatalog.task(id: "tutorial_work"))
        let repository = TaskSaveRepository(seed, writesFailing: true)
        let store = GameStore(repository: repository)
        await store.load()
        XCTAssertEqual(store.snapshot, seed, "Failed startup reconciliation leaves the completed shift pending.")
        XCTAssertNil(store.pendingWorkResultID)
        XCTAssertFalse(GameTaskCatalog.isClaimable(task, in: seed))
        store.enterHome()
        let baseline = await repository.attempts.count

        await repository.setWritesFailing(false)
        let claimed = await store.claimTask(id: task.id)

        XCTAssertTrue(claimed, "The same transaction must settle work before checking its task goal.")
        let committed = try XCTUnwrap(store.snapshot)
        let result = try XCTUnwrap(committed.player.lastWorkResult)
        XCTAssertNil(committed.player.activeWork)
        XCTAssertEqual(result.id, work.id)
        XCTAssertEqual(result.jobID, work.jobID)
        XCTAssertEqual(result.completedAt, work.endsAt)
        XCTAssertEqual(result.goldReward, work.goldReward)
        XCTAssertEqual(result.expReward, work.expReward)
        XCTAssertEqual(result.levelBefore, 1)
        XCTAssertEqual(result.levelAfter, 2)
        XCTAssertEqual(result.expAfter, 12, "The work receipt keeps the work result before the task's extra EXP.")
        XCTAssertEqual(committed.player.level, 2)
        XCTAssertEqual(committed.player.exp, result.expAfter + task.expReward)
        XCTAssertEqual(committed.player.gold, seed.player.gold + work.goldReward + task.goldReward)
        XCTAssertEqual(committed.player.completedWorkCount, 1)
        XCTAssertEqual(committed.tasks.claimedTaskIDs, [task.id])
        let calendar = Calendar(identifier: .gregorian)
        let completedToday = calendar.isDate(work.endsAt, inSameDayAs: committed.meta.lastSyncAt)
        XCTAssertEqual(committed.tasks.dailyWorkCount, completedToday ? 1 : 0)
        XCTAssertEqual(store.pendingWorkResultID, work.id)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("action.workFinished", work.goldReward)) == true)
        XCTAssertTrue(store.toast?.contains(GameStrings.format("tasks.claimedNotice", task.goldReward)) == true)
        XCTAssertFalse(store.hasSaveFailure)
        let saved = await repository.savedSnapshot
        let finalAttempts = await repository.attempts.count
        XCTAssertEqual(saved, committed)
        XCTAssertEqual(finalAttempts, baseline + 1, "Work and its task reward belong in one durable write.")
    }

    @MainActor
    func testDailyClaimRequiresTheDisplayedDayAndCannotPayTwice() async throws {
        let repository = TaskSaveRepository(try fedSnapshot())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let day = try XCTUnwrap(original.tasks.dailyDayKey)
        let task = try XCTUnwrap(GameTaskCatalog.task(id: "daily_feed"))
        XCTAssertTrue(GameTaskCatalog.isClaimable(task, in: original))

        let stale = await store.claimTask(id: task.id, expectedDayKey: "1900-01-01")
        XCTAssertFalse(stale)
        XCTAssertEqual(store.snapshot?.player.gold, original.player.gold)
        XCTAssertEqual(store.snapshot?.player.exp, original.player.exp)
        XCTAssertEqual(store.snapshot?.tasks.dailyClaimedTaskIDs, [])

        let claimed = await store.claimTask(id: task.id, expectedDayKey: day)
        XCTAssertTrue(claimed)
        let duplicate = await store.claimTask(id: task.id, expectedDayKey: day)
        XCTAssertFalse(duplicate)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable.player.gold, original.player.gold + task.goldReward)
        XCTAssertEqual(durable.player.exp, original.player.exp + task.expReward)
        XCTAssertEqual(durable.tasks.dailyClaimedTaskIDs, [task.id])
        XCTAssertEqual(durable.tasks.claimedTaskIDs, [], "Claiming a daily goal must not claim its starter counterpart.")
        XCTAssertEqual(durable.inventory, original.inventory)
    }

    private func mutedSnapshot(now: Date = Date()) -> GameSnapshot {
        var state = GameSnapshot.fresh(now: now)
        state.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        return state
    }

    private func fedSnapshot() throws -> GameSnapshot {
        let now = Date()
        var state = mutedSnapshot(now: now)
        guard GameEngine.feed(&state, catID: CatCatalog.initialCatID, now: now).succeeded else {
            throw TaskSaveTestError.unavailable
        }
        return state
    }

    @MainActor
    private func eventually(_ message: String, file: StaticString = #filePath, line: UInt = #line,
                            condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail(message, file: file, line: line)
        throw TaskSaveTestError.timedOut
    }
}

private enum TaskSaveTestError: Error { case unavailable, timedOut }

private actor TaskSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var savedSnapshot: GameSnapshot
    private(set) var attempts: [GameSnapshot] = []
    private(set) var maximumConcurrentSaves = 0
    private var activeSaves = 0
    private var writesFailing: Bool
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveBlocked: Bool { heldSave != nil }

    init(_ snapshot: GameSnapshot, writesFailing: Bool = false) {
        savedSnapshot = snapshot
        self.writesFailing = writesFailing
    }

    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func loadOrCreate(now: Date) async throws -> GameSnapshot { savedSnapshot }
    func checkWritable() throws { if writesFailing { throw TaskSaveTestError.unavailable } }

    func save(_ snapshot: GameSnapshot) async throws {
        let fails = writesFailing
        attempts.append(snapshot)
        activeSaves += 1
        maximumConcurrentSaves = max(maximumConcurrentSaves, activeSaves)
        defer { activeSaves -= 1 }
        if shouldHold {
            shouldHold = false
            await withCheckedContinuation { heldSave = $0 }
        }
        if fails { throw TaskSaveTestError.unavailable }
        savedSnapshot = snapshot
    }
}
