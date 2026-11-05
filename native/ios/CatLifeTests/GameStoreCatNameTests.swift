import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameStoreCatNameTests: XCTestCase {
    @MainActor
    func testBlueCatDefaultNameLocalizesButChosenAndLegacyNamesRemainLiteral() {
        let oldLanguage = GameLocalization.shared.language
        defer { GameLocalization.shared.language = oldLanguage }
        let blue = CatState(id: CatCatalog.blueCatID, name: "蓝影", now: Date(), appearance: .blue)
        var renamed = blue
        renamed.customName = "Blue🐾"
        var legacy = blue
        legacy.name = "旧名字"
        let names: [(GameLanguage, String)] = [(.simplifiedChinese, "蓝影"),
                                              (.traditionalChinese, "藍影"), (.english, "Bluebell")]
        for (language, expected) in names {
            GameLocalization.shared.language = language
            XCTAssertEqual(GameStrings.catName(blue), expected)
            XCTAssertEqual(GameStrings.catName(renamed), "Blue🐾")
            XCTAssertEqual(GameStrings.catName(legacy), "旧名字")
        }
    }

    @MainActor
    func testFailedCatRenameKeepsBothCatsWorkAndRestUntilExplicitRetry() async throws {
        let repository = CatNameSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        store.setRestingFurniture(id: "catBed", sessionID: "rename-active-rest")
        try await eventually { store.cat?.activeRest?.id == "rename-active-rest" && !store.isBusy }
        let original = try XCTUnwrap(store.snapshot)
        XCTAssertNotNil(original.player.activeWork?.quote)
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)

        let saved = await store.renameCat(id: "generated-cat", to: "  Nora🐾  ")

        XCTAssertFalse(saved)
        XCTAssertEqual(store.snapshot, original)
        XCTAssertFalse(store.isBusy)
        XCTAssertFalse(store.showSaveError, "The editor presents its retryable error inline.")
        XCTAssertTrue(store.hasSaveFailure)
        let unchanged = await repository.savedSnapshot
        XCTAssertEqual(unchanged, original)
        let attempts = await repository.attempts
        XCTAssertEqual(attempts.count, baseline + 1)
        XCTAssertEqual(attempts.last?.cats[1].customName, "Nora🐾")

        await repository.setWritesFailing(false)
        let retried = await store.renameCat(id: "generated-cat", to: "  Nora🐾  ")
        XCTAssertTrue(retried)
        var expected = original
        expected.cats[1].customName = "Nora🐾"
        XCTAssertEqual(store.snapshot, expected)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, expected)
        XCTAssertFalse(store.hasSaveFailure)
    }

    @MainActor
    func testInvalidMissingAndUnchangedNamesNeverWriteAndResetIsPerCat() async throws {
        let repository = CatNameSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        for invalid in ["", "  ", "Cat\n", "\u{200B}", "\u{3164}", String(repeating: "🐈‍⬛", count: 13)] {
            let saved = await store.renameCat(id: "generated-cat", to: invalid)
            XCTAssertFalse(saved)
        }
        let missing = await store.renameCat(id: "missing-cat", to: "Mochi")
        let unchanged = await store.renameCat(id: "generated-cat", to: nil)
        XCTAssertFalse(missing)
        XCTAssertTrue(unchanged)
        let afterInvalid = await repository.attempts.count
        XCTAssertEqual(afterInvalid, baseline)
        XCTAssertEqual(store.snapshot, original)

        let first = await store.renameCat(id: "cat_001", to: "小橘")
        let second = await store.renameCat(id: "generated-cat", to: "第二只🐈")
        XCTAssertTrue(first && second)
        var expected = original
        expected.cats[0].customName = "小橘"
        expected.cats[1].customName = "第二只🐈"
        XCTAssertEqual(store.snapshot, expected)
        let reset = await store.renameCat(id: "cat_001", to: nil)
        XCTAssertTrue(reset)
        expected.cats[0].customName = nil
        XCTAssertEqual(store.snapshot, expected)
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertNil(reopened.snapshot?.cats[0].customName)
        XCTAssertEqual(reopened.snapshot?.cats[1].customName, "第二只🐈")
        XCTAssertEqual(reopened.snapshot?.player.activeWork, original.player.activeWork)
        XCTAssertEqual(reopened.snapshot?.inventory, original.inventory)
    }

    @MainActor
    func testInFlightRenameOwnsSaveLockAndCannotPublishAnotherCatsDraft() async throws {
        let repository = CatNameSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        await repository.holdNextSave()
        defer { Task { await repository.releaseSave() } }
        let first = Task { await store.renameCat(id: "generated-cat", to: "Clover") }
        try await eventually { await repository.isSaveBlocked }
        XCTAssertTrue(store.isBusy)
        XCTAssertEqual(store.snapshot, original)
        let blocked = await store.renameCat(id: "cat_001", to: "不能抢先保存")
        XCTAssertFalse(blocked)
        await repository.releaseSave()
        let saved = await first.value
        XCTAssertTrue(saved)
        XCTAssertEqual(store.snapshot?.cats[1].customName, "Clover")
        XCTAssertNil(store.snapshot?.cats[0].customName)
        let next = await store.renameCat(id: "cat_001", to: "团子")
        XCTAssertTrue(next)
        XCTAssertEqual(store.snapshot?.cats.map(\.customName), ["团子", "Clover"])
        let maximum = await repository.maximumConcurrentSaves
        XCTAssertEqual(maximum, 1)
    }

    @MainActor
    func testRenameCommitsPendingRestExitAtItsCapturedTimeWithoutLosingTheOtherCat() async throws {
        let repository = CatNameSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        store.setRestingFurniture(id: "catBed", sessionID: "rename-failed-exit")
        try await eventually { store.cat?.activeRest?.id == "rename-failed-exit" && !store.isBusy }
        let before = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        await repository.setWritesFailing(true)
        store.setRestingFurniture(id: nil, sessionID: "rename-failed-exit")
        try await eventually {
            let count = await repository.attempts.count
            return count == baseline + 1 && !store.isBusy
        }
        let exit = await repository.attempts[baseline]
        XCTAssertNil(exit.cats[0].activeRest)
        XCTAssertEqual(store.snapshot, before)
        await repository.setWritesFailing(false)

        let saved = await store.renameCat(id: "generated-cat", to: "Moon")

        XCTAssertTrue(saved)
        var expected = exit
        expected.cats[1].customName = "Moon"
        XCTAssertEqual(store.snapshot, expected)
        XCTAssertEqual(store.snapshot?.player.activeWork, before.player.activeWork)
        let durable = await repository.savedSnapshot
        XCTAssertEqual(durable, expected)
    }

    @MainActor
    func testCustomDefaultSpellingStaysLiteralAcrossLanguagesAndInspectionIsTransient() async throws {
        let oldLanguage = GameLocalization.shared.language
        defer { GameLocalization.shared.language = oldLanguage }
        let repository = CatNameSaveRepository(seed())
        let store = GameStore(repository: repository)
        await store.load()
        let original = try XCTUnwrap(store.snapshot)
        let baseline = await repository.attempts.count
        store.inspectedCatID = "generated-cat"
        store.inspectCat()
        XCTAssertEqual(store.inspectedCatID, "cat_001")
        XCTAssertNil(store.activeSheet)
        XCTAssertEqual(store.snapshot, original)
        let afterInspection = await repository.attempts.count
        XCTAssertEqual(afterInspection, baseline)
        let saved = await store.renameCat(id: "cat_001", to: "小橘")
        XCTAssertTrue(saved)
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            XCTAssertEqual(GameStrings.catName(try XCTUnwrap(store.cat)), "小橘")
            XCTAssertEqual(GameStrings.catName(original.cats[0]), GameStrings.text("cat.defaultName"))
            XCTAssertEqual(GameStrings.catName(original.cats[1]), "Mochi")
        }
        let namedSecond = await store.renameCat(id: "generated-cat", to: "团子🐈‍⬛")
        XCTAssertTrue(namedSecond)
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            let second = try XCTUnwrap(store.snapshot?.cats.first { $0.id == "generated-cat" })
            XCTAssertEqual(GameStrings.catName(second), "团子🐈‍⬛")
        }
        let reset = await store.renameCat(id: "cat_001", to: nil)
        XCTAssertTrue(reset)
        GameLocalization.shared.language = .english
        XCTAssertEqual(GameStrings.catName(try XCTUnwrap(store.cat)), "Sunny")
        let reopened = GameStore(repository: repository)
        await reopened.load()
        XCTAssertNil(reopened.inspectedCatID)
    }

    private func seed() -> GameSnapshot {
        let now = Date()
        var value = GameSnapshot.fresh(now: now)
        value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
        value.player.level = 4
        value.player.gold = 918
        value.cats[0].energy = 40
        value.cats.append(CatState(id: "generated-cat", name: "Mochi", mood: 42, now: now))
        _ = GameEngine.startWork(&value, jobID: "job_petshop", now: now)
        return value
    }

    @MainActor
    private func eventually(_ condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The serialized cat-name save did not settle.")
        throw CatNameTestFailure.timedOut
    }
}

private enum CatNameTestFailure: Error { case unavailable, timedOut }

private actor CatNameSaveRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private(set) var savedSnapshot: GameSnapshot
    private(set) var attempts: [GameSnapshot] = []
    private(set) var maximumConcurrentSaves = 0
    private var activeSaves = 0
    private var writesFailing = false
    private var shouldHold = false
    private var heldSave: CheckedContinuation<Void, Never>?
    var isSaveBlocked: Bool { heldSave != nil }

    init(_ snapshot: GameSnapshot) { savedSnapshot = snapshot }
    func setWritesFailing(_ value: Bool) { writesFailing = value }
    func holdNextSave() { shouldHold = true }
    func releaseSave() { heldSave?.resume(); heldSave = nil }
    func loadOrCreate(now: Date) async throws -> GameSnapshot { savedSnapshot }

    func checkWritable() throws { if writesFailing { throw CatNameTestFailure.unavailable } }

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
        if fails { throw CatNameTestFailure.unavailable }
        savedSnapshot = snapshot
    }
}
