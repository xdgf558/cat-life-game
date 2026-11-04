import SwiftUI
import CatGameCore

@MainActor
struct CatAdoptionView: View {
    @Bindable var store: GameStore
    let catID: String
    @Binding var isSaving: Bool
    let adopted: () -> Void
    @State private var confirming = false
    @State private var failed = false

    private var offer: CatAdoptionOffer? { CatCatalog.adoptionOffer(catID: catID) }
    private var alreadyOwned: Bool { store.snapshot?.cats.contains { $0.id == catID } == true }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let offer, let snapshot = store.snapshot {
                    VStack(spacing: 10) {
                        GameIcon(asset: CatArtwork.asset("cat-idle", appearance: offer.appearance), symbol: "cat.fill", size: 132, tint: RoomTheme.gold)
                            .background(RoomTheme.paleMint.opacity(0.6), in: Circle())
                        Text(GameStrings.catAdoptionName(offer)).font(.title2.weight(.bold))
                            .accessibilityIdentifier("catAdoptionName")
                        Text(GameStrings.catDescription(offer.appearance))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20).frame(maxWidth: .infinity)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 16) {
                        Text(GameStrings.text("cat.adoptionRequirements")).font(.headline)
                        requirement(GameStrings.format("cat.adoptionPlayerLevel", offer.requiredPlayerLevel),
                                    met: snapshot.player.level >= offer.requiredPlayerLevel,
                                    identifier: "catAdoptionPlayerRequirement")
                        requirement(GameStrings.format("cat.adoptionRoomLevel", offer.requiredRoomLevel),
                                    met: snapshot.home.roomLevel >= offer.requiredRoomLevel,
                                    identifier: "catAdoptionRoomRequirement")
                        requirement(GameStrings.format("cat.adoptionPrice", offer.price),
                                    met: snapshot.player.gold >= offer.price,
                                    identifier: "catAdoptionGoldRequirement")
                        Text(GameStrings.format("cat.adoptionBalance", snapshot.player.gold))
                            .font(.footnote).foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("catAdoptionGold").accessibilityValue("\(snapshot.player.gold)")
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
                    Button { confirming = true } label: {
                        Text(GameStrings.text(isSaving ? "common.saving" :
                            (alreadyOwned ? "cat.adoptionOwned" : "cat.adoptionAction")))
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MintButtonStyle())
                    .disabled(isSaving || store.isBusy || alreadyOwned || snapshot.player.level < offer.requiredPlayerLevel
                              || snapshot.home.roomLevel < offer.requiredRoomLevel || snapshot.player.gold < offer.price)
                    .opacity(alreadyOwned || snapshot.player.level < offer.requiredPlayerLevel
                             || snapshot.home.roomLevel < offer.requiredRoomLevel || snapshot.player.gold < offer.price ? 0.5 : 1)
                    .accessibilityIdentifier("catAdoptionButton")
                    Text(GameStrings.text(failed ? "cat.adoptionFailed" : "cat.adoptionHint"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("catAdoptionHint").accessibilityValue(failed ? "failed" : "ready")
                } else {
                    Text(GameStrings.text("cat.adoptionMissing")).padding(24)
                }
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(RoomTheme.cream).accessibilityIdentifier("catAdoptionScroll")
        .navigationTitle(GameStrings.text("cat.adoptionTitle")).navigationBarTitleDisplayMode(.inline)
        .alert(GameStrings.text("cat.adoptionConfirmTitle"), isPresented: $confirming) {
            Button(GameStrings.text("cat.adoptionConfirm")) { adopt() }
                .accessibilityIdentifier("catAdoptionConfirmButton")
            Button(GameStrings.text("common.cancel"), role: .cancel) {}
        } message: {
            Text(GameStrings.format("cat.adoptionConfirmBody", offer?.price ?? 0))
        }
    }

    private func requirement(_ title: String, met: Bool, identifier: String) -> some View {
        Label(title, systemImage: met ? "checkmark.circle.fill" : "lock.fill")
            .font(.subheadline.weight(.medium)).foregroundStyle(met ? RoomTheme.darkMint : RoomTheme.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
            .accessibilityValue(GameStrings.text(met ? "cat.requirementMet" : "cat.requirementUnmet"))
    }

    private func adopt() {
        guard !isSaving, !store.isBusy, !alreadyOwned else { return }
        isSaving = true
        failed = false
        Task {
            let succeeded = await store.adoptCat(catID: catID)
            failed = !succeeded
            isSaving = false
            if succeeded { adopted() }
        }
    }
}
