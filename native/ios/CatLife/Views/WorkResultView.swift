import SwiftUI
import CatGameCore

@MainActor
struct WorkResultView: View {
    let store: GameStore
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            if let result = store.snapshot?.player.lastWorkResult {
                VStack(spacing: 22) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52)).foregroundStyle(RoomTheme.darkMint)
                    Text(GameStrings.text("career.resultSubtitle"))
                        .font(.title3.weight(.bold)).multilineTextAlignment(.center)
                        .accessibilityIdentifier("workResultID").accessibilityValue(result.id)
                    VStack(alignment: .leading, spacing: 18) {
                        Text(WorkJobPresentation.name(result.jobID)).font(.title2.weight(.bold))
                            .accessibilityIdentifier("workResultJob").accessibilityValue(result.jobID)
                        Text(verbatim: result.completedAt.formatted(.dateTime.month().day().hour().minute()
                            .locale(Locale(identifier: store.language.rawValue))))
                            .font(.footnote).foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("workResultCompletedAt")
                        resultValue("career.resultGold", result.goldReward, id: "workResultGold")
                        resultValue("career.resultExp", result.expReward, id: "workResultExp")
                        Divider()
                        HStack(spacing: 12) {
                            Text(GameStrings.format("career.level", result.levelBefore))
                                .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                                .accessibilityIdentifier("workResultLevelBefore").accessibilityValue("\(result.levelBefore)")
                            Image(systemName: "arrow.right").foregroundStyle(RoomTheme.secondary)
                            Text(GameStrings.format("career.level", result.levelAfter))
                                .font(.headline).foregroundStyle(RoomTheme.darkMint)
                                .accessibilityIdentifier("workResultLevelAfter").accessibilityValue("\(result.levelAfter)")
                        }
                        Text(GameStrings.format("career.exp", result.expAfter,
                                                WorkCatalog.requiredExperience(forLevel: result.levelAfter)))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("workResultExpAfter").accessibilityValue("\(result.expAfter)")
                        if !result.newlyUnlockedJobIDs.isEmpty {
                            Text(GameStrings.text("career.newJobs")).font(.headline)
                            ForEach(result.newlyUnlockedJobIDs, id: \.self) { id in
                                Label(WorkJobPresentation.name(id), systemImage: WorkJobPresentation.symbol(id))
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                                    .accessibilityIdentifier("careerUnlocked_\(id)")
                            }
                        }
                    }
                    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
                    Text(GameStrings.text("career.resultSaved"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary).multilineTextAlignment(.center)
                    Button { onDone() } label: {
                        Text(GameStrings.text("career.resultDone")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MintButtonStyle())
                    .accessibilityIdentifier("careerResultDoneButton")
                }
                .padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("careerResultScroll")
        .background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("career.resultTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }

    private func resultValue(_ key: String, _ value: Int, id: String) -> some View {
        HStack {
            Text(GameStrings.text(key)).font(.subheadline)
            Spacer()
            Text("+\(value)").font(.title2.weight(.bold)).foregroundStyle(RoomTheme.darkMint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameStrings.text(key)).accessibilityValue("\(value)")
        .accessibilityIdentifier(id)
    }
}
