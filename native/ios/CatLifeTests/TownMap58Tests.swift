import XCTest
import CatGameCore
@testable import CatLife

@MainActor
final class TownMap58Tests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAllPlacesStayInsideMapWithoutOverlappingArtOrNameplates() {
        XCTAssertEqual(Set(TownMapLayout.readingOrder), Set(TownPlace.allCases))
        XCTAssertEqual(TownMapLayout.readingOrder.count, TownPlace.allCases.count)
        let bounds = CGRect(origin: .zero, size: TownMapLayout.size)
        for place in TownMapLayout.readingOrder {
            let frame = TownMapLayout.frame(for: place)
            XCTAssertTrue(bounds.contains(frame), "\(place) must not be clipped off the map.")
            for other in TownPlace.allCases where other != place {
                XCTAssertFalse(TownMapLayout.frame(for: other).intersects(frame),
                               "\(other) must not cover \(place)'s artwork or nameplate.")
            }
        }
        XCTAssertEqual(TownPlace.market.layer, .neighbors)
    }

    func testDayNightUsesLocalTimeAtExactBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 8 * 3_600))
        for (hour, expected) in [(0, true), (6, true), (7, false), (18, false), (19, true), (23, true)] {
            let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: hour)))
            XCTAssertEqual(TownMapLayout.isNight(date, calendar: calendar), expected)
        }
    }

    func testNoMaterialsIsNotMistakenForExhaustedDailyExchanges() {
        var snapshot = GameSnapshot.fresh(now: now)
        snapshot.inventory.food = 0
        snapshot.inventory.litter = 0
        snapshot.inventory.toys = 0
        snapshot.inventory.gifts = [:]
        let empty = TownMapStatus(snapshot: snapshot)
        XCTAssertEqual(empty.availableExchanges, 0)
        XCTAssertFalse(empty.exhaustedExchanges)
        XCTAssertNil(empty.badge(for: .market, now: now))
        for neighbor in CommunityCatalog.neighbors {
            snapshot.community.exchangeCounts[neighbor.id] = .init(today: ExchangeCatalog.dailyLimit,
                                                                  total: ExchangeCatalog.dailyLimit)
        }
        let exhausted = TownMapStatus(snapshot: snapshot)
        XCTAssertTrue(exhausted.exhaustedExchanges)
        XCTAssertEqual(exhausted.badge(for: .market, now: now), GameStrings.text("townMap.exchangedToday"))
    }

    func testAvailableAdoptionsAndUnvisitedNeighborsFollowCurrentProgress() throws {
        var snapshot = GameSnapshot.fresh(now: now)
        snapshot.player.level = 8
        snapshot.home = HomeState(roomLevel: 3)
        snapshot.player.gold = 599
        XCTAssertEqual(TownMapStatus(snapshot: snapshot).availableAdoptions.map(\.id), [CatCatalog.cowCatID])
        snapshot.player.gold = 600
        XCTAssertEqual(TownMapStatus(snapshot: snapshot).availableAdoptions.map(\.id), [CatCatalog.cowCatID, CatCatalog.blueCatID])
        var adopted = try XCTUnwrap(snapshot.cats.first)
        adopted.id = CatCatalog.cowCatID
        snapshot.cats.append(adopted)
        XCTAssertEqual(TownMapStatus(snapshot: snapshot).availableAdoptions.map(\.id), [CatCatalog.blueCatID])
        let neighbor = try XCTUnwrap(CommunityCatalog.neighbors.first)
        snapshot.community.relationships[neighbor.id] = .init(visitedToday: true, totalVisitCount: 1)
        snapshot.community.relationships["retired-neighbor"] = .init()
        XCTAssertEqual(TownMapStatus(snapshot: snapshot).unvisitedNeighbors.count, CommunityCatalog.neighbors.count - 1)
        XCTAssertFalse(TownMapStatus(snapshot: snapshot).unvisitedNeighbors.contains { $0.id == neighbor.id })
    }

    func testWorkBadgeDoesNotAddTimeBackWhenClockMovesBackwards() {
        var snapshot = GameSnapshot.fresh(now: now)
        snapshot.player.activeWork = .init(startedAt: now.addingTimeInterval(-60), endsAt: now.addingTimeInterval(60))
        let status = TownMapStatus(snapshot: snapshot)
        XCTAssertEqual(status.badge(for: .work, now: now.addingTimeInterval(-3_600)),
                       GameStrings.format("townMap.working", "01:00"))
        XCTAssertEqual(status.badge(for: .work, now: now.addingTimeInterval(60)), GameStrings.text("townMap.workReady"))
        XCTAssertNil(status.badge(for: .shop, now: now), "Do not invent a shop-newness badge.")
        XCTAssertNil(TownMapStatus(snapshot: nil).badge(for: .market, now: now))
    }

    func testTownMapStringsExistInAllSupportedLanguages() {
        let dictionaries = [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english]
        let expected = Set(GameStrings.chinese.keys.filter { $0.hasPrefix("townMap.") })
        XCTAssertFalse(expected.isEmpty)
        for dictionary in dictionaries {
            XCTAssertEqual(Set(dictionary.keys.filter { $0.hasPrefix("townMap.") }), expected)
            for key in expected { XCTAssertFalse(dictionary[key]?.isEmpty ?? true, key) }
        }
    }
}
