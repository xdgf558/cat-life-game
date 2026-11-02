import SwiftUI
import CatGameCore

@MainActor
struct HomeDestinationSheet: View {
    let destination: HomeSheet
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var careerPath: [CareerRoute] = []
    @State private var selectedJobID = "job_flyer"

    private enum CareerRoute: Hashable { case jobs, result }

    var body: some View {
        NavigationStack(path: $careerPath) {
            ScrollView {
                VStack(spacing: 22) {
                    switch destination {
                    case .shop: shop
                    case .inventory: InventoryView(store: store)
                    case .work: work
                    case .town: cats
                    case .player: EmptyView()
                    }
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("destinationScroll")
            .background(RoomTheme.cream)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CareerRoute.self) { route in
                switch route {
                case .jobs: careerChoices
                case .result: workResult
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(GameStrings.text("common.done")) { dismiss() }
                        .foregroundStyle(RoomTheme.darkMint)
                        .accessibilityIdentifier("closeSheetButton")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    SaveStatusBanner(store: store)
                if let toast = store.toast, !toast.isEmpty {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoomTheme.paper)
                        .accessibilityIdentifier("sheetToast")
                }
                }
            }
        }
        .saveRecoveryAlert(store: store)
        .fontDesign(.rounded)
        .foregroundStyle(RoomTheme.ink)
        .presentationDetents(destination == .town ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(RoomTheme.cream)
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
        .onChange(of: store.pendingWorkResultID, initial: true) { _, id in
            guard destination == .work, let id, id == store.snapshot?.player.lastWorkResult?.id else { return }
            careerPath = [.result]
            store.consumeWorkResultPresentation()
        }
    }

    private var title: String {
        switch destination {
        case .work: return GameStrings.text("work.title")
        case .shop: return GameStrings.text("shop.title")
        case .inventory: return GameStrings.text("inventory.title")
        case .town: return GameStrings.text("town.title")
        case .player: return GameStrings.text("player.title")
        }
    }

    private var shop: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(GameStrings.text("shop.subtitle"))
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Label(GameStrings.format("shop.balance", store.snapshot?.player.gold ?? 0), systemImage: "circle.fill")
                .foregroundStyle(RoomTheme.secondary)
                .font(.system(size: 16, weight: .semibold))
                .accessibilityIdentifier("shopGoldCount")
                .accessibilityValue("\(store.snapshot?.player.gold ?? 0)")

            VStack(spacing: 0) {
                shopRow(name: "shop.food", detail: "shop.foodDetail", symbol: "takeoutbag.and.cup.and.straw.fill",
                        asset: "bowl-full", count: store.snapshot?.inventory.food ?? 0, price: 20,
                        identifier: "buyFoodButton", action: store.buyFood)
                Divider().overlay(RoomTheme.wood.opacity(0.4)).padding(.horizontal, 16)
                shopRow(name: "shop.litter", detail: "shop.litterDetail", symbol: "sparkles",
                        asset: "icon-clean", count: store.snapshot?.inventory.litter ?? 0, price: 18,
                        identifier: "buyLitterButton", action: store.buyLitter)
                Divider().overlay(RoomTheme.wood.opacity(0.4)).padding(.horizontal, 16)
                shopRow(name: "shop.toy", detail: "shop.toyDetail", symbol: "party.popper.fill",
                        asset: "icon-play", count: store.snapshot?.inventory.toys ?? 0, price: 35,
                        identifier: "buyToyButton", action: store.buyToy)
            }
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private func shopRow(name: String, detail: String, symbol: String, asset: String, count: Int, price: Int,
                         identifier: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                GameIcon(asset: asset, symbol: symbol, size: 50, tint: RoomTheme.gold)
                VStack(alignment: .leading, spacing: 5) {
                    Text(GameStrings.text(name)).font(.system(size: 20, weight: .bold))
                    Text(GameStrings.text(detail)).font(.system(size: 14)).foregroundStyle(RoomTheme.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Text(GameStrings.format("shop.owned", count)).font(.system(size: 14)).foregroundStyle(RoomTheme.secondary)
                Spacer()
                Button(action: action) {
                    Text(GameStrings.format("shop.buy", price)).font(.system(size: 16, weight: .bold))
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy)
                .accessibilityIdentifier(identifier)
            }
        }
        .padding(16)
    }

    private var selectedJob: WorkJob { WorkCatalog.job(id: selectedJobID) ?? WorkCatalog.all[0] }
    private var playerLevel: Int { store.snapshot?.player.level ?? 1 }
    private var playerExp: Int { store.snapshot?.player.exp ?? 0 }

    private func jobName(_ id: String) -> String {
        GameStrings.text(WorkCatalog.job(id: id) == nil ? "work.name" : "jobs.\(id).name")
    }

    private func jobSymbol(_ id: String) -> String {
        switch id {
        case "job_store": "storefront.fill"
        case "job_petshop": "pawprint.fill"
        case "job_it_engineer": "laptopcomputer"
        case "job_cat_cafe_manager": "cup.and.saucer.fill"
        default: "newspaper.fill"
        }
    }

    private var work: some View {
        VStack(spacing: 20) {
            careerProgress
            if store.snapshot?.player.lastWorkResult != nil {
                Button { careerPath = [.result] } label: {
                    HStack {
                        Label(GameStrings.text("career.previousResult"), systemImage: "checkmark.seal.fill")
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RoomTheme.darkMint)
                }
                .padding(.horizontal, 8)
                .accessibilityIdentifier("careerPreviousResultButton")
            }
            VStack(alignment: .leading, spacing: 18) {
                let active = store.snapshot?.player.activeWork
                let job = active.flatMap { WorkCatalog.job(id: $0.jobID) } ?? selectedJob
                let quote = active == nil ? preview(job) : active?.quote
                let seconds = active.map { Int(max(1, min(315_360_000, $0.endsAt.timeIntervalSince($0.startedAt)))) }
                    ?? quote?.durationSeconds ?? job.durationMinutes * 60
                HStack(spacing: 14) {
                    Image(systemName: jobSymbol(job.id))
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(RoomTheme.darkMint)
                        .frame(width: 58, height: 58)
                        .background(RoomTheme.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(jobName(job.id)).font(.system(size: 23, weight: .bold))
                            .accessibilityIdentifier("selectedCareerName")
                            .accessibilityValue(job.id)
                        Text(GameStrings.text("jobs.\(job.id).detail"))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                    }
                }
                jobRewards(job, quotedSeconds: seconds, captured: active)
                if active == nil || quote != nil { workCosts(job, quote: quote) }
                if let quote, !quote.equipmentIDs.isEmpty {
                    Text(GameStrings.text(active == nil ? "work.benefitsApplied" : "work.fixedShift"))
                        .font(.footnote).foregroundStyle(RoomTheme.darkMint)
                    if seconds != quote.baseDurationSeconds {
                        Text(GameStrings.format("work.baseDuration", workDurationText(quote.baseDurationSeconds)))
                            .font(.caption).foregroundStyle(RoomTheme.secondary)
                    }
                }

                if let active {
                    Text(GameStrings.format("career.working", jobName(active.jobID)))
                        .font(.headline)
                    Text(GameStrings.format("work.remaining", duration(until: active.endsAt)))
                        .font(.system(size: 29, weight: .bold, design: .rounded)).monospacedDigit()
                        .accessibilityIdentifier("workCountdown")
                    ProgressView(value: progress(active)).tint(RoomTheme.mint)
                        .accessibilityIdentifier("activeWorkDurationSeconds").accessibilityValue(Text(verbatim: String(seconds)))
                    Text(GameStrings.text("work.offline"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                } else {
                    Button { store.startWork(jobID: job.id) } label: {
                        Text(GameStrings.text("work.start"))
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MintButtonStyle())
                    .disabled(store.isBusy || store.snapshot?.player.activeSleep != nil
                              || (store.snapshot?.player.stamina ?? 0) < (quote?.staminaCost ?? job.staminaCost)
                              || playerLevel < job.unlockLevel)
                    .accessibilityIdentifier("startWorkButton")
                    if store.snapshot?.player.activeSleep != nil {
                        Text(GameStrings.text("work.sleeping"))
                            .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    } else if (store.snapshot?.player.stamina ?? 0) < (quote?.staminaCost ?? job.staminaCost) {
                        Text(GameStrings.format("career.lowStamina", quote?.staminaCost ?? job.staminaCost))
                            .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    }
                }
                Button { careerPath = [.jobs] } label: {
                    HStack {
                        Text(GameStrings.text("career.choose"))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }.font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(RoomTheme.darkMint)
                .accessibilityIdentifier("careerChooseJobButton")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            playerRest
        }
    }

    private var careerProgress: some View {
        HStack(spacing: 14) {
            GameIcon(asset: "icon-work", symbol: "briefcase.fill", size: 52, tint: RoomTheme.gold)
            VStack(alignment: .leading, spacing: 8) {
                Text(GameStrings.format("career.level", playerLevel))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("playerLevel").accessibilityValue("\(playerLevel)")
                let required = max(1, WorkCatalog.requiredExperience(forLevel: playerLevel))
                ProgressView(value: Double(playerExp), total: Double(required)).tint(RoomTheme.mint)
                Text(GameStrings.format("career.exp", playerExp, required))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .accessibilityIdentifier("playerExperience").accessibilityValue("\(playerExp)")
            }
        }
        .padding(.vertical, 4)
    }

    private func jobRewards(_ job: WorkJob, selected: Bool = true, quotedSeconds: Int? = nil,
                            captured: ActiveWork? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let seconds = quotedSeconds ?? preview(job)?.durationSeconds ?? job.durationMinutes * 60
            HStack(spacing: 6) {
                Image(systemName: "clock").accessibilityHidden(true)
                Text(workDurationText(seconds))
                    .accessibilityIdentifier(selected ? "workQuoteDurationSeconds" : "careerDurationSeconds_\(job.id)")
                    .accessibilityValue(Text(verbatim: String(seconds)))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { rewardLabels(job, captured: captured) }
                VStack(alignment: .leading, spacing: 7) { rewardLabels(job, captured: captured) }
            }
        }
        .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
    }

    private func preview(_ job: WorkJob) -> WorkQuote? {
        store.snapshot.flatMap { GameEngine.workQuote(for: $0.player, jobID: job.id) }
    }

    private func workDurationText(_ seconds: Int) -> String {
        seconds % 60 == 0 ? GameStrings.format("work.durationMinutes", seconds / 60)
            : GameStrings.format("work.durationSeconds", seconds / 60, seconds % 60)
    }

    private func workCosts(_ job: WorkJob, quote: WorkQuote?) -> some View {
        HStack(spacing: 14) {
            Text(GameStrings.text("player.stamina") + " −\(quote?.staminaCost ?? job.staminaCost)")
                .accessibilityIdentifier("workQuoteStaminaCost").accessibilityValue("\(quote?.staminaCost ?? job.staminaCost)")
            Text(GameStrings.text("player.mood") + " −\(quote?.moodCost ?? job.moodCost)")
                .accessibilityIdentifier("workQuoteMoodCost").accessibilityValue("\(quote?.moodCost ?? job.moodCost)")
        }.font(.footnote).foregroundStyle(RoomTheme.secondary)
    }

    @ViewBuilder private func rewardLabels(_ job: WorkJob, captured: ActiveWork? = nil) -> some View {
        Label(GameStrings.format("career.gold", captured?.goldReward ?? job.goldReward), systemImage: "circle.fill")
        Label(GameStrings.format("career.expReward", captured?.expReward ?? job.expReward), systemImage: "sparkle")
    }

    private var careerChoices: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(WorkCatalog.all) { job in
                    let unlocked = playerLevel >= job.unlockLevel
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: jobSymbol(job.id)).font(.title2)
                                .foregroundStyle(unlocked ? RoomTheme.darkMint : RoomTheme.secondary)
                            Text(jobName(job.id)).font(.title3.weight(.bold))
                                .accessibilityIdentifier("careerJobName_\(job.id)")
                        }
                        Text(GameStrings.text("jobs.\(job.id).detail"))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                        jobRewards(job, selected: false)
                        let quote = preview(job)
                        Text(GameStrings.format("career.cost", quote?.staminaCost ?? job.staminaCost, quote?.moodCost ?? job.moodCost))
                            .font(.footnote).foregroundStyle(RoomTheme.secondary)
                        if !unlocked {
                            Label(GameStrings.format("career.unlock", job.unlockLevel), systemImage: "lock.fill")
                                .font(.subheadline.weight(.semibold))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(GameStrings.format("career.unlock", job.unlockLevel))
                                .accessibilityIdentifier("careerLocked_\(job.id)")
                        }
                        Button {
                            selectedJobID = job.id
                            careerPath.removeAll()
                        } label: {
                            Label(GameStrings.text(selectedJobID == job.id ? "career.selected" : "career.choose"),
                                  systemImage: selectedJobID == job.id ? "checkmark.circle.fill" : "arrow.right.circle")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(!unlocked)
                        .accessibilityIdentifier("careerSelect_\(job.id)")
                    }
                    .padding(20)
                    .frame(maxWidth: 520, alignment: .leading)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
                    // Keep each name, requirement and action independently
                    // accessible instead of inheriting the card's identifier.
                    .accessibilityElement(children: .contain)
                }
            }
            .padding(20).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("careerJobsScroll")
        .background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("career.jobs"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { careerPath.removeAll() } label: {
                    Label(GameStrings.text("common.back"), systemImage: "chevron.left")
                }
                .foregroundStyle(RoomTheme.darkMint)
                .accessibilityIdentifier("careerJobsBackButton")
            }
        }
    }

    private var workResult: some View {
        ScrollView {
            if let result = store.snapshot?.player.lastWorkResult {
                VStack(spacing: 22) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52)).foregroundStyle(RoomTheme.darkMint)
                    Text(GameStrings.text("career.resultSubtitle"))
                        .font(.title3.weight(.bold)).multilineTextAlignment(.center)
                        .accessibilityIdentifier("workResultID").accessibilityValue(result.id)
                    VStack(alignment: .leading, spacing: 18) {
                        Text(jobName(result.jobID)).font(.title2.weight(.bold))
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
                                Label(jobName(id), systemImage: jobSymbol(id))
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                                    .accessibilityIdentifier("careerUnlocked_\(id)")
                            }
                        }
                    }
                    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
                    Text(GameStrings.text("career.resultSaved"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary).multilineTextAlignment(.center)
                    Button { careerPath.removeAll() } label: {
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { careerPath.removeAll() } label: {
                    Label(GameStrings.text("common.back"), systemImage: "chevron.left")
                }.foregroundStyle(RoomTheme.darkMint)
            }
        }
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

    private var playerRest: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(GameStrings.text("sleep.title"), systemImage: "moon.stars.fill")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(RoomTheme.darkMint)
            Text(GameStrings.text("sleep.subtitle"))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)
            stat("sleep.stamina", value: store.snapshot?.player.stamina ?? 0)
                .accessibilityIdentifier("playerStamina")
            stat("sleep.mood", value: store.snapshot?.player.mood ?? 0)
                .accessibilityIdentifier("playerMood")

            let sleeping = store.snapshot?.player.activeSleep != nil
            let working = store.snapshot?.player.activeWork != nil
            Text(sleeping ? GameStrings.text("sleep.sleeping") :
                    (store.snapshot?.player.activeWork.map {
                        GameStrings.format("career.working", jobName($0.jobID))
                    } ?? GameStrings.text("sleep.awake")))
                .font(.headline)
                .accessibilityIdentifier("sleepStatus")
                .accessibilityValue(sleeping ? "asleep" : (working ? "working" : "awake"))

            if let sleep = store.snapshot?.player.activeSleep {
                Text(GameStrings.format("sleep.elapsed", sleepDuration(since: sleep.startedAt)))
                    .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                    .accessibilityIdentifier("sleepElapsed")
                Text(GameStrings.text("sleep.offline"))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                Button { store.wakeUp() } label: {
                    Label(GameStrings.text("sleep.wake"), systemImage: "sun.max.fill")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy)
                .accessibilityIdentifier("sleepWakeButton")
            } else {
                if working {
                    Text(GameStrings.text("sleep.workActive"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                }
                Button { store.startSleep() } label: {
                    Label(GameStrings.text("sleep.start"), systemImage: "moon.fill")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
                .disabled(store.isBusy || working)
                .accessibilityIdentifier("sleepStartButton")
            }
            Text(GameStrings.text("sleep.rate"))
                .font(.footnote).foregroundStyle(RoomTheme.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func sleepDuration(since startedAt: Date) -> String {
        let reference = max(store.now, store.snapshot?.meta.lastSyncAt ?? store.now)
        let interval = max(0, reference.timeIntervalSince(startedAt))
        let seconds = Int(min(interval, 315_360_000))
        return String(format: "%d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }

    private var cats: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(GameStrings.text("town.subtitle"))
                .font(.system(size: 16)).foregroundStyle(RoomTheme.secondary)
            ForEach(store.snapshot?.cats ?? []) { cat in
                VStack(spacing: 18) {
                    HStack(spacing: 16) {
                        GameIcon(asset: "cat-avatar", symbol: "cat.fill", size: 70, tint: RoomTheme.gold)
                        Text(GameStrings.catName(cat)).font(.system(size: 29, weight: .heavy, design: .rounded))
                        Spacer()
                    }
                    stat("stat.satiety", value: cat.satiety)
                    stat("stat.cleanliness", value: cat.cleanliness)
                    stat("stat.mood", value: cat.mood)
                    stat("stat.bond", value: cat.intimacy)
                    stat("rest.energy", value: cat.energy)
                        .accessibilityIdentifier(cat.id == store.cat?.id ? "catEnergy" : "catEnergy_\(cat.id)")
                }
                .padding(20)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            }
        }
    }

    private func stat(_ title: String, value: Int) -> some View {
        HStack(spacing: 16) {
            Text(GameStrings.text(title)).font(.system(size: 15, weight: .semibold))
                .frame(width: 76, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.8)
            ProgressView(value: Double(value), total: 100).tint(RoomTheme.mint)
            Text("\(value)").font(.system(size: 15, weight: .semibold)).monospacedDigit().frame(width: 30, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(GameStrings.text(title))
        .accessibilityValue("\(value)")
    }

    private func duration(until deadline: Date) -> String {
        let reference = max(store.now, store.snapshot?.meta.lastSyncAt ?? store.now)
        let seconds = Int(min(315_360_000, max(0, ceil(deadline.timeIntervalSince(reference)))))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func progress(_ work: ActiveWork) -> Double {
        let total = max(1, work.endsAt.timeIntervalSince(work.startedAt))
        let reference = max(store.now, store.snapshot?.meta.lastSyncAt ?? store.now)
        return max(0, min(1, reference.timeIntervalSince(work.startedAt) / total))
    }
}
