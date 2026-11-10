import SpriteKit
import UIKit
import CatGameCore

/// Camera and touch arbitration, including cancelling a drag before a pinch.
@MainActor
extension RoomScene {
    func resetCamera() {
        cancelSingleTouchSequence()
        roomCamera.focus(on: cat.position, animated: !reducedMotion, resetScale: true)
    }

    var canZoomCamera: Bool {
        renderedRoomLevel > 1 && presentationActive && deferredRoomLayoutFromSize == nil
            && bowlPlanningRequest == nil && size.width > 0 && size.height > 0
    }

    /// UIKit supplies cumulative pinch scale and a location in SKView points.
    func handlePinch(state: UIGestureRecognizer.State, scale: CGFloat, location: CGPoint) {
        switch state {
        case .began:
            guard canZoomCamera else { return }
            cancelSingleTouchSequence()
            roomCamera.beginPinch(at: location)
        case .changed:
            guard canZoomCamera else { roomCamera.endPinch(); return }
            roomCamera.changePinch(factor: scale, at: location)
        case .ended, .cancelled, .failed:
            // The last remaining finger must not replace the two-finger center.
            roomCamera.endPinch()
        default: break
        }
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
        roomCamera.zoom(by: factor)
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
        _ = roomCamera.endTouch()
        touchOrigin = nil
        dragScreenPoint = nil
    }

    func cancelCameraInteraction() {
        cancelSingleTouchSequence()
        roomCamera.cancelGestures()
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
        guard !roomCamera.isPinching else { return }
        guard bowlPlanningRequest == nil else { return }
        guard let touch = touches.first else { return }
        blockedTouchSequence = false
        sceneTouch = touch
        let point = touch.location(in: self)
        touchOrigin = point
        if let view { roomCamera.beginTouch(at: touch.location(in: view), canPan: true) }
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput = "began:\(point.x),\(point.y)" }
#endif
        guard editing, activeRest == nil else { return }
        let hits = furnitureNodes.filter { $0.value.frame.contains(point) }
            .sorted { $0.value.zPosition > $1.value.zPosition }
        let hit = hits.first
        let bowlHit = bowl.frame.insetBy(dx: -8, dy: -8).contains(point)
        guard hit != nil || bowlHit else { return }
        let chosenID: String? = bowlHit && (hit == nil || bowl.zPosition >= hit!.value.zPosition) ? nil : hit?.key
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
        dragScreenPoint = view.map { touch.location(in: $0) }
        if let point = dragScreenPoint { roomCamera.beginTouch(at: point, canPan: false) }
        setPlacementPending(true)
        dragOffset = CGPoint(x: selectedNode.position.x - point.x, y: selectedNode.position.y - point.y)
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
        guard !blockedTouchSequence, !roomCamera.isPinching,
              let touch = sceneTouch, touches.contains(touch) else { return }
        if !dragging {
            if let view { roomCamera.moveTouch(to: touch.location(in: view)) }
            return
        }
        dragScreenPoint = view.map { touch.location(in: $0) }
#if DEBUG
        let started = CACurrentMediaTime()
#endif
        let point = touch.location(in: self)
        selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
#if DEBUG
        diagnostics.furnitureDragPreviewSamples += 1
        diagnostics.furnitureDragPreviewPoint = selectedNode.position
#endif
        updateSelection()
        updateBowlLayers()
        updateFurnitureLayers()
#if DEBUG
        if diagnostics.dragTesting {
            diagnostics.dragMoveSamples += 1
            diagnostics.maximumDragMoveMs = max(diagnostics.maximumDragMoveMs, (CACurrentMediaTime() - started) * 1_000)
        }
#endif
    }

    func endTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !blockedTouchSequence, !roomCamera.isPinching,
              let touch = sceneTouch, touches.contains(touch) else { return }
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput += ";ended" }
#endif
        let wasPanning = roomCamera.endTouch()
        defer { dragging = false; touchOrigin = nil; dragScreenPoint = nil; sceneTouch = nil }
        if wasPanning { return }
        if dragging {
            let point = touch.location(in: self)
            selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
            // A tap selects without doing an expensive route search.
            if let origin = touchOrigin,
               hypot(touch.location(in: self).x - origin.x, touch.location(in: self).y - origin.y) < 3 * roomCamera.scale,
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
        let point = touch.location(in: self)
        guard hypot(point.x - origin.x, point.y - origin.y) < 12 * roomCamera.scale else { return }
        if bowl.frame.contains(point) { onBowlTapped?() }
        else if cat.visualFrame.insetBy(dx: -8, dy: -8).contains(point) {
            if activeRest != nil { pendingRestID = nil; leaveFurnitureRest() }
            else if canInspectResidents { onCatTapped?() }
        } else if let residentID = residents.hit(at: point) {
            if canInspectResidents { onResidentTapped?(residentID) }
        } else {
            onBackgroundTapped?()
            if let hit = furnitureNodes.filter({ $0.value.frame.contains(point) })
            .sorted(by: { $0.value.zPosition > $1.value.zPosition }).first {
                visitFurniture(hit.key)
            }
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
}
