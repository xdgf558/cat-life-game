import XCTest
import SpriteKit
import UIKit
import CatGameCore
@testable import CatLife

final class HabitPresentationTests: XCTestCase {
    @MainActor
    func testEveryCatShowsAPounceOnlyForItsMatchingRhythmWithRealSpriteKitFrames() async throws {
        for definition in CatHabitCatalog.all {
            let appearance = definition.id == CatCatalog.initialCatID ? CatAppearance.orange
                : CatCatalog.adoptionOffer(catID: definition.id)!.appearance
            let scene = CatPlayTogetherScene(appearance: appearance)
            scene.style = definition.style
            var state = GameSnapshot.fresh()
            state.cats = [CatState(id: definition.id, name: "Test", now: state.meta.lastSyncAt, appearance: appearance)]
            state.activeCatID = definition.id
            XCTAssertTrue(CatHabitEngine.beginPlay(&state, catID: definition.id).succeeded)
            let session = try XCTUnwrap(state.catPlay.activeSession)
            var sequence = 0
            var phase = "watching"
            scene.onMotion = { phase = $0 }
            scene.onInput = { kind, control, duration, movement in
                sequence += 1
                let outcome = CatHabitEngine.recordPlayInput(&state, catID: definition.id, sessionID: session.id,
                    report: .init(sequence: sequence, kind: kind, control: control, duration: duration, movementDuration: movement))
                XCTAssertTrue(outcome.succeeded)
                guard duration >= (kind == .moveAndPause ? CatHabitCatalog.pauseResponseDuration : CatHabitCatalog.responseDuration),
                      let rhythm = kind.rhythm, state.catPlay.activeSession?.observedRhythms.contains(rhythm) == true else { return }
                if rhythm == definition.play { scene.completeResponse() } else { scene.waitAndWatch() }
            }
            let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: windowScene)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 350, height: 280))
            let controller = UIViewController(); controller.view = view
            window.rootViewController = controller; window.windowLevel = .alert + 1
            scene.scaleMode = .aspectFit; view.presentScene(scene); window.isHidden = false
            defer { scene.stop(); view.presentScene(nil); window.isHidden = true; window.rootViewController = nil }
            let other: CatPlayRhythm = definition.play == .slowMove ? .moveAndPause : .slowMove
            scene.runControl(other)
            for _ in 0..<100 { scene.runControl(definition.play) }
            XCTAssertEqual(sequence, 1, "Repeated taps must not restart the running comparison or enqueue more saves.")
            try await waitForScene { state.catPlay.activeSession?.observedRhythms.contains(other) == true }
            XCTAssertEqual(sequence, 2, "One demonstration emits only its start and completed input reports.")
            XCTAssertEqual(scene.pounces, 0, "\(definition.id) must not pounce for its comparison rhythm.")
            XCTAssertEqual(state.cats[0].habits.playClueSessionIDs.count, 0)
            scene.runControl(definition.play)
            try await waitForScene { phase == "satisfied" }
            XCTAssertEqual(scene.pounces, 1)
            XCTAssertEqual(scene.actor.completedPounces, 1, "The pounce must reach actual landing frames, not just issue an animation request.")
            XCTAssertEqual(state.cats[0].habits.playClueSessionIDs.count, 1)
            XCTAssertTrue(state.catPlay.tutorialCompleted)
            XCTAssertEqual(state.catPlay.activeSession?.effects.toysSpent, 0)
            XCTAssertTrue(CGRect(origin: .zero, size: scene.size).insetBy(dx: -2, dy: -2).contains(scene.actor.visualFrame))
        }
    }

    @MainActor
    func testAllHabitKeysAreRegisteredWithMatchingFormatsInThreeLanguages() {
        let dictionaries = [GameStrings.catHabits63Chinese, GameStrings.catHabits63Traditional, GameStrings.catHabits63English]
        let registered = [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english]
        let keys = Set(dictionaries[0].keys)
        XCTAssertGreaterThan(keys.count, 80)
        for (index, dictionary) in dictionaries.enumerated() {
            XCTAssertEqual(Set(dictionary.keys), keys)
            for key in keys {
                XCTAssertFalse(dictionary[key]!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertEqual(registered[index][key], dictionary[key], "Every language must register \(key), not rely on a fallback.")
                XCTAssertEqual(formats(dictionary[key]!), formats(dictionaries[0][key]!))
            }
            for style in CatBehaviorStyle.allCases { XCTAssertNotNil(dictionary["catHabits.style.\(style.rawValue)"]) }
            for preference in CatRestPreference.allCases {
                XCTAssertNotNil(dictionary["catHabits.restConfirmed.\(preference.rawValue)"])
                for suffix in ["match", "compare"] { XCTAssertNotNil(dictionary["catHabits.restHint.\(preference.rawValue).\(suffix)"]) }
            }
            for rhythm in CatPlayRhythm.allCases {
                XCTAssertNotNil(dictionary["catHabits.control.\(rhythm.rawValue)"])
                XCTAssertNotNil(dictionary["catHabits.playConfirmed.\(rhythm.rawValue)"])
                for suffix in ["match", "compare"] { XCTAssertNotNil(dictionary["catHabits.playHint.\(rhythm.rawValue).\(suffix)"]) }
            }
            for memory in CatMemoryKind.allCases {
                XCTAssertNotNil(registered[index][memory.titleKey]); XCTAssertNotNil(registered[index][memory.bodyKey])
            }
        }
    }

    func testHabitPromptsStayInsideTheActualFreeHUDRectAtEveryAnchorAndTextHeight() {
        for width in [CGFloat(150), 240, 360] {
            for height in [CGFloat(90), 240, 400] {
                let bounds = CGRect(x: 12, y: 240, width: width, height: height)
                for x in [CGFloat(-400), 12, 180, 900] {
                    for y in [CGFloat(-200), 260, 500, 1600] {
                        let frame = HabitRoomPromptLayout.frame(above: CGRect(x: x, y: y, width: 70, height: 50),
                                                               within: bounds, height: 450)
                        XCTAssertTrue(bounds.contains(frame))
                        XCTAssertGreaterThanOrEqual(frame.width, 150)
                        XCTAssertLessThanOrEqual(frame.height, height)
                    }
                }
            }
        }
    }

    func testStudyLogDatesSurviveReopenAndClearCanRecoverADamagedLog() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HabitLog-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let log = HabitStudyLog(directory: directory)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        try await log.append(.init(event: "playInput", catID: "cat_001", sessionID: "session",
            detail: "slowMove", control: "tap", duration: 2, date: date))
        let reopened = HabitStudyLog(directory: directory)
        let exported = try await reopened.export()
        let entries = try JSONDecoder().decode([HabitStudyLog.Entry].self, from: exported)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].date, date)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
        let file = try XCTUnwrap(enumerator.allObjects.compactMap { $0 as? URL }.first { $0.lastPathComponent == "observations.json" })
        try Data("damaged".utf8).write(to: file)
        let damaged = HabitStudyLog(directory: directory)
        do { _ = try await damaged.export(); XCTFail("A damaged log must report its error.") } catch {}
        try await damaged.clear()
        let cleared = try await damaged.export()
        XCTAssertTrue(try JSONDecoder().decode([HabitStudyLog.Entry].self, from: cleared).isEmpty)
    }

    private func formats(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%[@df]")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]) }
    }

    @MainActor private func waitForScene(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("The real interactive scene did not reach its expected response.")
        throw CocoaError(.coderInvalidValue)
    }
}
