import SwiftUI
import CatGameCore

@MainActor
struct ExchangeConfirmationView: View {
    let offer: ExchangeOffer
    let snapshot: GameSnapshot
    let isWorking: Bool
    let failed: Bool
    let hasSaveFailure: Bool
    let confirm: () -> Void
    let cancel: () -> Void
    private var eligible: Bool { ExchangeCatalog.eligibility(of: offer, in: snapshot) == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let neighbor = CommunityCatalog.neighbor(id: offer.neighborID) {
                    HStack(spacing: 12) {
                        CommunityPortrait(neighbor: neighbor, size: 54)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(GameStrings.text(offer.nameKey)).font(.headline.weight(.heavy))
                            Text(GameStrings.format("market.withNeighbor", GameStrings.text(neighbor.nameKey)))
                                .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(GameStrings.format("market.remaining", snapshot.community.exchangeCount(for: offer.neighborID).remainingToday,
                                        ExchangeCatalog.dailyLimit))
                    .font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.secondary)
                    .accessibilityIdentifier("marketRemaining")
                    .accessibilityValue("\(snapshot.community.exchangeCount(for: offer.neighborID).remainingToday)/\(ExchangeCatalog.dailyLimit)")
                items(offer.inputs, title: "market.give", showsOwned: true)
                Image(systemName: "arrow.down.circle.fill").font(.title2).foregroundStyle(RoomTheme.mint)
                    .frame(maxWidth: .infinity).accessibilityHidden(true)
                items(offer.outputs, title: "market.receive", showsOwned: false)
                if !eligible {
                    Text(ExchangePresentation.status(offer, snapshot: snapshot))
                        .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("marketConfirmationStatus")
                }
                Text(GameStrings.text("market.confirmHint"))
                    .font(.caption).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                if failed {
                    Label(GameStrings.text(hasSaveFailure ? "market.saveFailed" : "market.actionFailed"),
                          systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                        .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("marketFailure")
                }
            }.padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize).accessibilityIdentifier("marketConfirmation")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                Button(action: confirm) {
                    Label(GameStrings.text(isWorking ? "common.saving" : "market.confirm"), systemImage: "arrow.left.arrow.right")
                        .font(.headline.weight(.heavy)).frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle()).disabled(isWorking || !eligible)
                .accessibilityIdentifier("marketConfirmButton")
                Button(GameStrings.text("common.cancel"), action: cancel)
                    .font(.subheadline.weight(.bold)).frame(minHeight: 44).disabled(isWorking)
                    .accessibilityIdentifier("marketCancelButton")
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6).background(RoomTheme.cream)
                .accessibilityElement(children: .contain).accessibilityIdentifier("marketConfirmationBar")
        }
    }

    private func items(_ stacks: [ExchangeStack], title: String, showsOwned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(GameStrings.text(title)).font(.headline.weight(.heavy))
            ForEach(Array(stacks.enumerated()), id: \.offset) { _, stack in
                ExchangeItemRow(stack: stack, owned: showsOwned ? stack.item.count(in: snapshot.inventory) : nil)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 24)
    }
}
