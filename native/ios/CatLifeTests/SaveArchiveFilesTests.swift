import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class SaveArchiveFilesTests: XCTestCase {
    func testBackupFilenameUsesExportDateAndFilesystemSafeLocalTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 7,
                                                                   hour: 15, minute: 4, second: 5)))
        XCTAssertEqual(SaveArchiveFiles.backupFilename(exportedAt: date), "CatLife-Backup-2026-11-07_15-04-05")
        XCTAssertEqual(SaveArchiveFiles.backupFilename(exportedAt: date.addingTimeInterval(60)),
                       "CatLife-Backup-2026-11-07_15-05-05")
    }

    func testPreparingDatedShareKeepsOnlyLatestBackupAttachment() throws {
        let oldName = "CatLife-Backup-2026-11-07_15-04-05"
        let newName = "CatLife-Backup-2026-11-07_15-05-05"
        let oldURL = try SaveArchiveFiles.prepareShareFile(Data("first".utf8), filename: oldName)
        let unrelated = oldURL.deletingLastPathComponent().appendingPathComponent("Preserved-QA.json")
        let legacyURL = oldURL.deletingLastPathComponent().appendingPathComponent("CatLife-Backup.json")
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName + ".json")
        defer { for url in [oldURL, newURL, unrelated, legacyURL] { try? FileManager.default.removeItem(at: url) } }
        try Data("original".utf8).write(to: unrelated)
        try Data("legacy".utf8).write(to: legacyURL)

        let result = try SaveArchiveFiles.prepareShareFile(Data("second".utf8), filename: newName)
        XCTAssertEqual(result, newURL)
        XCTAssertEqual(result.lastPathComponent, newName + ".json")
        XCTAssertEqual(try Data(contentsOf: result), Data("second".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("original".utf8))
    }

    func testSelectedNativeFileReadsAndInvalidFileDoesNotBecomeAPreview() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date(timeIntervalSince1970: 1_793_800_000)
        let snapshot = GameSnapshot.fresh(now: date)
        let url = directory.appendingPathComponent("我的备份🐾.json")
        let data = try NativeSaveTransfer.encode(snapshot: snapshot, exportedAt: date)
        try data.write(to: url)
        let selection = try SaveArchiveFiles.readSelection(url)
        XCTAssertEqual(selection.filename, "我的备份🐾.json")
        XCTAssertEqual(selection.byteCount, data.count)
        XCTAssertEqual(selection.archive.snapshot, snapshot)
        let archive = try SaveArchiveFiles.read(url)
        XCTAssertEqual(archive.snapshot, snapshot)
        XCTAssertEqual(archive.exportedAt, date)

        try Data("{\"player\":\"unrelated document\"}".utf8).write(to: url)
        XCTAssertThrowsError(try SaveArchiveFiles.read(url))
        XCTAssertThrowsError(try SaveArchiveFiles.readSelection(url))
        XCTAssertThrowsError(try SaveArchiveFiles.read(directory.appendingPathComponent("missing.json")))
    }

    func testFileReaderRejectsOversizedFilesBeforeDecoding() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("oversized.json")
        try Data(repeating: 32, count: NativeSaveTransfer.maximumFileSize + 1).write(to: url)
        XCTAssertThrowsError(try SaveArchiveFiles.read(url)) { error in
            guard case SaveTransferError.fileTooLarge = error else {
                return XCTFail("Expected the file-size guard, got \(error)")
            }
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatLife-SaveFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
