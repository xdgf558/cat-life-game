import SpriteKit

/// View state stays outside saved layouts and never changes actor/path coordinates.
@MainActor
extension RoomScene {
    var roomViewAngle: RoomViewAngle { roomPresentation.projection.angle }
    var isWholeRoomView: Bool { roomPresentation.camera.isWholeRoom }
    var canChangeRoomView: Bool {
        presentationActive && !editing && !dragging && !isPlacementPending
            && bowlPlanningRequest == nil && !residents.isPreparing
    }

    func setRoomViewUsableRect(_ rect: CGRect) {
        roomPresentation.setUsableRect(rect)
        updateRoomPresentation()
    }

    func turnRoomView(by steps: Int) {
        guard canChangeRoomView else { return }
        let next = min(1, max(-1, roomViewAngle.rawValue + steps.signum()))
        guard let angle = RoomViewAngle(rawValue: next), angle != roomViewAngle else { return }
        cancelCameraInteraction()
        suspendRoomFollowing()
        roomPresentation.configure(world: roomPresentation.projection.worldSize, viewport: size,
                                   floor: floor?.polygon ?? [], angle: angle, level: renderedRoomLevel, homeFloor: homeFloor)
        updateRoomPresentation()
    }

    func showWholeRoom() {
        guard canChangeRoomView else { return }
        cancelCameraInteraction()
        suspendRoomFollowing()
        roomPresentation.camera.fit()
        updateRoomPresentation()
    }
}
