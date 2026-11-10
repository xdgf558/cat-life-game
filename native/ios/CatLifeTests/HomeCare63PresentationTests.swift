import XCTest
@testable import CatLife

final class HomeCare63PresentationTests: XCTestCase {
    func testMissingFoodStillHighlightsFeedWhileHospitalHasItsOwnEntry() {
        XCTAssertEqual(CatNeed.current(satiety: 49, cleanliness: 0, mood: 0, hasFood: false)?.careButtonID, "feedButton")
        XCTAssertEqual(CatNeed.food.careButtonID, CatNeed.buyFood.careButtonID)
        XCTAssertEqual(CatNeed.food.shortTitleKey, CatNeed.buyFood.shortTitleKey)
        XCTAssertEqual(CatNeed.clean.careButtonID, "cleanButton")
        XCTAssertEqual(CatNeed.play.careButtonID, "playButton")
        XCTAssertEqual(CatNeed.current(satiety: 0, cleanliness: 0, mood: 0, hasFood: false, isIll: true), .hospital)
        XCTAssertEqual(CatNeed.current(satiety: 100, cleanliness: 100, mood: 100, hasFood: true, isIll: true), .hospital)
        XCTAssertNil(CatNeed.hospital.careButtonID, "A hospital need must not falsely highlight an ordinary care action.")
    }

    func testStageEdgesAndBottomCapsuleBoundTheEntireBubble() {
        let bubble = CGSize(width: 174, height: 54)
        for canvas in [CGSize(width: 355, height: 290), CGSize(width: 382, height: 496)] {
            let usable = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height - 76)
            for anchor in [CGPoint(x: -20, y: -20), CGPoint(x: canvas.width / 2, y: canvas.height / 2),
                           CGPoint(x: canvas.width + 20, y: canvas.height + 20)] {
                let center = CatNeedBubbleLayout.position(above: anchor, in: canvas, bubbleSize: bubble)
                let frame = CGRect(x: center.x - bubble.width / 2, y: center.y - bubble.height / 2,
                                   width: bubble.width, height: bubble.height)
                XCTAssertTrue(usable.contains(frame), "The stage owns both the marker and its view-control clearance.")
            }
        }
    }

    func testNamePlateAndNeedBubbleKeepTheirTailNearTheSameMovingHead() {
        let canvas = CGSize(width: 355, height: 420)
        for size in [CGSize(width: 80, height: 24), CGSize(width: 174, height: 54)] {
            let first = CGPoint(x: 150, y: 180)
            let moved = CGPoint(x: 172, y: 202)
            let a = CatNeedBubbleLayout.position(above: first, in: canvas, bubbleSize: size)
            let b = CatNeedBubbleLayout.position(above: moved, in: canvas, bubbleSize: size)
            XCTAssertEqual(a.x, first.x)
            XCTAssertEqual(a.y + size.height / 2 + 6, first.y)
            XCTAssertEqual(b.x - a.x, moved.x - first.x)
            XCTAssertEqual(b.y - a.y, moved.y - first.y)
        }
    }
}
