import XCTest
@testable import CatLife

final class OnboardingSpotlightLayoutTests: XCTestCase {
    func testCardStaysInsideScreenAndNeverCoversItsMeasuredTarget() {
        for size in [CGSize(width: 375, height: 623), CGSize(width: 430, height: 839)] {
            let targets = [CGRect(x: size.width - 98, y: size.height - 310, width: 88, height: 245),
                           CGRect(x: 14, y: 78, width: 178, height: 44),
                           CGRect(x: size.width / 5, y: size.height - 64, width: size.width / 5, height: 56)]
            for target in targets {
                let card = OnboardingSpotlightLayout.card(in: size, target: target)
                XCTAssertTrue(CGRect(origin: .zero, size: size).contains(card))
                XCTAssertFalse(card.intersects(target))
                XCTAssertGreaterThan(card.height, 250)
            }
        }
    }
}
