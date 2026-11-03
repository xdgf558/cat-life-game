import Foundation

public enum SaveRepositoryError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case invalidSnapshot
    /// Neither the primary nor a validated backup can be loaded. Nothing is reset.
    case unreadableSave
}

public enum SaveLoadDisposition: Sendable {
    case created, loaded, recoveredBackup
}

/// One actor serializes access to a native JSON save and a validated checkpoint.
/// Frequent saves retain the checkpoint for five minutes instead of replacing it
/// with a nearly identical copy on every tick. File metadata preserves this window
/// across repository instances without adding fields to the game save schema.
/// The caller owns the Application Support location; no browser storage is touched.
public actor FileSaveRepository {
    static let backupInterval: TimeInterval = 5 * 60
    static let maximumRecoveryFiles = 3
    public nonisolated let directory: URL
    public nonisolated let saveURL: URL
    public nonisolated let backupURL: URL
    public private(set) var lastLoadDisposition: SaveLoadDisposition = .loaded

    public init(directory: URL) {
        self.directory = directory
        saveURL = directory.appendingPathComponent("cat-life-native-v1.json")
        backupURL = directory.appendingPathComponent("cat-life-native-v1.backup.json")
    }

    public func loadOrCreate(now: Date = Date()) async throws -> GameSnapshot {
        try ensureDirectory()
        let manager = FileManager.default
        if manager.fileExists(atPath: saveURL.path) {
            // A read-permission/I/O failure propagates instead of silently replacing a file.
            let primaryData = try Data(contentsOf: saveURL)
            do {
                let state = try decode(primaryData)
                lastLoadDisposition = .loaded
                return state
            } catch SaveRepositoryError.unsupportedSchemaVersion(let version) {
                // Never downgrade a future native save by restoring an older backup.
                throw SaveRepositoryError.unsupportedSchemaVersion(version)
            } catch {
                return try recoverBackup(preserving: primaryData)
            }
        }
        if manager.fileExists(atPath: backupURL.path) {
            return try recoverBackup(preserving: nil)
        }
        guard now.timeIntervalSince1970.isFinite else { throw SaveRepositoryError.invalidSnapshot }
        let fresh = GameSnapshot.fresh(now: now)
        try await save(fresh)
        lastLoadDisposition = .created
        return fresh
    }

    public func save(_ state: GameSnapshot) async throws {
        try await save(state, now: Date())
    }

    /// Probe the same storage directory without rewriting gameplay or rotating its checkpoint.
    public func checkWritable() throws {
        try ensureDirectory()
        if FileManager.default.fileExists(atPath: saveURL.path) {
            _ = try decode(Data(contentsOf: saveURL))
        }
        _ = try shouldRotateBackup(now: Date())
        let probe = directory.appendingPathComponent(".cat-life-save-check-\(UUID().uuidString).tmp")
        let data = Data("CatLife save check".utf8)
        defer { try? FileManager.default.removeItem(at: probe) }
        try data.write(to: probe, options: .atomic)
        guard try Data(contentsOf: probe) == data else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.removeItem(at: probe)
    }

    /// The explicit clock makes checkpoint rotation deterministic in durability tests.
    public func save(_ state: GameSnapshot, now: Date) async throws {
        guard now.timeIntervalSince1970.isFinite else { throw SaveRepositoryError.invalidSnapshot }
        guard state.schemaVersion == GameSnapshot.currentSchemaVersion else {
            throw SaveRepositoryError.unsupportedSchemaVersion(state.schemaVersion)
        }
        guard state.isValid else { throw SaveRepositoryError.invalidSnapshot }
        let candidate = try encode(state)
        // Validate serialization before touching existing durable files.
        _ = try decode(candidate)
        try ensureDirectory()
        if FileManager.default.fileExists(atPath: saveURL.path) {
            let previous = try Data(contentsOf: saveURL)
            // Do not rotate corrupt data over the last known-good backup or replace a
            // newer-schema file merely because the caller has an in-memory snapshot.
            _ = try decode(previous)
            if previous == candidate { return }
            if try shouldRotateBackup(now: now) {
                try previous.write(to: backupURL, options: .atomic)
                try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: backupURL.path)
            }
        }
        try candidate.write(to: saveURL, options: .atomic)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func shouldRotateBackup(now: Date) throws -> Bool {
        let manager = FileManager.default
        guard manager.fileExists(atPath: backupURL.path) else { return true }
        // Permission/I/O failures must not be treated as a corrupt file that can
        // be overwritten. A malformed backup can be repaired from the valid primary.
        let backupData = try Data(contentsOf: backupURL)
        do {
            _ = try decode(backupData)
        } catch SaveRepositoryError.unsupportedSchemaVersion(let version) {
            throw SaveRepositoryError.unsupportedSchemaVersion(version)
        } catch {
            return true
        }
        let attributes = try manager.attributesOfItem(atPath: backupURL.path)
        guard let checkpointAt = attributes[.modificationDate] as? Date else { return true }
        // Clock rollback keeps the existing known-good checkpoint until time catches up.
        return now.timeIntervalSince(checkpointAt) >= Self.backupInterval
    }

    private func recoverBackup(preserving corruptData: Data?) throws -> GameSnapshot {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw SaveRepositoryError.unreadableSave
        }
        let backupData = try Data(contentsOf: backupURL)
        let recovered: GameSnapshot
        do {
            recovered = try decode(backupData)
        } catch SaveRepositoryError.unsupportedSchemaVersion(let version) {
            throw SaveRepositoryError.unsupportedSchemaVersion(version)
        } catch {
            throw SaveRepositoryError.unreadableSave
        }
        if let corruptData {
            // Retrying a failed restore must not produce unlimited identical evidence.
            let alreadyPreserved = try recoveryFiles().first { url in
                (try? Data(contentsOf: url)) == corruptData
            }
            if let alreadyPreserved {
                try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: alreadyPreserved.path)
            } else {
                let recoveryURL = directory.appendingPathComponent("unreadable-save-\(UUID().uuidString).json")
                try corruptData.write(to: recoveryURL, options: .atomic)
            }
        }
        try backupData.write(to: saveURL, options: .atomic)
        lastLoadDisposition = .recoveredBackup
        // Cleanup cannot turn a successfully restored save into a load failure.
        // Keep the three newest recovery files, and never touch unrelated documents.
        if let files = try? recoveryFiles() {
            for url in files.dropFirst(Self.maximumRecoveryFiles) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return recovered
    }

    private func recoveryFiles() throws -> [URL] {
        let files = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])
        return files.compactMap { url -> (URL, Date)? in
            let name = url.lastPathComponent
            guard name.hasPrefix("unreadable-save-"), name.hasSuffix(".json"),
                  UUID(uuidString: String(name.dropFirst("unreadable-save-".count).dropLast(5))) != nil,
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast)
        }.sorted {
            if $0.1 == $1.1 { return $0.0.lastPathComponent < $1.0.lastPathComponent }
            return $0.1 > $1.1
        }.map(\.0)
    }

    private func encode(_ snapshot: GameSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.dateString(date))
        }
        return try encoder.encode(snapshot)
    }

    private func decode(_ data: Data) throws -> GameSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = Self.parseDate(string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
        let snapshot = try decoder.decode(GameSnapshot.self, from: data)
        guard snapshot.isValid else { throw SaveRepositoryError.invalidSnapshot }
        return snapshot
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
