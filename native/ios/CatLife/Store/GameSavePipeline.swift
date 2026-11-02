import Foundation
import CatGameCore

/// The app serializes commits; the repository provides atomic durable storage.
protocol GameSaveRepository: Sendable {
    var lastLoadDisposition: SaveLoadDisposition { get async }
    func loadOrCreate(now: Date) async throws -> GameSnapshot
    func save(_ state: GameSnapshot) async throws
}

extension FileSaveRepository: GameSaveRepository {}

/// Automatic retries are bounded per outage. A successful commit resets the
/// budget; an explicit player action is always allowed to attempt a new write.
struct SaveRetryState {
    private(set) var failures = 0
    private(set) var nextAttempt = Date.distantPast
    private(set) var hasReportedFailure = false
    static let maximumAutomaticAttempts = 3

    func permitsAutomaticAttempt(at date: Date) -> Bool {
        failures < Self.maximumAutomaticAttempts && date >= nextAttempt
    }

    mutating func failed(at date: Date) -> Bool {
        failures += 1
        nextAttempt = date.addingTimeInterval(failures == 1 ? 2 : 5)
        let shouldReport = !hasReportedFailure
        hasReportedFailure = true
        return shouldReport
    }

    mutating func succeeded() { self = Self() }
}
