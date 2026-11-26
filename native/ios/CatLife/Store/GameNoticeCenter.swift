import Foundation
import Observation

/// Warm-paper toast queue; deduplicates concurrent lines and auto-dismisses.
@MainActor
@Observable
final class GameNoticeCenter {
    private(set) var toast: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    func show(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let combined = ((toast.map { [$0] } ?? []) + [trimmed])
            .flatMap { $0.components(separatedBy: "\n") }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .reduce(into: [String]()) { lines, line in
                lines.removeAll { $0 == line }
                lines.append(line)
            }
            .suffix(2)
            .joined(separator: "\n")
        guard !combined.isEmpty else { return }
        task?.cancel()
        toast = combined
        task = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2.8)) } catch { return }
            self?.toast = nil
        }
    }

    func dismiss() {
        task?.cancel()
        toast = nil
    }
}
