import SwiftUI
import CatGameCore

@MainActor
struct NeighborDetailView: View {
    @Bindable var store: GameStore
    let neighborID: String
    @Environment(\.dismiss) private var dismiss
    @State private var dialogueKey: String?
    @State private var isWorking = false
    @State private var failed = false
    @State private var choosingGift = false
    @State private var rewardsExpanded = false

    private var neighbor: NeighborDefinition? { CommunityCatalog.neighbor(id: neighborID) }
    private var relationship: NeighborRelationship {
        store.snapshot?.community.relationship(for: neighborID) ?? NeighborRelationship()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { dismiss() } label: {
                    Label(GameStrings.text("community.title"), systemImage: "chevron.left")
                        .font(.subheadline.weight(.heavy))
                }
                .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("neighborBackButton")
                if let neighbor {
                    profile(neighbor)
                    friendship
                    VStack(alignment: .leading, spacing: 10) {
                        Text(GameStrings.text("community.favoriteGifts")).font(.headline.weight(.heavy))
                        Text(neighbor.favoriteGiftIDs.compactMap(CommunityCatalog.gift)
                            .map { GameStrings.text($0.nameKey) }.joined(separator: " · "))
                            .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(GameStrings.format("community.giftPreferenceHint", CommunityCatalog.favoriteGiftFriendship,
                                                CommunityCatalog.ordinaryGiftFriendship))
                            .font(.caption).foregroundStyle(RoomTheme.secondary)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard()
                    dialogue
                    actions
                    DisclosureGroup(isExpanded: $rewardsExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(GameStrings.text("community.stageRewardHint")).font(.caption)
                                .foregroundStyle(RoomTheme.secondary)
                            ForEach(CommunityCatalog.stages.filter { $0.level > 1 }) { stage in
                                rewardRow(stage)
                            }
                        }.padding(.top, 12)
                    } label: {
                        Label(GameStrings.text("community.stageRewards"), systemImage: "gift.fill")
                            .font(.headline.weight(.heavy))
                    }
                    .padding(16).gameCard().accessibilityIdentifier("neighborRewardsDisclosure")
                } else {
                    Text(GameStrings.text("community.neighborMissing")).font(.body)
                }
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
        .accessibilityIdentifier("neighborDetail_\(neighborID)")
        .navigationDestination(isPresented: $choosingGift) {
            CommunityGiftView(store: store, neighborID: neighborID, onGift: { giftID in
                dialogueKey = neighbor?.giftDialogueKey(giftID: giftID)
                failed = false
            })
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func profile(_ neighbor: NeighborDefinition) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(neighbor.portraitAssetName).resizable().scaledToFit().frame(width: 100, height: 128)
                    .background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 24))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(GameStrings.text(neighbor.nameKey)).font(.title.weight(.heavy))
                        .accessibilityAddTraits(.isHeader)
                    Text(GameStrings.text(neighbor.descriptionKey)).font(.subheadline.weight(.bold))
                        .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            Label(GameStrings.text(neighbor.homeKey), systemImage: "house.fill")
            Label(GameStrings.text(neighbor.catsKey), systemImage: "pawprint.fill")
        }
        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 28)
    }

    private var friendship: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack { stageTitle; Spacer(minLength: 8); friendshipValue }
                VStack(alignment: .leading, spacing: 6) { stageTitle; friendshipValue }
            }
            ProgressView(value: Double(relationship.friendship), total: 100).tint(RoomTheme.mint)
                .accessibilityHidden(true)
            if let next = relationship.nextStage {
                Text(GameStrings.format("community.nextStage", GameStrings.text(next.nameKey),
                                        next.minimumPoints - relationship.friendship))
                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
            } else {
                Text(GameStrings.text("community.closestStage")).font(.caption.weight(.bold))
                    .foregroundStyle(RoomTheme.darkMint)
            }
        }.padding(16).gameCard()
    }

    private var stageTitle: some View {
        Label(GameStrings.text(relationship.stage.nameKey), systemImage: "heart.fill")
            .font(.headline.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
    }

    private var friendshipValue: some View {
        Text(GameStrings.format("community.friendshipValue", relationship.friendship))
            .font(.subheadline.weight(.bold)).monospacedDigit()
            .accessibilityIdentifier("neighborFriendshipValue").accessibilityValue("\(relationship.friendship)")
    }

    private var dialogue: some View {
        Label(GameStrings.text(dialogueKey ?? "community.dialogueHint"), systemImage: "quote.bubble.fill")
            .font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoomTheme.paleMint.opacity(0.7), in: RoundedRectangle(cornerRadius: 24))
            .accessibilityIdentifier("neighborDialogue")
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if failed {
                Text(GameStrings.text(store.hasSaveFailure ? "save.writeTitle" : "community.actionFailed"))
                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                    .accessibilityIdentifier("neighborActionFailure")
            }
            Button(action: visit) {
                Label(GameStrings.text(relationship.visitedToday ? "community.chatAction" : "community.visitAction"),
                      systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.headline.weight(.heavy)).frame(maxWidth: .infinity)
            }
            .buttonStyle(MintButtonStyle()).disabled(isWorking || store.isBusy)
            .accessibilityIdentifier("neighborVisitButton")
            Text(relationship.visitedToday ? GameStrings.text("community.visitAlreadyEarned")
                 : GameStrings.format("community.visitGain", min(CommunityCatalog.visitFriendship, 100 - relationship.friendship)))
                .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { store.playNavigationSound(); choosingGift = true } label: {
                Label(GameStrings.text("community.chooseGift"), systemImage: "gift.fill")
                    .font(.headline.weight(.heavy)).frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle()).disabled(isWorking || store.isBusy || relationship.remainingGiftsToday == 0)
            .accessibilityIdentifier("neighborGiftButton")
            Text(GameStrings.format("community.giftsRemaining", relationship.remainingGiftsToday, CommunityCatalog.dailyGiftLimit))
                .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                .accessibilityIdentifier("neighborDailyGiftStatus")
        }
    }

    private func rewardRow(_ stage: FriendshipStage) -> some View {
        let earned = relationship.rewardedStageLevels.contains(stage.level)
        return VStack(alignment: .leading, spacing: 5) {
            Label(GameStrings.format("community.rewardStage", GameStrings.text(stage.nameKey), stage.minimumPoints),
                  systemImage: earned ? "checkmark.circle.fill" : "gift.fill")
                .font(.subheadline.weight(.bold)).foregroundStyle(earned ? RoomTheme.darkMint : RoomTheme.ink)
            Text(rewardSummary(stage)).font(.caption).foregroundStyle(RoomTheme.secondary)
            if earned {
                Text(GameStrings.text("community.rewardReceived")).font(.caption.weight(.bold))
                    .foregroundStyle(RoomTheme.darkMint)
            }
        }
        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func rewardSummary(_ stage: FriendshipStage) -> String {
        [("community.rewardGold", stage.goldReward), ("community.rewardFood", stage.foodReward),
         ("community.rewardLitter", stage.litterReward), ("community.rewardToys", stage.toyUsesReward)]
            .filter { $0.1 > 0 }.map { GameStrings.format($0.0, $0.1) }.joined(separator: " · ")
    }

    private func visit() {
        guard !isWorking, !store.isBusy, let neighbor else { return }
        isWorking = true; failed = false
        Task {
            defer { isWorking = false }
            if await store.visitNeighbor(id: neighborID) {
                dialogueKey = neighbor.dialogueKey(friendship: relationship.friendship)
            } else { failed = true }
        }
    }
}
