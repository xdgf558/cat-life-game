import XCTest
import CatGameCore
@testable import CatLife

final class GameProgressFeedbackTests: XCTestCase {
    func testNewTaskProgressPlaysOnceAndClaimingDoesNotReplayIt() {
        var state = GameSnapshot.fresh()
        let before = state
        state.tasks.totalFeedCount = 1
        XCTAssertEqual(GameProgressFeedback.sound(from: before, to: state), .taskDone)
        XCTAssertNil(GameProgressFeedback.sound(from: state, to: state))
        var claimed = state
        claimed.tasks.claimedTaskIDs = ["tutorial_feed"]
        XCTAssertNil(GameProgressFeedback.sound(from: state, to: claimed))
    }

    func testLevelGainTakesPriorityOverNewlyUnlockedTask() {
        let before = GameSnapshot.fresh()
        var after = before
        after.player.level = 2
        after.tasks.totalFeedCount = 1
        XCTAssertEqual(GameProgressFeedback.sound(from: before, to: after), .levelUp)
    }
}
