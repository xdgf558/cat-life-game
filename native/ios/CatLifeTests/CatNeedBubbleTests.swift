import XCTest
@testable import CatLife

final class CatNeedBubbleTests: XCTestCase {
    func testNeedsUseExactThresholdsAndFoodHasPriority() {
        XCTAssertEqual(CatNeed.current(satiety: 49, cleanliness: 0, mood: 0, hasFood: true), .food)
        XCTAssertEqual(CatNeed.current(satiety: 49, cleanliness: 0, mood: 0, hasFood: false), .buyFood)
        XCTAssertEqual(CatNeed.current(satiety: 50, cleanliness: 39, mood: 0, hasFood: false), .clean)
        XCTAssertEqual(CatNeed.current(satiety: 50, cleanliness: 40, mood: 44, hasFood: false), .play)
        XCTAssertNil(CatNeed.current(satiety: 50, cleanliness: 40, mood: 45, hasFood: false))
    }

    func testAnchorSamplerLimitsUpdatesAndIgnoresIdleJitter() {
        var sampler = CatNeedAnchorSampler()
        XCTAssertTrue(sampler.sample(CGPoint(x: 100, y: 100), at: 0))
        XCTAssertFalse(sampler.sample(CGPoint(x: 110, y: 100), at: 0.05))
        XCTAssertEqual(sampler.point, CGPoint(x: 100, y: 100))
        XCTAssertFalse(sampler.sample(CGPoint(x: 101, y: 100), at: 0.11))
        XCTAssertTrue(sampler.sample(CGPoint(x: 102, y: 100), at: 0.22))
        XCTAssertEqual(sampler.point, CGPoint(x: 102, y: 100))
        XCTAssertTrue(sampler.sample(nil, at: 0.33))
        XCTAssertNil(sampler.point)
        XCTAssertFalse(sampler.sample(nil, at: 0.44))
        XCTAssertTrue(sampler.sample(CGPoint(x: 102, y: 100), at: 0.55))
    }

    func testRestartedSpriteKitClockCanPublishAgain() {
        var sampler = CatNeedAnchorSampler()
        XCTAssertTrue(sampler.sample(CGPoint(x: 100, y: 100), at: 50))
        XCTAssertTrue(sampler.sample(CGPoint(x: 110, y: 100), at: 0))
        XCTAssertEqual(sampler.point, CGPoint(x: 110, y: 100))
    }

    func testBubbleFitsTheStageAndLeavesTheBottomViewControlsClear() {
        let size = CGSize(width: 390, height: 758)
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: 195, y: 350), in: size),
                       CGPoint(x: 195, y: 322))
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: -10, y: -10), in: size),
                       CGPoint(x: 103, y: 30))
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: 900, y: 900), in: size),
                       CGPoint(x: 287, y: 652))
    }

    func testBubbleBoundsRemainValidDuringTinyLayoutTransitions() {
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: 500, y: 500),
                                                    in: CGSize(width: 120, height: 160)),
                       CGPoint(x: 60, y: 54))
        XCTAssertEqual(CatNeedBubbleLayout.position(above: .zero, in: .zero), .zero)
    }

    func testBubbleClearsMeasuredViewControlsAcrossSizesAndHeights() {
        for canvas in [CGSize(width: 375, height: 603), CGSize(width: 430, height: 850)] {
            let controls = RoomStageLayout.controlsFrame(in: canvas)
            let anchor = CGPoint(x: controls.midX, y: controls.midY)
            for height: CGFloat in [44, 80, 140] {
                let bubble = CGSize(width: 190, height: height)
                let result = CatNeedBubbleLayout.position(above: anchor, in: canvas,
                    bubbleSize: bubble, avoiding: controls, bottomInset: 0)
                let frame = CGRect(x: result.x - bubble.width / 2, y: result.y - bubble.height / 2,
                                   width: bubble.width, height: bubble.height)
                XCTAssertFalse(frame.intersects(controls.insetBy(dx: -7, dy: -7)))
                XCTAssertTrue(CGRect(origin: .zero, size: canvas).contains(frame))
                XCTAssertLessThan(frame.maxY, controls.minY)
            }
        }
    }

    func testOffscreenBubbleClearsViewControlsAndClearAnchorsDoNotMove() {
        let canvas = CGSize(width: 375, height: 603)
        let controls = RoomStageLayout.controlsFrame(in: canvas)
        let bubble = CGSize(width: 190, height: 80)
        let result = CatNeedBubbleLayout.position(above: CGPoint(x: 900, y: 900), in: canvas,
            bubbleSize: bubble, avoiding: controls, bottomInset: 0)
        let frame = CGRect(x: result.x - 95, y: result.y - 40, width: 190, height: 80)
        XCTAssertFalse(frame.intersects(controls.insetBy(dx: -7, dy: -7)))
        XCTAssertTrue(CGRect(origin: .zero, size: canvas).contains(frame))
        let clear = CGPoint(x: 150, y: 180)
        XCTAssertEqual(CatNeedBubbleLayout.position(above: clear, in: canvas, avoiding: controls),
                       CatNeedBubbleLayout.position(above: clear, in: canvas))
    }

    func testVisualFrameSamplerIncludesZoomSizeChangesAndHidesOnlyWhenAbsent() {
        var sampler = CatVisualFrameSampler()
        let idle = CGRect(x: 140, y: 430, width: 100, height: 120)
        XCTAssertTrue(sampler.sample(idle, at: 0))
        let zoomed = CGRect(x: 140, y: 430, width: 120, height: 144)
        XCTAssertFalse(sampler.sample(zoomed, at: 0.05))
        XCTAssertTrue(sampler.sample(zoomed, at: 0.11))
        XCTAssertEqual(sampler.frame, zoomed)
        XCTAssertFalse(sampler.sample(zoomed.offsetBy(dx: 0.5, dy: 0.5), at: 0.22))
        XCTAssertTrue(sampler.sample(zoomed.offsetBy(dx: -10, dy: -10), at: 0.33))
        XCTAssertTrue(sampler.sample(nil, at: 0.44))
        XCTAssertNil(sampler.frame)
    }

    @MainActor
    func testSharedFrameUsesCanvasOriginToBridgeSafeAreaCoordinates() {
        let presentation = CatNeedPresentation()
        presentation.canvasOrigin = CGPoint(x: 0, y: 59)
        presentation.localCatFrame = CGRect(x: 120, y: 380, width: 90, height: 110)
        XCTAssertEqual(presentation.catFrame, CGRect(x: 120, y: 439, width: 90, height: 110))
        presentation.canvasOrigin = .zero
        XCTAssertEqual(presentation.catFrame, presentation.localCatFrame)
    }

}
