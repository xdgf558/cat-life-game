import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class SaveArchiveFilesTests: XCTestCase {
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
