import Foundation
import Testing
@testable import CatGameCore

@Suite("Native save durability")
struct FileSaveRepositoryTests {
    let now = Date(timeIntervalSince1970: 1_793_318_400)

    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CatGameCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func freshSaveRoundTripsLayoutAndGeneratedCats() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        #expect(await repository.lastLoadDisposition == .created)
        _ = GameEngine.feed(&state, catID: "cat_001", now: now)
        _ = GameEngine.setBowlPosition(&state, .init(x: 0.58, y: 0.72), now: now)
        state.cats.append(CatState(id: "kitten_existing", name: "小猫", now: now))
        _ = GameEngine.startWork(&state, now: now)
        try await repository.save(state)
        let reopened = FileSaveRepository(directory: folder)
        let loaded = try await reopened.loadOrCreate(now: now.addingTimeInterval(60))
        #expect(loaded == state)
        #expect(loaded.cats.contains { $0.id == "kitten_existing" })
        #expect(loaded.player.activeWork?.id == state.player.activeWork?.id)
        #expect(loaded.home.bowlPosition == .init(x: 0.58, y: 0.72))
    }

    @Test func interruptedWorkSurvivesReloadAndPaysOnce() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        _ = GameEngine.startWork(&state, now: now)
        try await repository.save(state)
        var restored = try await repository.loadOrCreate(now: now.addingTimeInterval(300))
        #expect(GameEngine.synchronize(&restored, now: now.addingTimeInterval(300)).kind == .workFinished)
        try await repository.save(restored)
        var again = try await repository.loadOrCreate(now: now.addingTimeInterval(301))
        #expect(GameEngine.synchronize(&again, now: now.addingTimeInterval(301)).kind == .none)
        #expect(again.player.gold == 260)
    }

    @Test func corruptedPrimaryRecoversValidatedBackupAndPreservesEvidence() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        let first = try await repository.loadOrCreate(now: now)
        var second = first
        _ = GameEngine.feed(&second, catID: "cat_001", now: now)
        try await repository.save(second)
        let damaged = Data("broken save".utf8)
        try damaged.write(to: repository.saveURL)
        let recovered = try await repository.loadOrCreate(now: now)
        #expect(recovered == first)
        #expect(await repository.lastLoadDisposition == .recoveredBackup)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let preserved = try #require(files.first { $0.lastPathComponent.hasPrefix("unreadable-save-") })
        #expect(try Data(contentsOf: preserved) == damaged)
        #expect(try await repository.loadOrCreate(now: now) == first)
    }

    @Test func corruptedSaveWithoutBackupIsNeverReplacedWithNewGame() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        let damaged = Data("{invalid".utf8)
        try damaged.write(to: repository.saveURL)
        await #expect(throws: SaveRepositoryError.unreadableSave) {
            _ = try await repository.loadOrCreate(now: now)
        }
        #expect(try Data(contentsOf: repository.saveURL) == damaged)
    }

    @Test func corruptBackupAndPrimaryRemainUntouched() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        let primary = Data("bad primary".utf8)
        let backup = Data("bad backup".utf8)
        try primary.write(to: repository.saveURL)
        try backup.write(to: repository.backupURL)
        await #expect(throws: SaveRepositoryError.unreadableSave) {
            _ = try await repository.loadOrCreate(now: now)
        }
        #expect(try Data(contentsOf: repository.saveURL) == primary)
        #expect(try Data(contentsOf: repository.backupURL) == backup)
    }

    @Test func futureSchemaRefusesDowngradeEvenWithGoodBackup() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        _ = GameEngine.feed(&state, catID: "cat_001", now: now)
        try await repository.save(state)
        let future = Data("{\"schemaVersion\":99,\"futureData\":\"keep\"}".utf8)
        try future.write(to: repository.saveURL)
        await #expect(throws: SaveRepositoryError.unsupportedSchemaVersion(99)) {
            _ = try await repository.loadOrCreate(now: now)
        }
        await #expect(throws: SaveRepositoryError.unsupportedSchemaVersion(99)) {
            try await repository.save(state)
        }
        #expect(try Data(contentsOf: repository.saveURL) == future)
    }

    @Test func invalidStateCannotOverwriteValidSave() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        let fresh = try await repository.loadOrCreate(now: now)
        var invalid = fresh
        invalid.cats[0].satiety = 101
        await #expect(throws: SaveRepositoryError.invalidSnapshot) {
            try await repository.save(invalid)
        }
        #expect(try await repository.loadOrCreate(now: now) == fresh)
    }

    @Test func millisecondTimestampsArePersisted() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        let timestamp = now.addingTimeInterval(0.123)
        _ = try await repository.loadOrCreate(now: timestamp)
        let loaded = try await repository.loadOrCreate(now: now)
        #expect(abs(loaded.meta.createdAt.timeIntervalSince(timestamp)) < 0.001)
        let json = try String(contentsOf: repository.saveURL, encoding: .utf8)
        #expect(json.contains(".123Z"))
    }

    @Test func missingPrimaryRecoversExistingBackup() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        let first = try await repository.loadOrCreate(now: now)
        var second = first
        _ = GameEngine.feed(&second, catID: "cat_001", now: now)
        try await repository.save(second)
        try FileManager.default.removeItem(at: repository.saveURL)
        #expect(try await repository.loadOrCreate(now: now) == first)
        #expect(await repository.lastLoadDisposition == .recoveredBackup)
    }

    @Test func frequentSavesPreserveCheckpointAndRotateAtTheIntervalAcrossReopen() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        let first = try Data(contentsOf: repository.saveURL)
        state.player.gold += 1
        try await repository.save(state, now: now)
        #expect(try Data(contentsOf: repository.backupURL) == first)
        for second in [1.0, 15, 60, 180, 299] {
            state.player.gold += 1
            try await FileSaveRepository(directory: folder).save(state, now: now.addingTimeInterval(second))
            #expect(try Data(contentsOf: repository.backupURL) == first)
        }
        let checkpoint = try Data(contentsOf: repository.saveURL)
        state.player.gold += 1
        try await FileSaveRepository(directory: folder).save(state, now: now.addingTimeInterval(300))
        #expect(try Data(contentsOf: repository.backupURL) == checkpoint)
        #expect(try await repository.loadOrCreate(now: now) == state)
        // Moving the clock backward or saving again shortly afterward cannot rotate it again.
        for second in [-1.0, 301, 599] {
            state.player.gold += 1
            try await FileSaveRepository(directory: folder).save(state, now: now.addingTimeInterval(second))
            #expect(try Data(contentsOf: repository.backupURL) == checkpoint)
        }
        try Data("interrupted primary".utf8).write(to: repository.saveURL)
        let recovered = try await repository.loadOrCreate(now: now)
        #expect(recovered.player.gold == 206)
        #expect(try Data(contentsOf: repository.saveURL) == checkpoint)
    }

    @Test func identicalSaveDoesNotPostponeTheNextCheckpoint() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        state.player.gold += 1
        try await repository.save(state, now: now)
        let checkpoint = try Data(contentsOf: repository.backupURL)
        try await repository.save(state, now: now.addingTimeInterval(400))
        #expect(try Data(contentsOf: repository.backupURL) == checkpoint)
        let saved = try Data(contentsOf: repository.saveURL)
        state.player.gold += 1
        try await repository.save(state, now: now.addingTimeInterval(401))
        #expect(try Data(contentsOf: repository.backupURL) == saved)
    }

    @Test func malformedBackupIsRepairedButFutureBackupIsNeverDowngraded() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        let initial = try Data(contentsOf: repository.saveURL)
        try Data("bad checkpoint".utf8).write(to: repository.backupURL)
        state.player.gold += 1
        try await repository.save(state, now: now)
        #expect(try Data(contentsOf: repository.backupURL) == initial)
        let primary = try Data(contentsOf: repository.saveURL)
        let future = Data("{\"schemaVersion\":99,\"futureData\":\"keep\"}".utf8)
        try future.write(to: repository.backupURL)
        state.player.gold += 1
        await #expect(throws: SaveRepositoryError.unsupportedSchemaVersion(99)) {
            try await repository.save(state, now: now.addingTimeInterval(1))
        }
        #expect(try Data(contentsOf: repository.saveURL) == primary)
        #expect(try Data(contentsOf: repository.backupURL) == future)
    }

    @Test func recoveryEvidenceIsBoundedDeduplicatedAndDoesNotDeleteUnrelatedFiles() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        state.player.gold += 1
        try await repository.save(state, now: now)
        let unrelated = folder.appendingPathComponent("unreadable-save-not-a-generated-uuid.json")
        try Data("personal notes".utf8).write(to: unrelated)
        func evidence() throws -> [URL] {
            try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("unreadable-save-")
                    && $0.lastPathComponent != unrelated.lastPathComponent }
        }
        for number in 1...7 {
            let damaged = Data("damaged primary \(number)".utf8)
            try damaged.write(to: repository.saveURL)
            #expect(try await repository.loadOrCreate(now: now).player.gold == 200)
            let files = try evidence()
            #expect(files.count == min(number, FileSaveRepository.maximumRecoveryFiles))
            let newest = try #require(files.first { (try? Data(contentsOf: $0)) == damaged })
            // Give the previous recoveries deterministic ages; no sleeps are needed.
            try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(Double(number))],
                                                  ofItemAtPath: newest.path)
        }
        let preserved = try Set(evidence().map { try Data(contentsOf: $0) })
        #expect(preserved == Set((5...7).map { Data("damaged primary \($0)".utf8) }))
        let repeated = Data("damaged primary 5".utf8)
        for _ in 0..<4 {
            try repeated.write(to: repository.saveURL)
            _ = try await repository.loadOrCreate(now: now)
        }
        #expect(try evidence().count == 3)
        #expect(try Set(evidence().map { try Data(contentsOf: $0) }) == preserved)
        #expect(try Data(contentsOf: unrelated) == Data("personal notes".utf8))
    }

    @Test func cappedReceiptAndFailedActionProgressSurviveReloadAndNeverPayTwice() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = FileSaveRepository(directory: folder)
        var state = try await repository.loadOrCreate(now: now)
        state.player.gold = GameSnapshot.maximumGold - 7
        state.inventory.food = 0
        _ = GameEngine.startWork(&state, now: now)
        try await repository.save(state)
        let later = now.addingTimeInterval(1440)
        #expect(!GameEngine.feed(&state, catID: "cat_001", now: later).succeeded)
        #expect(state.player.lastWorkResult?.goldReward == 7 && state.player.exp == 22)
        try await repository.save(state)
        var loaded = try await FileSaveRepository(directory: folder).loadOrCreate(now: later)
        #expect(loaded == state)
        #expect(GameEngine.synchronize(&loaded, now: later).kind == .none)
        #expect(loaded == state)
        _ = GameEngine.buyFood(&loaded, now: later)
        _ = GameEngine.synchronize(&loaded, now: later.addingTimeInterval(3600))
        #expect(loaded.player.gold == GameSnapshot.maximumGold - GameEngine.foodPrice)
        #expect(loaded.player.exp == 22 && loaded.player.completedWorkCount == 1)
    }
}
