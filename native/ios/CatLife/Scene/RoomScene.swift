import SpriteKit
import UIKit
import CatGameCore

/// Rendering and hit testing only. Game rules and saves stay in CatGameCore.
@MainActor
final class RoomScene: SKScene {
    var onSound: ((GameSoundEffect) -> Void)?
    // Keep the initial room textures resident between the welcome screen and
    // scene creation. The progress bar completes only after SpriteKit is ready.
    private static var welcomeTextures: [SKTexture]?
    private static var welcomePreloadTask: Task<Void, Never>?

    static func preloadWelcomeResources() async {
        guard welcomeTextures == nil else { return }
        if let welcomePreloadTask { await welcomePreloadTask.value; return }
        let task = Task {
#if DEBUG
            welcomePreloadPassCount += 1
#endif
            let names = ["room-empty", "room-floor-wood", "room-wall-plaster", "room-window-arched", "bowl-empty", "bowl-full", "icon-play"]
                + CatAppearance.allCases.flatMap { appearance in
                    (["cat-idle"] + CatClip.allCases.map(\.rawValue)).map {
                        CatArtwork.asset($0, appearance: appearance)
                    }
                }
                + FurnitureKind.allCases.map { FurnitureCatalog.metadata(for: $0).assetName }
            let textures = Set(names).sorted().map { SKTexture(imageNamed: $0) }
            // Serial requests avoid SpriteKit's cold-load setup racing across worker queues.
            for texture in textures {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    SKTexture.preload([texture]) { continuation.resume() }
                }
            }
            await CatSpriteLibrary.preload()
            welcomeTextures = textures
        }
        welcomePreloadTask = task
        await task.value
        welcomePreloadTask = nil
    }

#if DEBUG
    private(set) static var welcomePreloadPassCount = 0
    static var welcomeResourcesReadyForTests: Bool { welcomeTextures?.isEmpty == false }

    static func resetWelcomeResourcesForTests() async {
        await welcomePreloadTask?.value
        welcomeTextures = nil
        welcomePreloadPassCount = 0
    }
#endif

    var onCatTapped: (() -> Void)?
    var onResidentTapped: ((String) -> Void)?
    var onBackgroundTapped: (() -> Void)?
    var onVisibleResidentsChanged: ((Set<String>) -> Void)?
    private var lastVisibleResidents: Set<String>?
    var inspectedResidentID: String?
    var onInspectedResidentFrameChanged: ((CGRect?) -> Void)?
    private var inspectionFrameSampler = CatVisualFrameSampler()
    var homeFloor: HomeFloor = .ground
    let residents = RoomResidentCats()
    var onFloorTravelAvailabilityChanged: ((Bool) -> Void)?
    private var lastFloorTravelAvailability: Bool?
    var onCatNeedAnchorChanged: ((CGPoint?) -> Void)? {
        didSet { needAnchorSampler = CatNeedAnchorSampler(); updateThought() }
    }
    private var needAnchorSampler = CatNeedAnchorSampler()
    var onCatVisualFrameChanged: ((CGRect?) -> Void)? {
        didSet { visualFrameSampler = CatVisualFrameSampler() }
    }
    private var visualFrameSampler = CatVisualFrameSampler()
    var onArrangementFrameChanged: ((CGRect?) -> Void)? {
        didSet { arrangementFrameSampler = CatVisualFrameSampler() }
    }
    private var arrangementFrameSampler = CatVisualFrameSampler()
    var canShowCatNeed: Bool {
        presentationActive && !editing && !presentationBusy && (!cat.isPerforming || residents.isStrolling)
            && !cat.isHidden && bowlPlanningRequest == nil && !residents.isPreparing
    }
    var canInspectResidents: Bool { canShowCatNeed && activeRest == nil && !floorTravelCareActive }

    func residentFrame(id: String) -> CGRect? {
        let actor = id == renderedCatID ? cat : residents.actors[id]
        guard let actor, !actor.isHidden, view != nil else { return nil }
        return roomPresentation.frame(id == renderedCatID ? "cat" : "resident-" + id)
    }
    var onFurnitureSelected: ((String?) -> Void)?
    var onFurnitureMoved: ((String, NormalizedPoint) -> Void)?
    var onFurniturePlacementFinished: ((String, Bool) -> Void)?
    var furnitureNodes: [String: SKSpriteNode] { artwork.furnitureNodes }
    private var ownedFurniture = FurnitureCatalog.defaultItems
    private var renderedFurniture = FurnitureCatalog.defaultPlacements
    var selectedFurnitureID: String?
    var newPlacementID: String?
    private var lastPlacingRequest: String?
    var placementPrepared = false
    var onRestingFurnitureChanged: ((String?, String, String) -> Void)?
    var onFurnitureNotice: ((String) -> Void)?
    var activeRest: RoomFurnitureRest?
    // A visual visit starts on approach, but recovery starts only after all
    // paws have settled. The token also keeps stale exits away from a new save.
    private var restSessionID: String?
    private var restSessionWasCommitted = false
    private var restEndReported = false
    private var restDeadline: Date?
    private var restDeadlineTask: Task<Void, Never>?
    var presentationActive = true
    private var restPlanningTask: Task<RoomFurnitureRest?, Never>?
    private var restExiting = false
    var pendingRestID: String?
    private var requestedSelectionID: String?
    private var requestedPlacementID: String?
    private var lastRestFinished = Date.distantPast
    var deferredRoomLayoutFromSize: CGSize?
    var renderedRoomLevel = 1
    private let roomCameraNode = SKCameraNode()
    let roomPresentation = RoomPresentationRenderer()
    var onRoomViewChanged: (() -> Void)?
    private var lastRoomViewState = ""
    private var lastRoomViewTick: TimeInterval?
    private var followsPresentedCat = false
    var dragScreenPoint: CGPoint?
    weak var sceneTouch: UITouch?
    var blockedTouchSequence = false
    private var restFront: SKSpriteNode { artwork.restFront }
    var onBowlTapped: (() -> Void)?
    var onPlacementPendingChanged: ((Bool) -> Void)?
    private(set) var isPlacementPending = false
    var onBowlMoved: ((NormalizedPoint) -> Void)?
    private(set) var presentationPhase = "idle"
    var reducedMotion = false {
        didSet {
            guard reducedMotion != oldValue else { return }
            if reducedMotion { artwork.finishOrientationAnimations() }
            residents.invalidate()
            cancelCameraInteraction()
            if activeRest != nil { leaveFurnitureRest(); return }
            cancelPresentation(at: cat.position)
            cat.reducedMotion = reducedMotion
            resumeIdle()
        }
    }
    private let artwork = RoomSceneArtwork()
    private var room: SKSpriteNode { artwork.room }
    let cat = CatActor()
    var bowl: SKSpriteNode { artwork.bowl }
    private var toy: SKSpriteNode { artwork.toy }
    private var selection: SKShapeNode { artwork.selection }
    private var thought: SKNode { artwork.thought }
    private var latest: GameSnapshot?
    private var renderedCatID: String? = CatCatalog.initialCatID
    var editing = false
    var dragging = false
    var touchOrigin: CGPoint?
    var dragOffset = CGPoint.zero
    private var catWidth: CGFloat = 120
    private var presentationBusy = false
    private var pendingFeedback: ActionKind?
    private var floorTravelCareActive = false
    private var carePlanningTask: Task<RoomCarePlanningResult, Never>?
    private var planningCareKind: ActionKind?
    private var suspendedCareKind: ActionKind?
    private var revision = 0
    private var hasCommittedLayout = false
    private var renderedViewportSize: CGSize?
    var floor: RoomFloor?
    private var navigation: RoomNavigation?
    var placementNavigation: RoomNavigation?
    var placementTask: Task<RoomFurnitureResolution?, Never>?
    var placementRevision = 0
    var committedBowlPosition = CGPoint.zero
    private var lastRequestedBowlPoint: CGPoint?
    private let layoutPlanning = RoomLayoutPlanning()
    var bowlPlanningRequest: RoomBowlPlanner? { layoutPlanning.proposal?.planner }
    private var activeFeedingDock: FeedingDock?
    private var activeFeedingStage: CGPoint?
    private var dockingNavigation: RoomNavigation?
#if DEBUG
    let diagnostics = RoomSceneDiagnostics()
    private var bowlHasFood = false
#endif

    private var artworkTransform: RoomArtworkTransform {
        // SpriteKit updates scene.size before didChangeSize. An occupied room
        // keeps every furniture query/node in the old world until safe exit.
        RoomArtworkTransform(sceneSize: worldGeometry.worldSize,
                             artworkSize: room.texture?.size() ?? CGSize(width: 1024, height: 1536),
                             viewportSize: worldGeometry.viewportSize)
    }

    private var worldGeometry: RoomWorldGeometry {
        RoomWorldGeometry(viewportSize: renderedViewportSize ?? size,
                          worldScale: CGFloat(HomeCatalog.level(renderedRoomLevel)?.worldScale ?? 1))
    }

    var furnitureWorld: RoomFurnitureWorld {
        RoomFurnitureWorld(transform: artworkTransform, catWidth: catWidth, bowlSize: bowl.size,
                           bowlPosition: bowl.position, items: ownedFurniture, placements: renderedFurniture)
    }

    override init(size: CGSize) {
        super.init(size: size)
        cat.onSound = { [weak self] sound in self?.onSound?(sound) }
        residents.onFinished = { [weak self] in
            guard let self, self.presentationActive else { return }
            self.finishPresentation()
        }
        residents.onLimitedSpace = { [weak self] in
            self?.onFurnitureNotice?("room.sharedHomeNoSpace")
        }
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.98, green: 0.95, blue: 0.89, alpha: 1)
        artwork.install(in: self)
        addChild(roomCameraNode)
        camera = roomCameraNode
        roomCameraNode.addChild(roomPresentation.root)
        cat.name = "cat"
        cat.zPosition = 20
        addChild(cat)
        layoutRoom()
    }
    required init?(coder aDecoder: NSCoder) { fatalError("RoomScene is created in code") }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // SwiftUI/SpriteKit can report the same canvas with floating-point noise;
        // reappearing over a sheet must not cancel an active meal or its queue.
        guard abs(oldSize.width - size.width) > 0.001
            || abs(oldSize.height - size.height) > 0.001 else { return }
#if DEBUG
        diagnostics.recordPresentationEvent("resize \(oldSize) -> \(size), active=\(presentationActive)")
#endif
        cancelCameraInteraction()
        if activeRest != nil, deferredRoomLayoutFromSize == nil,
           oldSize.width > 0, oldSize.height > 0 {
            deferredRoomLayoutFromSize = oldSize
        }
        guard size.width > 0, size.height > 0 else {
            cancelBowlPlanning(keepingRequest: true)
            cancelPlacementPreview()
            if carePlanningTask != nil || suspendedCareKind != nil { cancelPresentation(at: cat.position) }
            return
        }
        if let floor {
            roomPresentation.configure(world: worldGeometry.worldSize, viewport: size,
                floor: floor.polygon, angle: roomViewAngle, level: renderedRoomLevel, homeFloor: homeFloor)
        }
        if activeRest != nil {
            // Nodes and navigation still use the old canvas. Walk out in that
            // world first, then remap the complete room together.
            leaveFurnitureRest()
            return
        }
        // Opening the arrangement panel changes the canvas height. Keep a
        // newly requested bag item alive while its worker is rebuilt for it.
        let pendingItem = newPlacementID
        deferredRoomLayoutFromSize = nil
        layoutRoom(preservingPositionFrom: worldGeometry.worldSize, preservingNewPlacement: pendingItem != nil)
        // The preview worker needs the new-size bowl/navigation result first.
        // apply() resumes the still-requested bag item after that result lands.
        if pendingItem != nil { lastPlacingRequest = nil }
    }
    override func update(_ currentTime: TimeInterval) {
        publishFloorTravelAvailability()
        let viewDelta = currentTime - (lastRoomViewTick ?? currentTime)
        lastRoomViewTick = currentTime
        updateRoomEdgeScrolling(delta: viewDelta)
        let frame = cat.visualFrame
        thought.position = CGPoint(x: frame.midX + catWidth * 0.30, y: frame.maxY + 30)
        // A smaller y is nearer the camera. The bowl is anchored at its base,
        // not the center of its tall texture.
        cat.zPosition = 1_000 - cat.position.y
        residents.updateDepths()
        if !editing, bowlPlanningRequest == nil, !residents.isPreparing, !cat.isHidden, let renderedCatID {
            let visible = Set(residents.actors.filter { !$0.value.isHidden }.keys).union([renderedCatID])
            if visible != lastVisibleResidents { lastVisibleResidents = visible; onVisibleResidentsChanged?(visible) }
        }
        updateBowlLayers()
        updateFurnitureLayers()
        toy.zPosition = 1_001 - toy.position.y
        thought.zPosition = 2_000
        if let onCatNeedAnchorChanged {
            // SpriteKit conversion includes camera pan, zoom and scene resize.
            let displayed = roomPresentation.frame("cat")
            let anchor = canShowCatNeed && view != nil
                ? displayed.map { CGPoint(x: $0.midX, y: $0.minY) } : nil
            if needAnchorSampler.sample(anchor, at: currentTime) { onCatNeedAnchorChanged(anchor) }
        }
        if let onCatVisualFrameChanged {
            var projected: CGRect?
            if presentationActive, !cat.isHidden, view != nil {
                projected = roomPresentation.frame("cat")
            }
            if visualFrameSampler.sample(projected, at: currentTime) { onCatVisualFrameChanged(projected) }
        }
        if let onArrangementFrameChanged {
            var projected: CGRect?
            if editing, presentationActive, !dragging, !isPlacementPending, view != nil {
                projected = roomPresentation.frame(selectedFurnitureID.map { "furniture-" + $0 } ?? "bowl")
            }
            if arrangementFrameSampler.sample(projected, at: currentTime) { onArrangementFrameChanged(projected) }
        }
#if DEBUG
        if bowlPlanningRequest == nil, !editing,
           !residents.isBusy || cat.isPerforming || residents.actors.values.contains(where: \.isPerforming) {
            diagnostics.sampleResidents(residents, cat: cat, floor: floor, dock: activeFeedingDock)
        }
        if bowlPlanningRequest == nil, diagnostics.enabled,
           diagnostics.sample(at: currentTime, cat: cat, floor: floor, navigation: navigation,
                              activeRest: activeRest, editing: editing, activeFeedingDock: activeFeedingDock,
                              dockingNavigation: dockingNavigation, furnitureWorld: furnitureWorld,
                              renderedFurniture: renderedFurniture, bowl: bowl.position) {
            publishNavigationStatus()
            publishDragMetrics()
            publishFurnitureStatus()
        }
#endif
    }
    override func didFinishUpdate() {
        super.didFinishUpdate()
        updateRoomPresentation()
    }

    func updateRoomPresentation() {
        artwork.updateCompanionMarker(cat: cat, name: latest?.activeCat.map(GameStrings.catName) ?? "",
                                      hidden: editing || cat.isHidden, reducedMotion: reducedMotion)
        if followsPresentedCat && presentationBusy && !editing {
            roomPresentation.camera.follow(roomPresentation.projection.project(cat.position))
        }
        roomPresentation.update(cat: cat, residents: residents, furniture: furnitureNodes,
            items: ownedFurniture, bowl: bowl, bowlFront: artwork.bowlFront, restFront: restFront,
            selection: artwork.selection, toy: toy, feeding: presentationPhase == "feeding", rest: activeRest,
            selectedID: selectedFurnitureID, particles: children.filter { $0.name == "care-particle" },
            companionRing: artwork.companionRing, companionPlaque: artwork.companionPlaque)
        let state = "\(roomViewAngle.rawValue)|\(isWholeRoomView)|\(canChangeRoomView)"
        if state != lastRoomViewState {
            lastRoomViewState = state
            inspectionFrameSampler = CatVisualFrameSampler()
            onRoomViewChanged?()
        }
        if let onInspectedResidentFrameChanged {
            let frame = canInspectResidents ? inspectedResidentID.flatMap { residentFrame(id: $0) } : nil
            if inspectionFrameSampler.sample(frame, at: lastRoomViewTick ?? 0) { onInspectedResidentFrameChanged(frame) }
        }
    }

    func beginRoomFollowing() { followsPresentedCat = true }
    func suspendRoomFollowing() { followsPresentedCat = false }
    func apply(snapshot: GameSnapshot, editing: Bool, selectedFurnitureID selected: String? = nil,
               placingFurnitureID placing: String? = nil) {
        let companionChanged = renderedCatID != snapshot.activeCatID
        if companionChanged {
            residents.invalidate()
            // Invalidate old paths, queued care and rest callbacks before changing identity.
            // First load has no prior owner; keep its initial bowl planning intact.
            if latest != nil { cancelPresentation(at: cat.position) }
            if let position = residents.exchangeActive(from: latest?.activeCat, to: snapshot.activeCat, at: cat.position) {
                cat.cancelAndSettle(at: position)
            }
            renderedCatID = snapshot.activeCatID
            cat.setAppearance(snapshot.activeCat?.appearance ?? .orange)
        }
        latest = snapshot
        requestedSelectionID = selected
        requestedPlacementID = placing
        if companionChanged, deferredRoomLayoutFromSize != nil,
           size.width > 0, size.height > 0 {
            deferredRoomLayoutFromSize = nil
            layoutRoom(preservingPositionFrom: worldGeometry.worldSize)
        }
        // Keep the occupied world frozen until the cat has walked out. The
        // panel may open immediately, but no furniture can move or be stored.
        if activeRest != nil {
            self.editing = editing
            view?.preferredFramesPerSecond = editing ? 60 : 30
            if editing || snapshot.home.roomLevel != renderedRoomLevel {
                pendingRestID = nil
                setPlacementPending(true)
#if DEBUG
                if !restExiting { recordRestInterruption(reason: "decorate") }
#endif
                leaveFurnitureRest(reason: editing ? "interaction" : "room-upgrade")
            } else {
                setPlacementPending(false)
                reconcileRestSession()
            }
            return
        }
        let modeChanged = self.editing != editing
        if modeChanged {
            residents.invalidate(hide: editing)
            self.editing = editing
            cancelBowlPlanning(keepingRequest: false)
            lastRequestedBowlPoint = nil
            cancelPlacementPreview()
            view?.preferredFramesPerSecond = editing ? 60 : 30
            cancelPresentation(at: cat.position)
            setPhase(editing ? "editing" : "idle")
            placementPrepared = false
        }
        if applyPendingRoomExpansion() { return }
        if !isPlacementPending || bowlPlanningRequest != nil {
            // Buying or changing a stored item cannot interrupt committed care.
            // Only placed items contribute artwork, obstacles and navigation.
            let pending = layoutPlanning.proposal
            let placements = pending?.placements ?? renderedFurniture
            let items = pending?.items ?? ownedFurniture
            let geometry = pending?.geometry ?? worldGeometry
            let furnitureChanged = placements != snapshot.home.furniture
                || snapshot.home.furniture.contains { placement in
                    items.first { $0.id == placement.itemID }
                        != snapshot.inventory.furniture.first { $0.id == placement.itemID }
                }
            let proposed = CGPoint(x: geometry.worldSize.width * snapshot.home.bowlPosition.x,
                                   y: geometry.worldSize.height * (1 - snapshot.home.bowlPosition.y))
            if (pending?.planner.requested ?? lastRequestedBowlPoint) != proposed || furnitureChanged
                || (pending.map { $0.roomLevel != snapshot.home.roomLevel } ?? false) {
                layoutRoom(preservingPositionFrom: worldGeometry.worldSize)
            } else if pending == nil {
                ownedFurniture = snapshot.inventory.furniture
            }
        }
        if self.selectedFurnitureID != selected && !dragging {
            self.selectedFurnitureID = selected
            placementPrepared = false
        }
        if editing && !isPlacementPending { preparePlacementNavigation() }
        if placing == nil { lastPlacingRequest = nil }
        if editing, bowlPlanningRequest == nil, let placing, placing != lastPlacingRequest {
            lastPlacingRequest = placing
            startPlacingFurniture(placing)
        }
        updateSelection()
        updateThought()
#if DEBUG
        publishFurnitureStatus()
#endif
        if !presentationBusy { resumeIdle() }
    }

    private func synchronizeFurnitureNodes() {
        artwork.synchronizeFurniture(items: ownedFurniture, placements: renderedFurniture,
                                     keeping: newPlacementID, transform: artworkTransform,
                                     animateOrientation: editing && !reducedMotion)
        updateFurnitureLayers()
    }

    private func furnitureNode(for item: FurnitureItem) -> SKSpriteNode {
        artwork.furnitureNode(for: item, transform: artworkTransform)
    }

    func updateFurnitureLayers() {
        artwork.updateFurnitureLayers(items: ownedFurniture, cat: cat, activeRest: activeRest)
    }

    var selectedNode: SKSpriteNode {
        selectedFurnitureID.flatMap { furnitureNodes[$0] } ?? bowl
    }

    func preparePlacementNavigation() {
        guard editing, bowlPlanningRequest == nil, !placementPrepared else { return }
        placementNavigation = furnitureWorld.placementNavigator(for: selectedFurnitureID, catAt: cat.position)
        placementPrepared = true
    }

    private func startPlacingFurniture(_ id: String) {
        guard bowlPlanningRequest == nil else { return }
        guard let item = ownedFurniture.first(where: { $0.id == id }),
              !renderedFurniture.contains(where: { $0.itemID == id }) else {
            onFurniturePlacementFinished?(id, false)
            return
        }
        cancelPlacementPreview()
        newPlacementID = id
        selectedFurnitureID = id
        let node = furnitureNode(for: item)
        let preferred = FurnitureCatalog.defaultPlacements.first { $0.itemID == id }?.position ?? .init(x: 0.62, y: 0.65)
        node.position = worldGeometry.worldScale > 1
            ? (RoomFurnitureSpec.forItem(item).isWall
                ? roomPresentation.projection.unprojectWallPoint(roomPresentation.camera.center)
                : roomPresentation.projection.unproject(roomPresentation.camera.center))
            : artworkTransform.point(preferred)
        node.alpha = 0.75
        placementPrepared = false
        preparePlacementNavigation()
        setPlacementPending(true)
        resolveReleasedItem()
        updateSelection()
    }

    func restInFurniture(kind: FurnitureKind) {
        guard let item = ownedFurniture.first(where: { item in
            item.kind == kind && renderedFurniture.contains { $0.itemID == item.id }
        }) else { onFurnitureNotice?("rest.noFurniture"); return }
        visitFurniture(item.id)
    }

    func visitFurniture(_ id: String, notify: Bool = true) {
#if DEBUG
        diagnostics.lastRestInput = "requested:" + id
#endif
        guard !editing, let item = ownedFurniture.first(where: { $0.id == id }),
              [.catBed, .floorCushion].contains(item.kind),
              renderedFurniture.contains(where: { $0.itemID == id }) else { return }
        if bowlPlanningRequest != nil || residents.isBusy { pendingRestID = id; return }
        if let occupied = activeRest {
            pendingRestID = occupied.item.id == id ? nil : id
            leaveFurnitureRest()
            return
        }
        if presentationBusy && presentationPhase != "strolling" && restPlanningTask == nil {
            pendingRestID = id
            return
        }
        cancelPresentation(at: cat.position)
        beginRoomFollowing()
        cat.setIdleEnabled(false)
        presentationBusy = true
        setPhase("rest-approach")
        updateThought()
        let ticket = revision
        let world = furnitureWorld
        let origin = cat.position
        let otherCats = residents.obstacles
        let worker = Task.detached(priority: .userInitiated) {
            world.restVisit(to: id, from: origin, additionalObstacles: otherCats)
        }
        restPlanningTask = worker
        Task { [weak self] in
            let visit = await worker.value
            guard let self, self.revision == ticket, !self.editing else { return }
            self.restPlanningTask = nil
            guard let visit else {
#if DEBUG
                self.diagnostics.lastRestInput = "blocked:" + id
#endif
                self.lastRestFinished = Date()
                if notify { self.onFurnitureNotice?("rest.blocked") }
                self.finishPresentation()
                return
            }
            self.activeRest = visit
            self.resetRestSession()
#if DEBUG
            self.diagnostics.lastRestInput = "ready:" + id
#endif
            self.restExiting = false
#if DEBUG
            self.noteRoute(visit.plan.approach)
#endif
            if let texture = self.furnitureNodes[id]?.texture, item.kind == .catBed {
                self.restFront.texture = SKTexture(rect: CGRect(x: 0, y: 0, width: 1, height: 0.22), in: texture)
            }
            if notify { self.onFurnitureNotice?(item.kind == .catBed ? "rest.goBed" : "rest.goCushion") }
            self.cat.rest(approach: visit.plan.approach, entry: visit.plan.entry,
                          facing: visit.plan.facing, duration: item.kind == .catBed ? 12 : 9,
                          elevation: visit.elevation, contactProgress: visit.entryContactProgress,
                          onSettled: { [weak self] in
                guard let self, self.revision == ticket, !self.restExiting else { return }
                let sessionID = UUID().uuidString
                self.restSessionID = sessionID
                // The committed save supplies the authoritative deadline. This
                // fallback only ends a visual stay if its start cannot be saved.
                self.restDeadline = Date().addingTimeInterval(item.kind == .catBed ? 12 : 9)
                self.setPhase("resting")
                if let catID = self.renderedCatID {
                    self.onRestingFurnitureChanged?(id, sessionID, catID)
                }
                self.reconcileRestSession()
#if DEBUG
                self.publishFurnitureStatus()
#endif
            }, completion: { [weak self] in
                guard let self, self.revision == ticket else { return }
                guard self.restSessionID != nil else {
                    self.leaveFurnitureRest(reason: "not-settled")
                    return
                }
                // SpriteKit time pauses in the background. It never decides
                // recovery or rest duration; the absolute session deadline does.
                self.reconcileRestSession()
            })
        }
    }

    /// Resume the existing pose without replaying its full sleep after a pause.
    /// Called before unpausing SKView and from onAppear for a retained scene.
    func setPresentationActive(_ active: Bool) {
        presentationActive = active
        if !active {
            needAnchorSampler = CatNeedAnchorSampler()
            visualFrameSampler = CatVisualFrameSampler()
            arrangementFrameSampler = CatVisualFrameSampler()
            cancelCameraInteraction()
            cancelBowlPlanning(keepingRequest: true)
            if residents.isStrolling {
                residents.invalidate()
                cat.cancelAndSettle(at: cat.position)
            }
        }
        if !active, let kind = planningCareKind {
            // A worker cannot start SpriteKit actions behind Settings or while
            // backgrounded. Retain this committed action and its pending follow-up.
            revision += 1
            cancelCarePlanning()
            suspendedCareKind = kind
        }
        if active {
            if bowlPlanningRequest != nil {
                startBowlPlanning()
                return
            }
            if let kind = suspendedCareKind, !editing {
                suspendedCareKind = nil
                presentationBusy = false
                prepareResidents()
                playFeedback(kind: kind)
            }
            reconcileRestSession()
            // A paused stroll may stop in a care corridor; validate those positions before draining care.
            if !presentationBusy { prepareResidents() }
            if !presentationBusy, !residents.isBusy, pendingFeedback != nil || pendingRestID != nil {
                finishPresentation()
            } else if !presentationBusy { resumeIdle() }
        }
    }

    private func reconcileRestSession(now: Date = Date()) {
        guard let visit = activeRest, !restExiting, let sessionID = restSessionID else { return }
        let committed = latest?.activeCat?.activeRest
        if committed?.id == sessionID, committed?.furnitureID == visit.item.id {
            restSessionWasCommitted = true
            restDeadline = committed?.endsAt
        } else if restSessionWasCommitted {
            // An absent state before the first successful save is expected.
            // Only a previously observed matching session can be revoked here.
            restDeadlineTask?.cancel()
            restDeadlineTask = nil
            if presentationActive { leaveFurnitureRest(reason: "session-ended") }
            return
        }
        guard let deadline = restDeadline else { return }
        restDeadlineTask?.cancel()
        restDeadlineTask = nil
        guard deadline > now else {
            if presentationActive {
                leaveFurnitureRest(reason: restSessionWasCommitted ? "deadline" : "unsaved-timeout")
            }
            return
        }
        // This task changes presentation only. The core awards energy from
        // elapsed wall-clock time, independently of frames and this timer.
        restDeadlineTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(deadline.timeIntervalSince(now))) }
            catch { return }
            guard let self, self.restSessionID == sessionID, !self.restExiting else { return }
            self.restDeadlineTask = nil
            self.reconcileRestSession()
        }
    }

    private func reportRestEnded() {
        restDeadlineTask?.cancel()
        restDeadlineTask = nil
        guard let sessionID = restSessionID, !restEndReported else { return }
        restEndReported = true
        if let catID = renderedCatID { onRestingFurnitureChanged?(nil, sessionID, catID) }
    }

    private func resetRestSession() {
        restDeadlineTask?.cancel()
        restDeadlineTask = nil
        restSessionID = nil
        restSessionWasCommitted = false
        restEndReported = false
        restDeadline = nil
    }

    func leaveFurnitureRest(reason: String = "interaction") {
        guard let visit = activeRest, !restExiting else { return }
        let path: [CGPoint]
        if !cat.isEnteringFurniture, navigation?.isWalkable(cat.position) == true {
            // An interrupted approach is already on ordinary walkable ground.
            path = [cat.position]
        } else {
            guard navigation?.isWalkable(visit.plan.stage) == true,
                  visit.navigation.segmentIsWalkable(from: cat.position, to: visit.plan.stage) else {
                onFurnitureNotice?("rest.blocked")
                return
            }
            path = [cat.position, visit.plan.stage]
        }
        revision += 1
        let ticket = revision
        restExiting = true
#if DEBUG
        diagnostics.lastRestEndReason = reason
#endif
        setPhase("rest-exit")
        reportRestEnded()
        let atSafeStage = navigation?.isWalkable(cat.position) == true
            && hypot(cat.position.x - visit.plan.stage.x, cat.position.y - visit.plan.stage.y) < 0.5
        cat.leaveRest(along: path, atSafeStage: atSafeStage) { [weak self] in
            guard let self, self.revision == ticket else { return }
#if DEBUG
            self.diagnostics.restExits += 1
#endif
            self.lastRestFinished = Date()
            self.activeRest = nil
            self.resetRestSession()
            self.restExiting = false
            self.restFront.isHidden = true
            self.presentationBusy = false
            self.cat.reducedMotion = self.reducedMotion
            let nextCare = self.pendingFeedback
            let nextRest = self.pendingRestID
            self.pendingFeedback = nil
            self.pendingRestID = nil
            self.setPlacementPending(false)
            self.setPhase(self.editing ? "editing" : "idle")
            if self.deferredRoomLayoutFromSize != nil,
               self.size.width > 0, self.size.height > 0 {
                self.deferredRoomLayoutFromSize = nil
                self.layoutRoom(preservingPositionFrom: self.worldGeometry.worldSize)
            }
            if let snapshot = self.latest {
                self.apply(snapshot: snapshot, editing: self.editing,
                           selectedFurnitureID: self.requestedSelectionID,
                           placingFurnitureID: self.requestedPlacementID)
            }
            self.updateFurnitureLayers()
            if !self.editing {
                if let nextCare { self.playFeedback(kind: nextCare) }
                else if let nextRest { self.visitFurniture(nextRest) }
                else { self.resumeIdle() }
            }
#if DEBUG
            self.publishFurnitureStatus()
#endif
        }
#if DEBUG
        publishFurnitureStatus()
#endif
    }

#if DEBUG
    private func recordRestInterruption(reason: String) {
        guard activeRest != nil, !restExiting else { return }
        diagnostics.lastRestInterrupt = ["reason": reason, "restPhase": cat.restPhase.rawValue,
                             "stepPhase": cat.stepPhase.rawValue, "stepProgress": cat.stepProgress]
    }
#endif

    func playFeedback(kind: ActionKind, catID: String? = nil) {
        defer { publishFloorTravelAvailability() }
        guard catID == nil || catID == renderedCatID else { return }
        guard [.feed, .clean, .play].contains(kind), !editing else { return }
        if bowlPlanningRequest != nil {
            if suspendedCareKind == nil { suspendedCareKind = kind }
            else { pendingFeedback = kind }
            return
        }
        guard presentationActive else {
            if presentationBusy || suspendedCareKind != nil { pendingFeedback = kind }
            else { suspendedCareKind = kind; presentationBusy = true }
            return
        }
        if activeRest != nil {
#if DEBUG
            recordRestInterruption(reason: kind.rawValue)
#endif
            pendingFeedback = kind
            pendingRestID = nil
            leaveFurnitureRest()
            return
        }
        if residents.isBusy { pendingFeedback = kind; return }
        if restPlanningTask != nil { cancelPresentation(at: cat.position) }
        if presentationBusy || cat.isPerforming {
            // Coalesce presentation only; each successful game action was saved.
            pendingFeedback = kind
            return
        }
        removeAction(forKey: "ambient-walk")
        floorTravelCareActive = true
        presentationBusy = true
        beginRoomFollowing()
        cat.setIdleEnabled(false)
        revision += 1
        let ticket = revision
        let returnPoint = cat.position
        let completion: () -> Void = { [weak self] in
            guard let self, self.revision == ticket else { return }
            self.finishPresentation()
        }
        if kind == .clean {
            setPhase("cleaning")
            showCareParticles()
            cat.clean(returnTo: returnPoint, completion: completion)
        } else {
            setPhase(kind == .feed ? "feeding" : "playing")
            if kind == .feed { setBowlTexture("bowl-full") }
            guard let floor, let navigation else {
                cat.clean(returnTo: returnPoint, completion: completion)
                return
            }
            let careFloor = floor.addingObstacles(residents.obstacles)
            let careNavigation = residents.obstacles.isEmpty ? navigation : careFloor.navigator(bowlAt: bowl.position, precomputeGrid: false)
            let planner = RoomCarePlanner(floor: careFloor, navigation: careNavigation, origin: returnPoint,
                                          bowl: bowl.position, catWidth: catWidth)
#if DEBUG
            let args = ProcessInfo.processInfo.arguments
            let slowTest = args.contains("--ui-testing") && args.contains("--slow-care-planning-test")
            diagnostics.carePlanning = true
#endif
            let worker = Task.detached(priority: .userInitiated) {
#if DEBUG
                if slowTest { try? await Task.sleep(for: .seconds(3)) }
#endif
                return planner.plan(kind)
            }
            planningCareKind = kind
            carePlanningTask = worker
            Task { [weak self] in
                let result = await worker.value
                guard let self, self.revision == ticket, !self.editing, self.presentationActive,
                      self.planningCareKind == kind else { return }
                self.carePlanningTask = nil
                self.planningCareKind = nil
#if DEBUG
                self.diagnostics.carePlanning = false
                self.diagnostics.carePlanCompletions += 1
                self.diagnostics.lastCarePlanMilliseconds = result.milliseconds
                self.diagnostics.lastCarePlanOnMainThread = result.ranOnMainThread
#endif
                self.performCarePlan(result.plan, returningTo: returnPoint, ticket: ticket, completion: completion)
            }
        }
        updateThought()
    }

    private func performCarePlan(_ plan: RoomCarePlan?, returningTo returnPoint: CGPoint,
                                 ticket: Int, completion: @escaping () -> Void) {
        switch plan {
        case .feed(let plan):
#if DEBUG
            noteRoute(plan.path)
#endif
            activeFeedingDock = plan.dock
            activeFeedingStage = plan.dockingPath.first
            dockingNavigation = plan.dockingNavigation
            cat.feed(at: plan.dock.eatingPoint, facing: plan.facing, approach: plan.path,
                     dockingPath: plan.dockingPath, returnPath: Array(plan.path.reversed()),
                     onMealFinished: { [weak self] in
                         guard let self, self.revision == ticket else { return }
                         self.setBowlTexture("bowl-empty")
                     }, completion: completion)
        case .play(let plan):
#if DEBUG
            noteRoute(plan.approach)
#endif
            toy.position = CGPoint(x: plan.landing.x + plan.facing * catWidth * 0.18,
                                   y: plan.landing.y + toy.size.height * 0.24)
            toy.alpha = reducedMotion ? 1 : 0
            toy.zRotation = -0.15
            toy.isHidden = false
            if !reducedMotion { toy.run(.group([.fadeIn(withDuration: 0.16), .rotate(toAngle: 0.12, duration: 0.45)])) }
            let pounce: () -> Void = { [weak self] in
                guard let self, self.revision == ticket else { return }
                self.cat.play(landing: plan.landing, facing: plan.facing,
                              returnPath: plan.returnPath, completion: completion)
            }
            if !reducedMotion, plan.approach.count > 1 { cat.stroll(along: plan.approach, completion: pounce) }
            else { pounce() }
        case nil:
            // A legacy layout can have no safe approach. Preserve the existing
            // stationary response rather than inventing a path through objects.
            cat.clean(returnTo: returnPoint, completion: completion)
        }
    }

    private func cancelCarePlanning() {
#if DEBUG
        if carePlanningTask != nil { diagnostics.carePlanCancelled += 1 }
        diagnostics.carePlanning = false
#endif
        carePlanningTask?.cancel()
        carePlanningTask = nil
        planningCareKind = nil
    }

    private func setBowlTexture(_ name: String) {
        artwork.setBowlTexture(name)
#if DEBUG
        bowlHasFood = name == "bowl-full"
#endif
        updateBowlLayers()
    }

    func updateBowlLayers() { artwork.updateBowlLayers(cat: cat, floor: floor) }

    private func finishPresentation() {
        floorTravelCareActive = false
        presentationBusy = false
        activeFeedingDock = nil
        activeFeedingStage = nil
        dockingNavigation = nil
        setBowlTexture("bowl-empty")
        toy.removeAllActions()
        toy.isHidden = true
        setPhase(editing ? "editing" : "idle")
        if applyPendingRoomExpansion() { return }
        if let next = pendingFeedback, !editing {
            pendingFeedback = nil
            playFeedback(kind: next)
        } else if let id = pendingRestID, !editing {
            pendingRestID = nil
            visitFurniture(id)
        } else {
            pendingFeedback = nil
            resumeIdle()
        }
        updateThought()
    }
    private func cancelPresentation(at point: CGPoint) {
        floorTravelCareActive = false
#if DEBUG
        diagnostics.recordPresentationEvent("cancel \(presentationPhase), active=\(presentationActive), size=\(size)")
#endif
        revision += 1
        cancelCarePlanning()
        suspendedCareKind = nil
        let wasOccupyingFurniture = activeRest != nil
        restPlanningTask?.cancel()
        restPlanningTask = nil
        pendingRestID = nil
        pendingFeedback = nil
        removeAction(forKey: "ambient-walk")
        // Editing/reduced-motion can interrupt a bite. Restore the known-safe
        // stage before switching back to the larger, directionless walk body.
        let stage = activeFeedingStage.flatMap { navigation?.isWalkable($0) == true ? $0 : nil }
        let restStage = cat.isEnteringFurniture ? activeRest?.plan.stage : nil
        let settled = restStage ?? (cat.isDockingForMeal ? (stage ?? navigation?.nearestWalkable(to: point) ?? point) : point)
        activeRest = nil
        restExiting = false
        restFront.isHidden = true
        // Routine room refreshes also pass here. They must not emit an end for
        // a newly queued or unrelated session that this scene never started.
        reportRestEnded()
        resetRestSession()
        if wasOccupyingFurniture { setPlacementPending(false) }
        cat.setIdleEnabled(false)
        cat.cancelAndSettle(at: settled)
        presentationBusy = false
        activeFeedingDock = nil
        activeFeedingStage = nil
        dockingNavigation = nil
        setBowlTexture("bowl-empty")
        toy.removeAllActions()
        toy.isHidden = true
        enumerateChildNodes(withName: "care-particle") { node, _ in node.removeFromParent() }
        setPhase(bowlPlanningRequest != nil ? "layout-planning" : (editing ? "editing" : "idle"))
    }
    private var residentPlanner: RoomResidentPlanner? {
        guard let floor else { return nil }
        return RoomResidentPlanner(floor: floor, bowl: bowl.position, world: furnitureWorld,
                                   active: cat.position, catWidth: catWidth)
    }

    private func prepareResidents() {
        if editing { residents.invalidate(hide: true); return }
        guard presentationActive, !presentationBusy, bowlPlanningRequest == nil,
              let latest, let planner = residentPlanner else { return }
        residents.prepare(snapshot: latest, active: cat.position, scene: self, planner: planner,
                          width: catWidth, reducedMotion: reducedMotion)
    }

    private func resumeIdle() {
        if applyPendingRoomExpansion() { return }
        prepareResidents()
        residents.setIdleEnabled(presentationActive && !editing)
        cat.setIdleEnabled(presentationActive && bowlPlanningRequest == nil && !editing && !presentationBusy)
        updateThought()
        guard presentationActive, bowlPlanningRequest == nil, !editing, !presentationBusy,
              !reducedMotion, !residents.isBusy, action(forKey: "ambient-walk") == nil else { return }
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing") && !args.contains("--allow-ambient-motion") { return }
#endif
        run(.sequence([.wait(forDuration: Double.random(in: 12...24)), .run { [weak self] in
            self?.takeQuietStroll()
        }]), withKey: "ambient-walk")
    }
    func takeQuietStroll(now: Date = Date(), restRoll: Int = Int.random(in: 0..<3)) {
        removeAction(forKey: "ambient-walk")
        guard presentationActive, bowlPlanningRequest == nil, !editing, !presentationBusy,
              !cat.isPerforming, !reducedMotion, !residents.isBusy else { resumeIdle(); return }
        if now.timeIntervalSince(lastRestFinished) > 40, restRoll == 0,
           let destination = renderedFurniture.filter({ placement in
               ownedFurniture.contains { $0.id == placement.itemID && [.catBed, .floorCushion].contains($0.kind) }
           }).randomElement() {
            visitFurniture(destination.itemID, notify: false)
            return
        }
        if !residents.actors.isEmpty, let planner = residentPlanner {
            _ = residents.stroll(planner: planner, active: cat.position, activeActor: cat)
            return
        }
        guard let navigation else { resumeIdle(); return }
        let candidates = navigation.walkablePoints.shuffled().filter {
            let distance = hypot($0.x - cat.position.x, $0.y - cat.position.y)
            return distance > catWidth * 0.38 && distance < size.width * 0.55
        }
        var route: [CGPoint]?
        for target in candidates.prefix(16) {
            if let path = navigation.route(from: cat.position, to: target),
               pathLength(path) < size.width * 0.85 {
                route = path
                break
            }
        }
        guard let route else { resumeIdle(); return }
#if DEBUG
        noteRoute(route)
#endif
        revision += 1
        let ticket = revision
        presentationBusy = true
        setPhase("strolling")
        updateThought()
        cat.stroll(along: route) { [weak self] in
            guard let self, self.revision == ticket else { return }
            self.finishPresentation()
        }
    }
    private func setPhase(_ phase: String) {
        guard presentationPhase != phase else { return }
        presentationPhase = phase
#if DEBUG
        diagnostics.onPresentationChanged?(phase)
#endif
    }

    private func publishFloorTravelAvailability() {
        let ready = bowlPlanningRequest == nil && !editing && !dragging && !isPlacementPending
            && !floorTravelCareActive && suspendedCareKind == nil && pendingFeedback == nil
            && restPlanningTask == nil && !cat.isEnteringFurniture && !restExiting && !residents.isPreparing
        if ready != lastFloorTravelAvailability {
            lastFloorTravelAvailability = ready
            onFloorTravelAvailabilityChanged?(ready)
        }
    }
    private func layoutRoom(preservingPositionFrom oldSize: CGSize? = nil, preservingNewPlacement: Bool = false) {
        residents.invalidate(hide: editing)
        guard size.width > 0, size.height > 0 else { return }
        let suspended = suspendedCareKind ?? planningCareKind
        let feedback = pendingFeedback
        let rest = pendingRestID
        cancelBowlPlanning(keepingRequest: false)
        cancelPresentation(at: cat.position)
        cancelPlacementPreview(reportAbandonedItem: !preservingNewPlacement)
        suspendedCareKind = suspended
        pendingFeedback = feedback
        pendingRestID = rest
        let proposal = RoomLayoutProposal(viewport: size, roomLevel: latest?.home.roomLevel ?? renderedRoomLevel,
            artworkSize: room.texture?.size() ?? CGSize(width: 1024, height: 1536),
            bowlAspect: bowl.texture.map { $0.size().height / $0.size().width } ?? 0.83,
            items: latest?.inventory.furniture ?? FurnitureCatalog.defaultItems,
            placements: latest?.home.furniture ?? FurnitureCatalog.defaultPlacements,
            bowl: latest?.home.bowlPosition ?? .init(x: 0.76, y: 0.79),
            previousCat: hasCommittedLayout ? cat.position : nil,
            previousWorld: oldSize ?? worldGeometry.worldSize)
        layoutPlanning.prepare(proposal)
        placementNavigation = nil
        placementPrepared = false
        // Only first load has no safe room to retain. Rebuilds keep the old
        // complete world visible; touches and movement wait for publication.
        if !hasCommittedLayout {
            applyLayoutArtwork(proposal)
            cat.isHidden = true
            bowl.isHidden = true
        }
        setPlacementPending(false)
        setPhase("layout-planning")
        updateSelection()
        updateThought()
        startBowlPlanning()
    }

    private func applyLayoutArtwork(_ proposal: RoomLayoutProposal) {
        renderedRoomLevel = proposal.roomLevel
        renderedViewportSize = proposal.geometry.viewportSize
        roomPresentation.configure(world: proposal.geometry.worldSize, viewport: size,
            floor: proposal.planner.floor.polygon, angle: roomViewAngle, level: proposal.roomLevel, homeFloor: homeFloor)
        let worldSize = proposal.geometry.worldSize
        let fill = max(worldSize.width / proposal.artworkSize.width, worldSize.height / proposal.artworkSize.height)
        room.size = CGSize(width: proposal.artworkSize.width * fill, height: proposal.artworkSize.height * fill)
        room.isHidden = true
        room.position = CGPoint(x: worldSize.width / 2, y: worldSize.height / 2)
        artwork.updateFloorAmbience(upper: homeFloor == .upper, transform: artworkTransform)
        catWidth = proposal.catWidth
        cat.setVisualWidth(catWidth)
        cat.reducedMotion = reducedMotion
        bowl.size = proposal.bowlSize
        ownedFurniture = proposal.items
        renderedFurniture = proposal.placements
        synchronizeFurnitureNodes()
        toy.size = CGSize(width: catWidth * 0.31, height: catWidth * 0.31)
    }
    func updateSelection() {
        artwork.updateSelection(editing: editing && bowlPlanningRequest == nil, selectedFurnitureID: selectedFurnitureID,
                                ownedFurniture: ownedFurniture, furnitureWorld: furnitureWorld, floor: floor)
    }
    private func updateThought() {
        thought.isHidden = onCatNeedAnchorChanged != nil || editing || bowlPlanningRequest != nil
            || presentationBusy || (latest?.activeCat?.satiety ?? 100) >= 50
    }
    private func showCareParticles() { artwork.showCareParticles(cat: cat, reducedMotion: reducedMotion) }
    private func scenePoint(_ point: NormalizedPoint) -> CGPoint {
        let canvas = worldGeometry.worldSize
        return CGPoint(x: canvas.width * point.x, y: canvas.height * (1 - point.y))
    }

    /// Keep the occupied world intact until care finishes or resting paws have
    /// returned to the floor. A queued action resumes on the rebuilt navigator.
    @discardableResult
    private func applyPendingRoomExpansion() -> Bool {
        guard let level = latest?.home.roomLevel, level != renderedRoomLevel,
              level != layoutPlanning.proposal?.roomLevel,
              activeRest == nil, !presentationBusy, !cat.isPerforming,
              !dragging, !isPlacementPending, size.width > 0, size.height > 0 else { return false }
        let previousWorld = worldGeometry.worldSize
        layoutRoom(preservingPositionFrom: previousWorld, preservingNewPlacement: newPlacementID != nil)
        return true
    }

    func setPlacementPending(_ pending: Bool) {
        let pending = pending || (editing && bowlPlanningRequest != nil)
        guard pending != isPlacementPending else { return }
        isPlacementPending = pending
        onPlacementPendingChanged?(pending)
    }

    /// Reverting the preview does not mutate the saved or edited layout.
    func cancelPlacementPreview(reportAbandonedItem: Bool = true) {
        placementRevision += 1
        placementTask?.cancel()
        placementTask = nil
        dragging = false
        dragScreenPoint = nil
        _ = roomPresentation.camera.endPan()
        touchOrigin = nil
        let abandoned = newPlacementID
        newPlacementID = nil
        bowl.position = committedBowlPosition
        synchronizeFurnitureNodes()
        placementPrepared = false
        setPlacementPending(editing && activeRest != nil)
        updateSelection()
        updateBowlLayers()
#if DEBUG
        publishDragMetrics()
        publishFurnitureStatus()
#endif
        if reportAbandonedItem, let abandoned { onFurniturePlacementFinished?(abandoned, false) }
    }

    func resolveReleasedItem() {
        guard let placementNavigation else { cancelPlacementPreview(); return }
        let ticket = placementRevision
        let id = selectedFurnitureID
        let point = selectedNode.position
        let start = cat.position
        let world = furnitureWorld
#if DEBUG
        let slowTest = diagnostics.dragTesting && ProcessInfo.processInfo.arguments.contains("--slow-placement-test")
#endif
        let worker = Task.detached(priority: .userInitiated) {
#if DEBUG
            if slowTest { try? await Task.sleep(for: .seconds(3)) }
#endif
            guard !Task.isCancelled else { return Optional<RoomFurnitureResolution>.none }
            return world.resolve(id: id, near: point, catAt: start, placement: placementNavigation)
        }
        placementTask = worker
        Task { [weak self] in
            let result = await worker.value
            guard let self, self.editing, self.placementRevision == ticket else { return }
            self.placementTask = nil
            let insertedID = self.newPlacementID
            self.newPlacementID = nil
            if let result {
                self.floor = result.floor
                self.navigation = result.navigation
                if let id = result.id {
                    let normalized = world.transform.normalized(result.center)
                    if let index = self.renderedFurniture.firstIndex(where: { $0.itemID == id }) {
                        self.renderedFurniture[index].position = normalized
                    } else {
                        self.renderedFurniture.append(.init(itemID: id, position: normalized))
                    }
                    self.furnitureNodes[id]?.position = result.center
                    self.furnitureNodes[id]?.alpha = 1
                    self.onFurnitureMoved?(id, normalized)
                } else {
                    self.bowl.position = result.center
                    self.committedBowlPosition = result.center
                    let normalized = NormalizedPoint(x: result.center.x / self.worldGeometry.worldSize.width,
                                                     y: 1 - result.center.y / self.worldGeometry.worldSize.height)
                    self.lastRequestedBowlPoint = self.scenePoint(normalized)
                    self.onBowlMoved?(normalized)
                }
            } else {
                self.bowl.position = self.committedBowlPosition
                self.synchronizeFurnitureNodes()
            }
            self.placementPrepared = false
            self.setPlacementPending(false)
            if let insertedID { self.onFurniturePlacementFinished?(insertedID, result != nil) }
            self.updateSelection()
            self.updateBowlLayers()
            self.updateFurnitureLayers()
#if DEBUG
            self.publishNavigationStatus()
            self.publishDragMetrics()
            self.publishFurnitureStatus()
#endif
        }
    }

    private func cancelBowlPlanning(keepingRequest: Bool) {
#if DEBUG
        if layoutPlanning.isRunning { diagnostics.bowlPlanCancelled += 1 }
        diagnostics.bowlPlanning = keepingRequest && bowlPlanningRequest != nil
#endif
        layoutPlanning.cancel(keepingRequest: keepingRequest)
    }

    private func startBowlPlanning() {
        guard presentationActive, size.width > 0, size.height > 0,
              !layoutPlanning.isRunning, bowlPlanningRequest != nil else { return }
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing") && args.contains("--slow-bowl-planning-test") {
            layoutPlanning.delay = .seconds(3)
        }
        diagnostics.bowlPlanning = true
#endif
        layoutPlanning.start { [weak self] proposal, result in
            guard let self, self.presentationActive else { return }
            self.applyLayoutArtwork(proposal)
            self.hasCommittedLayout = true
            self.floor = proposal.planner.floor
            self.navigation = result.navigation
            self.lastRequestedBowlPoint = proposal.planner.requested
            self.bowl.position = result.center
            self.committedBowlPosition = result.center
            self.cat.cancelAndSettle(at: result.catPosition ?? proposal.planner.catPosition)
            self.cat.isHidden = false
            self.bowl.isHidden = false
            self.placementPrepared = false
            self.presentationBusy = false
            self.setPlacementPending(false)
            self.setPhase(self.editing ? "editing" : "idle")
#if DEBUG
            self.diagnostics.bowlPlanning = false
            self.diagnostics.bowlPlanCompletions += 1
            self.diagnostics.lastBowlPlanOnMainThread = result.ranOnMainThread
#endif
            // Reconcile choices queued while the immutable layout was prepared.
            if let latest = self.latest {
                self.apply(snapshot: latest, editing: self.editing,
                    selectedFurnitureID: self.requestedSelectionID, placingFurnitureID: self.requestedPlacementID)
            }
            self.updateSelection()
            self.updateBowlLayers()
            self.updateFurnitureLayers()
            guard self.bowlPlanningRequest == nil else { return }
            if let kind = self.suspendedCareKind, !self.editing {
                self.suspendedCareKind = nil
                self.playFeedback(kind: kind)
            } else {
                self.finishPresentation()
            }
#if DEBUG
            self.publishNavigationStatus()
            self.publishFurnitureStatus()
#endif
        }
    }

    private func pathLength(_ path: [CGPoint]) -> CGFloat {
        zip(path, path.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

#if DEBUG
    private func noteRoute(_ path: [CGPoint]) { diagnostics.noteRoute(path, navigation: navigation) }
    func publishNavigationStatus() {
        diagnostics.publishNavigationStatus(phase: presentationPhase, cat: cat, bowl: bowl.position,
                                            geometry: worldGeometry, presentation: roomPresentation)
    }
    func publishDragMetrics() {
        diagnostics.publishDragMetrics(pending: isPlacementPending, bowl: bowl.position,
                                       geometry: worldGeometry, presentation: roomPresentation)
    }
    func publishFurnitureStatus() {
        updateRoomPresentation()
        diagnostics.publishFurnitureStatus(.init(geometry: worldGeometry, cameraPosition: roomPresentation.camera.center, cameraScale: roomPresentation.camera.scale,
            roomLevel: renderedRoomLevel, catWidth: catWidth, bowlWidth: bowl.size.width,
            furnitureWorld: furnitureWorld, renderedFurniture: renderedFurniture,
            ownedFurniture: ownedFurniture, furnitureNodes: furnitureNodes, selectedFurnitureID: selectedFurnitureID,
            isPlacementPending: isPlacementPending, presentationPhase: presentationPhase, activeRest: activeRest,
            restSessionID: restSessionID, restSessionWasCommitted: restSessionWasCommitted,
            restEndReported: restEndReported, restDeadline: restDeadline, latest: latest,
            presentation: roomPresentation, viewAngle: roomViewAngle), cat: cat, bowl: bowl.position, residents: residents, bowlHasFood: bowlHasFood)
    }
#endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { beginTouches(touches, with: event) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { moveTouches(touches, with: event) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches, with: event) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { cancelTouches(touches, with: event) }
}
