import XCTest
@testable import CatLife

final class HomeRoomLayoutTests: XCTestCase {
    func testStageNeverOverlapsTheHeaderOrPersistentCareBarOnPortraitPhones() {
        for size in [CGSize(width: 375, height: 539), CGSize(width: 402, height: 712), CGSize(width: 440, height: 804)] {
            for header: CGFloat in [100, 144, 190] {
                let stage = HomeRoomLayout.stageFrame(in: size, headerHeight: header, editing: false)
                let careTop = size.height - 8 - HomeRoomLayout.careHeight(in: size)
                XCTAssertTrue(CGRect(origin: .zero, size: size).contains(stage))
                XCTAssertGreaterThanOrEqual(stage.minY, header + 12)
                XCTAssertEqual(careTop - stage.maxY, 12, accuracy: 0.001)
                XCTAssertGreaterThan(stage.height, 150)
            }
        }
    }

    func testEditingKeepsTheFullCanvasWithoutChangingPhysicalRoomCoordinates() {
        let size = CGSize(width: 402, height: 712)
        XCTAssertEqual(HomeRoomLayout.stageFrame(in: size, headerHeight: 100, editing: true), CGRect(origin: .zero, size: size))
    }

    func testInvalidViewportCannotProduceAnUnboundedStage() {
        XCTAssertEqual(HomeRoomLayout.stageFrame(in: CGSize(width: CGFloat.nan, height: 700), headerHeight: 100, editing: false), .zero)
        XCTAssertEqual(HomeRoomLayout.stageFrame(in: .zero, headerHeight: 100, editing: false), .zero)
    }
}
