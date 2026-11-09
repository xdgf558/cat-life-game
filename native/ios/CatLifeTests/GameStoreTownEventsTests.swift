import Foundation
import UIKit
import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class GameStoreTownEventsTests: XCTestCase {
    func testFailedSaveDoesNotPublishAReplyOrSpendAndRetryCompletesOnlyOnce() async throws {
        let repository = TownEventTestRepository(try seed())
        let store = await makeStore(repository)
        let before = try XCTUnwrap(store.snapshot)
        let event = try XCTUnwrap(TownEventCatalog.current(in: before))
        let day = try XCTUnwrap(before.community.events.dayKey)
        await repository.setFailing(true)
        var presentations = 0
        let failed = await store.resolveTownEvent(eventID: event.id, choiceID: "help", dayKey: day) { _ in
            presentations += 1; return true
        }
        XCTAssertNil(failed)
        XCTAssertEqual(presentations, 0)
        XCTAssertEqual(store.snapshot, before)
        let unchanged = await repository.saved
        XCTAssertEqual(unchanged, before)
        XCTAssertTrue(store.hasSaveFailure && store.showSaveError)

        await repository.setFailing(false)
        let completed = await store.resolveTownEvent(eventID: event.id, choiceID: "help", dayKey: day) { _ in
            presentations += 1; return true
        }
        let receipt = try XCTUnwrap(completed)
        XCTAssertEqual(presentations, 1)
        XCTAssertEqual(receipt.eventID, event.id)
        XCTAssertEqual(receipt.stageBefore, 1)
        XCTAssertEqual(receipt.stageAfter, 2)
        XCTAssertEqual(store.snapshot?.community.events.totalCompleted, 1)
        XCTAssertEqual(store.snapshot?.community.events.letters, [receipt])
        XCTAssertEqual(store.snapshot?.player.stamina,
                       before.player.stamina - (try XCTUnwrap(event.choices.first { $0.id == "help" })).staminaCost)
        let committed = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(committed.inventory.food - before.inventory.food, receipt.rewards.food)
        XCTAssertEqual(committed.inventory.litter - before.inventory.litter, receipt.rewards.litter)
        XCTAssertEqual(committed.player.gold - before.player.gold, receipt.rewards.gold)
        XCTAssertFalse(store.hasSaveFailure)
        let duplicate = await store.resolveTownEvent(eventID: event.id, choiceID: "supply", dayKey: day)
        XCTAssertNil(duplicate)
        XCTAssertEqual(store.snapshot?.community.events.totalCompleted, 1)
        XCTAssertEqual(store.snapshot?.inventory, committed.inventory)
        let durable = await repository.saved
        XCTAssertEqual(durable, store.snapshot)
    }

    func testPendingChoiceRejectsDoubleTapAndUsesToastAfterLeavingBoard() async throws {
        let repository = TownEventTestRepository(try seed())
        let store = await makeStore(repository)
        let before = try XCTUnwrap(store.snapshot)
        let event = try XCTUnwrap(TownEventCatalog.current(in: before))
        let day = try XCTUnwrap(before.community.events.dayKey)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        var presentations = 0
        let first = Task {
            await store.resolveTownEvent(eventID: event.id, choiceID: "help", dayKey: day) { _ in
                presentations += 1
                return store.isShowingTownBoard
            }
        }
        try await eventually { await repository.isHeld }
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(store.snapshot, before)
        XCTAssertEqual(presentations, 0)
        let duplicate = await store.resolveTownEvent(eventID: event.id, choiceID: "supply", dayKey: day)
        XCTAssertNil(duplicate)
        store.activeSheet = .work
        XCTAssertFalse(store.isShowingTownBoard)
        await repository.releaseSave()
        let receipt = await first.value
        XCTAssertNotNil(receipt)
        XCTAssertEqual(presentations, 1)
        XCTAssertEqual(store.snapshot?.community.events.totalCompleted, 1)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("townEvents.completedNotice")) == true)
    }

    func testStaleDayCannotSpendAndBackgroundCompletionDoesNotPresentInline() async throws {
        let repository = TownEventTestRepository(try seed())
        let store = await makeStore(repository)
        let before = try XCTUnwrap(store.snapshot)
        let event = try XCTUnwrap(TownEventCatalog.current(in: before))
        let absent = await store.resolveTownEvent(eventID: event.id, choiceID: "help", dayKey: "2000-01-01")
        XCTAssertNil(absent)
        XCTAssertEqual(store.snapshot?.inventory, before.inventory)
        XCTAssertEqual(store.snapshot?.community.events, before.community.events)
        store.setForeground(false)
        var presentations = 0
        let receipt = await store.resolveTownEvent(eventID: event.id, choiceID: "help",
            dayKey: try XCTUnwrap(before.community.events.dayKey)) { _ in
                presentations += 1; return true
            }
        XCTAssertNotNil(receipt)
        XCTAssertEqual(presentations, 0)
        XCTAssertTrue(store.toast?.contains(GameStrings.text("townEvents.completedNotice")) == true)
    }

    func testMilestoneRequiresDurableSaveAndRemainsClaimedThroughArchiveRoundTrip() async throws {
        let repository = TownEventTestRepository(try sevenEvents())
        let store = await makeStore(repository)
        let milestone = try XCTUnwrap(TownEventCatalog.milestones.first)
        let before = try XCTUnwrap(store.snapshot)
        await repository.setFailing(true)
        let failed = await store.claimTownMilestone(milestoneID: milestone.id)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.snapshot, before)
        await repository.setFailing(false)
        let claimed = await store.claimTownMilestone(milestoneID: milestone.id)
        XCTAssertTrue(claimed)
        let after = try XCTUnwrap(store.snapshot)
        XCTAssertEqual(after.inventory.furniture.filter { $0.id == milestone.itemID }.count, 1)
        XCTAssertEqual(after.inventory.furniture.first { $0.id == milestone.itemID }?.kind, .wallTownMemory)
        XCTAssertFalse(after.home.furniture.contains { $0.itemID == milestone.itemID })
        let archive = try NativeSaveTransfer.decode(NativeSaveTransfer.encode(snapshot: after))
        let reloaded = await makeStore(TownEventTestRepository(archive.snapshot))
        let duplicate = await reloaded.claimTownMilestone(milestoneID: milestone.id)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(reloaded.snapshot?.community.events.claimedMilestoneIDs, [milestone.id])
        XCTAssertEqual(reloaded.snapshot?.inventory.furniture.filter { $0.id == milestone.itemID }.count, 1)
    }

    func testEventCatalogKeysAndNewFurnitureAreAvailableInEveryLanguage() throws {
        var keys = ["townEvents.completedNotice", "townEvents.milestone.claimed", "releases.60.title", "releases.60.body", "townEvents.detailTitle",
                    "townEvents.letter.archived", "townEvents.error.missing", "townEvents.error.dayChanged",
                    "townEvents.error.completed", "townEvents.error.stamina", "townEvents.error.supplies", "townEvents.error.busy",
                    "townEvents.error.milestoneClaimed", "townEvents.error.milestoneIncomplete"]
        for event in TownEventCatalog.all {
            keys += [event.titleKey, event.bodyKey] + event.choices.flatMap { [$0.titleKey, $0.responseKey] }
        }
        for milestone in TownEventCatalog.milestones { keys += [milestone.titleKey, milestone.bodyKey] }
        for dictionary in [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english] {
            for key in keys { XCTAssertFalse(dictionary[key]?.isEmpty ?? true, key) }
        }
        XCTAssertNotNil(UIImage(named: "furniture-town-memory-frame"))
        XCTAssertFalse(TownPlace.board.isFuture)
        XCTAssertFalse(TownPlace.plaza.isFuture)
        XCTAssertEqual(TownPlace.board.layer, .community)
        XCTAssertEqual(TownPlace.plaza.layer, .community)
        XCTAssertTrue(TownPlace.cafe.isFuture)
    }

    private func seed(now: Date = Date()) throws -> GameSnapshot {
        var state = GameSnapshot.fresh(now: now)
        state.inventory.food = 20
        state.inventory.litter = 20
        state.inventory.toys = 20
        state.inventory.gifts = Dictionary(uniqueKeysWithValues: CommunityCatalog.gifts.map { ($0.id, 3) })
        for id in state.community.relationships.keys { state.community.relationships[id]?.friendship = 19 }
        state.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        XCTAssertTrue(GameEngine.synchronize(&state, now: now).succeeded)
        return state
    }

    private func sevenEvents() throws -> GameSnapshot {
        let now = Date()
        let start = now.addingTimeInterval(-6 * 86_400)
        var state = try seed(now: start)
        for offset in 0..<7 {
            let date = start.addingTimeInterval(Double(offset) * 86_400)
            XCTAssertTrue(GameEngine.synchronize(&state, now: date).succeeded)
            let event = try XCTUnwrap(TownEventCatalog.current(in: state))
            let day = try XCTUnwrap(state.community.events.dayKey)
            XCTAssertTrue(GameEngine.resolveTownEvent(&state, eventID: event.id, choiceID: "help", dayKey: day, now: date).succeeded)
        }
        return state
    }

    private func makeStore(_ repository: TownEventTestRepository) async -> GameStore {
        let suite = "CatLife-town-events-tests-\(UUID())"
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = GameStore(repository: repository, reminderDefaults: UserDefaults(suiteName: suite)!)
        await store.load()
        store.setForeground(true)
        store.enterHome()
        store.openTownBoard()
        return store
    }

    private func eventually(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The held event save did not reach the expected state.")
        throw CocoaError(.coderInvalidValue)
    }
}

private actor TownEventTestRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var saved: GameSnapshot
    private var failing = false
    private var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    var isHeld: Bool { continuation != nil }
    init(_ state: GameSnapshot) { saved = state }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() throws { if failing { throw CocoaError(.fileWriteUnknown) } }
    func setFailing(_ value: Bool) { failing = value }
    func holdNextSave() { hold = true }
    func releaseSave() { continuation?.resume(); continuation = nil }
    func save(_ state: GameSnapshot) async throws {
        if hold { hold = false; await withCheckedContinuation { continuation = $0 } }
        if failing { throw CocoaError(.fileWriteUnknown) }
        saved = state
    }
}
