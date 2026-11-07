import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameOnboardingCenterTests: XCTestCase {
    private let createdAt = Date(timeIntervalSince1970: 1_793_600_000.123456)

    @MainActor
    func testNewSavePreparesFirstStepWithoutPresentingBeforeHomeEntry() throws {
        let center = GameOnboardingCenter(defaults: try isolatedDefaults())
        let snapshot = GameSnapshot.fresh(now: createdAt)
        center.prepare(snapshot: snapshot, disposition: .created)
        XCTAssertEqual(center.step, .care)
        XCTAssertEqual(center.stepIndex, 0)
        XCTAssertTrue(center.isActive)
        XCTAssertFalse(center.isPresented)
        center.show()
        XCTAssertTrue(center.isPresented)
        XCTAssertEqual(snapshot, GameSnapshot.fresh(now: createdAt))
    }

    @MainActor
    func testExistingAndRecoveredSavesWithoutTourHistoryNeverStartAutomatically() throws {
        for disposition in [SaveLoadDisposition.loaded, .recoveredBackup] {
            let center = GameOnboardingCenter(defaults: try isolatedDefaults())
            center.prepare(snapshot: GameSnapshot.fresh(now: createdAt), disposition: disposition)
            center.show()
            XCTAssertNil(center.step)
            XCTAssertFalse(center.isActive || center.isPresented)
        }
    }

    @MainActor
    func testPendingStepSurvivesDiskDatePrecisionAndColdLaunch() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let first = GameOnboardingCenter(defaults: defaults)
        first.prepare(snapshot: snapshot, disposition: .created)
        first.show()
        first.next()
        first.next()
        XCTAssertEqual(first.step, .supplies)
        first.isPresented = false

        let data = try NativeSaveTransfer.encode(snapshot: snapshot, exportedAt: createdAt)
        let reloaded = try NativeSaveTransfer.decode(data, now: createdAt).snapshot
        let resumed = GameOnboardingCenter(defaults: defaults)
        resumed.prepare(snapshot: reloaded, disposition: .loaded)
        XCTAssertEqual(resumed.step, .supplies)
        XCTAssertEqual(resumed.stepIndex, 2)
        XCTAssertFalse(resumed.isPresented)
        resumed.show()
        XCTAssertTrue(resumed.isPresented)
    }

    @MainActor
    func testPendingStepSurvivesEveryMillisecondBoundaryAndSeededCreationDates() throws {
        let defaults = try isolatedDefaults()
        var dates: [Date] = []
        for millisecond in 0..<1000 {
            // Both sides of half-millisecond rounding, including the next-second boundary.
            for microseconds in [0, 499, 501, 999] {
                dates.append(Date(timeIntervalSince1970: 1_793_600_000
                    + Double(millisecond) / 1000 + Double(microseconds) / 1_000_000))
            }
        }
        // Fixed seed makes failures reproducible across SDKs; span 2020 through 2099.
        var seed: UInt64 = 0xCA7_11FE
        for _ in 0..<2000 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let seconds = 1_577_836_800 + Double(seed % 2_524_608_000)
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            dates.append(Date(timeIntervalSince1970: seconds + Double(seed % 1_000_000) / 1_000_000))
        }

        for date in dates {
            let resumedStep = try autoreleasepool {
                let snapshot = GameSnapshot.fresh(now: date)
                let first = GameOnboardingCenter(defaults: defaults)
                first.prepare(snapshot: snapshot, disposition: .created)
                first.next()
                first.next()
                // Exercise the shared production disk/archive codec, not a test date formatter.
                let data = try NativeSaveTransfer.encode(snapshot: snapshot, exportedAt: date)
                let reloaded = try NativeSaveTransfer.decode(data, now: date).snapshot
                let resumed = GameOnboardingCenter(defaults: defaults)
                resumed.prepare(snapshot: reloaded, disposition: .loaded)
                return resumed.step
            }
            guard resumedStep == .supplies else {
                XCTFail("Tour did not resume after date round-trip: \(date.timeIntervalSince1970)")
                return
            }
        }
    }

    @MainActor
    func testRecoveringSameSaveResumesItsTourWithoutResettingTheStep() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: snapshot, disposition: .created)
        center.next()
        let restored = GameOnboardingCenter(defaults: defaults)
        restored.prepare(snapshot: snapshot, disposition: .recoveredBackup)
        XCTAssertEqual(restored.step, .work)
        XCTAssertFalse(restored.isPresented)
    }

    @MainActor
    func testPreviousDoesNotGoBeforeFirstStepAndPersistsItsPosition() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: snapshot, disposition: .created)
        center.previous()
        XCTAssertEqual(center.step, .care)
        center.next()
        center.next()
        center.previous()
        let resumed = GameOnboardingCenter(defaults: defaults)
        resumed.prepare(snapshot: snapshot, disposition: .loaded)
        XCTAssertEqual(resumed.step, .work)
    }

    @MainActor
    func testCompletingFinalStepStaysDismissedAcrossRelaunchAndExtraActions() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: snapshot, disposition: .created)
        center.show()
        for _ in GameOnboardingStep.allCases { center.next() }
        center.next()
        center.previous()
        center.show()
        XCTAssertNil(center.step)
        XCTAssertFalse(center.isPresented)
        let reloaded = GameOnboardingCenter(defaults: defaults)
        reloaded.prepare(snapshot: snapshot, disposition: .loaded)
        reloaded.show()
        XCTAssertFalse(reloaded.isActive || reloaded.isPresented)
    }

    @MainActor
    func testFinishingStaysDismissedButSettingsCanExplicitlyRestart() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: snapshot, disposition: .created)
        center.show()
        center.next()
        center.finish()
        let reloaded = GameOnboardingCenter(defaults: defaults)
        reloaded.prepare(snapshot: snapshot, disposition: .loaded)
        XCTAssertFalse(reloaded.isActive)
        reloaded.restart(snapshot: snapshot)
        XCTAssertEqual(reloaded.step, .care)
        XCTAssertTrue(reloaded.isPresented)
    }

    @MainActor
    func testDismissingGuidePreservesPendingStepAndResumesAfterRelaunch() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: snapshot, disposition: .created)
        center.show()
        center.next()
        let progress = try XCTUnwrap(defaults.data(forKey: GameOnboardingCenter.progressKey))

        center.isPresented = false
        XCTAssertFalse(center.isPresented)
        XCTAssertEqual(center.step, .work)
        XCTAssertTrue(center.isActive)
        XCTAssertEqual(defaults.data(forKey: GameOnboardingCenter.progressKey), progress)

        let resumed = GameOnboardingCenter(defaults: defaults)
        resumed.prepare(snapshot: snapshot, disposition: .loaded)
        XCTAssertFalse(resumed.isPresented)
        resumed.show()
        XCTAssertTrue(resumed.isPresented)
        XCTAssertEqual(resumed.step, .work)
        XCTAssertEqual(resumed.stepIndex, 1)
    }

    @MainActor
    func testImportClosesAndEndsTheTourEvenWhenCreationDateMatches() throws {
        let defaults = try isolatedDefaults()
        var imported = GameSnapshot.fresh(now: createdAt)
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: imported, disposition: .created)
        center.show()
        center.next()
        imported.player.gold = 900
        center.didImport(snapshot: imported)
        XCTAssertFalse(center.isActive || center.isPresented)
        let reloaded = GameOnboardingCenter(defaults: defaults)
        reloaded.prepare(snapshot: imported, disposition: .loaded)
        reloaded.show()
        XCTAssertFalse(reloaded.isActive || reloaded.isPresented)
        XCTAssertEqual(imported.player.gold, 900)
    }

    @MainActor
    func testAnotherExistingSaveDoesNotInheritPendingTourAndNewSaveCanStart() throws {
        let defaults = try isolatedDefaults()
        let first = GameSnapshot.fresh(now: createdAt)
        let second = GameSnapshot.fresh(now: createdAt.addingTimeInterval(60))
        let center = GameOnboardingCenter(defaults: defaults)
        center.prepare(snapshot: first, disposition: .created)
        center.next()
        center.prepare(snapshot: second, disposition: .loaded)
        XCTAssertFalse(center.isActive || center.isPresented)
        center.prepare(snapshot: second, disposition: .created)
        XCTAssertEqual(center.step, .care)
        XCTAssertFalse(center.isPresented)
    }

    @MainActor
    func testCorruptUnknownAndInconsistentLocalPreferencesDoNotBlockExistingSaves() throws {
        let defaults = try isolatedDefaults()
        let snapshot = GameSnapshot.fresh(now: createdAt)
        let original = GameOnboardingCenter(defaults: defaults)
        original.prepare(snapshot: snapshot, disposition: .created)
        let validData = try XCTUnwrap(defaults.data(forKey: GameOnboardingCenter.progressKey))
        let valid = try XCTUnwrap(JSONSerialization.jsonObject(with: validData) as? [String: Any])
        var unknownStep = valid
        unknownStep["step"] = "future_step"
        var inconsistent = valid
        inconsistent["completed"] = true
        var missingStep = valid
        missingStep.removeValue(forKey: "step")
        let invalid = try [unknownStep, inconsistent, missingStep]
            .map { try JSONSerialization.data(withJSONObject: $0) } + [Data("broken".utf8)]
        for data in invalid {
            defaults.set(data, forKey: GameOnboardingCenter.progressKey)
            let center = GameOnboardingCenter(defaults: defaults)
            center.prepare(snapshot: snapshot, disposition: .loaded)
            center.show()
            XCTAssertFalse(center.isActive || center.isPresented)
        }
        defaults.set(Data("broken".utf8), forKey: GameOnboardingCenter.progressKey)
        let fresh = GameOnboardingCenter(defaults: defaults)
        fresh.prepare(snapshot: snapshot, disposition: .created)
        XCTAssertEqual(fresh.step, .care)
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "CatLife-Onboarding-Tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }
}
