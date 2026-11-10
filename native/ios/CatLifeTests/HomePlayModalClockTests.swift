import XCTest
import SwiftUI
import SpriteKit
import UIKit
import CatGameCore
@testable import CatLife

@MainActor
final class HomePlayModalClockTests: XCTestCase {
    func testPlayChoicesAndTogetherCoverPauseTheRealHomeClockAndResumeWithoutSpending() async throws {
        var seed = GameSnapshot.fresh()
        seed.catPlay.introDismissed = true
        seed.inventory.toys = 0
        seed.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
        let suite = "CatLife-home-modal-clock-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let store = GameStore(repository: HomeModalClockRepository(seed), reminderDefaults: defaults)
        await store.load()
        store.enterHome()
        store.setForeground(true)

        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: windowScene)
        let host = UIHostingController(rootView: RoomHomeView(store: store).environment(\.scenePhase, .active))
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.makeKeyAndVisible()
        defer {
            store.showsPlayChoices = false
            store.isShowingPlayTogether = false
            store.setForeground(false)
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        defer {
            if !store.roomFloorTravelReady {
                let states = spriteViews(in: host.view).map { "attached=\($0.window != nil), paused=\($0.isPaused), scene=\(String(describing: type(of: $0.scene)))" }
                let evidence = XCTAttachment(string: "entered=\(store.hasEnteredHome), busy=\(store.isBusy), onboarding=\(store.onboarding.isPresented), canOpen=\(store.canOpenPlayTogether); \(states)")
                evidence.name = "Hosted home clock readiness"; evidence.lifetime = .keepAlways; add(evidence)
            }
        }
        try await eventually("The actual home SKView must be attached and ready.") {
            self.spriteViews(in: host.view).contains { $0.scene is RoomScene && $0.window != nil }
                && store.canOpenPlayTogether && !store.isBusy
        }
        let canvas = try XCTUnwrap(spriteViews(in: host.view).first { $0.scene is RoomScene })
        let scene = try XCTUnwrap(canvas.scene as? RoomScene)
        let counter = HomeClockCounter()
        let probe = SKNode()
        scene.addChild(probe)
        probe.run(.repeatForever(.sequence([.wait(forDuration: 0.05), .run { counter.ticks += 1 }])), withKey: "home-clock-probe")
        defer { probe.removeAllActions(); probe.removeFromParent() }
        try await eventually("The probe must first advance on real SpriteKit frames.") { counter.ticks >= 3 }
        let before = try XCTUnwrap(store.snapshot)

        store.presentPlayChoices()
        try await eventually("The real choice dialog must pause both home clock owners.") {
            host.presentedViewController != nil && store.showsPlayChoices && canvas.isPaused && scene.isPaused
        }
        let dialogTicks = counter.ticks
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(counter.ticks, dialogTicks, "A paused home must not advance actions behind the choice dialog.")
        store.showsPlayChoices = false
        try await eventually("Closing choices must resume the same home scene.") {
            host.presentedViewController == nil && canvas.scene === scene && !canvas.isPaused && !scene.isPaused
                && store.canOpenPlayTogether
        }
        try await eventually("The home action clock must advance again after choices close.") { counter.ticks >= dialogTicks + 3 }

        let opened = await store.openPlayTogether()
        XCTAssertTrue(opened)
        let session = try XCTUnwrap(store.snapshot?.catPlay.activeSession)
        XCTAssertTrue(session.isTutorial, "Zero toys must still allow the free tutorial.")
        try await eventually("The real together cover must contain its separate scene while home is paused.") {
            guard let presented = host.presentedViewController else { return false }
            return self.spriteViews(in: presented.view).contains { $0.scene is CatPlayTogetherScene && $0.window != nil }
                && canvas.isPaused && scene.isPaused
        }
        let coverTicks = counter.ticks
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(counter.ticks, coverTicks, "Home actions must stay frozen under the actual together cover.")
        store.isShowingPlayTogether = false
        try await eventually("Closing an untouched tutorial must end its session and restore the retained home.") {
            host.presentedViewController == nil && canvas.scene === scene && !canvas.isPaused && !scene.isPaused
                && store.snapshot?.catPlay.activeSession == nil && !store.isBusy
        }
        try await eventually("The original home probe must resume after the cover closes.") { counter.ticks >= coverTicks + 3 }
        XCTAssertEqual(store.snapshot?.inventory, before.inventory)
        XCTAssertEqual(store.snapshot?.player.gold, before.player.gold)
        XCTAssertEqual(store.snapshot?.tasks, before.tasks)
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.id, session.id)
        XCTAssertEqual(store.snapshot?.catPlay.lastResult?.session.effects, CatPlayEffects())
        XCTAssertFalse(store.snapshot?.catPlay.tutorialCompleted ?? true)
    }

    private func spriteViews(in view: UIView) -> [SKView] {
        (view as? SKView).map { [$0] } ?? view.subviews.flatMap { spriteViews(in: $0) }
    }

    private func eventually(_ message: String, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail(message)
        throw CocoaError(.coderInvalidValue)
    }
}

private final class HomeClockCounter { var ticks = 0 }

private actor HomeModalClockRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var saved: GameSnapshot
    init(_ saved: GameSnapshot) { self.saved = saved }
    func loadOrCreate(now: Date) -> GameSnapshot { saved }
    func checkWritable() {}
    func save(_ value: GameSnapshot) { saved = value }
}
