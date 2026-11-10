import XCTest
@testable import CatLife

final class CatNeedBubbleTests: XCTestCase {
    func testCompactStatusCardClearsTheMeasuredHeaderWithoutChangingItsWidth() {
        for size in [CGSize(width: 375, height: 603), CGSize(width: 402, height: 800)] {
            let original = RoomCatStatusLayout.frame(in: size, compact: true, sharedControls: true)
            let measured = RoomCatStatusLayout.frame(in: size, compact: true, sharedControls: true, headerBottom: 260)
            XCTAssertGreaterThanOrEqual(measured.minY, 272)
            XCTAssertEqual(measured.width, original.width)
            XCTAssertTrue(CGRect(origin: .zero, size: size).contains(measured))
        }
    }

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

    func testBubbleMovesBesideMeasuredStairsWithoutCoveringTheirHitTarget() {
        for canvas in [CGSize(width: 375, height: 603), CGSize(width: 430, height: 850)] {
            let stairs = RoomStairLandingLayout.frame(size: CGSize(width: 76, height: 106), canvas: canvas)
            XCTAssertEqual(stairs.minX, canvas.width - 88)
            XCTAssertEqual(stairs.minY, RoomStairLandingLayout.topInset)
            let anchor = CGPoint(x: canvas.width - 75, y: 344)
            for height: CGFloat in [44, 80, 140] {
                let bubble = CGSize(width: 190, height: height)
                let result = CatNeedBubbleLayout.position(above: anchor, in: canvas,
                                                         bubbleSize: bubble, avoiding: stairs)
                let frame = CGRect(x: result.x - bubble.width / 2, y: result.y - bubble.height / 2,
                                   width: bubble.width, height: bubble.height)
                XCTAssertFalse(frame.intersects(stairs.insetBy(dx: -7, dy: -7)))
                XCTAssertTrue(CGRect(origin: .zero, size: canvas).contains(frame))
                XCTAssertLessThan(result.x, stairs.minX)
                XCTAssertEqual(result.y, anchor.y - 36, "Sideways avoidance keeps the bubble above its cat.")
            }
        }
    }

    func testWideStairCardUsesVerticalSpaceAndClearAnchorsDoNotMove() {
        let canvas = CGSize(width: 375, height: 603)
        let stairs = RoomStairLandingLayout.frame(size: CGSize(width: 183, height: 106), canvas: canvas)
        XCTAssertEqual(RoomStairLandingLayout.frame(size: .zero, canvas: canvas), .zero)
        let bubble = CGSize(width: 190, height: 80)
        let result = CatNeedBubbleLayout.position(above: CGPoint(x: 290, y: 344), in: canvas,
                                                 bubbleSize: bubble, avoiding: stairs)
        let frame = CGRect(x: result.x - 95, y: result.y - 40, width: 190, height: 80)
        XCTAssertFalse(frame.intersects(stairs.insetBy(dx: -7, dy: -7)))
        XCTAssertTrue(CGRect(origin: .zero, size: canvas).contains(frame))
        let clear = CGPoint(x: 150, y: 180)
        XCTAssertEqual(CatNeedBubbleLayout.position(above: clear, in: canvas, avoiding: stairs),
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

    func testSharedHomeCompactCardLeavesTheFullWidthFloorControlsClear() {
        let viewport = CGSize(width: 375, height: 583)
        let card = RoomCatStatusLayout.frame(in: viewport, compact: true, sharedControls: true)
        XCTAssertGreaterThanOrEqual(card.minY, 218)
        XCTAssertGreaterThanOrEqual(card.height, 72, "The explicit care target can wrap a long cat name onto two lines.")
        XCTAssertFalse(card.intersects(CGRect(x: 14, y: 160, width: 347, height: 50)))
        let upstairs = RoomStairLandingLayout.frame(size: CGSize(width: 76, height: 88), canvas: viewport, floor: .upper, top: card.maxY + 28)
        XCTAssertEqual(upstairs.minX, 12)
        XCTAssertGreaterThanOrEqual(upstairs.minY, card.maxY + 20 + 8)
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
