import XCTest
import CatGameCore
@testable import CatLife

final class CatCollectionBadgeTests: XCTestCase {
    func testNewCompanionsAreLimitedToTheirIntroductionReleaseSeries() {
        for appearance in [CatAppearance.siamese, .silver] {
            for version in ["0.14", "0.14.0", "0.14.1", "0.14.99"] {
                XCTAssertEqual(CatCollectionBadge.adoption(appearance: appearance, isOwned: false,
                                                           isAvailable: false, version: version), .newCompanion, version)
            }
            for version in ["0.13.99", "0.15.0", "0.140.0", "1.14.0", "", "0..14"] {
                XCTAssertNil(CatCollectionBadge.adoption(appearance: appearance, isOwned: false,
                                                        isAvailable: false, version: version), version)
            }
        }
        for appearance in [CatAppearance.orange, .cow, .blue] {
            XCTAssertNil(CatCollectionBadge.adoption(appearance: appearance, isOwned: false,
                                                    isAvailable: false, version: "0.14.1"))
        }
    }

    func testReadyToAdoptTakesPriorityDuringAndAfterNewCompanionPromotion() {
        for appearance in CatAppearance.allCases {
            for version in ["0.14.1", "0.15.0"] {
                XCTAssertEqual(CatCollectionBadge.adoption(appearance: appearance, isOwned: false,
                                                           isAvailable: true, version: version), .available)
            }
        }
    }

    func testOwnedCatsNeverReceiveNewCompanionOrAdoptionBadges() {
        for appearance in CatAppearance.allCases {
            for available in [false, true] {
                XCTAssertNil(CatCollectionBadge.adoption(appearance: appearance, isOwned: true,
                                                        isAvailable: available, version: "0.14.1"))
            }
        }
    }
}
