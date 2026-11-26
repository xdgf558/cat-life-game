import Foundation
import CatGameCore

protocol GameSaveRepository: Sendable {
    var lastLoadDisposition: SaveLoadDisposition { get async }
    func loadOrCreate(now: Date) async throws -> DiaryGameState
    func save(_ state: DiaryGameState, now: Date) async throws
}

extension DiarySaveRepository: GameSaveRepository {}

struct SaveRetryState {
    private(set) var failures = 0
    private(set) var nextAttempt = Date.distantPast
    private(set) var hasReportedFailure = false
    static let maximumAutomaticAttempts = 3

    func permitsAutomaticAttempt(at date: Date) -> Bool {
        date >= nextAttempt
    }

    mutating func failed(at date: Date) -> Bool {
        failures = min(Self.maximumAutomaticAttempts, failures + 1)
        nextAttempt = date.addingTimeInterval(failures == 1 ? 2 : (failures == 2 ? 5 : 60))
        let shouldReport = !hasReportedFailure
        hasReportedFailure = true
        return shouldReport
    }

    mutating func succeeded() { self = Self() }
}
