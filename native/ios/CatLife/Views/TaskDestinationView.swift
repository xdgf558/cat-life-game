import SwiftUI
import CatGameCore

@MainActor
struct TaskDestinationView: View {
    @Bindable var store: GameStore
    @State private var category: GameTaskCategory = .daily
    @State private var path: [TaskRoute] = []
    @State private var claimingTaskID: String?

    private struct TaskRoute: Hashable {
        let id: String
        let dayKey: String?
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if let snapshot = store.snapshot {
                    VStack(alignment: .leading, spacing: 18) {
                        GamePageHeading(title: GameStrings.text("tasks.title"),
                                        subtitle: GameStrings.text("tasks.subtitle"),
                                        symbol: "checklist", tint: RoomTheme.darkMint,
                                        background: RoomTheme.paleMint)
                        summary(snapshot)
                        categoryPicker(snapshot)
                        Text(GameStrings.text(categoryHintKey))
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 12) {
                            ForEach(GameTaskCatalog.all.filter { $0.category == category }, id: \.id) { task in
                                taskCard(task, snapshot: snapshot)
                            }
                        }
                        if category == .tutorial {
                            Text(GameStrings.text("tasks.legacyNotice"))
                                .font(.footnote).foregroundStyle(RoomTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(RoomTheme.cream)
            .accessibilityIdentifier("tasksScroll")
            .navigationTitle(GameStrings.text("tasks.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(path.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: TaskRoute.self) { route in
                if let task = GameTaskCatalog.task(id: route.id), let snapshot = store.snapshot {
                    taskDetail(task, route: route, snapshot: snapshot)
                }
            }
        }
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink).tint(RoomTheme.darkMint)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
    }

    private var categoryHintKey: String {
        switch category {
        case .tutorial: "tasks.tutorialHint"
        case .daily: "tasks.dayRule"
        case .achievement: "tasks.achievementHint"
        }
    }

    private func summary(_ snapshot: GameSnapshot) -> some View {
        let daily = GameTaskCatalog.all.filter { $0.category == .daily }
        let completed = daily.filter { progress($0, in: snapshot) >= $0.target }.count
        let claimable = GameTaskCatalog.all.filter { GameTaskCatalog.isClaimable($0, in: snapshot) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(GameStrings.format("tasks.dailyProgress", completed, daily.count))
                    .font(.system(size: 16, weight: .heavy))
                    .accessibilityIdentifier("tasksDailySummary").accessibilityValue("\(completed)/\(daily.count)")
                Spacer(minLength: 8)
                Image(systemName: "sun.max.fill").foregroundStyle(RoomTheme.gold).accessibilityHidden(true)
            }
            Label(GameStrings.format("tasks.claimableCount", claimable), systemImage: "gift.fill")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(RoomTheme.darkMint)
                .accessibilityIdentifier("tasksClaimableSummary").accessibilityValue("\(claimable)")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 24))
    }

    private func categoryPicker(_ snapshot: GameSnapshot) -> some View {
        HStack(spacing: 4) {
            ForEach(GameTaskCategory.allCases, id: \.rawValue) { item in
                let available = GameTaskCatalog.all.filter { $0.category == item && GameTaskCatalog.isClaimable($0, in: snapshot) }.count
                Button { category = item } label: {
                    HStack(spacing: 4) {
                        Text(GameStrings.text("tasks.category.\(item.rawValue)"))
                            .font(.system(size: 12, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                        if available > 0 {
                            Text("\(available)").font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white).frame(width: 18, height: 18)
                                .background(RoomTheme.coral, in: Circle()).accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(category == item ? RoomTheme.darkMint : RoomTheme.secondary)
                    .background(category == item ? RoomTheme.paper : .clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityIdentifier("taskCategory_\(item.rawValue)")
                .accessibilityAddTraits(category == item ? .isSelected : [])
                .accessibilityValue(GameStrings.format("tasks.claimableCount", available))
            }
        }
        .padding(4).background(RoomTheme.chipBg, in: Capsule())
    }

    private func taskCard(_ task: GameTaskDefinition, snapshot: GameSnapshot) -> some View {
        Button {
            path.append(TaskRoute(id: task.id, dayKey: snapshot.tasks.dailyDayKey))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    GameIconTile(symbol: symbol(task.destination), tint: RoomTheme.darkMint,
                                 background: RoomTheme.paleMint, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(GameStrings.text("task.\(task.id).title"))
                            .font(.system(size: 16, weight: .heavy)).fixedSize(horizontal: false, vertical: true)
                        Text(GameStrings.text(statusKey(task, in: snapshot)))
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(RoomTheme.darkMint)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                }
                progressBar(task, snapshot: snapshot)
                rewards(task)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard()
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain).accessibilityIdentifier("taskCard_\(task.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameStrings.text("task.\(task.id).title"))
        .accessibilityValue(GameStrings.format("tasks.progress", progress(task, in: snapshot), task.target)
            + ", " + GameStrings.text(statusKey(task, in: snapshot)))
        .accessibilityHint(GameStrings.text("tasks.detailTitle"))
    }

    private func taskDetail(_ task: GameTaskDefinition, route: TaskRoute, snapshot: GameSnapshot) -> some View {
        let expired = task.category == .daily && (route.dayKey == nil || route.dayKey != snapshot.tasks.dailyDayKey)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GamePageHeading(title: GameStrings.text("task.\(task.id).title"),
                                symbol: symbol(task.destination), tint: RoomTheme.darkMint,
                                background: RoomTheme.paleMint)
                Text(GameStrings.text("task.\(task.id).detail"))
                    .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if expired {
                    Label(GameStrings.text("tasks.dailyExpired"), systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true).padding(16).gameCard()
                        .accessibilityIdentifier("taskDailyExpired")
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(GameStrings.text(statusKey(task, in: snapshot)))
                            .font(.headline).foregroundStyle(RoomTheme.darkMint)
                            .accessibilityIdentifier("taskStatus_\(task.id)")
                        progressBar(task, snapshot: snapshot)
                        rewards(task)
                    }
                    .padding(18).gameCard()
                }
                Text(GameStrings.text(task.category == .daily ? "tasks.dayRule" : categoryHintKey))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize).background(RoomTheme.cream)
        .accessibilityIdentifier("taskDetailScroll").accessibilityValue(task.id)
        .safeAreaInset(edge: .bottom) {
            detailAction(task, route: route, snapshot: snapshot, expired: expired)
                .padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
                .background(RoomTheme.cream)
        }
        .navigationTitle(GameStrings.text("tasks.detailTitle"))
        .navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { if !path.isEmpty { path.removeLast() } } label: {
                    Label(GameStrings.text("common.back"), systemImage: "chevron.left").frame(minHeight: 44)
                }
                .disabled(claimingTaskID != nil).accessibilityIdentifier("tasksBackButton")
            }
        }
    }

    @ViewBuilder private func detailAction(_ task: GameTaskDefinition, route: TaskRoute,
                                          snapshot: GameSnapshot, expired: Bool) -> some View {
        if expired {
            Button { path.removeAll() } label: {
                Text(GameStrings.text("tasks.backToList")).font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(MintButtonStyle()).accessibilityIdentifier("tasksRefreshButton")
        } else if GameTaskCatalog.isClaimed(task, in: snapshot) {
            Label(GameStrings.text("tasks.claimed"), systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(RoomTheme.darkMint).frame(maxWidth: .infinity, minHeight: 48)
                .accessibilityIdentifier("taskClaimed_\(task.id)")
        } else if GameTaskCatalog.isClaimable(task, in: snapshot) {
            Button {
                guard claimingTaskID == nil else { return }
                claimingTaskID = task.id
                Task {
                    defer { claimingTaskID = nil }
                    _ = await store.claimTask(id: task.id, expectedDayKey: route.dayKey)
                }
            } label: {
                Label(GameStrings.text(claimingTaskID == task.id ? "common.saving" : "tasks.claim"), systemImage: "gift.fill")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(MintButtonStyle()).disabled(store.isBusy || claimingTaskID != nil)
            .accessibilityIdentifier("taskClaim_\(task.id)")
        } else {
            Button { store.goToTaskDestination(task.destination) } label: {
                Label(GameStrings.text("tasks.goComplete"), systemImage: "arrow.right")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(MintButtonStyle()).disabled(store.isBusy || claimingTaskID != nil)
            .accessibilityIdentifier("taskGo_\(task.id)")
        }
    }

    private func progressBar(_ task: GameTaskDefinition, snapshot: GameSnapshot) -> some View {
        let value = progress(task, in: snapshot)
        return VStack(alignment: .leading, spacing: 6) {
            Text(GameStrings.format("tasks.progress", value, task.target))
                .font(.system(size: 12, weight: .bold)).monospacedDigit().foregroundStyle(RoomTheme.secondary)
            ProgressView(value: Double(value), total: Double(task.target)).tint(RoomTheme.mint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameStrings.format("tasks.progress", value, task.target))
        .accessibilityValue("\(value)/\(task.target)").accessibilityIdentifier("taskProgress_\(task.id)")
    }

    private func rewards(_ task: GameTaskDefinition) -> some View {
        HStack(spacing: 14) {
            Label(GameStrings.format("tasks.rewardGold", task.goldReward), systemImage: "dollarsign.circle.fill")
                .foregroundStyle(RoomTheme.gold)
            Label(GameStrings.format("tasks.rewardExperience", task.expReward), systemImage: "sparkles")
                .foregroundStyle(RoomTheme.darkMint)
        }
        .font(.system(size: 12, weight: .bold)).fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine).accessibilityIdentifier("taskRewards_\(task.id)")
    }

    private func progress(_ task: GameTaskDefinition, in snapshot: GameSnapshot) -> Int {
        GameTaskCatalog.isClaimed(task, in: snapshot) ? task.target
            : min(task.target, GameTaskCatalog.progress(for: task, in: snapshot))
    }

    private func statusKey(_ task: GameTaskDefinition, in snapshot: GameSnapshot) -> String {
        if GameTaskCatalog.isClaimed(task, in: snapshot) { return "tasks.claimed" }
        return GameTaskCatalog.isClaimable(task, in: snapshot) ? "tasks.claimable" : "tasks.inProgress"
    }

    private func symbol(_ destination: GameTaskDestination) -> String {
        switch destination {
        case .work: "briefcase.fill"
        case .care: "pawprint.fill"
        case .furnitureShop: "sofa.fill"
        case .upgrade: "house.and.flag.fill"
        }
    }
}

@MainActor
struct HomeTaskEntry: View {
    let store: GameStore

    var body: some View {
        if let snapshot = store.snapshot {
            let daily = GameTaskCatalog.all.filter { $0.category == .daily }
            let completed = daily.filter {
                GameTaskCatalog.isClaimed($0, in: snapshot) || GameTaskCatalog.progress(for: $0, in: snapshot) >= $0.target
            }.count
            let claimable = GameTaskCatalog.all.filter { GameTaskCatalog.isClaimable($0, in: snapshot) }.count
            Button { store.activeSheet = .tasks } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checklist").foregroundStyle(RoomTheme.darkMint)
                    Text(GameStrings.format("tasks.todayShort", completed, daily.count))
                        .lineLimit(1).minimumScaleFactor(0.75)
                    if claimable > 0 {
                        Text("\(claimable)").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(RoomTheme.coral, in: Circle())
                    }
                }
                .font(.system(size: 12, weight: .heavy)).padding(.horizontal, 10)
                .frame(minHeight: 44).gameCard(cornerRadius: 20).contentShape(Capsule())
            }
            .buttonStyle(.plain).accessibilityIdentifier("homeTasksButton")
            .accessibilityElement(children: .ignore).accessibilityLabel(GameStrings.text("tasks.title"))
            .accessibilityValue(GameStrings.format("tasks.dailyProgress", completed, daily.count)
                + ", " + GameStrings.format("tasks.claimableCount", claimable))
        }
    }
}
