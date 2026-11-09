import XCTest
import CatGameCore
@testable import CatLife

final class ShopBrowserTests: XCTestCase {
    func testGrowingCatalogsStayBoundedWithoutOmittingOrRepeatingProducts() {
        for accessible in [false, true] {
            let size = ShopBrowser.pageSize(accessibility: accessible)
            XCTAssertEqual(size, accessible ? 2 : 6)
            for count in [0, 1, 2, 5, 6, 7, 101] {
                let pages = (0..<ShopBrowser.pageCount(for: count, pageSize: size)).map {
                    ShopBrowser.pageRange($0, count: count, pageSize: size)
                }
                XCTAssertTrue(pages.allSatisfy { $0.count <= size })
                XCTAssertEqual(pages.flatMap { Array($0) }, Array(0..<count))
            }
        }
    }

    func testFilteringOrPageSizeChangesClampStalePagesAndExtremeInputsSafely() {
        XCTAssertEqual(ShopBrowser.pageRange(2, count: 1, pageSize: 2), 0..<1)
        XCTAssertEqual(ShopBrowser.pageRange(-1, count: 7, pageSize: 6), 0..<6)
        XCTAssertEqual(ShopBrowser.pageRange(Int.max, count: 0, pageSize: 6), 0..<0)
        XCTAssertEqual(ShopBrowser.pageRange(3, count: -1, pageSize: 2), 0..<0)
        XCTAssertEqual(ShopBrowser.pageRange(1, count: 7, pageSize: 0), 1..<2)
        XCTAssertEqual(ShopBrowser.clampedPage(2, count: 6, pageSize: 6), 0)
        let last = ShopBrowser.pageRange(Int.max, count: Int.max, pageSize: 6)
        XCTAssertEqual(last.upperBound, Int.max)
        XCTAssertLessThanOrEqual(last.count, 6)
    }

    @MainActor
    func testFurnitureFiltersUsePlacementMetadataAndKeepEveryOfferIncludingOwnedOrLocked() throws {
        let all = ShopBrowser.products(in: .furniture, filter: .all)
        let floor = ShopBrowser.products(in: .furniture, filter: .floor)
        let wall = ShopBrowser.products(in: .furniture, filter: .wall)
        XCTAssertEqual(Set(all.map(\.id)), Set(ShopCatalog.furnitureOffers.map(\.id)))
        XCTAssertEqual(Set(floor.map(\.id)).union(wall.map(\.id)), Set(all.map(\.id)))
        XCTAssertTrue(Set(floor.map(\.id)).isDisjoint(with: wall.map(\.id)))
        for (products, isWall) in [(floor, false), (wall, true)] {
            for product in products {
                let offer = try XCTUnwrap(ShopCatalog.furnitureOffer(id: product.id))
                XCTAssertEqual(FurnitureCatalog.metadata(for: offer.kind).isWall, isWall)
            }
            XCTAssertEqual(products.map(\.id), all.filter { products.contains($0) }.map(\.id))
        }
        XCTAssertEqual(all.prefix(4).map(\.id), ["oak_bookcase", "rattan_chair", "round_side_table", "sunrise_art"])
        XCTAssertEqual(ShopBrowser.products(in: .furniture, filter: .standard), all)
        XCTAssertTrue(ShopBrowser.products(in: .furniture, filter: .premium).isEmpty,
                      "The design prototype must not invent premium furniture absent from Core.")
        XCTAssertEqual(ShopBrowser.filters(for: .furniture), [.all, .floor, .wall, .standard, .premium])
    }

    @MainActor
    func testSuppliesAndEquipmentKeepTheirExistingPurchaseIDsAndCatalogValues() {
        let all = ShopBrowser.products(in: .supplies, filter: .all)
        let premium = ShopBrowser.products(in: .supplies, filter: .premium)
        let standard = ShopBrowser.products(in: .supplies, filter: .standard)
        XCTAssertEqual(all, premium + standard)
        XCTAssertEqual(Set(all.map(\.id)), Set(SupplyKind.allCases.map(\.rawValue)))
        for (products, isPremium) in [(premium, true), (standard, false)] {
            for product in products {
                guard case .supply(let kind) = product.kind else { return XCTFail("Unexpected supply type") }
                XCTAssertEqual(kind.isPremium, isPremium)
                XCTAssertEqual(product.price, SupplyCatalog.definition(for: kind).price)
                XCTAssertEqual(product.purchaseIdentifier(prefix: "shopQuickBuy_"), kind.buyID)
            }
        }
        XCTAssertEqual(ShopBrowser.products(in: .equipment, filter: .wall), ShopListing.list(.equipment))
        XCTAssertTrue(ShopBrowser.filters(for: .equipment).isEmpty)
    }

    @MainActor
    func testBrowseLabelsResolveInAllThreeLanguages() {
        let language = GameLocalization.shared.language
        defer { GameLocalization.shared.language = language }
        let keys = Set(GameStrings.shopBrowseChinese.keys)
        XCTAssertEqual(keys, Set(GameStrings.shopBrowseTraditionalChinese.keys))
        XCTAssertEqual(keys, Set(GameStrings.shopBrowseEnglish.keys))
        for language in GameLanguage.allCases {
            GameLocalization.shared.language = language
            for key in keys { XCTAssertNotEqual(GameStrings.text(key), key) }
        }
    }
}
