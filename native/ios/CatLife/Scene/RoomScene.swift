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

    static func preloadWelcomeResources() async {
        guard welcomeTextures == nil else { return }
        let names = ["room-empty", "bowl-empty", "bowl-full", "icon-play",
                     "cat-idle", "cat-expressions", "cat-walk", "cat-rise",
                     "cat-meal", "cat-play", "cat-rest", "cat-step"]
            + FurnitureKind.allCases.map { FurnitureCatalog.metadata(for: $0).assetName }
        let textures = Set(names).sorted().map { SKTexture(imageNamed: $0) }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            SKTexture.preload(textures) { continuation.resume() }
        }
        welcomeTextures = textures
    }

    var onCatTapped: (() -> Void)?
    var onFurnitureSelected: ((String?) -> Void)?
    var onFurnitureMoved: ((String, NormalizedPoint) -> Void)?
    var onFurniturePlacementFinished: ((String, Bool) -> Void)?
    private var furnitureNodes: [String: SKSpriteNode] { artwork.furnitureNodes }
    private var ownedFurniture = FurnitureCatalog.defaultItems
    private var renderedFurniture = FurnitureCatalog.defaultPlacements
    private var selectedFurnitureID: String?
    private var newPlacementID: String?
    private var lastPlacingRequest: String?
    private var placementPrepared = false
    var onRestingFurnitureChanged: ((String?, String) -> Void)?
    var onFurnitureNotice: ((String) -> Void)?
    private var activeRest: RoomFurnitureRest?
    // A visual visit starts on approach, but recovery starts only after all
    // paws have settled. The token also keeps stale exits away from a new save.
    private var restSessionID: String?
    private var restSessionWasCommitted = false
    private var restEndReported = false
    private var restDeadline: Date?
    private var restDeadlineTask: Task<Void, Never>?
    private var presentationActive = true
    private var restPlanningTask: Task<RoomFurnitureRest?, Never>?
    private var restExiting = false
    private var pendingRestID: String?
    private var requestedSelectionID: String?
    private var requestedPlacementID: String?
    private var lastRestFinished = Date.distantPast
    private var deferredRoomLayoutFromSize: CGSize?
    private var restFront: SKSpriteNode { artwork.restFront }
    var onBowlTapped: (() -> Void)?
    var onPlacementPendingChanged: ((Bool) -> Void)?
    private(set) var isPlacementPending = false
    var onBowlMoved: ((NormalizedPoint) -> Void)?
    private(set) var presentationPhase = "idle"
    var reducedMotion = false {
        didSet {
            guard reducedMotion != oldValue else { return }
            if activeRest != nil { leaveFurnitureRest(); return }
            cancelPresentation(at: cat.position)
            cat.reducedMotion = reducedMotion
            resumeIdle()
        }
    }
    private let artwork = RoomSceneArtwork()
    private var room: SKSpriteNode { artwork.room }
    private let cat = CatActor()
    private var bowl: SKSpriteNode { artwork.bowl }
    private var toy: SKSpriteNode { artwork.toy }
    private var selection: SKShapeNode { artwork.selection }
    private var thought: SKNode { artwork.thought }
    private var latest: GameSnapshot?
    private var editing = false
    private var dragging = false
    private var touchOrigin: CGPoint?
    private var dragOffset = CGPoint.zero
    private var homePoint = CGPoint.zero
    private var catWidth: CGFloat = 120
    private var presentationBusy = false
    private var pendingFeedback: ActionKind?
    private var carePlanningTask: Task<RoomCarePlanningResult, Never>?
    private var planningCareKind: ActionKind?
    private var suspendedCareKind: ActionKind?
    private var revision = 0
    private var hasLaidOutRoom = false
    private var floor: RoomFloor?
    private var navigation: RoomNavigation?
    private var placementNavigation: RoomNavigation?
    private var placementTask: Task<RoomFurnitureResolution?, Never>?
    private var placementRevision = 0
    private var committedBowlPosition = CGPoint.zero
    private var lastRequestedBowlPoint: CGPoint?
    private var activeFeedingDock: FeedingDock?
    private var activeFeedingStage: CGPoint?
    private var dockingNavigation: RoomNavigation?
#if DEBUG
    let diagnostics = RoomSceneDiagnostics()
#endif

    private var artworkTransform: RoomArtworkTransform {
        // SpriteKit updates scene.size before didChangeSize. An occupied room
        // keeps every furniture query/node in the old world until safe exit.
        RoomArtworkTransform(sceneSize: deferredRoomLayoutFromSize ?? size,
                             artworkSize: room.texture?.size() ?? CGSize(width: 1024, height: 1536))
    }

    private var furnitureWorld: RoomFurnitureWorld {
        RoomFurnitureWorld(transform: artworkTransform, catWidth: catWidth, bowlSize: bowl.size,
                           bowlPosition: bowl.position, items: ownedFurniture, placements: renderedFurniture)
    }

    override init(size: CGSize) {
        super.init(size: size)
        cat.onSound = { [weak self] sound in self?.onSound?(sound) }
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.98, green: 0.95, blue: 0.89, alpha: 1)
        artwork.install(in: self)
        cat.name = "cat"
        cat.zPosition = 20
        addChild(cat)
        layoutRoom()
    }
    required init?(coder aDecoder: NSCoder) { fatalError("RoomScene is created in code") }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // SpriteKit calls this even when size is assigned the same value.
        // Reappearing over a sheet must not cancel an active meal or its queue.
        guard oldSize != size else { return }
        if activeRest != nil, deferredRoomLayoutFromSize == nil,
           oldSize.width > 0, oldSize.height > 0 {
            deferredRoomLayoutFromSize = oldSize
        }
        guard size.width > 0, size.height > 0 else {
            cancelPlacementPreview()
            if carePlanningTask != nil || suspendedCareKind != nil { cancelPresentation(at: cat.position) }
            return
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
        let previousSize = deferredRoomLayoutFromSize ?? oldSize
        deferredRoomLayoutFromSize = nil
        layoutRoom(preservingPositionFrom: previousSize, preservingNewPlacement: pendingItem != nil)
        if editing, let pendingItem { startPlacingFurniture(pendingItem) }
    }
    override func update(_ currentTime: TimeInterval) {
        let frame = cat.visualFrame
        thought.position = CGPoint(x: frame.midX + catWidth * 0.30, y: frame.maxY + 30)
        // A smaller y is nearer the camera. The bowl is anchored at its base,
        // not the center of its tall texture.
        cat.zPosition = 1_000 - cat.position.y
        updateBowlLayers()
        updateFurnitureLayers()
        toy.zPosition = 1_001 - toy.position.y
        thought.zPosition = 2_000
#if DEBUG
        if diagnostics.enabled,
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
    func apply(snapshot: GameSnapshot, editing: Bool, selectedFurnitureID selected: String? = nil,
               placingFurnitureID placing: String? = nil) {
        latest = snapshot
        requestedSelectionID = selected
        requestedPlacementID = placing
        // Keep the occupied world frozen until the cat has walked out. The
        // panel may open immediately, but no furniture can move or be stored.
        if activeRest != nil {
            self.editing = editing
            view?.preferredFramesPerSecond = editing ? 60 : 30
            if editing {
                pendingRestID = nil
                setPlacementPending(true)
#if DEBUG
                if !restExiting { recordRestInterruption(reason: "decorate") }
#endif
                leaveFurnitureRest()
            } else {
                setPlacementPending(false)
                reconcileRestSession()
            }
            return
        }
        let modeChanged = self.editing != editing
        if modeChanged {
            self.editing = editing
            cancelPlacementPreview()
            view?.preferredFramesPerSecond = editing ? 60 : 30
            cancelPresentation(at: cat.position)
            setPhase(editing ? "editing" : "idle")
            placementPrepared = false
        }
        if !isPlacementPending {
            let furnitureChanged = renderedFurniture != snapshot.home.furniture || ownedFurniture != snapshot.inventory.furniture
            if furnitureChanged {
                renderedFurniture = snapshot.home.furniture
                ownedFurniture = snapshot.inventory.furniture
                synchronizeFurnitureNodes()
                floor = furnitureWorld.roomFloor
                placementPrepared = false
            }
            let proposed = scenePoint(snapshot.home.bowlPosition)
            if lastRequestedBowlPoint != proposed || furnitureChanged {
                lastRequestedBowlPoint = proposed
                let resolved = resolvedBowlPosition(proposed)
                cancelPresentation(at: cat.position)
                bowl.position = resolved
                committedBowlPosition = resolved
                rebuildNavigation(keeping: cat.position)
            }
        }
        if self.selectedFurnitureID != selected && !dragging {
            self.selectedFurnitureID = selected
            placementPrepared = false
        }
        if editing && !isPlacementPending { preparePlacementNavigation() }
        if placing == nil { lastPlacingRequest = nil }
        if editing, let placing, placing != lastPlacingRequest {
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
                                     keeping: newPlacementID, transform: artworkTransform)
        updateFurnitureLayers()
    }

    private func furnitureNode(for item: FurnitureItem) -> SKSpriteNode {
        artwork.furnitureNode(for: item, transform: artworkTransform)
    }

    private func updateFurnitureLayers() {
        artwork.updateFurnitureLayers(items: ownedFurniture, cat: cat, activeRest: activeRest)
    }

    private var selectedNode: SKSpriteNode {
        selectedFurnitureID.flatMap { furnitureNodes[$0] } ?? bowl
    }

    private func preparePlacementNavigation() {
        guard editing, !placementPrepared else { return }
        placementNavigation = furnitureWorld.placementNavigator(for: selectedFurnitureID, catAt: cat.position)
        placementPrepared = true
    }

    private func startPlacingFurniture(_ id: String) {
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
        node.position = artworkTransform.point(preferred)
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
        cat.setIdleEnabled(false)
        presentationBusy = true
        setPhase("rest-approach")
        updateThought()
        let ticket = revision
        let world = furnitureWorld
        let origin = cat.position
        let worker = Task.detached(priority: .userInitiated) { world.restVisit(to: id, from: origin) }
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
                          elevation: visit.elevation, onSettled: { [weak self] in
                guard let self, self.revision == ticket, !self.restExiting else { return }
                let sessionID = UUID().uuidString
                self.restSessionID = sessionID
                // The committed save supplies the authoritative deadline. This
                // fallback only ends a visual stay if its start cannot be saved.
                self.restDeadline = Date().addingTimeInterval(item.kind == .catBed ? 12 : 9)
                self.setPhase("resting")
                self.onRestingFurnitureChanged?(id, sessionID)
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
        if !active, let kind = planningCareKind {
            // A worker cannot start SpriteKit actions behind Settings or while
            // backgrounded. Retain this committed action and its pending follow-up.
            revision += 1
            cancelCarePlanning()
            suspendedCareKind = kind
        }
        if active {
            if let kind = suspendedCareKind, !editing {
                suspendedCareKind = nil
                presentationBusy = false
                playFeedback(kind: kind)
            }
            reconcileRestSession()
            if !presentationBusy { resumeIdle() }
        }
    }

    private func reconcileRestSession(now: Date = Date()) {
        guard let visit = activeRest, !restExiting, let sessionID = restSessionID else { return }
        let committed = latest?.cats.first?.activeRest
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
        onRestingFurnitureChanged?(nil, sessionID)
    }

    private func resetRestSession() {
        restDeadlineTask?.cancel()
        restDeadlineTask = nil
        restSessionID = nil
        restSessionWasCommitted = false
        restEndReported = false
        restDeadline = nil
    }

    private func leaveFurnitureRest(reason: String = "interaction") {
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
            if let previousSize = self.deferredRoomLayoutFromSize,
               self.size.width > 0, self.size.height > 0 {
                self.deferredRoomLayoutFromSize = nil
                self.layoutRoom(preservingPositionFrom: previousSize)
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

    func playFeedback(kind: ActionKind) {
        guard [.feed, .clean, .play].contains(kind), !editing else { return }
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
        if restPlanningTask != nil { cancelPresentation(at: cat.position) }
        if presentationBusy || cat.isPerforming {
            // Coalesce presentation only; each successful game action was saved.
            pendingFeedback = kind
            return
        }
        removeAction(forKey: "ambient-walk")
        presentationBusy = true
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
            let planner = RoomCarePlanner(floor: floor, navigation: navigation, origin: returnPoint,
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
                     dockingPath: plan.dockingPath, returnPath: Array(plan.path.reversed()), completion: completion)
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
        updateBowlLayers()
    }

    private func updateBowlLayers() { artwork.updateBowlLayers(cat: cat, floor: floor) }

    private func finishPresentation() {
        presentationBusy = false
        activeFeedingDock = nil
        activeFeedingStage = nil
        dockingNavigation = nil
        setBowlTexture("bowl-empty")
        toy.removeAllActions()
        toy.isHidden = true
        setPhase(editing ? "editing" : "idle")
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
        setPhase(editing ? "editing" : "idle")
    }
    private func resumeIdle() {
        cat.setIdleEnabled(presentationActive && !editing && !presentationBusy)
        updateThought()
        guard presentationActive, !editing, !presentationBusy, !reducedMotion, action(forKey: "ambient-walk") == nil else { return }
#if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing") && !args.contains("--allow-ambient-motion") { return }
#endif
        run(.sequence([.wait(forDuration: Double.random(in: 12...24)), .run { [weak self] in
            self?.takeQuietStroll()
        }]), withKey: "ambient-walk")
    }
    private func takeQuietStroll() {
        removeAction(forKey: "ambient-walk")
        guard !editing, !presentationBusy, !cat.isPerforming, !reducedMotion else { resumeIdle(); return }
        if Date().timeIntervalSince(lastRestFinished) > 40, Int.random(in: 0..<3) == 0,
           let destination = renderedFurniture.filter({ placement in
               ownedFurniture.contains { $0.id == placement.itemID && [.catBed, .floorCushion].contains($0.kind) }
           }).randomElement() {
            visitFurniture(destination.itemID, notify: false)
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
    private func layoutRoom(preservingPositionFrom oldSize: CGSize? = nil, preservingNewPlacement: Bool = false) {
        guard size.width > 0, size.height > 0 else { return }
        let previousFloorPosition: CGPoint?
        if hasLaidOutRoom, let oldSize, oldSize.width > 0, oldSize.height > 0 {
            previousFloorPosition = CGPoint(x: cat.position.x / oldSize.width,
                                            y: cat.position.y / oldSize.height)
        } else {
            previousFloorPosition = nil
        }
        if let texture = room.texture {
            let dimensions = texture.size()
            let fill = max(size.width / dimensions.width, size.height / dimensions.height)
            room.size = CGSize(width: dimensions.width * fill, height: dimensions.height * fill)
            room.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        // Keep cat and bowl in proportion while leaving room to pass between
        // the bed and scratching tree on the floor below the wall pictures.
        cancelPlacementPreview(reportAbandonedItem: !preservingNewPlacement)
        catWidth = min(size.width * 0.14, size.height * 0.172)
        homePoint = CGPoint(x: size.width * 0.43, y: size.height * 0.18)
        let restingPoint = previousFloorPosition.map {
            CGPoint(x: $0.x * size.width, y: $0.y * size.height)
        } ?? homePoint
        cancelPresentation(at: restingPoint)
        hasLaidOutRoom = true
        cat.setVisualWidth(catWidth)
        cat.reducedMotion = reducedMotion
        let bowlWidth = min(size.width * 0.156, size.height * 0.185)
        let ratio = bowl.texture.map { $0.size().height / $0.size().width } ?? 0.83
        bowl.size = CGSize(width: bowlWidth, height: bowlWidth * ratio)
        ownedFurniture = latest?.inventory.furniture ?? FurnitureCatalog.defaultItems
        renderedFurniture = latest?.home.furniture ?? FurnitureCatalog.defaultPlacements
        synchronizeFurnitureNodes()
        floor = furnitureWorld.roomFloor
        let requestedBowl = scenePoint(latest?.home.bowlPosition ?? .init(x: 0.76, y: 0.79))
        lastRequestedBowlPoint = requestedBowl
        bowl.position = resolvedBowlPosition(requestedBowl)
        committedBowlPosition = bowl.position
        rebuildNavigation(keeping: restingPoint)
        toy.size = CGSize(width: catWidth * 0.31, height: catWidth * 0.31)
        selection.xScale = bowlWidth / 100
        selection.yScale = bowlWidth / 100
        updateSelection()
        resumeIdle()
    }
    private func updateSelection() {
        artwork.updateSelection(editing: editing, selectedFurnitureID: selectedFurnitureID,
                                ownedFurniture: ownedFurniture, furnitureWorld: furnitureWorld, floor: floor)
    }
    private func updateThought() {
        thought.isHidden = editing || presentationBusy || (latest?.cats.first?.satiety ?? 100) >= 50
    }
    private func showCareParticles() { artwork.showCareParticles(cat: cat, reducedMotion: reducedMotion) }
    private func scenePoint(_ point: NormalizedPoint) -> CGPoint {
        let canvas = deferredRoomLayoutFromSize ?? size
        return CGPoint(x: canvas.width * point.x, y: canvas.height * (1 - point.y))
    }
    private func previewFloorPoint(_ point: CGPoint) -> CGPoint {
        guard let floor, let placementNavigation else { return selectedNode.position }
        if selectedFurnitureID != nil {
            return placementNavigation.nearestWalkable(to: point) ?? selectedNode.position
        }
        guard let safe = placementNavigation.nearestWalkable(to: floor.bowlGround(at: point)) else { return bowl.position }
        return CGPoint(x: safe.x, y: safe.y - floor.bowlGroundOffset)
    }

    private func setPlacementPending(_ pending: Bool) {
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

    private func resolveReleasedItem() {
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
                    let normalized = NormalizedPoint(x: result.center.x / self.size.width,
                                                     y: 1 - result.center.y / self.size.height)
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

    private func resolvedBowlPosition(_ point: CGPoint) -> CGPoint {
        guard let floor else { return point }
        let placement = floor.placementNavigator()
        // Old layouts were allowed on furniture and walls. Find the closest
        // usable presentation position, without overwriting the original save.
        for ground in placementCandidates(near: floor.bowlGround(at: point), in: placement) {
            let candidate = CGPoint(x: ground.x, y: ground.y - floor.bowlGroundOffset)
            let proposedNavigation = floor.navigator(bowlAt: candidate)
            if let start = proposedNavigation.nearestWalkable(to: cat.position),
               feedingPlan(from: start, bowlAt: candidate, navigator: proposedNavigation) != nil {
                return candidate
            }
        }
        return point
    }

    private func placementCandidates(near point: CGPoint, in navigator: RoomNavigation) -> [CGPoint] {
        let nearest = navigator.nearestWalkable(to: point).map { [$0] } ?? []
        return nearest + navigator.walkablePoints.sorted {
            hypot($0.x - point.x, $0.y - point.y) < hypot($1.x - point.x, $1.y - point.y)
        }
    }

    private func rebuildNavigation(keeping point: CGPoint) {
        guard let floor else { return }
        let updated = floor.navigator(bowlAt: bowl.position)
        navigation = updated
        if let safe = updated.nearestWalkable(to: point),
           hypot(safe.x - cat.position.x, safe.y - cat.position.y) > 0.01 {
            cancelPresentation(at: safe)
        }
        placementPrepared = false
        preparePlacementNavigation()
#if DEBUG
        publishNavigationStatus()
        publishFurnitureStatus()
#endif
    }

    private func feedingPlan(from start: CGPoint, bowlAt candidate: CGPoint? = nil,
                             navigator supplied: RoomNavigation? = nil) -> RoomFeedingPlan? {
        guard let floor, let navigator = supplied ?? navigation else { return nil }
        return floor.feedingPlan(from: start, bowlAt: candidate ?? bowl.position, navigator: navigator)
    }

    private func pathLength(_ path: [CGPoint]) -> CGFloat {
        zip(path, path.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

#if DEBUG
    private func noteRoute(_ path: [CGPoint]) { diagnostics.noteRoute(path, navigation: navigation) }
    private func publishNavigationStatus() {
        diagnostics.publishNavigationStatus(phase: presentationPhase, cat: cat, bowl: bowl.position, size: size)
    }
    private func publishDragMetrics() {
        diagnostics.publishDragMetrics(pending: isPlacementPending, bowl: bowl.position, size: size)
    }
    private func publishFurnitureStatus() {
        diagnostics.publishFurnitureStatus(.init(size: size, renderedFurniture: renderedFurniture,
            ownedFurniture: ownedFurniture, furnitureNodes: furnitureNodes, selectedFurnitureID: selectedFurnitureID,
            isPlacementPending: isPlacementPending, presentationPhase: presentationPhase, activeRest: activeRest,
            restSessionID: restSessionID, restSessionWasCommitted: restSessionWasCommitted,
            restEndReported: restEndReported, restDeadline: restDeadline, latest: latest), cat: cat, bowl: bowl.position)
    }
#endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        touchOrigin = point
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
        setPlacementPending(true)
        dragOffset = CGPoint(x: selectedNode.position.x - point.x, y: selectedNode.position.y - point.y)
        updateSelection()
#if DEBUG
        publishFurnitureStatus()
#endif
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard dragging, let touch = touches.first else { return }
#if DEBUG
        let started = CACurrentMediaTime()
#endif
        let point = touch.location(in: self)
        selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
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

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput += ";ended" }
#endif
        defer { dragging = false; touchOrigin = nil }
        if dragging {
            if let touch = touches.first {
                let point = touch.location(in: self)
                selectedNode.position = previewFloorPoint(CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y))
            }
            // A tap selects without doing an expensive route search.
            if let origin = touchOrigin, let touch = touches.first,
               hypot(touch.location(in: self).x - origin.x, touch.location(in: self).y - origin.y) < 3,
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
        guard !editing, let touch = touches.first, let origin = touchOrigin else { return }
        let point = touch.location(in: self)
        guard hypot(point.x - origin.x, point.y - origin.y) < 12 else { return }
        if bowl.frame.contains(point) { onBowlTapped?() }
        else if cat.visualFrame.insetBy(dx: -8, dy: -8).contains(point) {
            if activeRest != nil { pendingRestID = nil; leaveFurnitureRest() }
            else { onCatTapped?() }
        } else if let hit = furnitureNodes.filter({ $0.value.frame.contains(point) })
            .sorted(by: { $0.value.zPosition > $1.value.zPosition }).first {
            visitFurniture(hit.key)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
#if DEBUG
        if diagnostics.furnitureTesting { diagnostics.lastRestInput += ";cancelled" }
#endif
        if dragging { cancelPlacementPreview() }
        touchOrigin = nil
    }
}
