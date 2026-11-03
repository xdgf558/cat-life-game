import SwiftUI
import CatGameCore

/// Work navigation and presentation. Quotes and all durable actions stay in GameStore/Core.
@MainActor
struct WorkDestinationView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var careerPath: [CareerRoute] = []
    @State private var selectedJobID = "job_flyer"
    @State private var careerSearch = ""
    @State private var careerFilter = CareerDirectory.Filter.all
    @State private var careerPage = 0
    @FocusState private var careerSearchFocused: Bool

    private enum CareerRoute: Hashable { case jobs, job(String), rest, result }

    var body: some View {
        NavigationStack(path: $careerPath) {
            ScrollView {
                work.padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("destinationScroll")
            .background(RoomTheme.cream)
            .navigationTitle(GameStrings.text("work.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CareerRoute.self) { route in
                switch route {
                case .jobs: careerChoices
                case .job(let id): careerDetail(id)
                case .rest: restPage
                case .result: workResult
                }
            }
            .toolbar { careerDoneButton }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                SaveStatusBanner(store: store)
                if let toast = store.toast, !toast.isEmpty {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(12).frame(maxWidth: .infinity)
                        .background(RoomTheme.paper)
                        .accessibilityIdentifier("sheetToast")
                }
            }
        }
        .saveRecoveryAlert(store: store)
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(RoomTheme.cream)
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
        .onChange(of: store.pendingWorkResultID, initial: true) { _, id in
            guard let id, id == store.snapshot?.player.lastWorkResult?.id else { return }
            careerSearchFocused = false
            careerPath = [.result]
            store.consumeWorkResultPresentation()
        }
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
        VStack(spacing: 16) {
            careerProgress
            currentWorkCard
            VStack(spacing: 0) {
                workEntry("career.choose", symbol: "list.bullet", id: "careerChooseJobButton",
                          subtitle: store.snapshot?.player.activeWork == nil ? nil
                            : GameStrings.format("career.nextJob", jobName(selectedJobID))) {
                    careerPath = [.jobs]
                }
                Divider().padding(.leading, 48)
                workEntry("career.details", symbol: "info.circle", id: "workDetailsButton") {
                    careerPath = [.job(store.snapshot?.player.activeWork?.jobID ?? selectedJobID)]
                }
                Divider().padding(.leading, 48)
                workEntry("work.rest.open", symbol: "moon.stars", id: "workRestButton",
                          subtitle: store.snapshot?.player.activeSleep == nil ? nil : GameStrings.text("sleep.sleeping")) {
                    careerPath = [.rest]
                }
                if store.snapshot?.player.lastWorkResult != nil {
                    Divider().padding(.leading, 48)
                    workEntry("career.previousResult", symbol: "checkmark.seal", id: "careerPreviousResultButton") {
                        careerPath = [.result]
                    }
                }
            }
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private func workEntry(_ key: String, symbol: String, id: String, subtitle: String? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(GameStrings.text(key)).font(.subheadline.weight(.semibold))
                    if let subtitle {
                        if id == "careerChooseJobButton" {
                            Text(subtitle).font(.caption).foregroundStyle(RoomTheme.secondary)
                                .accessibilityIdentifier("careerNextJobName").accessibilityValue(selectedJobID)
                        } else {
                            Text(subtitle).font(.caption).foregroundStyle(RoomTheme.secondary)
                        }
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).accessibilityHidden(true)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(RoomTheme.darkMint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private var currentWorkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            let active = store.snapshot?.player.activeWork
            let job = active.flatMap { WorkCatalog.job(id: $0.jobID) } ?? selectedJob
            let quote = active == nil ? preview(job) : active?.quote
            let seconds = shiftSeconds(job, captured: active, quote: quote)
            HStack(spacing: 12) {
                Image(systemName: jobSymbol(job.id))
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(RoomTheme.darkMint)
                    .frame(width: 44, height: 44)
                    .background(RoomTheme.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                Text(jobName(job.id)).font(.system(size: 21, weight: .bold))
                    .accessibilityIdentifier("selectedCareerName").accessibilityValue(job.id)
            }
            jobRewards(job, quotedSeconds: seconds, captured: active)
            if active == nil || quote != nil { workCosts(job, quote: quote) }
            if let active {
                Text(GameStrings.format("work.remaining", duration(until: active.endsAt)))
                    .font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                    .accessibilityIdentifier("workCountdown")
                ProgressView(value: progress(active)).tint(RoomTheme.mint)
                    .accessibilityIdentifier("activeWorkDurationSeconds").accessibilityValue(Text(verbatim: String(seconds)))
            } else {
                Button { store.startWork(jobID: job.id) } label: {
                    Text(GameStrings.text("work.start")).font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy || store.snapshot?.player.activeSleep != nil
                          || (store.snapshot?.player.stamina ?? 0) < (quote?.staminaCost ?? job.staminaCost)
                          || playerLevel < job.unlockLevel)
                .accessibilityIdentifier("startWorkButton")
                if store.snapshot?.player.activeSleep != nil {
                    Text(GameStrings.text("work.sleeping")).font(.footnote).foregroundStyle(RoomTheme.secondary)
                } else if (store.snapshot?.player.stamina ?? 0) < (quote?.staminaCost ?? job.staminaCost) {
                    Text(GameStrings.format("career.lowStamina", quote?.staminaCost ?? job.staminaCost))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private var careerProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GameIcon(asset: "icon-work", symbol: "briefcase.fill", size: 44, tint: RoomTheme.gold)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(GameStrings.format("career.level", playerLevel)).font(.title3.weight(.bold))
                            .accessibilityIdentifier("playerLevel").accessibilityValue("\(playerLevel)")
                        Spacer(minLength: 4)
                        let required = max(1, WorkCatalog.requiredExperience(forLevel: playerLevel))
                        Text(GameStrings.format("career.exp", playerExp, required))
                            .font(.caption).foregroundStyle(RoomTheme.secondary)
                            .accessibilityIdentifier("playerExperience").accessibilityValue("\(playerExp)")
                    }
                    ProgressView(value: Double(playerExp), total: Double(max(1, WorkCatalog.requiredExperience(forLevel: playerLevel))))
                        .tint(RoomTheme.mint)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { workAttributeSummaries }
                VStack(alignment: .leading, spacing: 6) { workAttributeSummaries }
            }
            .font(.subheadline.weight(.medium)).foregroundStyle(RoomTheme.secondary)
        }
    }

    @ViewBuilder private var workAttributeSummaries: some View {
        Label(GameStrings.text("player.stamina") + " \(store.snapshot?.player.stamina ?? 0)/100", systemImage: "bolt.fill")
            .accessibilityIdentifier("workStaminaSummary").accessibilityValue("\(store.snapshot?.player.stamina ?? 0)")
        Label(GameStrings.text("player.mood") + " \(store.snapshot?.player.mood ?? 0)/100", systemImage: "face.smiling")
            .accessibilityIdentifier("workMoodSummary").accessibilityValue("\(store.snapshot?.player.mood ?? 0)")
    }

    private func shiftSeconds(_ job: WorkJob, captured: ActiveWork?, quote: WorkQuote?) -> Int {
        captured.map { Int(max(1, min(315_360_000, $0.endsAt.timeIntervalSince($0.startedAt)))) }
            ?? quote?.durationSeconds ?? job.durationMinutes * 60
    }

    private func jobRewards(_ job: WorkJob, quotedSeconds: Int,
                            captured: ActiveWork? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock").accessibilityHidden(true)
                Text(workDurationText(quotedSeconds))
                    .accessibilityIdentifier("workQuoteDurationSeconds")
                    .accessibilityValue(Text(verbatim: String(quotedSeconds)))
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

    private var filteredJobs: [WorkJob] {
        CareerDirectory.matching(WorkCatalog.all, level: playerLevel, query: careerSearch, filter: careerFilter,
                                 locale: Locale(identifier: store.language.rawValue)) { jobName($0.id) }
    }

    private var directoryPage: Int { CareerDirectory.clampedPage(careerPage, count: filteredJobs.count) }

    private var careerChoices: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(RoomTheme.secondary).accessibilityHidden(true)
                    TextField(GameStrings.text("career.search.placeholder"), text: $careerSearch)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search).focused($careerSearchFocused)
                        .onSubmit { careerSearchFocused = false }
                        .accessibilityIdentifier("careerSearchField")
                    if !careerSearch.isEmpty {
                        Button { careerSearch = ""; careerSearchFocused = false } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain).foregroundStyle(RoomTheme.secondary)
                        .accessibilityLabel(GameStrings.text("career.search.clear"))
                        .accessibilityIdentifier("careerSearchClearButton")
                    }
                }
                .padding(.leading, 12).padding(.trailing, careerSearch.isEmpty ? 12 : 0)
                .frame(minHeight: 48)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 16))
                HStack(spacing: 6) {
                    ForEach(CareerDirectory.Filter.allCases, id: \.self) { filter in
                        Button { careerFilter = filter; careerSearchFocused = false } label: {
                            Text(GameStrings.text("career.filter.\(filter.rawValue)"))
                                .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(careerFilter == filter ? RoomTheme.paleMint : RoomTheme.paper,
                                            in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("careerFilter_\(filter.rawValue)")
                        .accessibilityValue(careerFilter == filter ? "selected" : "unselected")
                        .accessibilityAddTraits(careerFilter == filter ? .isSelected : [])
                    }
                }
                let jobs = filteredJobs
                if jobs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.title).accessibilityHidden(true)
                        Text(GameStrings.text("career.empty")).font(.subheadline).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(RoomTheme.secondary).padding(24).frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine).accessibilityIdentifier("careerEmptyState")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(jobs[CareerDirectory.pageRange(careerPage, count: jobs.count)])) { job in
                            careerRow(job)
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button { careerPage = directoryPage - 1; careerSearchFocused = false } label: {
                        Label(GameStrings.text("career.page.previous"), systemImage: "chevron.left")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain).disabled(directoryPage == 0)
                    .accessibilityIdentifier("careerPagePrevious")
                    Text(GameStrings.format("career.page.indicator", directoryPage + 1, CareerDirectory.pageCount(for: jobs.count)))
                        .font(.subheadline.monospacedDigit()).fixedSize()
                        .accessibilityIdentifier("careerPageIndicator")
                        .accessibilityValue("\(directoryPage + 1)/\(CareerDirectory.pageCount(for: jobs.count))")
                    Button { careerPage = directoryPage + 1; careerSearchFocused = false } label: {
                        HStack(spacing: 5) {
                            Text(GameStrings.text("career.page.next"))
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain).disabled(directoryPage + 1 >= CareerDirectory.pageCount(for: jobs.count))
                    .accessibilityIdentifier("careerPageNext")
                }
                .foregroundStyle(RoomTheme.darkMint)
            }
            .padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("careerJobsScroll")
        .background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("career.jobs"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            careerBackButton("careerJobsBackButton")
            careerDoneButton
        }
        .onChange(of: careerSearch) { _, _ in careerPage = 0 }
        .onChange(of: careerFilter) { _, _ in careerPage = 0 }
        .onChange(of: filteredJobs.count) { _, count in careerPage = CareerDirectory.clampedPage(careerPage, count: count) }
    }

    private func careerRow(_ job: WorkJob) -> some View {
        Button { careerSearchFocused = false; careerPath.append(.job(job.id)) } label: {
            HStack(spacing: 12) {
                Image(systemName: jobSymbol(job.id)).font(.title3).frame(width: 28)
                    .foregroundStyle(playerLevel >= job.unlockLevel ? RoomTheme.darkMint : RoomTheme.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(jobName(job.id)).font(.headline).multilineTextAlignment(.leading)
                        .accessibilityIdentifier("careerJobName_\(job.id)")
                    Text(playerLevel >= job.unlockLevel ? GameStrings.text(selectedJobID == job.id ? "career.selected" : "career.available")
                         : GameStrings.format("career.unlock", job.unlockLevel))
                        .font(.caption).foregroundStyle(RoomTheme.secondary)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).accessibilityHidden(true)
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityElement(children: .contain)
        .accessibilityLabel(jobName(job.id))
        .accessibilityValue(playerLevel >= job.unlockLevel
            ? GameStrings.text(selectedJobID == job.id ? "career.selected" : "career.available")
            : GameStrings.format("career.unlock", job.unlockLevel))
        .accessibilityIdentifier("careerJobRow_\(job.id)")
    }

    private func careerDetail(_ id: String) -> some View {
        ScrollView {
            if let job = WorkCatalog.job(id: id) {
                let active = store.snapshot?.player.activeWork.flatMap { $0.jobID == id ? $0 : nil }
                let quote = active == nil ? preview(job) : active?.quote
                let seconds = shiftSeconds(job, captured: active, quote: quote)
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: jobSymbol(job.id)).font(.largeTitle).foregroundStyle(RoomTheme.darkMint)
                            .accessibilityHidden(true)
                        Text(jobName(job.id)).font(.title2.weight(.bold))
                            .accessibilityIdentifier("careerJobName_\(job.id)")
                    }
                    Text(GameStrings.text("jobs.\(job.id).detail")).foregroundStyle(RoomTheme.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        detailValue("career.duration", value: workDurationText(seconds),
                                    id: "careerDurationSeconds_\(job.id)", accessibilityValue: String(seconds))
                        detailValue("career.reward", value: GameStrings.format("career.gold", active?.goldReward ?? job.goldReward))
                        detailValue("career.experience", value: GameStrings.format("career.expReward", active?.expReward ?? job.expReward))
                        if active == nil || quote != nil {
                            detailValue("career.costs", value: GameStrings.format("career.cost", quote?.staminaCost ?? job.staminaCost,
                                                                                 quote?.moodCost ?? job.moodCost))
                        }
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(GameStrings.text("player.bonuses")).font(.headline)
                        if let quote {
                            if active != nil || !quote.equipmentIDs.isEmpty {
                                Text(GameStrings.text(active == nil ? "work.benefitsApplied" : "work.fixedShift"))
                                    .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                            }
                            if quote.equipmentIDs.isEmpty {
                                Text(GameStrings.text("player.noBonuses")).font(.subheadline)
                            } else {
                                ForEach(quote.equipmentIDs, id: \.self) { itemID in
                                    if let item = PlayerCatalog.item(id: itemID) {
                                        Label(GameStrings.text(item.nameKey), systemImage: "checkmark.circle")
                                            .font(.subheadline).foregroundStyle(RoomTheme.darkMint)
                                    }
                                }
                                if quote.bonuses.durationReductionPercent > 0 {
                                    Text(GameStrings.format("player.bonus.duration", quote.bonuses.durationReductionPercent)).font(.subheadline)
                                }
                                if quote.bonuses.staminaReductionPercent > 0 {
                                    Text(GameStrings.format("player.bonus.stamina", quote.bonuses.staminaReductionPercent)).font(.subheadline)
                                }
                                if quote.bonuses.moodReductionPercent > 0 {
                                    Text(GameStrings.format("player.bonus.mood", quote.bonuses.moodReductionPercent)).font(.subheadline)
                                }
                            }
                            if seconds != quote.baseDurationSeconds {
                                Text(GameStrings.format("work.baseDuration", workDurationText(quote.baseDurationSeconds)))
                                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                            }
                        } else if active != nil {
                            Text(GameStrings.text("work.fixedShift")).font(.subheadline).foregroundStyle(RoomTheme.secondary)
                        }
                    }
                    if playerLevel < job.unlockLevel {
                        Label(GameStrings.format("career.unlock", job.unlockLevel), systemImage: "lock.fill")
                            .font(.headline).foregroundStyle(RoomTheme.secondary)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(GameStrings.format("career.unlock", job.unlockLevel))
                            .accessibilityIdentifier("careerLocked_\(job.id)")
                    } else {
                        Label(GameStrings.format("career.unlock", job.unlockLevel), systemImage: "checkmark.circle")
                            .font(.subheadline).foregroundStyle(RoomTheme.darkMint)
                    }
                    if store.snapshot?.player.activeWork != nil {
                        Text(GameStrings.text("career.workingHint")).font(.footnote).foregroundStyle(RoomTheme.secondary)
                    }
                    Button {
                        selectedJobID = job.id
                        careerPath.removeAll()
                    } label: {
                        Label(GameStrings.text(selectedJobID == job.id ? "career.selected" : "career.select"),
                              systemImage: selectedJobID == job.id ? "checkmark.circle.fill" : "arrow.right.circle")
                            .font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MintButtonStyle()).disabled(playerLevel < job.unlockLevel)
                    .accessibilityIdentifier("careerSelect_\(job.id)")
                    Text(GameStrings.text("work.offline")).font(.footnote).foregroundStyle(RoomTheme.secondary)
                }
                .padding(20).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            } else if let active = store.snapshot?.player.activeWork, active.jobID == id {
                // Legacy contracts may outlive a catalog entry. Show their
                // captured terms without inventing a current job or costs.
                VStack(alignment: .leading, spacing: 20) {
                    Text(GameStrings.format("work.remaining", duration(until: active.endsAt)))
                        .font(.title2.weight(.bold)).monospacedDigit()
                    let seconds = Int(max(1, min(315_360_000, active.endsAt.timeIntervalSince(active.startedAt))))
                    VStack(alignment: .leading, spacing: 16) {
                        detailValue("career.duration", value: workDurationText(seconds),
                                    id: "careerDurationSeconds_\(id)", accessibilityValue: String(seconds))
                        detailValue("career.reward", value: GameStrings.format("career.gold", active.goldReward))
                        detailValue("career.experience", value: GameStrings.format("career.expReward", active.expReward))
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
                    Text(GameStrings.text("work.offline")).font(.footnote).foregroundStyle(RoomTheme.secondary)
                }
                .padding(20).frame(maxWidth: 520, alignment: .leading).frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("careerDetailScroll").background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("career.details")).navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            careerBackButton("careerDetailBackButton")
            careerDoneButton
        }
    }

    private func detailValue(_ key: String, value: String, id: String = "", accessibilityValue: String? = nil) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(GameStrings.text(key)).foregroundStyle(RoomTheme.secondary)
                Spacer(minLength: 4)
                Text(value).fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(GameStrings.text(key)).foregroundStyle(RoomTheme.secondary)
                Text(value).fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GameStrings.text(key)).accessibilityValue(accessibilityValue ?? value)
        .accessibilityIdentifier(id)
    }

    @ToolbarContentBuilder private func careerBackButton(_ id: String) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                careerSearchFocused = false
                if !careerPath.isEmpty { careerPath.removeLast() }
            } label: {
                Label(GameStrings.text("common.back"), systemImage: "chevron.left")
            }
            .foregroundStyle(RoomTheme.darkMint).accessibilityIdentifier(id)
        }
    }

    @ToolbarContentBuilder private var careerDoneButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(GameStrings.text("common.done")) { dismiss() }
                .foregroundStyle(RoomTheme.darkMint)
                .accessibilityIdentifier("closeSheetButton")
        }
    }

    private var restPage: some View {
        ScrollView {
            playerRest.padding(20).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("workRestScroll").background(RoomTheme.cream)
        .navigationTitle(GameStrings.text("sleep.title")).navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            careerBackButton("workRestBackButton")
            careerDoneButton
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
            careerDoneButton
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
