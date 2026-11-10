import SpriteKit
import UIKit
import CatGameCore

/// Camera and touch arbitration, including cancelling a drag before a pinch.
@MainActor
extension RoomScene {
    func resetCamera() {
        cancelSingleTouchSequence()
        beginRoomFollowing()
        roomPresentation.camera.focus(on: roomPresentation.projection.project(cat.position))
        updateRoomPresentation()
    }

    var canZoomCamera: Bool {
        presentationActive && deferredRoomLayoutFromSize == nil
            && bowlPlanningRequest == nil && size.width > 0 && size.height > 0
    }

    /// UIKit supplies cumulative pinch scale and a location in SKView points.
    func handlePinch(state: UIGestureRecognizer.State, scale: CGFloat, location: CGPoint) {
        switch state {
        case .began:
            guard canZoomCamera else { return }
            cancelSingleTouchSequence()
            suspendRoomFollowing()
            roomPresentation.camera.beginPinch(at: location)
        case .changed:
            guard canZoomCamera else { roomPresentation.camera.endPinch(); return }
            roomPresentation.camera.changePinch(factor: scale, at: location)
        case .ended, .cancelled, .failed:
            // The last remaining finger must not replace the two-finger center.
            roomPresentation.camera.endPinch()
        default: break
        }
        updateRoomPresentation()
#if DEBUG
        publishNavigationStatus()
        publishDragMetrics()
        publishFurnitureStatus()
#endif
    }

    func zoomIn() { zoomCamera(by: 1.25) }
    func zoomOut() { zoomCamera(by: 0.8) }

    private func zoomCamera(by factor: CGFloat) {
        guard canZoomCamera else { return }
        cancelSingleTouchSequence()
        suspendRoomFollowing()
        roomPresentation.camera.zoom(by: factor)
        updateRoomPresentation()
#if DEBUG
        publishNavigationStatus()
        publishDragMetrics()
        publishFurnitureStatus()
#endif
    }

    func cancelSingleTouchSequence() {
        blockedTouchSequence = true
        sceneTouch = nil
        if dragging { cancelPlacementPreview() }
        _ = roomPresentation.camera.endPan()
        touchOrigin = nil
        dragScreenPoint = nil
    }

    func cancelCameraInteraction() {
        cancelSingleTouchSequence()
        roomPresentation.camera.cancelGestures()
    }
    func previewFloorPoint(_ point: CGPoint) -> CGPoint {
        guard let floor, let placementNavigation else { return selectedNode.position }
        if selectedFurnitureID != nil {
            return placementNavigation.nearestWalkable(to: point) ?? selectedNode.position
        }
        guard let safe = placementNavigation.nearestWalkable(to: floor.bowlGround(at: point)) else { return bowl.position }
        return CGPoint(x: safe.x, y: safe.y - floor.bowlGroundOffset)
    }

    func beginTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        if hasMultipleActiveTouches(touches, event: event) {
            cancelSingleTouchSequence()
            return
        }
        guard !roomPresentation.camera.isPinching else { return }
        guard bowlPlanningRequest == nil else { return }
        guard let touch = touches.first else { return }
        blockedTouchSequence = false
        sceneTouch = touch
        guard let view else { return }
        let screen = touch.location(in: view)
        let point = roomPresentation.worldPoint(screen: screen)
        touchOrigin = screen
        roomPresentation.camera.beginPan(at: screen)
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput = "began:\(point.x),\(point.y)" }
#endif
        guard editing, activeRest == nil else { return }
        guard let hit = roomPresentation.hit(screen: screen, editing: true) else { return }
        let chosenID: String? = hit == "bowl" ? nil : String(hit.dropFirst("furniture-".count))
        // A pending new item can be grabbed again, but a second item must wait
        // for its placement or be reached after cancelling the current preview.
        if newPlacementID != nil && chosenID != selectedFurnitureID { return }
        if selectedFurnitureID != chosenID {
            if isPlacementPending { cancelPlacementPreview() }
            selectedFurnitureID = chosenID
            placementPrepared = false
            onFurnitureSelected?(chosenID)
        }
        placementRevision += 1
        placementTask?.cancel()
        placementTask = nil
        preparePlacementNavigation()
        dragging = true
#if DEBUG
        diagnostics.furnitureDragPreviewSamples = 0
        diagnostics.furnitureDragPreviewPoint = nil
#endif
        dragScreenPoint = touch.location(in: view)
        _ = roomPresentation.camera.endPan()
        setPlacementPending(true)
        let input = roomPresentation.worldPoint(screen: screen, wall: selectedIsWall)
        dragOffset = CGPoint(x: selectedNode.position.x - input.x, y: selectedNode.position.y - input.y)
        updateSelection()
#if DEBUG
        publishFurnitureStatus()
#endif
    }

    func moveTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        if hasMultipleActiveTouches(touches, event: event) {
            cancelSingleTouchSequence()
            return
        }
        guard !blockedTouchSequence, !roomPresentation.camera.isPinching,
              let touch = sceneTouch, touches.contains(touch) else { return }
        if !dragging {
            if let view {
                if roomPresentation.camera.changePan(to: touch.location(in: view)) { suspendRoomFollowing() }
                updateRoomPresentation()
            }
            return
        }
        dragScreenPoint = view.map { touch.location(in: $0) }
#if DEBUG
        let started = CACurrentMediaTime()
#endif
        guard let view else { return }
        let point = roomPresentation.worldPoint(screen: touch.location(in: view), wall: selectedIsWall)
        selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
#if DEBUG
        diagnostics.furnitureDragPreviewSamples += 1
        diagnostics.furnitureDragPreviewPoint = selectedNode.position
#endif
        updateSelection()
        updateBowlLayers()
        updateFurnitureLayers()
        updateRoomPresentation()
#if DEBUG
        if diagnostics.dragTesting {
            diagnostics.dragMoveSamples += 1
            diagnostics.maximumDragMoveMs = max(diagnostics.maximumDragMoveMs, (CACurrentMediaTime() - started) * 1_000)
        }
#endif
    }

    func endTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !blockedTouchSequence, !roomPresentation.camera.isPinching,
              let touch = sceneTouch, touches.contains(touch) else { return }
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput += ";ended" }
#endif
        let wasPanning = roomPresentation.camera.endPan()
        defer { dragging = false; touchOrigin = nil; dragScreenPoint = nil; sceneTouch = nil }
        if wasPanning { return }
        if dragging {
            guard let view else { return }
            let screen = touch.location(in: view)
            let point = roomPresentation.worldPoint(screen: screen, wall: selectedIsWall)
            selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
            // A tap selects without doing an expensive route search.
            if let origin = touchOrigin,
               hypot(screen.x - origin.x, screen.y - origin.y) < 3,
               newPlacementID == nil {
                selectedNode.position = selectedFurnitureID.flatMap { furnitureWorld.center($0) } ?? committedBowlPosition
                setPlacementPending(false)
                updateSelection()
#if DEBUG
                publishFurnitureStatus()
#endif
                return
            }
            resolveReleasedItem()
#if DEBUG
            publishDragMetrics()
            publishFurnitureStatus()
#endif
            return
        }
        guard !editing, let origin = touchOrigin else { return }
        guard let view else { return }
        let point = touch.location(in: view)
        guard hypot(point.x - origin.x, point.y - origin.y) < 12 else { return }
        let hit = roomPresentation.hit(screen: point, editing: false)
        if hit == "bowl" { onBowlTapped?() }
        else if hit == "cat" {
            if activeRest != nil { pendingRestID = nil; leaveFurnitureRest() }
            else if canInspectResidents { onCatTapped?() }
        } else if let hit, hit.hasPrefix("resident-") {
            if canInspectResidents { onResidentTapped?(String(hit.dropFirst("resident-".count))) }
        } else {
            onBackgroundTapped?()
            if let hit, hit.hasPrefix("furniture-") { visitFurniture(String(hit.dropFirst("furniture-".count))) }
        }
    }

    func cancelTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput += ";cancelled" }
#endif
        cancelSingleTouchSequence()
    }

    private func hasMultipleActiveTouches(_ touches: Set<UITouch>, event: UIEvent?) -> Bool {
        let active = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }
        return (active?.count ?? touches.count) > 1
    }

    private var selectedIsWall: Bool {
        selectedFurnitureID.flatMap { furnitureWorld.item($0) }.map { RoomFurnitureSpec.forItem($0).isWall } ?? false
    }

    func updateRoomEdgeScrolling(delta: TimeInterval) {
        guard dragging, let screen = dragScreenPoint,
              roomPresentation.camera.scrollNearEdge(at: screen, delta: delta) else { return }
        let point = roomPresentation.worldPoint(screen: screen, wall: selectedIsWall)
        selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
        updateSelection()
    }
}
