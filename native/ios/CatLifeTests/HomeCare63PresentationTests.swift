import XCTest
import CatGameCore
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

    @MainActor
    func testCareHintsDistinguishRestockingPremiumChoiceAndRequiredMealPortions() async throws {
        for (food, premiumFood, litter, premiumLitter, toys, required, foodHint, litterHint, playHint) in [
            (0, 0, 0, 0, 0, 1, "care.shopFood", "care.shopLitter", "catHabits.choosePlay"),
            (0, 1, 0, 1, 1, 1, "supply.home.foodChoice", "supply.home.litterChoice", "catHabits.choosePlay"),
            (1, 1, 1, 0, 1, 2, "care.shopFood", "", "catHabits.choosePlay"),
            (2, 1, 1, 0, 1, 2, "", "", "catHabits.choosePlay"),
            (1, 2, 1, 0, 1, 2, "supply.home.foodShort", "", "catHabits.choosePlay")
        ] {
            let now = Date()
            var state = GameSnapshot.fresh(now: now)
            state.inventory.food = food; state.inventory.premiumFood = premiumFood
            state.inventory.litter = litter; state.inventory.premiumLitter = premiumLitter; state.inventory.toys = toys
            state.cats[0].isPregnant = required == 2
            state.cats[0].growthState = .legacy(appearance: .orange, now: now, isPregnant: required == 2)
            state.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false, catEnabled: false, haptics: false)
            let suite = "CatLife-care-hints-\(UUID())"
            addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
            let store = GameStore(repository: CareHintRepository(state), reminderDefaults: UserDefaults(suiteName: suite)!)
            await store.load()
            XCTAssertNotNil(store.snapshot)
            XCTAssertEqual(store.foodRequired, required)
            XCTAssertEqual(CatNeed.food.careHintKey(in: store) ?? "", foodHint)
            XCTAssertEqual(CatNeed.clean.careHintKey(in: store) ?? "", litterHint)
            XCTAssertEqual(CatNeed.play.careHintKey(in: store) ?? "", playHint)
            XCTAssertEqual(store.snapshot?.inventory, state.inventory, "Reading care hints must not spend either supply tier.")
        }
    }

    @MainActor
    func testTaskOnboardingUsesMoreAndRestockingHintsExistInEveryLanguage() {
        for strings in [GameStrings.chinese, GameStrings.traditionalChinese, GameStrings.english] {
            let tip = strings["onboarding.tasks.tip1", default: ""]
            XCTAssertFalse(tip.isEmpty)
            XCTAssertFalse(tip.contains("首页") || tip.contains("首頁") || tip.contains("from home"))
            for key in ["care.shopFood", "care.shopLitter", "care.shopToy", "tasks.claimableCount"] {
                XCTAssertFalse(strings[key, default: ""].isEmpty, "Every language needs \(key).")
            }
        }
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

private actor CareHintRepository: GameSaveRepository {
    let lastLoadDisposition = SaveLoadDisposition.loaded
    private var state: GameSnapshot
    init(_ state: GameSnapshot) { self.state = state }
    func loadOrCreate(now: Date) -> GameSnapshot { state }
    func save(_ snapshot: GameSnapshot) { state = snapshot }
    func checkWritable() {}
}
