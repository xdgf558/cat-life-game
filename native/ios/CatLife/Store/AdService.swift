import Foundation
import CatGameCore

/// Platform abstraction for rewarded video ads (mirrors WeChat `IAdPlayer`).
/// M1 uses `MockRewardedAdService`; M3 swaps in Google AdMob without changing Core or Store.
@MainActor
protocol RewardedAdService: AnyObject {
    func isReady(slot: AdSlot) -> Bool
    func play(slot: AdSlot) async -> AdPlayResult
}

/// Interactive mock player for M1 development & automated tests.
/// shortcut: Replace with GoogleMobileAds SDK adapter in M3 once AdMob unit IDs are provisioned.
@MainActor
final class MockRewardedAdService: RewardedAdService {
    var readySlots: Set<AdSlot> = Set(AdSlot.allCases)
    /// When set (e.g. in unit tests), immediately resolves with this outcome.
    /// When nil, suspends until the in-app mock player overlay resolves via `complete(with:)`.
    var immediateOutcome: AdPlayResult?
    var onRequestPlayback: ((AdSlot) -> Void)?
    private var continuation: CheckedContinuation<AdPlayResult, Never>?

    init(immediateOutcome: AdPlayResult? = nil) {
        self.immediateOutcome = immediateOutcome
    }

    func isReady(slot: AdSlot) -> Bool {
        readySlots.contains(slot)
    }

    func play(slot: AdSlot) async -> AdPlayResult {
        guard isReady(slot: slot) else { return .failed }
        if let outcome = immediateOutcome { return outcome }
        onRequestPlayback?(slot)
        return await withCheckedContinuation { cont in
            continuation = cont
        }
    }

    func complete(with result: AdPlayResult) {
        let cont = continuation
        continuation = nil
        cont?.resume(returning: result)
    }
}
