import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class GameAdoptionReminderTests: XCTestCase {
    @MainActor
    func testLevelGainQueuesBothOffersOnceAndPresentationSurvivesRelaunch() throws {
        let defaults = try isolatedDefaults()
        let reminders = GameAdoptionReminderCenter(defaults: defaults)
        let old = snapshot(level: 1, room: 3, gold: 2_000)
        let new = snapshot(level: 4, room: 3, gold: 2_000)
        reminders.consider(from: old, to: new)
        reminders.consider(from: old, to: new)
        XCTAssertEqual(reminders.pendingOffer?.id, CatCatalog.cowCatID)
        reminders.markPresented(CatCatalog.cowCatID)
        reminders.dismiss(CatCatalog.cowCatID)
        XCTAssertEqual(reminders.pendingOffer?.id, CatCatalog.blueCatID)
        reminders.markPresented(CatCatalog.blueCatID)
        reminders.dismiss(CatCatalog.blueCatID)
        XCTAssertNil(reminders.pendingOffer)
        XCTAssertEqual(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey),
                       [CatCatalog.cowCatID, CatCatalog.blueCatID])

        let reopened = GameAdoptionReminderCenter(defaults: defaults)
        reopened.consider(from: old, to: new)
        XCTAssertNil(reopened.pendingOffer)
    }

    @MainActor
    func testRoomUpgradeChecksRemainingGoldRatherThanPreUpgradeBalance() throws {
        let reminders = GameAdoptionReminderCenter(defaults: try isolatedDefaults())
        let old = snapshot(level: 4, room: 2, gold: 1_499)
        reminders.consider(from: old, to: snapshot(level: 4, room: 3, gold: 599))
        XCTAssertNil(reminders.pendingOffer)
        reminders.consider(from: snapshot(level: 4, room: 2, gold: 1_500),
                           to: snapshot(level: 4, room: 3, gold: 600))
        XCTAssertEqual(reminders.pendingOffer?.id, CatCatalog.blueCatID)
    }

    @MainActor
    func testExistingEligibilityAndGoldOnlyChangesDoNotCreateReminders() throws {
        let reminders = GameAdoptionReminderCenter(defaults: try isolatedDefaults())
        reminders.consider(from: snapshot(level: 4, room: 3, gold: 600),
                           to: snapshot(level: 5, room: 3, gold: 700))
        XCTAssertNil(reminders.pendingOffer)
        reminders.consider(from: snapshot(level: 4, room: 3, gold: 599),
                           to: snapshot(level: 4, room: 3, gold: 600))
        XCTAssertNil(reminders.pendingOffer)
        reminders.consider(from: snapshot(level: 1, room: 1, gold: 2_000),
                           to: snapshot(level: 4, room: 1, gold: 2_000))
        XCTAssertNil(reminders.pendingOffer, "A player level alone cannot bypass the room requirement.")
    }

    @MainActor
    func testAlreadyOwnedCatsAreExcludedEvenWhenLevelsIncrease() throws {
        let reminders = GameAdoptionReminderCenter(defaults: try isolatedDefaults())
        var old = snapshot(level: 1, room: 1, gold: 2_000)
        for offer in CatCatalog.adoptionOffers {
            old.cats.append(CatState(id: offer.id, name: offer.name, now: old.meta.lastSyncAt, appearance: offer.appearance))
        }
        var new = old
        new.player.level = 4
        new.home.roomLevel = 3
        reminders.consider(from: old, to: new)
        XCTAssertNil(reminders.pendingOffer)
    }

    @MainActor
    func testOnlyDisplayedHeadIsRememberedAndClearingPendingPreservesHistory() throws {
        let defaults = try isolatedDefaults()
        let reminders = GameAdoptionReminderCenter(defaults: defaults)
        let old = snapshot(level: 1, room: 3, gold: 2_000)
        let new = snapshot(level: 4, room: 3, gold: 2_000)
        reminders.consider(from: old, to: new)
        reminders.markPresented(CatCatalog.blueCatID)
        XCTAssertNil(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey))
        reminders.clearPending()
        XCTAssertNil(reminders.pendingOffer)
        reminders.consider(from: old, to: new)
        XCTAssertEqual(reminders.pendingOffer?.id, CatCatalog.cowCatID,
                       "A queued but hidden offer must not be marked as presented.")
        reminders.markPresented(CatCatalog.cowCatID)
        reminders.clearPending()

        let reopened = GameAdoptionReminderCenter(defaults: defaults)
        reopened.consider(from: old, to: new)
        XCTAssertEqual(reopened.pendingOffer?.id, CatCatalog.blueCatID)
        XCTAssertEqual(defaults.stringArray(forKey: GameAdoptionReminderCenter.presentedIDsKey), [CatCatalog.cowCatID])
    }

    @MainActor
    func testPendingOfferIsRemovedIfFundsAreSpentOrCatIsAdopted() throws {
        let reminders = GameAdoptionReminderCenter(defaults: try isolatedDefaults())
        let old = snapshot(level: 3, room: 3, gold: 600)
        let ready = snapshot(level: 4, room: 3, gold: 600)
        reminders.consider(from: old, to: ready)
        XCTAssertEqual(reminders.pendingOffer?.id, CatCatalog.blueCatID)
        var spent = ready
        spent.player.gold = 599
        reminders.consider(from: ready, to: spent)
        XCTAssertNil(reminders.pendingOffer)

        reminders.consider(from: old, to: ready)
        var adopted = ready
        adopted.cats.append(CatState(id: CatCatalog.blueCatID, name: "蓝影", now: adopted.meta.lastSyncAt, appearance: .blue))
        reminders.consider(from: ready, to: adopted)
        XCTAssertNil(reminders.pendingOffer)
    }

    private func snapshot(level: Int, room: Int, gold: Int) -> GameSnapshot {
        var value = GameSnapshot.fresh()
        value.player.level = level
        value.home.roomLevel = room
        value.player.gold = gold
        return value
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "CatLife-AdoptionReminders-Tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return defaults
    }
}
