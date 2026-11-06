import XCTest
import CatGameCore
@testable import CatLife

final class SaveTransferPresentationTests: XCTestCase {
    func testComparisonDirectionMatchesDisplayedValueChangeIncludingLargeNumbers() {
        XCTAssertEqual(SaveTransferComparison.direction(current: 200, incoming: 0), -1)
        XCTAssertEqual(SaveTransferComparison.direction(current: 0, incoming: 1_000_000_000), 1)
        XCTAssertEqual(SaveTransferComparison.direction(current: 1_000_000_000, incoming: 1_000_000_000), 0)
        XCTAssertEqual(SaveTransferComparison.direction(current: Int.max, incoming: Int.min), -1)
        XCTAssertEqual(SaveTransferComparison.direction(current: Int.min, incoming: Int.max), 1)
    }

    func testEarlierBackupWarningUsesEitherLevelOrProgressTime() {
        var current = GameSnapshot.fresh(now: Date(timeIntervalSince1970: 1_793_800_000))
        current.player.level = 5
        var incoming = current
        XCTAssertFalse(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
        incoming.player.level = 4
        incoming.meta.lastSyncAt = current.meta.lastSyncAt.addingTimeInterval(60)
        XCTAssertTrue(SaveTransferComparison.isEarlier(current: current, incoming: incoming),
                      "A lower-level backup is older progress even when its device clock is later.")
        incoming.player.level = 6
        incoming.meta.lastSyncAt = current.meta.lastSyncAt.addingTimeInterval(-60)
        XCTAssertTrue(SaveTransferComparison.isEarlier(current: current, incoming: incoming),
                      "An older timestamp still needs the warning when the backup level is higher.")
        incoming.meta.lastSyncAt = current.meta.lastSyncAt.addingTimeInterval(60)
        XCTAssertFalse(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
    }

    func testNewDeviceWithOnlyPreferencesDoesNotWarnThatAnOlderBackupIsARegression() {
        let now = Date(timeIntervalSince1970: 1_793_800_000)
        var current = GameSnapshot.fresh(now: now)
        var incoming = GameSnapshot.fresh(now: now.addingTimeInterval(-86_400))
        incoming.player.level = 4
        incoming.player.completedWorkCount = 20
        XCTAssertFalse(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
        current.settings.language = .english
        current.player.profile.name = "New device"
        current.player.profile.avatarID = PlayerCatalog.avatars.last?.id
        current.home.name = "New home"
        current.cats[0].customName = "Milo"
        _ = GameEngine.synchronize(&current, now: now.addingTimeInterval(60))
        _ = GameEngine.synchronize(&current, now: now.addingTimeInterval(120))
        XCTAssertFalse(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
    }

    func testLevelOneGameWithRealCareOrRoomChangesStillWarnsBeforeEarlierImport() {
        let now = Date(timeIntervalSince1970: 1_793_800_000)
        let incoming = GameSnapshot.fresh(now: now.addingTimeInterval(-86_400))
        var current = GameSnapshot.fresh(now: now)
        XCTAssertTrue(GameEngine.feed(&current, catID: current.activeCatID, now: now).succeeded)
        XCTAssertTrue(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
        current = .fresh(now: now)
        current.home.bowlPosition.x += 0.02
        XCTAssertTrue(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
        current = .fresh(now: now)
        current.player.profile.equipped[.head] = PlayerCatalog.starterEquipmentIDs.first
        XCTAssertTrue(SaveTransferComparison.isEarlier(current: current, incoming: incoming))
    }
}
