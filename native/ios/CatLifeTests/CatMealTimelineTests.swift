import SpriteKit
import UIKit
import XCTest
@testable import CatLife

final class CatMealTimelineTests: XCTestCase {
    @MainActor
    func testMealFinishesAtBowlBeforeWithdrawalAndOnlyOnce() async throws {
        let playback = try Playback()
        defer { playback.close() }
        let cat = playback.cat
        let finished = expectation(description: "The whole meal and withdrawal finish")
        var mealCount = 0
        var completionCount = 0
        var positionWhenMealFinished: CGPoint?
        cat.feed(at: playback.food, facing: 1, approach: [playback.home, playback.stage],
                 dockingPath: [playback.stage, playback.food], returnPath: [playback.stage, playback.home],
                 onMealFinished: {
                     mealCount += 1
                     positionWhenMealFinished = cat.position
                     XCTAssertTrue(cat.isPerforming)
                     XCTAssertTrue(cat.isDockingForMeal)
                     XCTAssertEqual(completionCount, 0)
                 }, completion: {
                     completionCount += 1
                     finished.fulfill()
                 })

        let result = await XCTWaiter.fulfillment(of: [finished], timeout: 8)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(positionWhenMealFinished, playback.food)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(cat.position, playback.home)
        XCTAssertEqual(mealCount, 1)
        XCTAssertFalse(cat.isPerforming)
        XCTAssertFalse(cat.isDockingForMeal)
    }

    @MainActor
    func testCancelledMealDoesNotEmitAStaleMealFinishedEvent() async throws {
        let playback = try Playback()
        defer { playback.close() }
        let cat = playback.cat
        var mealCount = 0
        var completionCount = 0
        cat.feed(at: playback.food, facing: 1, approach: [playback.home, playback.stage],
                 dockingPath: [playback.stage, playback.food], returnPath: [playback.stage, playback.home],
                 onMealFinished: { mealCount += 1 }, completion: { completionCount += 1 })
        try await playback.waitUntilDocking()
        cat.cancelAndSettle(at: playback.stage)
        let nextFinished = expectation(description: "A replacement meal completes after cancellation")
        var nextMealCount = 0
        cat.feed(at: playback.food, facing: 1, approach: [playback.stage],
                 dockingPath: [playback.stage, playback.food], returnPath: [playback.stage, playback.home],
                 onMealFinished: { nextMealCount += 1 }, completion: { nextFinished.fulfill() })
        let result = await XCTWaiter.fulfillment(of: [nextFinished], timeout: 8)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(mealCount, 0)
        XCTAssertEqual(nextMealCount, 1)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(cat.position, playback.home)
    }

    @MainActor
    func testReducedMotionEndsMealAfterCalmResponseWithoutWalking() async throws {
        let playback = try Playback(speed: 1)
        defer { playback.close() }
        let cat = playback.cat
        cat.reducedMotion = true
        let finished = expectation(description: "Reduced motion ends the short meal response")
        let started = Date()
        var events: [String] = []
        cat.feed(at: playback.food, facing: 1, approach: [playback.home, playback.stage],
                 dockingPath: [playback.stage, playback.food], returnPath: [playback.stage, playback.home],
                 onMealFinished: {
                     XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.25)
                     events.append("meal")
                 }, completion: {
                     events.append("complete")
                     finished.fulfill()
                 })
        XCTAssertTrue(events.isEmpty)
        let result = await XCTWaiter.fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(events, ["meal", "complete"])
        XCTAssertEqual(cat.position, playback.home)
    }

    @MainActor
    func testInvalidApproachDoesNotClaimToHaveFinishedEating() async throws {
        let playback = try Playback()
        defer { playback.close() }
        let cat = playback.cat
        let finished = expectation(description: "Invalid route settles without eating")
        var mealCount = 0
        var completionCount = 0
        cat.feed(at: playback.food, facing: 1, approach: [playback.stage],
                 dockingPath: [playback.stage, playback.food], returnPath: [playback.stage, playback.home],
                 onMealFinished: { mealCount += 1 }, completion: {
                     completionCount += 1
                     finished.fulfill()
                 })
        let result = await XCTWaiter.fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(result, .completed)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(mealCount, 0)
        XCTAssertEqual(cat.position, playback.home)
    }
}

/// A separate visible SKView supplies SpriteKit's real frame clock; the game's window is untouched.
@MainActor
private final class Playback {
    let cat = CatActor()
    let home = CGPoint(x: 80, y: 100)
    let stage = CGPoint(x: 100, y: 100)
    let food = CGPoint(x: 120, y: 100)
    private let window: UIWindow
    private let view: SKView

    init(speed: CGFloat = 4) throws {
        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.coordinateSpace.bounds
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        view = SKView(frame: window.bounds)
        view.preferredFramesPerSecond = 60
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        let scene = SKScene(size: view.bounds.size)
        cat.setIdleEnabled(false)
        cat.speed = speed
        cat.position = home
        scene.addChild(cat)
        view.presentScene(scene)
        window.isHidden = false
    }

    func waitUntilDocking() async throws {
        let deadline = Date().addingTimeInterval(4)
        while !cat.isDockingForMeal && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(cat.isDockingForMeal, "The displayed SpriteKit scene must advance to the bowl.")
    }

    func close() {
        cat.removeAllActions()
        view.presentScene(nil)
        window.isHidden = true
        window.rootViewController = nil
    }
}
