import SwiftUI
import SpriteKit
import CatGameCore

enum RoomStairLandingLayout {
    static let topInset: CGFloat = 240
    static let trailingInset: CGFloat = 12

    static func frame(size: CGSize, canvas: CGSize, floor: HomeFloor = .ground, top: CGFloat = RoomStairLandingLayout.topInset) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGRect(x: floor == .upper ? trailingInset : canvas.width - trailingInset - size.width, y: top,
                      width: size.width, height: size.height)
    }
}

@MainActor
struct RoomSceneHost: View {
    let store: GameStore
    let isActive: Bool
    let reducedMotion: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var attachedGeneration: UUID?
    @State private var previewCatID: String?
    @State private var previewFrame: CGRect?
    @State private var previewReservedStatusFrame: CGRect?
    @State private var previewReservedStatusIsCompact = false
    @State private var previewHeight: CGFloat = 200
    @State private var accessibleGrowthID: String?
    @State private var isSavingGrowth = false
    @State private var scene = RoomScene(size: CGSize(width: 390, height: 480))
    @State private var arrangementFrame: CGRect?
    @State private var canTravelFloors = false
    @State private var stairSize = CGSize.zero
    @State private var viewControlsSize = CGSize.zero
    @State private var roomViewAngle: RoomViewAngle = .front
    @State private var isWholeRoomView = true
    @State private var canChangeRoomView = false
    let catNeedPresentation: CatNeedPresentation
    var arrangementBottomInset: CGFloat = 0
    #if DEBUG
    @State private var animationPhase = "idle"
    @State private var navigationStatus = ""
    @State private var dragStatus = ""
    @State private var furnitureStatus = ""

    private var furnitureTesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--ui-testing")
            && (args.contains("--furniture-test") || args.contains("--rest-test"))
    }

    private var dragTesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--ui-testing") && args.contains("--drag-performance-test")
    }

    private var navigationTesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--ui-testing") && args.contains("--navigation-test")
    }

    private var animationTesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--ui-testing") && args.contains("--animation-test")
    }

    #endif

    private var effectiveReducedMotion: Bool {
        #if DEBUG
        reducedMotion || (animationTesting && ProcessInfo.processInfo.arguments.contains("--reduce-motion-test"))
        #else
        reducedMotion
        #endif
    }

    private var ownsPresentation: Bool {
        attachedGeneration == store.saveSceneGeneration && scene.homeFloor == store.visibleHomeFloor
    }

    var body: some View {
        GeometryReader { geometry in
            roomContent(geometry: geometry)
        }
        .sheet(isPresented: Binding(get: { dynamicTypeSize.isAccessibilitySize && previewCatID != nil },
                                    set: { if !$0 { closePreview() } })) {
            if let cat = store.snapshot?.cats.first(where: { $0.id == previewCatID }) {
                NavigationStack {
                    Group {
                        if let id = accessibleGrowthID {
                            CatGrowthView(store: store, catID: id, isSaving: $isSavingGrowth, home: closePreview)
                        } else {
                            ScrollView {
                                RoomResidentPreviewCard(store: store, cat: cat, close: closePreview,
                                    openGrowth: { accessibleGrowthID = cat.id }).padding(20)
                            }
                        }
                    }.toolbar {
                        if accessibleGrowthID != nil {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(GameStrings.text("common.back")) { accessibleGrowthID = nil }.disabled(isSavingGrowth)
                            }
                        }
                    }
                }.presentationBackground(RoomTheme.cream).presentationDetents([.large]).presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(store.isBusy || isSavingGrowth)
            }
        }
    }


    @ViewBuilder
    private func roomContent(geometry: GeometryProxy) -> some View {
        let showsStairs = isActive && ownsPresentation && store.snapshot?.home.availableFloors.count == 2
        let controlsLayout = cameraControlsLayout(geometry: geometry, showsStairs: showsStairs)
        ZStack {
            roomCanvas(geometry: geometry).accessibilityHidden(true)
            // Keep only the active SwiftUI surface in the accessibility tree.
            if isActive && ownsPresentation { accessibleRoom }
        }
        #if DEBUG
        .overlay {
            if furnitureTesting, isActive {
                // Keep the test-only pinch target behind buttons in the accessibility hit order.
                let target = pinchTestRect(in: controlsLayout.usableRect, canvas: geometry.size)
                Color.clear
                    .frame(width: target.width * 0.8, height: target.height * 0.8)
                    .offset(x: target.midX - geometry.size.width / 2,
                            y: target.midY - geometry.size.height / 2)
                    .accessibilityElement()
                    .accessibilityLabel("Room pinch surface")
                    .accessibilityIdentifier("roomPinchSurface")
                    .allowsHitTesting(false)
            }
        }
        #endif
        .overlay {
            CatNeedBubble(store: store, presentation: catNeedPresentation,
                          canvasSize: geometry.size, isActive: isActive && ownsPresentation && previewCatID == nil,
                          canAct: { scene.canShowCatNeed }, avoidingFrame: controlsLayout.stairFrame)
        }
        .overlay {
            if isActive, ownsPresentation, store.isDecorating, !store.isResolvingLayout, let arrangementFrame {
                RoomArrangementOverlay(store: store, selectedFrame: arrangementFrame,
                                       canvasSize: geometry.size, bottomInset: arrangementBottomInset)
            }
        }
        .overlay {
            residentPreview(geometry: geometry, below: max(controlsLayout.controlsTop + viewControlsSize.height, controlsLayout.stairFrame.maxY) + 12)
        }
        .overlay(alignment: store.visibleHomeFloor == .upper ? .topTrailing : .topLeading) {
            cameraControls(width: controlsLayout.width, top: controlsLayout.controlsTop)
        }
        .overlay(alignment: store.visibleHomeFloor == .upper ? .topLeading : .topTrailing) {
            stairLanding(isVisible: showsStairs, top: controlsLayout.stairTop)
        }
        .onChange(of: controlsLayout.usableRect, initial: true) { _, rect in updateRoomViewUsableRect(rect) }
        .onChange(of: isActive) { _, active in
            if active { updateRoomViewUsableRect(controlsLayout.usableRect) }
        }
    }

    @ViewBuilder
    private func residentPreview(geometry: GeometryProxy, below toolsBottom: CGFloat) -> some View {
        if isActive, ownsPresentation, !dynamicTypeSize.isAccessibilitySize,
           let id = previewCatID, let frame = previewFrame,
           let cat = store.snapshot?.cats.first(where: { $0.id == id }) {
            let origin = geometry.frame(in: .global).origin
            let top = max(toolsBottom, (catNeedPresentation.headerFrame?.maxY ?? origin.y) - origin.y + 12)
            let cardWidth = min(230, max(200, geometry.size.width - 140))
            let halfWidth = cardWidth / 2
            let right = (catNeedPresentation.careActionsFrame?.minX ?? geometry.frame(in: .global).maxX) - origin.x - 12
            let minimumX = 12 + halfWidth
            let maximumX = max(minimumX, right - halfWidth)
            RoomResidentPreviewCard(store: store, cat: cat, close: closePreview)
                .frame(width: cardWidth)
                .background {
                    GeometryReader { card in
                        Color.clear.onAppear { previewHeight = card.size.height }
                            .onChange(of: card.size.height) { _, value in previewHeight = value }
                    }.allowsHitTesting(false)
                }
                .position(x: min(maximumX, max(minimumX, frame.midX)),
                          y: min(geometry.size.height - previewHeight / 2 - 14,
                                 max(top + previewHeight / 2, frame.minY - previewHeight / 2 - 12)))
        }
    }

    private func inspectResident(_ id: String) {
        guard scene.canInspectResidents, !store.isBusy, !store.isDecorating,
              let frame = scene.residentFrame(id: id) else { return }
        previewReservedStatusFrame = catNeedPresentation.statusCardFrame
        previewReservedStatusIsCompact = catNeedPresentation.statusCardIsCompact
        previewCatID = id; previewFrame = frame
        scene.inspectedResidentID = id
        catNeedPresentation.isInspectingResident = true
    }

    private func closePreview() {
        previewCatID = nil; previewFrame = nil; previewReservedStatusFrame = nil
        scene.inspectedResidentID = nil
        accessibleGrowthID = nil
        if ownsPresentation { catNeedPresentation.isInspectingResident = false }
    }

    private func roomCanvas(geometry: GeometryProxy) -> some View {
        NativeRoomCanvas(scene: scene, isActive: isActive && ownsPresentation, canvasSize: geometry.size)
            .allowsHitTesting(!store.isSavingLayout && !store.isChangingHomeFloor)
            .onAppear { configureScene(geometry: geometry) }
            .onChange(of: isActive) { _, active in
                scene.setPresentationActive(active && ownsPresentation)
                if active && ownsPresentation { catNeedPresentation.focusRoom = { [weak source = scene] in source?.resetCamera() } }
                if !active {
                    closePreview()
                    if ownsPresentation { catNeedPresentation.anchor = nil; catNeedPresentation.localCatFrame = nil }
                    arrangementFrame = nil
                    scene.cancelPlacementPreview()
                }
            }
            .onDisappear {
                closePreview()
                scene.setPresentationActive(false)
                scene.onCatNeedAnchorChanged = nil
                scene.onCatVisualFrameChanged = nil
                scene.onArrangementFrameChanged = nil
                scene.onFloorTravelAvailabilityChanged = nil
                scene.onRoomViewChanged = nil
                arrangementFrame = nil
                scene.onBackgroundTapped = nil
                scene.onVisibleResidentsChanged = nil
                scene.onInspectedResidentFrameChanged = nil
                if ownsPresentation {
                    catNeedPresentation.anchor = nil; catNeedPresentation.localCatFrame = nil
                    catNeedPresentation.focusRoom = nil
                }
                scene.cancelPlacementPreview()
            }
            .onChange(of: geometry.size) { _, size in scene.size = size }
            .onChange(of: geometry.frame(in: .global).origin) { _, origin in catNeedPresentation.canvasOrigin = origin }
            .onChange(of: effectiveReducedMotion) { _, value in scene.reducedMotion = value }
            .onChange(of: store.cat?.id) { _, _ in closePreview() }
            .onChange(of: store.sceneSnapshot) { _, _ in refreshScene() }
            .onChange(of: store.isDecorating) { _, _ in refreshScene() }
            .onChange(of: store.selectedFurnitureID) { _, _ in refreshScene() }
            .onChange(of: store.placingFurnitureID) { _, _ in refreshScene() }
            .onChange(of: store.feedback?.id) { _, _ in
                refreshScene()
                if let feedback = store.feedback { scene.playFeedback(kind: feedback.kind, catID: feedback.catID) }
            }
    }

    private func configureScene(geometry: GeometryProxy) {
        scene.scaleMode = .resizeFill
        if scene.size != geometry.size { scene.size = geometry.size }
        #if DEBUG
        scene.diagnostics.onPresentationChanged = { animationPhase = $0 }
        scene.diagnostics.onNavigationChanged = { navigationStatus = $0 }
        scene.diagnostics.onDragMetricsChanged = { dragStatus = $0 }
        scene.diagnostics.onFurnitureDiagnosticsChanged = { furnitureStatus = $0 }
        dragStatus = scene.diagnostics.dragDescription
        furnitureStatus = scene.diagnostics.furnitureDescription
        navigationStatus = scene.diagnostics.navigationDescription
        animationPhase = scene.presentationPhase
        #endif
        let generation = store.saveSceneGeneration
        attachedGeneration = generation
        let sourceFloor = store.visibleHomeFloor
        // Only the new floor/save owner resets inspection after the old host has relinquished ownership.
        catNeedPresentation.isInspectingResident = false
        let acceptsSceneUpdates = {
            store.saveSceneGeneration == generation && store.visibleHomeFloor == sourceFloor
                && !store.isChangingHomeFloor
        }
        scene.onPlacementPendingChanged = { if acceptsSceneUpdates() { store.setLayoutResolving($0) } }
        scene.reducedMotion = effectiveReducedMotion
        scene.homeFloor = sourceFloor
        scene.onCatTapped = { if acceptsSceneUpdates(), let id = store.cat?.id { inspectResident(id) } }
        scene.onResidentTapped = { if acceptsSceneUpdates() { inspectResident($0) } }
        scene.onBackgroundTapped = { if acceptsSceneUpdates() { closePreview() } }
        scene.onVisibleResidentsChanged = { if acceptsSceneUpdates() { store.visibleRoomCatIDs = $0 } }
        scene.onInspectedResidentFrameChanged = { frame in
            guard acceptsSceneUpdates() else { return }
            previewFrame = frame
            if frame == nil { closePreview() }
        }
        scene.onFloorTravelAvailabilityChanged = {
            guard acceptsSceneUpdates() else { return }
            canTravelFloors = $0
            store.roomFloorTravelReady = $0
        }
        scene.onRoomViewChanged = {
            if acceptsSceneUpdates() { refreshRoomViewControls() }
        }
        let presentation = catNeedPresentation
        presentation.focusRoom = { [weak source = scene] in source?.resetCamera() }
        presentation.canvasOrigin = geometry.frame(in: .global).origin
        scene.onCatNeedAnchorChanged = { [weak presentation] point in if acceptsSceneUpdates() { presentation?.anchor = point } }
        scene.onCatVisualFrameChanged = { [weak presentation] frame in if acceptsSceneUpdates() { presentation?.localCatFrame = frame } }
        scene.onArrangementFrameChanged = { if acceptsSceneUpdates() { arrangementFrame = $0 } }
        scene.onSound = { store.playSceneSound($0) }
        scene.onBowlTapped = { if acceptsSceneUpdates() { store.feed() } }
        scene.onBowlMoved = { if acceptsSceneUpdates() { store.moveBowl(to: $0) } }
        scene.onFurnitureSelected = { if acceptsSceneUpdates() { store.selectFurniture(id: $0) } }
        scene.onFurnitureMoved = { if acceptsSceneUpdates() { store.moveFurniture(id: $0, to: $1) } }
        scene.onFurniturePlacementFinished = {
            if acceptsSceneUpdates() { store.finishFurniturePlacement(id: $0, succeeded: $1) }
        }
        scene.onRestingFurnitureChanged = { furnitureID, sessionID, catID in
            guard acceptsSceneUpdates() else { return }
            store.setRestingFurniture(id: furnitureID, sessionID: sessionID, catID: catID)
        }
        scene.onFurnitureNotice = {
            guard acceptsSceneUpdates() else { return }
            if $0 != "room.sharedHomeNoSpace" { store.showFurnitureNotice($0) }
        }
        refreshScene()
        scene.setPresentationActive(isActive)
        refreshRoomViewControls()
    }

    private func cameraControlsLayout(geometry: GeometryProxy, showsStairs: Bool)
        -> (width: CGFloat, controlsTop: CGFloat, stairTop: CGFloat, stairFrame: CGRect, usableRect: CGRect) {
        let size = geometry.size
        let origin = geometry.frame(in: .global).origin
        let card = (catNeedPresentation.statusCardFrame ?? previewReservedStatusFrame)?.offsetBy(dx: -origin.x, dy: -origin.y)
        let care = catNeedPresentation.careActionsFrame?.offsetBy(dx: -origin.x, dy: -origin.y)
        let cardAtTop = catNeedPresentation.statusCardFrame != nil
            ? catNeedPresentation.statusCardIsCompact : previewReservedStatusIsCompact
        let headerBottom = catNeedPresentation.headerFrame.map { $0.maxY - origin.y } ?? 0
        let controlsTop = max(max(RoomStairLandingLayout.topInset, headerBottom + 12),
                              cardAtTop ? (card?.maxY ?? 0) + 12 : 0)
        let besideStairsWidth = size.width - 36 - max(76, stairSize.width)
        let stacksStairs = showsStairs && !store.isDecorating && besideStairsWidth < 160
        let width = min(244, max(0, showsStairs && !stacksStairs ? besideStairsWidth : size.width - 24))
        let top = controlsTop + (stacksStairs ? viewControlsSize.height + 12 : 0)
        let frame = showsStairs ? RoomStairLandingLayout.frame(size: stairSize, canvas: size, floor: store.visibleHomeFloor, top: top) : .zero
        let controlsBottom = store.isDecorating ? 0 : controlsTop + viewControlsSize.height
        let desiredTop = store.isDecorating ? CGFloat(160) : max(controlsBottom, frame.maxY) + 12
        var bottom = size.height - 20
        if store.isDecorating {
            bottom = min(bottom, size.height - arrangementBottomInset - 12)
        } else if let card, !cardAtTop {
            bottom = min(bottom, card.minY - 12)
        }
        let usableTop = min(max(20, desiredTop), max(20, bottom - 80))
        let rightInset: CGFloat = !store.isDecorating ? max(12, care.map { size.width - $0.minX + 12 } ?? 12) : 12
        let usableRect = CGRect(x: 12, y: usableTop, width: max(1, size.width - 12 - rightInset),
                                height: max(80, bottom - usableTop))
        return (width, controlsTop, top, frame, usableRect)
    }

    private func updateRoomViewUsableRect(_ rect: CGRect) {
        guard isActive else { return }
        scene.setRoomViewUsableRect(rect)
    }

    @ViewBuilder
    private func cameraControls(width: CGFloat, top: CGFloat) -> some View {
        if isActive, ownsPresentation, !store.isDecorating {
            RoomViewControls(angle: roomViewAngle, isWholeRoomView: isWholeRoomView,
                             canChangeView: canChangeRoomView && !store.isSavingLayout && !store.isChangingHomeFloor,
                             compact: width < 208,
                             showsFindCat: (store.snapshot?.cats.count ?? 0) <= 1 && store.snapshot?.home.availableFloors.count != 2,
                             turn: { scene.turnRoomView(by: $0) },
                             showWholeRoom: { scene.showWholeRoom() }, focusCat: { scene.resetCamera() })
                .frame(width: width)
                .background {
                    GeometryReader { controls in
                        Color.clear.onAppear { viewControlsSize = controls.size }
                            .onChange(of: controls.size) { _, size in viewControlsSize = size }
                    }.allowsHitTesting(false)
                }
                .padding(.horizontal, 12).padding(.top, top)
        }
    }

    @ViewBuilder
    private func stairLanding(isVisible: Bool, top: CGFloat) -> some View {
        if isVisible {
            HomeStairLanding(store: store, roomReady: canTravelFloors)
                .background {
                    GeometryReader { landing in
                        Color.clear.onAppear { stairSize = landing.size }
                            .onChange(of: landing.size) { _, size in stairSize = size }
                    }.allowsHitTesting(false)
                }
                .padding(.horizontal, RoomStairLandingLayout.trailingInset)
                .padding(.top, top)
        }
    }

    private var accessibleRoom: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GameStrings.text("accessibility.cat"))
            .accessibilityIdentifier("roomScene")
            .accessibilityValue(sceneAccessibilityValue)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { store.inspectCat() }
            .accessibilityActions { roomAccessibilityActions }
    }

    @ViewBuilder
    private var roomAccessibilityActions: some View {
        Group {
            Button(GameStrings.text("care.feed")) { store.feed() }
            Button(GameStrings.text("rest.bedAction")) { scene.restInFurniture(kind: .catBed) }
            Button(GameStrings.text("rest.cushionAction")) { scene.restInFurniture(kind: .floorCushion) }
        }
        roomCameraAccessibilityActions
        residentAccessibilityActions
    }

    private var roomCameraAccessibilityActions: some View {
        Group {
            Button(GameStrings.text("homeUpgrade.focusCat")) { scene.resetCamera() }
            Button(GameStrings.text("roomView.showWhole")) { scene.showWholeRoom() }
                .disabled(!canChangeRoomView)
            Button(GameStrings.text("roomView.turnLeft")) { scene.turnRoomView(by: -1) }
                .disabled(!canChangeRoomView || roomViewAngle == .left)
            Button(GameStrings.text("roomView.turnRight")) { scene.turnRoomView(by: 1) }
                .disabled(!canChangeRoomView || roomViewAngle == .right)
            Button(GameStrings.text("homeUpgrade.zoomIn")) { scene.zoomIn() }
            Button(GameStrings.text("homeUpgrade.zoomOut")) { scene.zoomOut() }
        }
    }

    @ViewBuilder
    private var residentAccessibilityActions: some View {
        let cats: [CatState] = store.snapshot?.cats ?? []
        if (store.snapshot?.home.roomLevel ?? 1) >= RoomResidentCats.unlockLevel {
            ForEach(cats) { cat in
                Button(GameStrings.format("room.inspectResident", GameStrings.catName(cat))) {
                    inspectResident(cat.id)
                }
            }
        }
    }

    private var sceneAccessibilityValue: String {
        #if DEBUG
        if furnitureTesting { return furnitureStatus }
        if dragTesting { return dragStatus }
        if navigationTesting { return navigationStatus }
        if animationTesting { return animationPhase }
        return ProcessInfo.processInfo.arguments.contains("--ui-testing") ? bowlPositionDescription : store.catStatus
        #else
        return store.catStatus
        #endif
    }

    private func refreshScene() {
        guard ownsPresentation else { return }
        if let value = store.sceneSnapshot {
            scene.apply(snapshot: value, editing: store.isDecorating,
                        selectedFurnitureID: store.selectedFurnitureID,
                        placingFurnitureID: store.placingFurnitureID)
        }
    }

    private func refreshRoomViewControls() {
        roomViewAngle = scene.roomViewAngle
        isWholeRoomView = scene.isWholeRoomView
        catNeedPresentation.showsWholeRoom = isWholeRoomView
        canChangeRoomView = scene.canChangeRoomView
    }

    #if DEBUG
    private func pinchTestRect(in usableRect: CGRect, canvas: CGSize) -> CGRect {
        guard store.isDecorating, let arrangementFrame else { return usableRect }
        let tools = RoomArrangementOverlayLayout.center(for: arrangementFrame, canvas: canvas,
            bottomInset: arrangementBottomInset, width: min(232, max(0, canvas.width - 24)))
        // A pinch on a native tool button belongs to that button, not the canvas underneath.
        let height = tools.y - 36 - usableRect.minY
        return height >= 80 ? CGRect(x: usableRect.minX, y: usableRect.minY,
                                      width: usableRect.width, height: height) : usableRect
    }

    private var bowlPositionDescription: String {
        guard let point = store.sceneSnapshot?.home.bowlPosition else { return "" }
        return String(format: "%.3f,%.3f", point.x, point.y)
    }
    #endif
}

/// Present the scene explicitly so scene attachment and resume ordering are
/// consistent across supported OS versions, including a cold launch from inactive.
@MainActor
private struct NativeRoomCanvas: UIViewRepresentable {
    let scene: RoomScene
    let isActive: Bool
    let canvasSize: CGSize

    func makeCoordinator() -> Coordinator { Coordinator(scene: scene) }

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 30
        view.ignoresSiblingOrder = true
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.addGestureRecognizer(context.coordinator.pinch)
        context.coordinator.setActive(isActive)
        configure(view)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        context.coordinator.setActive(isActive)
        configure(view)
    }

    static func dismantleUIView(_ view: SKView, coordinator: Coordinator) {
        coordinator.setActive(false)
        view.removeGestureRecognizer(coordinator.pinch)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let pinch = UIPinchGestureRecognizer()
        private weak var scene: RoomScene?

        init(scene: RoomScene) {
            self.scene = scene
            super.init()
            pinch.addTarget(self, action: #selector(pinched(_:)))
            pinch.delegate = self
            pinch.cancelsTouchesInView = true
            pinch.delaysTouchesBegan = false
        }

        func setActive(_ active: Bool) {
            if pinch.isEnabled != active { pinch.isEnabled = active }
            if !active { scene?.handlePinch(state: .cancelled, scale: 1, location: .zero) }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            scene?.canZoomCamera == true
        }

        @objc private func pinched(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began, .changed:
                guard recognizer.numberOfTouches >= 2 else { return }
            default: break
            }
            scene?.handlePinch(state: recognizer.state, scale: recognizer.scale,
                               location: recognizer.location(in: view))
        }
    }

    private func configure(_ view: SKView) {
        if canvasSize.width > 0 && canvasSize.height > 0 && scene.size != canvasSize {
            scene.size = canvasSize
        }
        if view.scene !== scene { view.presentScene(scene) }
        scene.setPresentationActive(isActive)
        view.isPaused = !isActive
        scene.isPaused = !isActive
    }
}
