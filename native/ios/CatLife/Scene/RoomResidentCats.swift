import SpriteKit
import CatGameCore

/// Other companions share the floor, but care and durable rest belong to the selected cat.
@MainActor
final class RoomResidentCats {
    static let unlockLevel = 4
    private(set) var actors: [String: CatActor] = [:]
    private var preparedIDs: [String]?
    private var revision = 0
    private var worker: Task<Void, Never>?
    private(set) var isBusy = false
    private(set) var isPreparing = false
    var isStrolling: Bool { isBusy && !isPreparing }
    var onFinished: (() -> Void)?
    var onLimitedSpace: (() -> Void)?

    var obstacles: [CGRect] {
        actors.values.filter { !$0.isHidden }.map {
            RoomResidentPlanner.obstacle(at: $0.position, width: visualWidth)
        }
    }
    private var visualWidth: CGFloat = 0

    func hit(at point: CGPoint) -> String? {
        actors.filter { !$0.value.isHidden && $0.value.visualFrame.contains(point) }
            .max { $0.value.zPosition < $1.value.zPosition }?.key
    }

    func updateDepths() {
        for actor in actors.values { actor.zPosition = 1_000 - actor.position.y }
    }

    func invalidate(hide: Bool = false) {
        revision += 1
        worker?.cancel()
        worker = nil
        isBusy = false
        isPreparing = false
        preparedIDs = nil
        for actor in actors.values {
            actor.cancelAndSettle(at: actor.position)
            actor.setIdleEnabled(false)
            if hide { actor.isHidden = true }
        }
    }

    func setIdleEnabled(_ enabled: Bool) {
        for actor in actors.values { actor.setIdleEnabled(enabled && !actor.isPerforming && !actor.isHidden) }
    }

    /// Exchange render roles at their actual positions, keeping the scene's care actor stable.
    func exchangeActive(from old: CatState?, to new: CatState?, at position: CGPoint) -> CGPoint? {
        guard let old, let new, let replacement = actors[new.id], !replacement.isHidden else {
            invalidate(); return nil
        }
        actors.removeValue(forKey: new.id)
        let destination = replacement.position
        invalidate()
        replacement.cancelAndSettle(at: position)
        replacement.setAppearance(old.appearance)
        replacement.name = "resident-\(old.id)"
        actors[old.id] = replacement
        return destination
    }

    func prepare(snapshot: GameSnapshot, active: CGPoint, scene: SKScene,
                 planner: RoomResidentPlanner, width: CGFloat, reducedMotion: Bool) {
        let cats = snapshot.home.roomLevel >= Self.unlockLevel
            ? snapshot.cats.filter { $0.id != snapshot.activeCatID } : []
        let ids = cats.map(\.id)
        guard preparedIDs != ids, !isBusy else { return }
        for id in Array(actors.keys) where !ids.contains(id) {
            actors.removeValue(forKey: id)?.removeFromParent()
        }
        visualWidth = width
        guard !cats.isEmpty else { preparedIDs = []; return }
        revision += 1
        let ticket = revision
        isBusy = true
        isPreparing = true
        let existing = ids.prefix { actors[$0] != nil }.compactMap { actors[$0]?.position }
        let calculation = Task.detached(priority: .userInitiated) {
            planner.positions(count: cats.count, existing: existing)
        }
        worker = Task { [weak self, weak scene] in
            let points = await withTaskCancellationHandler {
                await calculation.value
            } onCancel: { calculation.cancel() }
            guard let self, let scene, !Task.isCancelled, self.revision == ticket else { return }
            self.worker = nil
            for (index, state) in cats.enumerated() {
                guard index < points.count else {
                    self.actors[state.id]?.isHidden = true
                    continue
                }
                let actor = self.actors[state.id] ?? CatActor()
                actor.name = "resident-\(state.id)"
                actor.setAppearance(state.appearance)
                actor.setVisualWidth(width)
                actor.reducedMotion = reducedMotion
                actor.cancelAndSettle(at: points[index])
                actor.isHidden = false
                if actor.parent == nil { scene.addChild(actor) }
                actor.setIdleEnabled(true)
                self.actors[state.id] = actor
            }
            self.preparedIDs = ids
            self.isBusy = false
            self.isPreparing = false
            if points.count < cats.count { self.onLimitedSpace?() }
            self.onFinished?()
        }
    }

    /// One cat travels at a time. All other cats keep breathing and looking around.
    @discardableResult
    func stroll(planner: RoomResidentPlanner, active: CGPoint, activeActor: CatActor) -> Bool {
        var candidates = actors.filter { !$0.value.isHidden }
        candidates["active"] = activeActor
        guard !isBusy, let (id, actor) = candidates.randomElement() else { return false }
        isBusy = true
        revision += 1
        let ticket = revision
        let origin = actor.position
        let others = actors.filter { $0.key != id && !$0.value.isHidden }.map { $0.value.position }
        let calculation = Task.detached(priority: .utility) {
            planner.stroll(from: origin, others: others, active: active)
        }
        worker = Task { [weak self, weak actor] in
            let path = await withTaskCancellationHandler {
                await calculation.value
            } onCancel: { calculation.cancel() }
            guard let self, let actor, !Task.isCancelled, self.revision == ticket else { return }
            self.worker = nil
            guard let path else { self.isBusy = false; self.onFinished?(); return }
            actor.setIdleEnabled(false)
            actor.stroll(along: path) { [weak self, weak actor] in
                guard let self, self.revision == ticket else { return }
                self.isBusy = false
                actor?.setIdleEnabled(true)
                self.onFinished?()
            }
        }
        return true
    }
}
