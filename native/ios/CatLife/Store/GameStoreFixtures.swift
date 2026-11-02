#if DEBUG
import Foundation
import CatGameCore

/// Fixture parsing and fault injection do not exist in Release builds.
struct GameStoreFixtures {
    var initialSnapshot: GameSnapshot?
    var failRestExitOnce = false
    var failWorkCompletionOnce = false
    private var failUserSaves = false
    private var outageStarted = false

    init(arguments: [String] = [], allowsSeeding: Bool = false, now: Date = Date()) {
        guard arguments.contains("--ui-testing") else { return }
        failUserSaves = arguments.contains("--save-outage-test")
        failRestExitOnce = arguments.contains("--recovery-end-failure-once")
        let reset = allowsSeeding && arguments.contains("--reset-ui-test-save")
        failWorkCompletionOnce = reset && arguments.contains("--career-save-failure-once")
        guard reset else { return }
        if let fixture = arguments.first(where: {
            ["--career-completion-fixture", "--career-active-fixture", "--career-level10-fixture",
             "--player-equipped-active-fixture"].contains($0)
        }) {
            let offset: TimeInterval = fixture == "--player-equipped-active-fixture" ? -57 :
                (fixture == "--career-completion-fixture" ? -130 : (fixture == "--career-active-fixture" ? -195 : 0))
            let started = now.addingTimeInterval(offset)
            var value = GameSnapshot.fresh(now: started)
            if fixture == "--player-equipped-active-fixture" {
                _ = GameEngine.equipStarterSet(&value, now: started)
                _ = GameEngine.startWork(&value, now: started)
            } else if fixture == "--career-completion-fixture" {
                value.player.exp = 90
                _ = GameEngine.startWork(&value, now: started)
            } else {
                value.player.level = fixture == "--career-active-fixture" ? 4 : 10
                value.player.stamina = 100
                value.player.mood = 100
                if fixture == "--career-active-fixture" {
                    _ = GameEngine.startWork(&value, jobID: "job_petshop", now: started)
                }
            }
            initialSnapshot = value
        } else if arguments.contains("--recovery-sleep-fixture") {
            let started = now.addingTimeInterval(-1800)
            var value = GameSnapshot.fresh(now: started)
            value.player.stamina = 40
            value.player.mood = 50
            value.player.gold = 180
            value.inventory.food = 4
            _ = GameEngine.startSleep(&value, now: started)
            initialSnapshot = value
        }
    }

    mutating func checkSave(_ candidate: GameSnapshot, original: GameSnapshot,
                            exitsRest: Bool) throws {
        if failUserSaves && (outageStarted || candidate.inventory != original.inventory) {
            outageStarted = true
            throw CocoaError(.fileWriteUnknown)
        }
        if exitsRest && failRestExitOnce {
            failRestExitOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failWorkCompletionOnce, let receipt = candidate.player.lastWorkResult,
           receipt.id != original.player.lastWorkResult?.id {
            failWorkCompletionOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
#endif
