import XCTest
@testable import CatGameCore

final class DiarySaveRepositoryTests: XCTestCase {
    func testSaveLoadBackupRecoveryAndLegacyFileIsolation() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Place a legacy v0.21 file to guarantee the new repository never modifies it.
        let legacyURL = dir.appendingPathComponent("cat-life-native-v1.json")
        let legacyBytes = Data("{\"legacy\":true}".utf8)
        try legacyBytes.write(to: legacyURL)

        let repo = DiarySaveRepository(directory: dir)
        let t0 = Date(timeIntervalSince1970: 1_760_000_000)
        var state = try await repo.loadOrCreate(now: t0)
        let d0 = await repo.lastLoadDisposition
        XCTAssertEqual(d0, .created)

        state.coins = 250
        try await repo.save(state, now: t0.addingTimeInterval(600))
        // Second save creates backup of 250-coin state after backupInterval
        state.coins = 400
        try await repo.save(state, now: t0.addingTimeInterval(1200))

        // Corrupt primary save -> must auto-recover backup cleanly.
        try Data("{corrupt".utf8).write(to: repo.saveURL)
        let recovered = try await repo.loadOrCreate(now: t0.addingTimeInterval(1300))
        let d1 = await repo.lastLoadDisposition
        XCTAssertEqual(d1, .recoveredBackup)
        XCTAssertEqual(recovered.coins, 250)

        // Legacy file untouched byte-for-byte.
        XCTAssertEqual(try Data(contentsOf: legacyURL), legacyBytes)
    }

    func testNewerSchemaVersionIsRejectedWithoutOverwriting() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let repo = DiarySaveRepository(directory: dir)
        try Data("{\"schemaVersion\":99}".utf8).write(to: repo.saveURL)
        do {
            _ = try await repo.loadOrCreate()
            XCTFail("Expected unsupportedSchemaVersion")
        } catch let error as SaveRepositoryError {
            XCTAssertEqual(error, .unsupportedSchemaVersion(99))
        }
    }
}
