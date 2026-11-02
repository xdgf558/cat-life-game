#if DEBUG
import SpriteKit
import CatGameCore

/// Debug-only UI-test instrumentation; no counters, test flags or JSON samples
/// from this component are compiled into a shipping Release app.
@MainActor
final class RoomSceneDiagnostics {
    let navigationTesting: Bool
    let dragTesting: Bool
    let furnitureTesting: Bool
    var enabled: Bool { navigationTesting || dragTesting || furnitureTesting }
    var onPresentationChanged: ((String) -> Void)?
    var onNavigationChanged: ((String) -> Void)?
    var onDragMetricsChanged: ((String) -> Void)?
    var onFurnitureDiagnosticsChanged: ((String) -> Void)?
    private(set) var navigationDescription = ""
    private(set) var dragDescription = "0|0|0|0,0"
    private(set) var furnitureDescription = "{}"
    var lastRestEndReason = "none"
    var lastRestInput = "none"
    var restExits = 0
    var carePlanning = false
    var carePlanCompletions = 0
    var carePlanCancelled = 0
    var lastCarePlanMilliseconds: Double = 0
    var lastCarePlanOnMainThread = false
    var lastRestInterrupt: [String: Any]?
    var dragMoveSamples = 0
    var maximumDragMoveMs: Double = 0
    private var restContactSamples = 0
    private var stepForeSupportSamples = 0
    private var bedEdgeContactSamples = 0
    private var bedEdgeContactViolations = 0
    private var bedEdgeMaxError: CGFloat = 0
    private var stepLiftSamples = 0
    private var stepDownSamples = 0
    private var stepClearanceViolations = 0
    private var foodContactSamples = 0
    private var foodContactViolations = 0
    private var collisionViolations = 0
    private var longestRoute = 0
    private var lastDiagnosticTime: TimeInterval = 0

    init() {
        let args = ProcessInfo.processInfo.arguments
        let testing = args.contains("--ui-testing")
        navigationTesting = testing && args.contains("--navigation-test")
        dragTesting = testing && args.contains("--drag-performance-test")
        furnitureTesting = testing && (args.contains("--furniture-test") || args.contains("--rest-test"))
    }

    struct FurnitureState {
        let size: CGSize
        let renderedFurniture: [FurniturePlacement]
        let ownedFurniture: [FurnitureItem]
        let furnitureNodes: [String: SKSpriteNode]
        let selectedFurnitureID: String?
        let isPlacementPending: Bool
        let presentationPhase: String
        let activeRest: RoomFurnitureRest?
        let restSessionID: String?
        let restSessionWasCommitted: Bool
        let restEndReported: Bool
        let restDeadline: Date?
        let latest: GameSnapshot?
    }

    func sample(at currentTime: TimeInterval, cat: CatActor, floor: RoomFloor?, navigation: RoomNavigation?,
                activeRest: RoomFurnitureRest?, editing: Bool, activeFeedingDock: FeedingDock?,
                dockingNavigation: RoomNavigation?, furnitureWorld: RoomFurnitureWorld,
                renderedFurniture: [FurniturePlacement], bowl: CGPoint) -> Bool {
        if navigationTesting || furnitureTesting {
            if (!editing || activeRest != nil), let floor {
                let feet: CGRect
                let occupied = cat.isEnteringFurniture ? activeRest : nil
                if cat.isDockingForMeal, let dock = activeFeedingDock, let dockingNavigation {
                    feet = dock.feetRect(at: cat.position)
                    if !dockingNavigation.isWalkable(dock.footCenter(at: cat.position)) { collisionViolations += 1 }
                } else {
                    feet = CGRect(x: cat.position.x - floor.catFootprint.width / 2,
                                  y: cat.position.y - floor.catFootprint.height / 2,
                                  width: floor.catFootprint.width, height: floor.catFootprint.height)
                    if (occupied?.navigation ?? navigation)?.isWalkable(cat.position) != true { collisionViolations += 1 }
                }
                // Independently audit the live bowl even if a navigation cache
                // becomes stale. Docking changes foot registration, not solidity.
                if feet.intersects(floor.bowlObstacle(at: bowl)) { collisionViolations += 1 }
                if furnitureWorld.floorObstacles(excluding: occupied?.item.id).contains(where: { feet.intersects($0) }) {
                    collisionViolations += 1
                }
                if cat.isRestingOnFurniture, let visit = occupied {
                    if visit.target.contains(cat.position),
                       hypot(cat.position.x - visit.plan.restPoint.x, cat.position.y - visit.plan.restPoint.y) < 1,
                       renderedFurniture.contains(where: { $0.itemID == visit.item.id }) {
                        restContactSamples += 1
                    } else { collisionViolations += 1 }
                }
                // Audit the sprite's measured paw landmarks, not just the
                // actor's floor anchor. Ground collision alone cannot prove
                // that a climbing pose clears the cushion's visible edge.
                if let front = cat.frontPawContact, let rear = cat.rearPawContact {
                    if ![front.x, front.y, rear.x, rear.y, cat.supportElevation].allSatisfy(\.isFinite) {
                        stepClearanceViolations += 1
                    } else {
                        switch cat.stepPhase {
                        case .frontPaws:
                            stepForeSupportSamples += 1
                            if front.y <= rear.y { stepClearanceViolations += 1 }
                            if cat.stepProgress >= 0.139, let band = occupied?.entrySupportBand {
                                // Measure the held paw against the real yellow
                                // mattress edge, not merely against its rear paw.
                                let dx = max(band.minX - front.x, 0, front.x - band.maxX)
                                let dy = max(band.minY - front.y, 0, front.y - band.maxY)
                                let error = hypot(dx, dy)
                                bedEdgeContactSamples += 1
                                bedEdgeMaxError = max(bedEdgeMaxError, error)
                                if error > 1 { bedEdgeContactViolations += 1 }
                            }
                        case .lifting: stepLiftSamples += 1
                        case .frontPawsDown, .lowering:
                            stepDownSamples += 1
                            if rear.y <= front.y { stepClearanceViolations += 1 }
                        case .rearPawsDown:
                            // Backing out of a partially completed climb puts
                            // the rear paws down first, without turning midair.
                            stepDownSamples += 1
                        default: break
                        }
                    }
                }
                if let contact = cat.currentMealContact {
                    foodContactSamples += 1
                    if activeFeedingDock?.containsFoodContact(contact) != true { foodContactViolations += 1 }
                }
            }
        }
        if (navigationTesting || dragTesting || furnitureTesting), currentTime - lastDiagnosticTime > 0.25 {
            lastDiagnosticTime = currentTime
            return true
        }
        return false
    }

    func noteRoute(_ path: [CGPoint], navigation: RoomNavigation?) {
        longestRoute = max(longestRoute, path.count)
        if navigationTesting, let navigation,
           !zip(path, path.dropFirst()).allSatisfy({ navigation.segmentIsWalkable(from: $0.0, to: $0.1) }) {
            collisionViolations += 1
        }
    }

    func publishNavigationStatus(phase presentationPhase: String, cat: CatActor, bowl: CGPoint, size: CGSize) {
        guard navigationTesting, size.width > 0, size.height > 0 else { return }
        navigationDescription = String(format: "%@|%d|%.3f,%.3f|%.3f,%.3f|%d|%d|%d|%d|%d", presentationPhase,
                                       collisionViolations, cat.position.x / size.width, 1 - cat.position.y / size.height,
                                       bowl.x / size.width, 1 - bowl.y / size.height, longestRoute,
                                       cat.completedMeals, cat.completedPounces, foodContactSamples, foodContactViolations)
        onNavigationChanged?(navigationDescription)
    }
    func publishDragMetrics(pending isPlacementPending: Bool, bowl: CGPoint, size: CGSize) {
        guard dragTesting, size.width > 0, size.height > 0 else { return }
        dragDescription = String(format: "%d|%.3f|%d|%.3f,%.3f", dragMoveSamples, maximumDragMoveMs,
                                 isPlacementPending ? 1 : 0, bowl.x / size.width, 1 - bowl.y / size.height)
        onDragMetricsChanged?(dragDescription)
    }

    func publishFurnitureStatus(_ state: FurnitureState, cat: CatActor, bowl: CGPoint) {
        let size = state.size
        let renderedFurniture = state.renderedFurniture
        let ownedFurniture = state.ownedFurniture
        let furnitureNodes = state.furnitureNodes
        let selectedFurnitureID = state.selectedFurnitureID
        let isPlacementPending = state.isPlacementPending
        let presentationPhase = state.presentationPhase
        let activeRest = state.activeRest
        let restSessionID = state.restSessionID
        let restSessionWasCommitted = state.restSessionWasCommitted
        let restEndReported = state.restEndReported
        let restDeadline = state.restDeadline
        let latest = state.latest
        guard furnitureTesting, size.width > 0, size.height > 0 else { return }
        let objects: [[String: Any]] = renderedFurniture.compactMap { placement in
            guard let item = ownedFurniture.first(where: { $0.id == placement.itemID }),
                  let node = furnitureNodes[item.id] else { return nil }
            return ["id": item.id, "kind": item.kind.rawValue,
                    "x": node.position.x / size.width, "y": 1 - node.position.y / size.height]
        }
        let payload: [String: Any] = [
            "items": objects, "selected": selectedFurnitureID ?? "bowl", "pending": isPlacementPending,
            "phase": presentationPhase, "violations": collisionViolations,
            "completedMeals": cat.completedMeals, "foodContactSamples": foodContactSamples,
            "foodContactViolations": foodContactViolations,
            "restFurniture": activeRest?.item.id as Any? ?? NSNull(),
            "restPoint": activeRest.map { ["x": $0.plan.restPoint.x / size.width,
                                           "y": 1 - $0.plan.restPoint.y / size.height] } as Any? ?? NSNull(),
            "restPhase": cat.restPhase.rawValue, "restContactSamples": restContactSamples,
            "restSession": restSessionID as Any? ?? NSNull(),
            "restSessionCommitted": restSessionWasCommitted,
            "restSessionEndReported": restEndReported,
            "restDeadline": restDeadline?.timeIntervalSince1970 as Any? ?? NSNull(),
            "savedRestSession": latest?.cats.first?.activeRest?.id as Any? ?? NSNull(),
            "catEnergy": latest?.cats.first?.energy as Any? ?? NSNull(),
            "lastRestEndReason": lastRestEndReason,
            "lastRestInput": lastRestInput,
            "stepPhase": cat.stepPhase.rawValue, "stepProgress": cat.stepProgress,
            "supportElevation": cat.supportElevation,
            "restVisualPoint": cat.restVisualContactPoint.map { ["x": $0.x / size.width, "y": 1 - $0.y / size.height] } as Any? ?? NSNull(),
            "bedEdgeContactSamples": bedEdgeContactSamples,
            "bedEdgeContactViolations": bedEdgeContactViolations,
            "bedEdgeMaxError": bedEdgeMaxError,
            "frontPaw": cat.frontPawContact.map { ["x": $0.x / size.width, "y": 1 - $0.y / size.height] } as Any? ?? NSNull(),
            "rearPaw": cat.rearPawContact.map { ["x": $0.x / size.width, "y": 1 - $0.y / size.height] } as Any? ?? NSNull(),
            "stepForeSupportSamples": stepForeSupportSamples, "stepLiftSamples": stepLiftSamples,
            "stepDownSamples": stepDownSamples, "stepClearanceViolations": stepClearanceViolations,
            "lastRestInterrupt": lastRestInterrupt as Any? ?? NSNull(),
            "completedRests": cat.completedRests, "restExits": restExits,
            "carePlanning": carePlanning, "carePlanCompletions": carePlanCompletions,
            "carePlanCancelled": carePlanCancelled, "lastCarePlanMilliseconds": lastCarePlanMilliseconds,
            "lastCarePlanOnMainThread": lastCarePlanOnMainThread,
            "bowl": ["x": bowl.x / size.width, "y": 1 - bowl.y / size.height],
            "cat": ["x": cat.position.x / size.width, "y": 1 - cat.position.y / size.height]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            furnitureDescription = text
            onFurnitureDiagnosticsChanged?(text)
        }
    }

}
#endif
