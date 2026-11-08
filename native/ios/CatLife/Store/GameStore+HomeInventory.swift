import CatGameCore

extension GameStore {
    /// Current-floor drafts override only their floor; items on the other floor stay placed.
    func furnitureFloor(for itemID: String) -> HomeFloor? {
        if sceneSnapshot?.home.furniture.contains(where: { $0.itemID == itemID }) == true {
            return visibleHomeFloor
        }
        return snapshot?.home.furniture.first { $0.itemID == itemID && $0.floor != visibleHomeFloor }?.floor
    }

    var totalPlacedFurnitureCount: Int {
        placedFurnitureCount + (snapshot?.home.furniture.filter { $0.floor != visibleHomeFloor }.count ?? 0)
    }

    @discardableResult
    func arrangeInventoryFurniture(id: String) async -> Bool {
        guard !isBusy, !isSavingLayout, !isResolvingLayout, !isChangingHomeFloor,
              !saveTransferInProgress, let target = furnitureFloor(for: id) else { return false }
        let generation = saveSceneGeneration
        if target != visibleHomeFloor {
            guard !isDecorating else { return false }
            await changeHomeFloor(to: target)
        }
        guard generation == saveSceneGeneration, target == visibleHomeFloor,
              !isBusy, furnitureFloor(for: id) == target else { return false }
        activeSheet = nil
        beginDecorating()
        guard isDecorating else { return false }
        selectFurniture(id: id)
        return selectedFurnitureID == id
    }
}
