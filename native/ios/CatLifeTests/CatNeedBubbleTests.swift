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

    func testBubbleAvoidsHeaderAndLowerHUDWhileKeepingItsHeadOffset() {
        let size = CGSize(width: 390, height: 758)
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: 195, y: 350), in: size),
                       CGPoint(x: 195, y: 314))
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: -10, y: -10), in: size),
                       CGPoint(x: 100, y: 100))
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: 900, y: 900), in: size),
                       CGPoint(x: 290, y: 558))
    }

    func testBubbleBoundsRemainValidDuringTinyLayoutTransitions() {
        XCTAssertEqual(CatNeedBubbleLayout.position(above: CGPoint(x: 500, y: 500),
                                                    in: CGSize(width: 120, height: 160)),
                       CGPoint(x: 60, y: 80))
        XCTAssertEqual(CatNeedBubbleLayout.position(above: .zero, in: .zero), .zero)
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

    func testBottomCardMovesAboveTheCatAndRestoresWhenItsRegionIsClear() {
        let viewport = CGSize(width: 375, height: 583)
        let full = RoomCatStatusLayout.frame(in: viewport, compact: false).offsetBy(dx: 0, dy: 20)
        let lowCat = CGRect(x: 140, y: 430, width: 130, height: 150)
        XCTAssertTrue(RoomCatStatusLayout.shouldCompact(catFrame: lowCat, fullCard: full))
        let compact = RoomCatStatusLayout.frame(in: viewport, compact: true).offsetBy(dx: 0, dy: 20)
        XCTAssertFalse(compact.intersects(lowCat))
        XCTAssertFalse(RoomCatStatusLayout.shouldCompact(catFrame: CGRect(x: 150, y: 230, width: 100, height: 130),
                                                         fullCard: full))
        XCTAssertTrue(RoomCatStatusLayout.shouldCompact(catFrame: nil, fullCard: full),
                      "An unmeasured cat must not flash behind the large card during initial layout.")
    }

    func testCardAvoidanceIncludesMarginBeforeTheNextFrameSample() {
        let full = RoomCatStatusLayout.frame(in: CGSize(width: 390, height: 700), compact: false)
        let approachingCat = CGRect(x: 140, y: full.minY - 103, width: 100, height: 100)
        XCTAssertFalse(full.intersects(approachingCat))
        XCTAssertTrue(RoomCatStatusLayout.shouldCompact(catFrame: approachingCat, fullCard: full))
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

    func testCardHysteresisPreventsIdleBoundaryJitter() {
        let full = RoomCatStatusLayout.frame(in: CGSize(width: 390, height: 700), compact: false)
        let near = CGRect(x: 140, y: full.minY - 113, width: 100, height: 100)
        XCTAssertFalse(RoomCatStatusLayout.shouldCompact(catFrame: near, fullCard: full, wasCompact: false))
        XCTAssertTrue(RoomCatStatusLayout.shouldCompact(catFrame: near, fullCard: full, wasCompact: true))
        let closer = near.offsetBy(dx: 0, dy: 2)
        XCTAssertTrue(RoomCatStatusLayout.shouldCompact(catFrame: closer, fullCard: full, wasCompact: false))
        let clear = near.offsetBy(dx: 0, dy: -17)
        XCTAssertFalse(RoomCatStatusLayout.shouldCompact(catFrame: clear, fullCard: full, wasCompact: true))
    }

}
