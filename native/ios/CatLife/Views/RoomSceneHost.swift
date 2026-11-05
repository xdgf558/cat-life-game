import SwiftUI
import SpriteKit
import CatGameCore

@MainActor
struct RoomSceneHost: View {
    let store: GameStore
    let isActive: Bool
    let reducedMotion: Bool
    @State private var scene = RoomScene(size: CGSize(width: 390, height: 480))
    @State private var arrangementFrame: CGRect?
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

    var body: some View {
        GeometryReader { geometry in
            let canvas = NativeRoomCanvas(scene: scene, isActive: isActive, canvasSize: geometry.size)
                .allowsHitTesting(!store.isSavingLayout)
                .onAppear {
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
                    scene.onPlacementPendingChanged = { store.setLayoutResolving($0) }
                    scene.reducedMotion = effectiveReducedMotion
                    scene.onCatTapped = { store.inspectCat() }
                    let presentation = catNeedPresentation
                    presentation.canvasOrigin = geometry.frame(in: .global).origin
                    scene.onCatNeedAnchorChanged = { [weak presentation] point in presentation?.anchor = point }
                    scene.onCatVisualFrameChanged = { [weak presentation] frame in presentation?.localCatFrame = frame }
                    scene.onArrangementFrameChanged = { arrangementFrame = $0 }
                    scene.onSound = { store.playSceneSound($0) }
                    scene.onBowlTapped = { store.feed() }
                    scene.onBowlMoved = { store.moveBowl(to: $0) }
                    scene.onFurnitureSelected = { store.selectFurniture(id: $0) }
                    scene.onFurnitureMoved = { store.moveFurniture(id: $0, to: $1) }
                    scene.onFurniturePlacementFinished = { store.finishFurniturePlacement(id: $0, succeeded: $1) }
                    let generation = store.saveSceneGeneration
                    scene.onRestingFurnitureChanged = { furnitureID, sessionID, catID in
                        guard store.saveSceneGeneration == generation else { return }
                        store.setRestingFurniture(id: furnitureID, sessionID: sessionID, catID: catID)
                    }
                    scene.onFurnitureNotice = { store.showFurnitureNotice($0) }
                    refreshScene()
                    scene.setPresentationActive(isActive)
                }
                .onChange(of: isActive) { _, active in
                    scene.setPresentationActive(active)
                    if !active {
                        catNeedPresentation.anchor = nil
                        catNeedPresentation.localCatFrame = nil
                        arrangementFrame = nil
                        scene.cancelPlacementPreview()
                    }
                }
                .onDisappear {
                    scene.setPresentationActive(false)
                    scene.onCatNeedAnchorChanged = nil
                    scene.onCatVisualFrameChanged = nil
                    scene.onArrangementFrameChanged = nil
                    arrangementFrame = nil
                    catNeedPresentation.anchor = nil
                    catNeedPresentation.localCatFrame = nil
                    scene.cancelPlacementPreview()
                }
                .onChange(of: geometry.size) { _, size in scene.size = size }
                .onChange(of: geometry.frame(in: .global).origin) { _, origin in catNeedPresentation.canvasOrigin = origin }
                .onChange(of: effectiveReducedMotion) { _, value in scene.reducedMotion = value }
                .onChange(of: store.sceneSnapshot) { _, _ in refreshScene() }
                .onChange(of: store.isDecorating) { _, _ in refreshScene() }
                .onChange(of: store.selectedFurnitureID) { _, _ in refreshScene() }
                .onChange(of: store.placingFurnitureID) { _, _ in refreshScene() }
                .onChange(of: store.feedback?.id) { _, _ in
                    refreshScene()
                    if let feedback = store.feedback { scene.playFeedback(kind: feedback.kind, catID: feedback.catID) }
                }
            ZStack {
                canvas.accessibilityHidden(true)
                // Keep only the active SwiftUI surface in the accessibility tree.
                if isActive { accessibleRoom }
            }
            #if DEBUG
            .overlay {
                if furnitureTesting, isActive {
                    // Keep the test-only pinch target behind buttons in the accessibility hit order.
                    Color.clear
                        .frame(width: geometry.size.width * 0.7, height: geometry.size.height * 0.5)
                        .accessibilityElement()
                        .accessibilityLabel("Room pinch surface")
                        .accessibilityIdentifier("roomPinchSurface")
                        .allowsHitTesting(false)
                }
            }
            #endif
            .overlay {
                CatNeedBubble(store: store, presentation: catNeedPresentation,
                              canvasSize: geometry.size, isActive: isActive,
                              canAct: { scene.canShowCatNeed })
            }
            .overlay {
                if isActive, store.isDecorating, !store.isResolvingLayout, let arrangementFrame {
                    RoomArrangementOverlay(store: store, selectedFrame: arrangementFrame,
                                           canvasSize: geometry.size, bottomInset: arrangementBottomInset)
                }
            }
            .overlay(alignment: .topLeading) {
                if isActive, (store.snapshot?.home.roomLevel ?? 1) > 1, !store.isDecorating {
                    Button { scene.resetCamera() } label: {
                        Label(GameStrings.text("homeUpgrade.focusCat"), systemImage: "scope")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(RoomTheme.paper.opacity(0.95), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("focusCatButton")
                    .accessibilityHint(GameStrings.text("homeUpgrade.zoomHint"))
                    .padding(.leading, 12).padding(.top, 240)
                }
            }
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
            .accessibilityAction(named: Text(GameStrings.text("care.feed"))) { store.feed() }
            .accessibilityAction(named: Text(GameStrings.text("rest.bedAction"))) { scene.restInFurniture(kind: .catBed) }
            .accessibilityAction(named: Text(GameStrings.text("rest.cushionAction"))) { scene.restInFurniture(kind: .floorCushion) }
            .accessibilityAction(named: Text(GameStrings.text("homeUpgrade.focusCat"))) { scene.resetCamera() }
            .accessibilityAction(named: Text(GameStrings.text("homeUpgrade.zoomIn"))) { scene.zoomIn() }
            .accessibilityAction(named: Text(GameStrings.text("homeUpgrade.zoomOut"))) { scene.zoomOut() }
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
        if let value = store.sceneSnapshot {
            scene.apply(snapshot: value, editing: store.isDecorating,
                        selectedFurnitureID: store.selectedFurnitureID,
                        placingFurnitureID: store.placingFurnitureID)
        }
    }

    #if DEBUG
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
