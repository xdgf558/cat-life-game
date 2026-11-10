import XCTest

extension RoomHomeUITests {
    struct FurniturePoint: Decodable {
        let x: Double
        let y: Double
        var position: CGVector { CGVector(dx: x, dy: y) }
    }

    struct FurnitureItemState: Decodable {
        let id: String
        let kind: String
        let x: Double
        let y: Double
        let orientation: String
        var position: CGVector { CGVector(dx: x, dy: y) }
        var isWall: Bool { kind == "wallFlower" || kind == "wallCat" }

        private enum CodingKeys: String, CodingKey { case id, kind, x, y, orientation }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decode(String.self, forKey: .id)
            kind = try values.decode(String.self, forKey: .kind)
            x = try values.decode(Double.self, forKey: .x)
            y = try values.decode(Double.self, forKey: .y)
            orientation = try values.decodeIfPresent(String.self, forKey: .orientation) ?? "normal"
        }
    }

    struct RestInterruptState: Decodable {
        let reason: String
        let restPhase: String
        let stepPhase: String
        let stepProgress: Double
    }

    struct FurnitureState: Decodable {
        let phase: String
        let items: [FurnitureItemState]
        let selected: String
        let pending: Bool
        let violations: Int
        let completedMeals: Int
        let completedPounces: Int?
        let activeCatID: String?
        let catAppearance: String?
        let cameraScale: Double?
        let fitScale: Double?
        let cameraX: Double?
        let cameraY: Double?
        let worldWidth: Double?
        let worldHeight: Double?
        let viewportWidth: Double?
        let viewportHeight: Double?
        let carePlanning: Bool?
        let foodContactSamples: Int
        let foodContactViolations: Int
        let bowl: FurniturePoint
        let cat: FurniturePoint
        let restFurniture: String?
        let restPoint: FurniturePoint?
        let restVisualPoint: FurniturePoint?
        let restContactSamples: Int?
        let completedRests: Int?
        let restPhase: String?
        let restExits: Int?
        let stepPhase: String?
        let stepProgress: Double?
        let supportElevation: Double?
        let frontPaw: FurniturePoint?
        let rearPaw: FurniturePoint?
        let stepForeSupportSamples: Int?
        let stepLiftSamples: Int?
        let stepDownSamples: Int?
        let stepClearanceViolations: Int?
        let bedEdgeContactSamples: Int?
        let bedEdgeContactViolations: Int?
        let bedEdgeMaxError: Double?
        let lastRestInterrupt: RestInterruptState?
        let restSession: String?
        let restSessionCommitted: Bool?
        let restSessionEndReported: Bool?
        let restDeadline: Double?
        let savedRestSession: String?
        let catEnergy: Int?
        let lastRestEndReason: String?

        init?(value: Any?) {
            guard let value = value as? String, let data = value.data(using: .utf8),
                  let state = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
            self = state
        }
    }

    @MainActor
    func launchRestHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--rest-test"]
        launchAndEnterHome(app)
        let ready = waitForFurniture(in: app, description: "rest-enabled room to open",
                                     matching: { $0.phase == "idle" && !$0.pending && $0.restPhase == "none" })
        XCTAssertNotNil(ready.restContactSamples)
        XCTAssertNotNil(ready.completedRests)
        XCTAssertNotNil(ready.restExits)
        XCTAssertNotNil(ready.stepForeSupportSamples)
        XCTAssertNotNil(ready.stepLiftSamples)
        XCTAssertNotNil(ready.stepDownSamples)
        XCTAssertEqual(ready.stepClearanceViolations, 0)
        XCTAssertNotNil(ready.bedEdgeContactSamples)
        XCTAssertEqual(ready.bedEdgeContactViolations, 0)
        XCTAssertEqual(ready.bedEdgeMaxError, 0)
        return app
    }

    @MainActor
    func relaunchRestHome(_ app: XCUIApplication) -> FurnitureState {
        app.terminate()
        app.launchArguments = arguments(reset: false) + ["--rest-test"]
        launchAndEnterHome(app)
        return waitForFurniture(in: app, description: "saved room to reopen without a transient furniture rest",
                                matching: { $0.phase == "idle" && !$0.pending && $0.restPhase == "none" })
    }

    @MainActor
    func restFurnitureCoordinate(_ item: FurnitureItemState, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> XCUICoordinate {
        let canvas = element("roomScene", in: app).frame
        let expected = CGPoint(x: canvas.minX + item.x * canvas.width, y: canvas.minY + item.y * canvas.height)
        let frames = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "furniture-" + item.id))
            .allElementsBoundByIndex.map(\.frame).filter { $0.intersects(canvas) && !$0.isEmpty }
        // The logical source and displayed proxy share names; use the live visible frame, not a cached camera anchor.
        let frame = try XCTUnwrap(frames.min {
            hypot($0.midX - expected.x, $0.midY - expected.y) < hypot($1.midX - expected.x, $1.midY - expected.y)
        }, "Expected displayed furniture \(item.id)", file: file, line: line)
        let visible = frame.intersection(canvas)
        let diagnostic = try XCTUnwrap(element("roomScene", in: app).value as? String, file: file, line: line)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(diagnostic.utf8)) as? [String: Any],
                                   file: file, line: line)
        let residents = try XCTUnwrap(payload["residentCats"] as? [[String: Any]], file: file, line: line)
        let catFrames = residents.compactMap { cat -> CGRect? in
            guard cat["visible"] as? Bool == true,
                  let x = cat["x"] as? Double, let y = cat["y"] as? Double,
                  let width = cat["screenWidth"] as? Double, let height = cat["screenHeight"] as? Double else { return nil }
            return CGRect(x: canvas.minX + x * canvas.width - width / 2,
                          y: canvas.minY + y * canvas.height - height / 2, width: width, height: height)
        }
        // A cat can stand over the old tap point after leaving; touch visible furniture once, not the cat.
        let candidates = [(0.25, 0.12), (0.75, 0.12), (0.5, 0.25), (0.75, 0.5), (0.25, 0.5)]
            .map { CGPoint(x: visible.minX + visible.width * $0.0, y: visible.minY + visible.height * $0.1) }
        let point = try XCTUnwrap(candidates.first { point in
            !catFrames.contains { $0.insetBy(dx: -2, dy: -2).contains(point) }
        }, "Expected an exposed part of furniture \(item.id)", file: file, line: line)
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y))
    }

    @MainActor
    func beginFurnitureRest(_ id: String, in app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) throws -> FurnitureState {
        let before = furnitureState(in: app, file: file, line: line)
        let item = try XCTUnwrap(before.items.first { $0.id == id }, file: file, line: line)
        try restFurnitureCoordinate(item, in: app, file: file, line: line).tap()
        let resting = waitForFurniture(in: app, timeout: 60, description: "cat walks to and settles on \(id)",
                                       matching: { $0.phase == "resting" && $0.restFurniture == id && $0.restPhase == "resting"
                                           && ($0.restContactSamples ?? -1) > (before.restContactSamples ?? -1) },
                                       file: file, line: line)
        let restPoint = try XCTUnwrap(resting.restPoint, file: file, line: line)
        XCTAssertLessThan(hypot(resting.cat.x - restPoint.x, resting.cat.y - restPoint.y), 0.015,
                          "The cat must reach the real furniture rest anchor before lying down.", file: file, line: line)
        XCTAssertGreaterThan(hypot(resting.cat.x - before.cat.x, resting.cat.y - before.cat.y), 0.02,
                             "The furniture tap must trigger a real approach from the cat's previous position.", file: file, line: line)
        XCTAssertGreaterThan(resting.stepForeSupportSamples ?? -1, before.stepForeSupportSamples ?? -1,
                             "Climbing onto furniture must include actual front-paw support before the body follows.", file: file, line: line)
        XCTAssertGreaterThan(resting.stepLiftSamples ?? -1, before.stepLiftSamples ?? -1,
                             "The body and rear paws must visibly rise across the furniture edge before resting.", file: file, line: line)
        XCTAssertEqual(resting.stepClearanceViolations, 0,
                       "A completed rest must not hide paw or body penetration during the preceding climb.", file: file, line: line)
        XCTAssertEqual(resting.stepPhase, "supported", file: file, line: line)
        XCTAssertEqual(try XCTUnwrap(resting.stepProgress, file: file, line: line), 1, accuracy: 0.001,
                       file: file, line: line)
        let elevation = try XCTUnwrap(resting.supportElevation, file: file, line: line)
        XCTAssertGreaterThan(elevation, 0,
                             "The resting pose must remain supported at the real furniture surface height.", file: file, line: line)
        let visualPoint = try XCTUnwrap(resting.restVisualPoint, file: file, line: line)
        let roomHeight = Double(element("roomScene", in: app).frame.height)
        let cameraScale = resting.cameraScale ?? 1
        XCTAssertTrue([visualPoint.x, visualPoint.y, elevation, cameraScale].allSatisfy(\.isFinite), file: file, line: line)
        XCTAssertGreaterThan(cameraScale, 0, file: file, line: line)
        XCTAssertGreaterThan(roomHeight, 0, file: file, line: line)
        XCTAssertEqual(visualPoint.x, resting.cat.x, accuracy: 0.002, file: file, line: line)
        XCTAssertEqual(visualPoint.y, resting.cat.y - elevation / cameraScale / roomHeight, accuracy: 0.002,
                       "Rest diagnostics and taps must follow the visible supported body, not the lower navigation anchor.",
                       file: file, line: line)
        if id == "catBed" {
            XCTAssertGreaterThan(try XCTUnwrap(resting.bedEdgeContactSamples, file: file, line: line),
                                 try XCTUnwrap(before.bedEdgeContactSamples, file: file, line: line),
                                 "The front paws must contact the visible bed rim before the body follows.", file: file, line: line)
            XCTAssertEqual(resting.bedEdgeContactViolations, 0,
                           "Generic collision clearance cannot substitute for actual front-paw contact with the visible bed rim.",
                           file: file, line: line)
            let edgeError = try XCTUnwrap(resting.bedEdgeMaxError, file: file, line: line)
            XCTAssertTrue(edgeError.isFinite && edgeError >= 0, file: file, line: line)
            XCTAssertLessThanOrEqual(edgeError, 1,
                                     "Front paws may be at most one scene point outside the independently measured bed-rim support region.",
                                     file: file, line: line)
        }
        let attachment = XCTAttachment(string: String(describing: element("roomScene", in: app).value))
        attachment.name = "Rest contact — \(id)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return resting
    }

    @MainActor
    func assertRestSuppliesUnchanged(in app: XCUIApplication,
                                             file: StaticString = #filePath, line: UInt = #line) {
        waitForObservedValue("foodCount", "3", in: app, file: file, line: line)
        waitForObservedValue("goldCount", "200", in: app, file: file, line: line)
        tapAnimationControl("tabInventory", in: app, file: file, line: line)
        waitForObservedValue("inventoryFoodCount", "3", in: app, file: file, line: line)
        waitForObservedValue("inventoryLitterCount", "2", in: app, file: file, line: line)
        waitForObservedValue("inventoryToyUses", "0", in: app, file: file, line: line)
        tapAnimationControl("tabHome", in: app, file: file, line: line)
    }

    @MainActor
    func selectBagFurniture(_ id: String, in app: XCUIApplication,
                            file: StaticString = #filePath, line: UInt = #line) {
        scrollCareerPage("destinationScroll", to: "inventoryFurniture_\(id)", in: app, file: file, line: line)
        tapAnimationControl("inventoryFurniture_\(id)", in: app, file: file, line: line)
    }

    @MainActor
    func launchFurnitureHome() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--furniture-test"]
        launchAndEnterHome(app)
        _ = waitForFurniture(in: app, description: "furniture room to open",
                             matching: { $0.phase == "idle" && !$0.pending })
        return app
    }

    @MainActor
    func furnitureState(in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) -> FurnitureState {
        let value = element("roomScene", in: app).value
        guard let state = FurnitureState(value: value) else {
            XCTFail("Expected furniture diagnostics, received \(String(describing: value))", file: file, line: line)
            return FurnitureState(value: "{\"phase\":\"invalid\",\"items\":[],\"selected\":\"bowl\",\"pending\":false,\"violations\":-1,\"completedMeals\":0,\"foodContactSamples\":0,\"foodContactViolations\":-1,\"bowl\":{\"x\":0,\"y\":0},\"cat\":{\"x\":0,\"y\":0}}")!
        }
        XCTAssertEqual(state.violations, 0, "Furniture changes must not make the cat cross an obstacle or wall.", file: file, line: line)
        XCTAssertEqual(state.foodContactViolations, 0, "The mouth must reach the food surface after furniture changes.", file: file, line: line)
        if let violations = state.stepClearanceViolations {
            XCTAssertEqual(violations, 0, "Stepping onto or off furniture must preserve paw and body clearance.", file: file, line: line)
        }
        if let violations = state.bedEdgeContactViolations {
            XCTAssertEqual(violations, 0, "The front paws must meet the visible bed rim while supporting the climb.", file: file, line: line)
        }
        XCTAssertEqual(Set(state.items.map(\.id)).count, state.items.count,
                       "Placed furniture IDs must remain unique.", file: file, line: line)
        let coordinates = [state.cat.x, state.cat.y, state.bowl.x, state.bowl.y]
            + state.items.flatMap { [$0.x, $0.y] }
        XCTAssertTrue(coordinates.allSatisfy(\.isFinite), "Furniture coordinates must remain finite.", file: file, line: line)
        return state
    }

    @MainActor
    func waitForFurniture(in app: XCUIApplication, timeout: TimeInterval = 15, description: String,
                                  matching condition: @escaping (FurnitureState) -> Bool,
                                  file: StaticString = #filePath, line: UInt = #line) -> FurnitureState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, target.exists,
                  let state = FurnitureState(value: target.value) else { return false }
            return state.violations != 0 || state.foodContactViolations != 0
                || (state.stepClearanceViolations ?? 0) != 0
                || (state.bedEdgeContactViolations ?? 0) != 0 || condition(state)
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Expected \(description); received \(String(describing: room.value))", file: file, line: line)
        return furnitureState(in: app, file: file, line: line)
    }

    @MainActor
    func selectFurniture(_ id: String, in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> FurnitureState {
        let state = furnitureState(in: app, file: file, line: line)
        let item = try XCTUnwrap(state.items.first { $0.id == id }, "Expected placed furniture \(id)", file: file, line: line)
        let room = element("roomScene", in: app)
        let roomFrame = room.frame
        var touch = CGVector(dx: item.x, dy: item.y - (item.isWall ? 0 : 0.02))
        let point = CGPoint(x: roomFrame.minX + touch.dx * roomFrame.width,
                            y: roomFrame.minY + touch.dy * roomFrame.height)
        let quickActions = ["flipFurnitureButton", "quickStoreFurnitureButton"].map { element($0, in: app) }
            .filter(\.exists).reduce(CGRect.null) { $0.union($1.frame) }.insetBy(dx: -8, dy: -8)
        if quickActions.contains(point) {
            // Select the exposed artwork, not the previous selection's floating controls.
            let sprite = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "furniture-" + id)).firstMatch
            XCTAssertTrue(sprite.exists, "Expected visible furniture artwork \(id)", file: file, line: line)
            let visible = sprite.frame.intersection(roomFrame).insetBy(dx: 3, dy: 3)
            let candidates = [0.5, 0.25, 0.75].flatMap { y in
                [0.5, 0.25, 0.75].map { x in
                    CGPoint(x: visible.minX + visible.width * x, y: visible.minY + visible.height * y)
                }
            }
            let exposed = try XCTUnwrap(candidates.first { visible.contains($0) && !quickActions.contains($0) },
                                       "Expected an exposed tap point on \(id)", file: file, line: line)
            touch = CGVector(dx: (exposed.x - roomFrame.minX) / roomFrame.width,
                             dy: (exposed.y - roomFrame.minY) / roomFrame.height)
        }
        room.coordinate(withNormalizedOffset: touch).tap()
        return waitForFurniture(in: app, description: "\(id) to be selected",
                                matching: { $0.selected == id && !$0.pending }, file: file, line: line)
    }

    @MainActor
    func dragFurniture(_ item: FurnitureItemState, to target: CGVector, in app: XCUIApplication,
                               file: StaticString = #filePath, line: UInt = #line) -> FurnitureState {
        let room = element("roomScene", in: app)
        let offset: CGFloat = item.isWall ? 0 : 0.02
        let start = CGVector(dx: item.x, dy: item.y - Double(offset))
        let finish = CGVector(dx: target.dx, dy: target.dy - offset)
        room.coordinate(withNormalizedOffset: start)
            .press(forDuration: 0.15, thenDragTo: room.coordinate(withNormalizedOffset: finish),
                   withVelocity: .slow, thenHoldForDuration: 0)
        let done = element("layoutDoneButton", in: app)
        return waitForFurniture(in: app, timeout: 25, description: "\(item.id) drag to finish placement validation",
                                matching: { $0.selected == item.id && !$0.pending && done.exists && done.isEnabled },
                                file: file, line: line)
    }

    struct NavigationState {
        let phase: String
        let violations: Int
        let cat: CGVector
        let bowl: CGVector
        let maxRoutePoints: Int
        let completedMeals: Int
        let completedPounces: Int
        let foodContactSamples: Int
        let foodContactViolations: Int

        init?(value: Any?) {
            guard let value = value as? String else { return nil }
            let fields = value.split(separator: "|", omittingEmptySubsequences: false)
            guard fields.count >= 9, let violations = Int(fields[1]),
                  let maxRoutePoints = Int(fields[4]), let completedMeals = Int(fields[5]),
                  let completedPounces = Int(fields[6]), let foodContactSamples = Int(fields[7]),
                  let foodContactViolations = Int(fields[8]) else { return nil }
            func point(_ field: Substring) -> CGVector? {
                let coordinates = field.split(separator: ",").compactMap { Double($0) }
                guard coordinates.count == 2, coordinates.allSatisfy(\.isFinite) else { return nil }
                return CGVector(dx: coordinates[0], dy: coordinates[1])
            }
            guard let cat = point(fields[2]), let bowl = point(fields[3]) else { return nil }
            phase = String(fields[0])
            self.violations = violations
            self.cat = cat
            self.bowl = bowl
            self.maxRoutePoints = maxRoutePoints
            self.completedMeals = completedMeals
            self.completedPounces = completedPounces
            self.foodContactSamples = foodContactSamples
            self.foodContactViolations = foodContactViolations
        }
    }

    @MainActor
    func launchNavigationHome() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = arguments(reset: true) + ["--navigation-test"]
        launchAndEnterHome(app)
        waitForNavigationPhase("idle", in: app, timeout: 15)
        return app
    }

    @MainActor
    func completeNavigationFeed(in app: XCUIApplication, remainingFood: Int,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let before = navigationState(in: app, file: file, line: line)
        tapAnimationControl("feedButton", in: app, file: file, line: line)
        waitForNavigationPhase("feeding", in: app, timeout: 5, file: file, line: line)
        _ = waitForNavigation(in: app, timeout: 25, description: "mouth reaches food",
                              matching: { $0.foodContactSamples > before.foodContactSamples }, file: file, line: line)
        attachScreenshot(app, named: "Feeding — mouth at food, meal \(before.completedMeals + 1)")
        let after = waitForNavigationPhase("idle", in: app, timeout: 35, file: file, line: line)
        XCTAssertGreaterThan(after.foodContactSamples, before.foodContactSamples,
                             "A real meal must sample the low-head mouth against the food surface.", file: file, line: line)
        XCTAssertEqual(after.completedMeals, before.completedMeals + 1,
                       "This feeding must reach the bowl and complete the eating poses, not a stationary fallback.",
                       file: file, line: line)
        XCTAssertEqual(after.cat.dx, before.cat.dx, accuracy: 0.008,
                       "Feeding must return to the starting floor position.", file: file, line: line)
        XCTAssertEqual(after.cat.dy, before.cat.dy, accuracy: 0.008,
                       "Feeding must finish its return path.", file: file, line: line)
        waitForObservedValue("foodCount", "\(remainingFood)", in: app, file: file, line: line)
    }

    @MainActor
    func navigationState(in app: XCUIApplication,
                                 file: StaticString = #filePath, line: UInt = #line) -> NavigationState {
        let value = element("roomScene", in: app).value
        guard let state = NavigationState(value: value) else {
            XCTFail("Expected navigation diagnostics, received \(String(describing: value))", file: file, line: line)
            // continueAfterFailure is false; keep a return value only so this
            // helper can report the malformed diagnostics at the calling line.
            return NavigationState(value: "invalid|-1|0,0|0,0|0|0|0|0|-1")!
        }
        XCTAssertEqual(state.violations, 0, "A cat route crossed the bowl or left the floor: \(value ?? "")",
                       file: file, line: line)
        XCTAssertEqual(state.foodContactViolations, 0, "The mouth missed the food surface during a bite.", file: file, line: line)
        for coordinate in [state.cat.dx, state.cat.dy, state.bowl.dx, state.bowl.dy] {
            XCTAssertTrue((0...1).contains(coordinate), "The cat and bowl must stay inside the visible room.",
                          file: file, line: line)
        }
        return state
    }

    @MainActor
    @discardableResult
    func waitForNavigationPhase(_ phase: String, in app: XCUIApplication, timeout: TimeInterval,
                                        file: StaticString = #filePath, line: UInt = #line) -> NavigationState {
        waitForNavigation(in: app, timeout: timeout, description: "phase \(phase)",
                          matching: { $0.phase == phase }, file: file, line: line)
    }

    @MainActor
    func waitForNavigation(in app: XCUIApplication, timeout: TimeInterval, description: String,
                                    matching condition: @escaping (NavigationState) -> Bool,
                                    file: StaticString = #filePath, line: UInt = #line) -> NavigationState {
        let room = element("roomScene", in: app)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            guard let target = object as? XCUIElement, target.exists,
                  let state = NavigationState(value: target.value) else { return false }
            // Violations accumulate in the scene on every rendered frame. Stop
            // immediately on one, even if the expected phase has not arrived.
            return state.violations != 0 || state.foodContactViolations != 0 || condition(state)
        }, object: room)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed,
                       "Expected \(description); received \(String(describing: room.value))", file: file, line: line)
        return navigationState(in: app, file: file, line: line)
    }

    @MainActor
    func bowlPosition(in app: XCUIApplication) -> CGVector {
        let value = element("roomScene", in: app).value as? String ?? ""
        let parts = value.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(parts.count, 2, "Room must expose its saved bowl position")
        guard parts.count == 2 else { return .zero }
        return CGVector(dx: parts[0], dy: parts[1])
    }

    @MainActor
    func roomCoordinate(forArtworkCoordinate point: CGVector, in app: XCUIApplication) -> CGVector {
        let roomSize = element("roomScene", in: app).frame.size
        XCTAssertGreaterThan(roomSize.width, 0)
        XCTAssertGreaterThan(roomSize.height, 0)
        let fill = max(roomSize.width / 1024, roomSize.height / 1536)
        return CGVector(dx: 0.5 + (point.dx - 0.5) * 1024 * fill / roomSize.width,
                        dy: 0.5 + (point.dy - 0.5) * 1536 * fill / roomSize.height)
    }

    @MainActor
    func artworkCoordinate(forRoomCoordinate point: CGVector, in app: XCUIApplication) -> CGVector {
        let roomSize = element("roomScene", in: app).frame.size
        XCTAssertGreaterThan(roomSize.width, 0)
        XCTAssertGreaterThan(roomSize.height, 0)
        let fill = max(roomSize.width / 1024, roomSize.height / 1536)
        return CGVector(dx: 0.5 + (point.dx - 0.5) * roomSize.width / (1024 * fill),
                        dy: 0.5 + (point.dy - 0.5) * roomSize.height / (1536 * fill))
    }

    @MainActor
    func dragBowl(from: CGVector, to: CGVector, in app: XCUIApplication) {
        let room = element("roomScene", in: app)
        room.coordinate(withNormalizedOffset: from)
            .press(forDuration: 0.15, thenDragTo: room.coordinate(withNormalizedOffset: to))
    }
}
