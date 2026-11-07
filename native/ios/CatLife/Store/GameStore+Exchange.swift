import CatGameCore

extension GameStore {
    func openExchangeMarket() {
        guard !isBusy, !isDecorating, snapshot != nil else { return }
        inspectedCatID = nil
        isShowingSettings = false
        activeSheet = .town
        catCollectionFilter = nil
        adoptionCatID = nil
        isShowingNeighbors = false
        isShowingMarket = true
    }

    @discardableResult
    func exchange(offerID: String) async -> Bool {
        let generation = saveSceneGeneration
        // The shared pipeline publishes stock and feedback only after the save succeeds,
        // including when the player has already left the market.
        let succeeded = await performPersistedAction {
            GameEngine.exchange(&$0, offerID: offerID, now: $1)
        }
        return succeeded && generation == saveSceneGeneration
    }
}
