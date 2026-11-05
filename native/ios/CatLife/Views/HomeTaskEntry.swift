import SwiftUI
import CatGameCore

@MainActor
struct HomeTaskEntry: View {
    let store: GameStore

    var body: some View {
        if let snapshot = store.snapshot {
            let daily = GameTaskCatalog.all.filter { $0.category == .daily && GameTaskCatalog.isUnlocked($0, in: snapshot) }
            let completed = daily.filter { TaskCardPresentation.progress($0, in: snapshot) >= $0.target }.count
            let claimable = GameTaskCatalog.all.filter { GameTaskCatalog.isClaimable($0, in: snapshot) }.count
            Button { store.activeSheet = .tasks } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checklist").font(.system(size: 13, weight: .heavy)).foregroundStyle(RoomTheme.darkMint)
                        .frame(width: 26, height: 26).background(RoomTheme.paleMint, in: Circle())
                    Text(GameStrings.text("tasks.entryLabel")).font(.system(size: 12, weight: .heavy))
                    Text(GameStrings.format("tasks.todayShort", completed, daily.count))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(RoomTheme.secondary)
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                .padding(.horizontal, 9).frame(minHeight: 44).gameCard(cornerRadius: 22)
                .overlay(alignment: .topTrailing) {
                    if claimable > 0 {
                        Text("\(claimable)").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20).background(RoomTheme.gold, in: Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2)).offset(x: 3, y: -5).accessibilityHidden(true)
                    }
                }.contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("homeTasksButton")
            .accessibilityElement(children: .ignore).accessibilityLabel(GameStrings.text("tasks.title"))
            .accessibilityValue(GameStrings.format("tasks.dailyProgress", completed, daily.count)
                + ", " + GameStrings.format("tasks.claimableCount", claimable))
        }
    }
}
