import Foundation
import XCTest
@testable import CatLife

final class RoomViewCameraTests: XCTestCase {
    @MainActor
    func testFitKeepsEveryProjectedBoundaryInsideUsableViewport() {
        let bounds = CGRect(x: -640, y: -320, width: 1280, height: 960)
        for viewport in viewports {
            let usable = usableRect(in: viewport)
            let camera = RoomViewCamera()
            camera.configure(bounds: bounds, viewport: viewport, usableRect: usable, worldScale: 2, reset: true)
            XCTAssertTrue(camera.isWholeRoom)
            XCTAssertEqual(camera.viewportSize, viewport)
            XCTAssertEqual(camera.fitScale, max(bounds.width / usable.width, bounds.height / usable.height))
            let center = camera.viewPoint(projectedWorld: camera.center)
            XCTAssertEqual(center.x, usable.midX, accuracy: 0.0001)
            XCTAssertEqual(center.y, usable.midY, accuracy: 0.0001)
            for point in [CGPoint(x: bounds.minX, y: bounds.minY), CGPoint(x: bounds.maxX, y: bounds.minY),
                          CGPoint(x: bounds.minX, y: bounds.maxY), CGPoint(x: bounds.maxX, y: bounds.maxY)] {
                let projected = camera.viewPoint(projectedWorld: point)
                XCTAssertGreaterThanOrEqual(projected.x, usable.minX - 0.0001)
                XCTAssertLessThanOrEqual(projected.x, usable.maxX + 0.0001)
                XCTAssertGreaterThanOrEqual(projected.y, usable.minY - 0.0001)
                XCTAssertLessThanOrEqual(projected.y, usable.maxY + 0.0001)
                let restored = camera.worldPoint(viewPoint: projected)
                XCTAssertEqual(restored.x, point.x, accuracy: 0.0001)
                XCTAssertEqual(restored.y, point.y, accuracy: 0.0001)
            }
        }
    }

    @MainActor
    func testPinchKeepsProjectedWorldAnchorUnderMovingMidpoint() {
        let camera = RoomViewCamera()
        camera.configure(bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000),
                         viewport: CGSize(width: 400, height: 600),
                         usableRect: CGRect(x: 20, y: 100, width: 360, height: 400), worldScale: 2, reset: true)
        camera.focus(on: .zero)
        let origin = CGPoint(x: 180, y: 280)
        let anchor = camera.worldPoint(viewPoint: origin)
        let before = camera.center
        camera.beginPinch(at: origin)
        XCTAssertTrue(camera.isPinching)
        XCTAssertEqual(camera.center, before)
        for (factor, midpoint): (CGFloat, CGPoint) in [
            (1.4, CGPoint(x: 195, y: 310)), (1.8, CGPoint(x: 210, y: 325))
        ] {
            camera.changePinch(factor: factor, at: midpoint)
            let projected = camera.viewPoint(projectedWorld: anchor)
            XCTAssertEqual(projected.x, midpoint.x, accuracy: 0.0001)
            XCTAssertEqual(projected.y, midpoint.y, accuracy: 0.0001)
        }
        camera.endPinch()
        XCTAssertFalse(camera.isPinching)
        let ended = camera.center
        camera.changePinch(factor: 2, at: .zero)
        XCTAssertEqual(camera.center, ended)
    }

    @MainActor
    func testInvalidScalesAndCoordinatesPreserveValidCameraState() {
        let camera = RoomViewCamera()
        let viewport = CGSize(width: 400, height: 600)
        let usable = CGRect(x: 10, y: 80, width: 380, height: 440)
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        camera.configure(bounds: bounds, viewport: viewport, usableRect: usable, worldScale: 2, reset: true)
        camera.focus(on: CGPoint(x: bounds.midX, y: bounds.midY))
        camera.beginPinch(at: CGPoint(x: usable.midX, y: usable.midY))
        let before = camera.center, scale = camera.scale
        let invalid: [CGFloat] = [0, -1, .nan, .infinity, -.infinity]
        for value in invalid {
            camera.changePinch(factor: value, at: .zero)
            camera.zoom(by: value)
            XCTAssertEqual(camera.center, before)
            XCTAssertEqual(camera.scale, scale)
        }
        camera.focus(on: CGPoint(x: CGFloat.nan, y: 0))
        camera.changePinch(factor: 1, at: CGPoint(x: 0, y: CGFloat.infinity))
        XCTAssertEqual(camera.center, before)
        XCTAssertEqual(camera.scale, scale)
        camera.configure(bounds: .zero, viewport: .zero, usableRect: .zero, worldScale: .nan, reset: true)
        XCTAssertEqual(camera.center, before)
        XCTAssertEqual(camera.scale, scale)
        for value in invalid {
            camera.configure(bounds: bounds, viewport: viewport, usableRect: usable, worldScale: value, reset: true)
            camera.zoom(by: 100)
            XCTAssertEqual(camera.scale, camera.fitScale * 0.625, accuracy: 0.0001)
            XCTAssertTrue(camera.center.x.isFinite && camera.center.y.isFinite)
        }
    }

    @MainActor
    func testPanThresholdAndClampingDoNotExposeWorldOutsideBoundsAcrossScreens() {
        let bounds = CGRect(x: -750, y: -600, width: 1500, height: 1200)
        for viewport in viewports {
            let camera = RoomViewCamera()
            let usable = usableRect(in: viewport)
            camera.configure(bounds: bounds, viewport: viewport, usableRect: usable, worldScale: 2, reset: true)
            camera.zoom(by: 100)
            XCTAssertEqual(camera.scale, camera.fitScale / 2 * 0.625, accuracy: 0.0001)
            let before = camera.center
            camera.beginPan(at: .zero)
            XCTAssertFalse(camera.changePan(to: CGPoint(x: 6, y: 0)))
            XCTAssertEqual(camera.center, before)
            XCTAssertTrue(camera.changePan(to: CGPoint(x: 8, y: 0)))
            for point in [CGPoint(x: 100_000, y: -100_000), CGPoint(x: -100_000, y: 100_000)] {
                XCTAssertTrue(camera.changePan(to: point))
                let visible = camera.visibleRect
                XCTAssertGreaterThanOrEqual(visible.minX, bounds.minX - 0.0001)
                XCTAssertLessThanOrEqual(visible.maxX, bounds.maxX + 0.0001)
                XCTAssertGreaterThanOrEqual(visible.minY, bounds.minY - 0.0001)
                XCTAssertLessThanOrEqual(visible.maxY, bounds.maxY + 0.0001)
            }
            XCTAssertTrue(camera.endPan())
            XCTAssertFalse(camera.endPan())
            camera.zoom(by: 0.001)
            XCTAssertTrue(camera.isWholeRoom)
        }
    }

    @MainActor
    func testResizePreservesRelativeZoomAndResetReturnsToFit() {
        let camera = RoomViewCamera()
        let bounds = CGRect(x: 0, y: 0, width: 2000, height: 2000)
        let original = CGSize(width: 400, height: 600)
        camera.configure(bounds: bounds, viewport: original, usableRect: usableRect(in: original), worldScale: 2, reset: true)
        camera.zoom(by: 1.5)
        let relativeZoom = camera.scale / camera.fitScale
        camera.beginPinch(at: CGPoint(x: 200, y: 300))
        let resized = CGSize(width: 800, height: 600)
        camera.configure(bounds: bounds, viewport: resized, usableRect: usableRect(in: resized), worldScale: 2, reset: false)
        XCTAssertFalse(camera.isPinching)
        XCTAssertEqual(camera.scale / camera.fitScale, relativeZoom, accuracy: 0.0001)
        camera.configure(bounds: bounds, viewport: resized, usableRect: usableRect(in: resized), worldScale: 2, reset: true)
        XCTAssertTrue(camera.isWholeRoom)
        camera.focus(on: CGPoint(x: 500, y: 500))
        XCTAssertEqual(camera.scale, camera.fitScale / 2, accuracy: 0.0001)
        XCTAssertFalse(camera.isWholeRoom)
        camera.fit()
        XCTAssertTrue(camera.isWholeRoom)
    }

    @MainActor
    func testFollowPreservesZoomAndLeavesWholeRoomAndGesturesAlone() {
        let camera = RoomViewCamera()
        camera.configure(bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000),
                         viewport: CGSize(width: 400, height: 600),
                         usableRect: CGRect(x: 20, y: 100, width: 360, height: 400), worldScale: 2, reset: true)
        camera.follow(CGPoint(x: 800, y: 800))
        XCTAssertEqual(camera.center, .zero)
        XCTAssertTrue(camera.isWholeRoom)
        camera.focus(on: .zero)
        let scale = camera.scale
        let point = CGPoint(x: 600, y: 600)
        camera.follow(point)
        XCTAssertEqual(camera.scale, scale)
        XCTAssertEqual(camera.center.x, point.x - camera.visibleRect.width * 0.3, accuracy: 0.0001)
        XCTAssertEqual(camera.center.y, point.y - camera.visibleRect.height * 0.3, accuracy: 0.0001)
        let followed = camera.center
        camera.beginPan(at: .zero)
        camera.follow(CGPoint(x: -600, y: -600))
        XCTAssertEqual(camera.center, followed)
        camera.endPan()
        camera.beginPinch(at: CGPoint(x: 200, y: 300))
        camera.follow(CGPoint(x: -600, y: -600))
        XCTAssertEqual(camera.center, followed)
    }

    @MainActor
    func testLevelOneFocusLeavesWholeRoomAtCloseScale() {
        let camera = RoomViewCamera()
        camera.configure(bounds: CGRect(x: -1000, y: -1000, width: 2000, height: 2000),
                         viewport: CGSize(width: 400, height: 600),
                         usableRect: CGRect(x: 20, y: 100, width: 360, height: 400), worldScale: 1, reset: true)
        XCTAssertTrue(camera.isWholeRoom)
        camera.focus(on: .zero)
        XCTAssertEqual(camera.scale, camera.fitScale / 1.6, accuracy: 0.0001)
        XCTAssertFalse(camera.isWholeRoom)
    }

    @MainActor
    func testFurnitureEdgeScrollUsesUsableViewportCapsTimeAndStopsAtBoundsOrPinch() {
        let camera = RoomViewCamera()
        let bounds = CGRect(x: -1000, y: -1000, width: 2000, height: 2000)
        let usable = CGRect(x: 20, y: 100, width: 360, height: 400)
        camera.configure(bounds: bounds, viewport: CGSize(width: 400, height: 600),
                         usableRect: usable, worldScale: 2, reset: true)
        camera.focus(on: .zero)
        let edge = CGPoint(x: usable.minX, y: usable.midY)
        XCTAssertFalse(camera.scrollNearEdge(at: CGPoint(x: usable.midX, y: usable.midY), delta: 1))
        XCTAssertTrue(camera.scrollNearEdge(at: edge, delta: 1))
        XCTAssertEqual(camera.center.x, -100 / 15 * camera.scale, accuracy: 0.0001)
        XCTAssertEqual(camera.center.y, 0)
        let before = camera.center
        camera.beginPinch(at: CGPoint(x: usable.midX, y: usable.midY))
        XCTAssertFalse(camera.scrollNearEdge(at: edge, delta: 1))
        XCTAssertEqual(camera.center, before)
        camera.endPinch()
        camera.focus(on: CGPoint(x: bounds.minX, y: bounds.midY))
        XCTAssertFalse(camera.scrollNearEdge(at: edge, delta: 1))
        XCTAssertEqual(camera.visibleRect.minX, bounds.minX, accuracy: 0.0001)
        XCTAssertFalse(camera.scrollNearEdge(at: edge, delta: .nan))
        XCTAssertFalse(camera.scrollNearEdge(at: edge, delta: -1))
    }

    @MainActor
    func testOversizedVisibleAxisRemainsCentered() {
        let camera = RoomViewCamera()
        let bounds = CGRect(x: -200, y: -50, width: 400, height: 100)
        camera.configure(bounds: bounds, viewport: CGSize(width: 400, height: 800),
                         usableRect: CGRect(x: 20, y: 100, width: 360, height: 600), worldScale: 2, reset: true)
        camera.focus(on: CGPoint(x: 100_000, y: 100_000))
        XCTAssertGreaterThan(camera.visibleRect.height, bounds.height)
        XCTAssertEqual(camera.center.y, bounds.midY)
        XCTAssertLessThanOrEqual(camera.visibleRect.maxX, bounds.maxX + 0.0001)
        camera.beginPan(at: .zero)
        camera.changePan(to: CGPoint(x: -100_000, y: -100_000))
        camera.cancelGestures()
        XCTAssertFalse(camera.endPan())
        XCTAssertEqual(camera.center.y, bounds.midY)
    }

    private var viewports: [CGSize] {
        [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844),
         CGSize(width: 430, height: 932), CGSize(width: 1024, height: 768)]
    }

    private func usableRect(in viewport: CGSize) -> CGRect {
        CGRect(x: 12, y: 90, width: viewport.width - 24, height: viewport.height - 220)
    }
}
