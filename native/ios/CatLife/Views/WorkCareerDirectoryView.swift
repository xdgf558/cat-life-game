import SwiftUI
import CatGameCore

@MainActor
struct WorkCareerDirectoryView: View {
    let playerLevel: Int
    let selectedJobID: String
    let language: GameLanguage
    @Binding var careerSearch: String
    @Binding var careerFilter: CareerDirectory.Filter
    @Binding var careerPage: Int
    let onSelect: (String) -> Void
    @FocusState private var careerSearchFocused: Bool

    private var filteredJobs: [WorkJob] {
        CareerDirectory.matching(WorkCatalog.all, level: playerLevel, query: careerSearch, filter: careerFilter,
                                 locale: Locale(identifier: language.rawValue)) { WorkJobPresentation.name($0.id) }
    }

    private var directoryPage: Int { CareerDirectory.clampedPage(careerPage, count: filteredJobs.count) }

    var body: some View {
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
        .onDisappear { careerSearchFocused = false }
        .onChange(of: careerSearch) { _, _ in careerPage = 0 }
        .onChange(of: careerFilter) { _, _ in careerPage = 0 }
        .onChange(of: filteredJobs.count) { _, count in careerPage = CareerDirectory.clampedPage(careerPage, count: count) }
    }

    private func careerRow(_ job: WorkJob) -> some View {
        Button { careerSearchFocused = false; onSelect(job.id) } label: {
            HStack(spacing: 12) {
                Image(systemName: WorkJobPresentation.symbol(job.id)).font(.title3).frame(width: 28)
                    .foregroundStyle(playerLevel >= job.unlockLevel ? RoomTheme.darkMint : RoomTheme.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(WorkJobPresentation.name(job.id)).font(.headline).multilineTextAlignment(.leading)
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
        .accessibilityLabel(WorkJobPresentation.name(job.id))
        .accessibilityValue(playerLevel >= job.unlockLevel
            ? GameStrings.text(selectedJobID == job.id ? "career.selected" : "career.available")
            : GameStrings.format("career.unlock", job.unlockLevel))
        .accessibilityIdentifier("careerJobRow_\(job.id)")
    }
}
