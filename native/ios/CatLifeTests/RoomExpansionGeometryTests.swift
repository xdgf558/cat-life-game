import Foundation
import XCTest
import CatGameCore
@testable import CatLife

final class RoomExpansionGeometryTests: XCTestCase {
    private let viewports = [CGSize(width: 375, height: 436), CGSize(width: 402, height: 567)]
    private let artworkSize = CGSize(width: 1024, height: 1536)

    func testWorldExpansionPreservesLevelOneMappingAndPhysicalFootprints() throws {
        for viewport in viewports {
            let original = RoomArtworkTransform(sceneSize: viewport, artworkSize: artworkSize)
            let base = makeWorld(viewport: viewport, scale: 1)
            let baseArea = area(base.roomFloor.polygon)
            for level in 1...3 {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)).worldScale)
                let world = makeWorld(viewport: viewport, scale: scale)
                XCTAssertEqual(world.roomFloor.catFootprint, base.roomFloor.catFootprint)
                XCTAssertEqual(world.roomFloor.bowlFootprint, base.roomFloor.bowlFootprint)
                XCTAssertEqual(world.transform.visualScale, original.scale)
                XCTAssertEqual(world.placements, base.placements, "An upgrade must not rewrite saved normalized layout.")
                for item in world.items {
                    XCTAssertEqual(world.footprint(item), base.footprint(item))
                    let position = try XCTUnwrap(world.center(item.id))
                    let oldPosition = try XCTUnwrap(base.center(item.id))
                    XCTAssertEqual(position.x, oldPosition.x * scale, accuracy: 0.0001)
                    XCTAssertEqual(position.y, oldPosition.y * scale, accuracy: 0.0001)
                }
                if level == 1 {
                    XCTAssertEqual(world.transform.point(.init(x: 0.31, y: 0.68)), original.point(.init(x: 0.31, y: 0.68)))
                    XCTAssertEqual(world.roomFloor.polygon, base.roomFloor.polygon)
                } else {
                    XCTAssertGreaterThan(area(world.roomFloor.polygon), baseArea * scale)
                }
            }
        }
    }

    @MainActor
    func testEveryLevelRestoresReachableBowlAndAddsUsablePlacementBeyondOldViewport() async throws {
        for viewport in viewports {
            for level in 1...3 {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)).worldScale)
                let initial = makeWorld(viewport: viewport, scale: scale)
                let start = CGPoint(x: initial.transform.sceneSize.width * 0.43, y: initial.transform.sceneSize.height * 0.18)
                let value = await Task.detached {
                    RoomBowlPlanner(floor: initial.roomFloor, requested: initial.bowlPosition, catPosition: start).resolve()
                }.value
                let bowl = try XCTUnwrap(value, "\(viewport), level \(level)")
                let cat = try XCTUnwrap(bowl.catPosition)
                let meal = try XCTUnwrap(initial.roomFloor.feedingPlan(from: cat, bowlAt: bowl.center, navigator: bowl.navigation))
                XCTAssertTrue(zip(meal.path, meal.path.dropFirst()).allSatisfy {
                    bowl.navigation.segmentIsWalkable(from: $0.0, to: $0.1)
                })
                XCTAssertEqual(initial.bowlPosition, CGPoint(x: viewport.width * scale * 0.76, y: viewport.height * scale * 0.21))
#if DEBUG
                XCTAssertFalse(bowl.ranOnMainThread)
#endif
                guard level > 1 else { continue }
                let plant = FurnitureItem(id: "shop-plant-instance", kind: .plant)
                let world = RoomFurnitureWorld(transform: initial.transform, catWidth: initial.catWidth,
                    bowlSize: initial.bowlSize, bowlPosition: bowl.center,
                    items: initial.items + [plant], placements: initial.placements)
                let result = await Task.detached {
                    let navigation = world.placementNavigator(for: plant.id, catAt: cat)
                    guard let point = navigation.walkablePoints.first(where: {
                        $0.x - world.footprint(plant).width / 2 > viewport.width
                    }) else { return Optional<RoomFurnitureResolution>.none }
                    return world.resolve(id: plant.id, near: point, catAt: cat, placement: navigation)
                }.value
                let placement = try XCTUnwrap(result, "Expansion must add usable space outside the old viewport.")
                XCTAssertGreaterThan(placement.center.x - world.footprint(plant).width / 2, viewport.width)
                XCTAssertTrue(placement.navigation.isWalkable(cat))
                XCTAssertNotNil(placement.floor.feedingPlan(from: cat, bowlAt: bowl.center, navigator: placement.navigation))
            }
        }
    }

    func testRoundedBedPlacementReachesTheWindowFloorWhileKeepingItsSizeAndSafeRest() throws {
        let bed = FurnitureItem(id: "catBed", kind: .catBed)
        let placements = FurnitureCatalog.defaultPlacements.filter { $0.itemID == bed.id }
        for viewport in [CGSize(width: 375, height: 436), CGSize(width: 402, height: 776)] {
            let world = makeWorld(viewport: viewport, scale: 1.5, items: [bed], placements: placements)
            let start = CGPoint(x: world.transform.sceneSize.width * 0.43,
                                y: world.transform.sceneSize.height * 0.18)
            let destination = world.transform.point(.init(x: 270.0 / 1024, y: 740.0 / 1536))
            let placement = world.placementNavigator(for: bed.id, catAt: start)
            let oldRectangle = RoomNavigation(floor: placement.floor, obstacles: placement.obstacles,
                footprint: placement.footprint, precomputeGrid: false)
            XCTAssertEqual(placement.floorFootprintShape, .clippedCorners)
            XCTAssertFalse(oldRectangle.isWalkable(destination))
            XCTAssertTrue(placement.isWalkable(destination))
            XCTAssertEqual(placement.nearestWalkable(to: destination), destination,
                           "The live drag preview must reach the requested floor point, not stop at a rectangular corner.")
            XCTAssertFalse(placement.isWalkable(world.transform.point(.init(x: 270.0 / 1024, y: 732.0 / 1536))))
            let resolved = try XCTUnwrap(world.resolve(id: bed.id, near: destination, catAt: start, placement: placement))
            XCTAssertEqual(resolved.center.x, destination.x, accuracy: 0.0001)
            XCTAssertEqual(resolved.center.y, destination.y, accuracy: 0.0001)
            let moved = world.replacing(bed.id, with: resolved.center)
            XCTAssertEqual(moved.roomFloor.polygon, world.roomFloor.polygon)
            XCTAssertEqual(moved.footprint(bed), world.footprint(bed))
            XCTAssertEqual(resolved.navigation.floorFootprintShape, .rectangle)
            XCTAssertNotNil(moved.restVisit(to: bed.id, from: start))
        }
    }

    func testOtherFurnitureBowlAndCatKeepRectangularFloorClearance() {
        let viewport = CGSize(width: 375, height: 436)
        let world = makeWorld(viewport: viewport, scale: 1.5)
        let cat = CGPoint(x: viewport.width * 1.5 * 0.43, y: viewport.height * 1.5 * 0.18)
        for item in world.items where item.kind != .catBed {
            XCTAssertEqual(world.placementNavigator(for: item.id, catAt: cat).floorFootprintShape, .rectangle)
        }
        XCTAssertEqual(world.placementNavigator(for: nil, catAt: cat).floorFootprintShape, .rectangle)
        XCTAssertEqual(world.roomFloor.navigator(bowlAt: world.bowlPosition, precomputeGrid: false).floorFootprintShape,
                       .rectangle)
    }

    func testPurchasedCushionKeepsStepHeightAndSafeEntryExitAtEveryLevel() throws {
        let cushion = FurnitureItem(id: "shop-cushion-instance", kind: .floorCushion)
        let placement = FurniturePlacement(itemID: cushion.id, position: .init(x: 0.30, y: 0.65))
        for viewport in viewports {
            let base = makeWorld(viewport: viewport, scale: 1, items: [cushion], placements: [placement])
            for level in 1...3 {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)).worldScale)
                let world = makeWorld(viewport: viewport, scale: scale, items: [cushion], placements: [placement])
                let start = CGPoint(x: viewport.width * scale * 0.43, y: viewport.height * scale * 0.18)
                let visit = try XCTUnwrap(world.restVisit(to: cushion.id, from: start), "\(viewport), level \(level)")
                XCTAssertEqual(world.footprint(cushion), base.footprint(cushion))
                XCTAssertEqual(visit.elevation, base.catWidth * 0.14)
                XCTAssertEqual(visit.entryContactProgress, 0.14)
                XCTAssertTrue(visit.target.contains(visit.plan.restPoint))
                XCTAssertEqual(visit.plan.exit, Array(visit.plan.entry.reversed()))
                for route in [visit.plan.entry, visit.plan.exit] {
                    XCTAssertTrue(zip(route, route.dropFirst()).allSatisfy {
                        visit.navigation.segmentIsWalkable(from: $0.0, to: $0.1)
                    })
                }
                let approach = world.roomFloor.navigator(bowlAt: world.bowlPosition)
                XCTAssertTrue(zip(visit.plan.approach, visit.plan.approach.dropFirst()).allSatisfy {
                    approach.segmentIsWalkable(from: $0.0, to: $0.1)
                })
            }
        }
    }

    func testTallViewportBedKeepsReachableRimAndSafeEntryAtEveryRoomSize() throws {
        // The full-height Pro room previously rejected every bed before trying
        // a route: its .14 contact required a 35.08pt step, above the 30.95pt cap.
        for viewport in [CGSize(width: 375, height: 569), CGSize(width: 402, height: 776)] {
            for level in [1, 3] {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)).worldScale)
                for orientation in FurnitureOrientation.allCases {
                    var items = FurnitureCatalog.defaultItems
                    let bedIndex = try XCTUnwrap(items.firstIndex { $0.id == "catBed" })
                    items[bedIndex].orientation = orientation
                    let world = makeWorld(viewport: viewport, scale: scale, items: items)
                    let start = CGPoint(x: viewport.width * scale * 0.43, y: viewport.height * scale * 0.18)
                    let visit = try XCTUnwrap(world.restVisit(to: "catBed", from: start),
                                             "\(viewport), level \(level), \(orientation)")
                    let center = try XCTUnwrap(world.center("catBed"))
                    let spec = RoomFurnitureSpec.forItem(items[bedIndex])
                    let bedHeight = spec.width * world.transform.visualScale * 917 / 1391
                    let rimY = center.y + bedHeight * (0.17 - spec.anchorY)
                    let visualRestY = center.y + visit.target.height * 0.16 + world.catWidth * 0.06
                    let contactAnchorY = visit.plan.stage.y
                        + (visit.plan.restPoint.y - visit.plan.stage.y) * visit.entryContactProgress
                    XCTAssertEqual(contactAnchorY + visit.elevation, rimY, accuracy: 0.0001)
                    XCTAssertEqual(visit.plan.restPoint.y + visit.elevation, visualRestY, accuracy: 0.0001)
                    XCTAssertGreaterThan(visit.elevation, 0)
                    XCTAssertLessThanOrEqual(visit.elevation, world.catWidth * 0.55)
                    XCTAssertLessThanOrEqual(visit.entryContactProgress, 0.40)
                    if viewport.height == 569 {
                        XCTAssertEqual(visit.entryContactProgress, 0.14, "Existing safe climbs must not change.")
                        XCTAssertEqual(visit.elevation, 27.439878224633443, accuracy: 0.0001)
                    } else {
                        XCTAssertEqual(world.catWidth, 56.28, accuracy: 0.0001)
                        XCTAssertEqual(world.footprint(items[bedIndex]).height, 72.75, accuracy: 0.0001)
                        XCTAssertEqual(visit.entryContactProgress, 0.27383629025948686, accuracy: 0.0001)
                    }
                    let keys = CatFurnitureStepTimeline.ascending(elevation: visit.elevation,
                                                                 contactProgress: visit.entryContactProgress)
                    let contacts = keys.filter { $0.phase == .frontPaws }
                    XCTAssertEqual(contacts.count, 2)
                    XCTAssertTrue(contacts.allSatisfy {
                        $0.travel == visit.entryContactProgress && $0.progress == visit.entryContactProgress
                            && $0.elevation == 0
                    })
                    XCTAssertEqual(visit.plan.exit, Array(visit.plan.entry.reversed()))
                    for route in [visit.plan.entry, visit.plan.exit] {
                        XCTAssertTrue(zip(route, route.dropFirst()).allSatisfy {
                            visit.navigation.segmentIsWalkable(from: $0.0, to: $0.1)
                        })
                    }
                    let approach = world.roomFloor.navigator(bowlAt: world.bowlPosition, precomputeGrid: false)
                    XCTAssertTrue(zip(visit.plan.approach, visit.plan.approach.dropFirst()).allSatisfy {
                        approach.segmentIsWalkable(from: $0.0, to: $0.1)
                    })
                    let descent = CatFurnitureStepTimeline.descending(elevation: visit.elevation)
                    XCTAssertEqual(descent.first?.elevation, visit.elevation)
                    XCTAssertEqual(descent.last?.elevation, 0)
                    XCTAssertEqual(descent.last?.travel, 1)
                }
            }
        }
    }

    func testTallViewportBedCanMoveWithoutShrinkingItOrRelaxingClimbLimits() throws {
        let viewport = CGSize(width: 402, height: 776)
        let initial = makeWorld(viewport: viewport, scale: 1.5)
        let start = CGPoint(x: 603 * 0.43, y: 1164 * 0.18)
        let bed = try XCTUnwrap(initial.item("catBed"))
        let center = try XCTUnwrap(initial.center(bed.id))
        let placement = initial.placementNavigator(for: bed.id, catAt: start)
        let destination = CGPoint(x: center.x + 35, y: center.y + 15)
        let resolved = try XCTUnwrap(initial.resolve(id: bed.id, near: destination, catAt: start, placement: placement))
        let moved = initial.replacing(bed.id, with: resolved.center)
        XCTAssertGreaterThan(hypot(resolved.center.x - center.x, resolved.center.y - center.y), 10)
        XCTAssertEqual(moved.footprint(bed), initial.footprint(bed))
        XCTAssertNotNil(moved.restVisit(to: bed.id, from: start))

        // With no other furniture present, an extreme bed/cat size mismatch
        // must still fail the physical reach limit rather than fake a climb.
        let impossible = RoomFurnitureWorld(transform: initial.transform, catWidth: 5,
            bowlSize: initial.bowlSize, bowlPosition: initial.bowlPosition,
            items: [bed], placements: initial.placements.filter { $0.itemID == bed.id })
        XCTAssertNil(impossible.restVisit(to: bed.id, from: start))
    }

    func testStarterCushionFitsFullHeightRoomWithoutTouchingBedOrFlowerStool() throws {
        for viewport in [CGSize(width: 375, height: 569), CGSize(width: 402, height: 776)] {
            for level in [1, 3] {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)).worldScale)
                let world = makeWorld(viewport: viewport, scale: scale)
                let start = CGPoint(x: viewport.width * scale * 0.43, y: viewport.height * scale * 0.18)
                let cushion = try XCTUnwrap(world.item("floorCushion"))
                let center = try XCTUnwrap(world.center(cushion.id))
                let rectangle = world.rectangle(cushion, at: center)
                let placement = world.placementNavigator(for: cushion.id, catAt: start)
                XCTAssertTrue(placement.isWalkable(center), "\(viewport), level \(level)")
                for neighborID in ["catBed", "flowerStool"] {
                    let neighbor = try XCTUnwrap(world.item(neighborID))
                    let neighborCenter = try XCTUnwrap(world.center(neighborID))
                    XCTAssertFalse(rectangle.intersects(world.rectangle(neighbor, at: neighborCenter)))
                }
                let visit = try XCTUnwrap(world.restVisit(to: cushion.id, from: start),
                                         "\(viewport), level \(level)")
                XCTAssertEqual(visit.elevation, world.catWidth * 0.14)
                XCTAssertEqual(visit.entryContactProgress, 0.14)
                XCTAssertEqual(visit.plan.exit, Array(visit.plan.entry.reversed()))
                for route in [visit.plan.entry, visit.plan.exit] {
                    XCTAssertTrue(zip(route, route.dropFirst()).allSatisfy {
                        visit.navigation.segmentIsWalkable(from: $0.0, to: $0.1)
                    })
                }
                let approach = world.roomFloor.navigator(bowlAt: world.bowlPosition, precomputeGrid: false)
                XCTAssertTrue(zip(visit.plan.approach, visit.plan.approach.dropFirst()).allSatisfy {
                    approach.segmentIsWalkable(from: $0.0, to: $0.1)
                })
            }
        }
    }

    func testCameraClampsAndProjectsWithoutChangingWorldPositions() throws {
        for viewport in viewports {
            for level in 1...3 {
                let scale = CGFloat(try XCTUnwrap(HomeCatalog.level(level)).worldScale)
                let geometry = RoomWorldGeometry(viewportSize: viewport, worldScale: scale)
                let near = geometry.clampedCameraPosition(CGPoint(x: -1_000, y: -1_000))
                let far = geometry.clampedCameraPosition(CGPoint(x: 10_000, y: 10_000))
                XCTAssertEqual(near, CGPoint(x: viewport.width / 2, y: viewport.height / 2))
                XCTAssertEqual(far, CGPoint(x: geometry.worldSize.width - viewport.width / 2,
                                           y: geometry.worldSize.height - viewport.height / 2))
                let point = CGPoint(x: geometry.worldSize.width * 0.76, y: geometry.worldSize.height * 0.21)
                for camera in [near, far] {
                    let screen = geometry.screenPoint(point, camera: camera)
                    let restored = geometry.worldPoint(screen, camera: camera)
                    XCTAssertEqual(restored.x, point.x, accuracy: 0.0001)
                    XCTAssertEqual(restored.y, point.y, accuracy: 0.0001)
                }
                if level == 1 { XCTAssertEqual(near, far) }
                else { XCTAssertNotEqual(geometry.screenPoint(point, camera: near), geometry.screenPoint(point, camera: far)) }
            }
        }
    }

#if DEBUG
    @MainActor
    func testStoredFurniturePurchasePreservesPendingAndActiveFeeding() async throws {
        let scene = RoomScene(size: CGSize(width: 375, height: 436))
        defer { scene.setPresentationActive(false) }
        var snapshot = GameSnapshot.fresh()
        scene.apply(snapshot: snapshot, editing: false)
        let readyDeadline = Date().addingTimeInterval(10)
        while scene.presentationPhase != "idle", Date() < readyDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(scene.presentationPhase, "idle")
        let cat = try XCTUnwrap(scene.childNode(withName: "cat") as? CatActor)
        let bowlCompletions = scene.diagnostics.bowlPlanCompletions
        let bowlCancellations = scene.diagnostics.bowlPlanCancelled
        XCTAssertGreaterThan(bowlCompletions, 0)

        scene.playFeedback(kind: .feed)
        XCTAssertTrue(scene.diagnostics.carePlanning)
        let careCancellations = scene.diagnostics.carePlanCancelled
        snapshot.inventory.furniture.append(.init(id: "purchased-plant", kind: .plant))
        // The worker cannot publish until this MainActor call yields. A bag
        // purchase here must retain that exact in-flight care request.
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertTrue(scene.diagnostics.carePlanning)
        XCTAssertEqual(scene.diagnostics.carePlanCancelled, careCancellations)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, bowlCompletions)
        XCTAssertEqual(scene.diagnostics.bowlPlanCancelled, bowlCancellations)

        let plannedDeadline = Date().addingTimeInterval(10)
        while scene.diagnostics.carePlanCompletions == 0, Date() < plannedDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, 1)
        XCTAssertTrue(cat.isPerforming)
        // The actor owns its feeding action now. Without attaching an SKView,
        // rendering cannot advance it and make this interruption check race.
        snapshot.inventory.furniture.append(.init(id: "purchased-cushion", kind: .floorCushion))
        scene.apply(snapshot: snapshot, editing: false)
        snapshot.inventory.furniture.removeAll { $0.id == "purchased-plant" }
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertTrue(cat.isPerforming)
        XCTAssertEqual(scene.presentationPhase, "feeding")
        XCTAssertEqual(scene.diagnostics.carePlanCompletions, 1)
        XCTAssertEqual(scene.diagnostics.carePlanCancelled, careCancellations)
        XCTAssertEqual(scene.diagnostics.bowlPlanCompletions, bowlCompletions)
        XCTAssertEqual(scene.diagnostics.bowlPlanCancelled, bowlCancellations)

        // A real change to a placed item's geometry must still rebuild it.
        let bed = try XCTUnwrap(snapshot.inventory.furniture.firstIndex { $0.id == "catBed" })
        snapshot.inventory.furniture[bed].kind = .floorCushion
        scene.apply(snapshot: snapshot, editing: false)
        XCTAssertEqual(scene.presentationPhase, "layout-planning")
        XCTAssertFalse(cat.isPerforming)
    }
#endif

    private func makeWorld(viewport: CGSize, scale: CGFloat,
                           items: [FurnitureItem] = FurnitureCatalog.defaultItems,
                           placements: [FurniturePlacement] = FurnitureCatalog.defaultPlacements) -> RoomFurnitureWorld {
        let worldSize = CGSize(width: viewport.width * scale, height: viewport.height * scale)
        let bowlWidth = min(viewport.width * 0.156, viewport.height * 0.185)
        return RoomFurnitureWorld(transform: .init(sceneSize: worldSize, artworkSize: artworkSize, viewportSize: viewport),
            catWidth: min(viewport.width * 0.14, viewport.height * 0.172),
            bowlSize: CGSize(width: bowlWidth, height: bowlWidth * 0.83),
            bowlPosition: CGPoint(x: worldSize.width * 0.76, y: worldSize.height * 0.21),
            items: items, placements: placements)
    }

    private func area(_ polygon: [CGPoint]) -> CGFloat {
        abs(zip(polygon, polygon.dropFirst() + polygon.prefix(1)).reduce(0) {
            $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y
        }) / 2
    }
}
