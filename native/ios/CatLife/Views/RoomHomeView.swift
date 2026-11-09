import SwiftUI
import CatGameCore

@MainActor
struct RoomHomeView: View {
    @Bindable var store: GameStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moreVisible = false
    @State private var townSelectedPlace: TownPlace = .home
    @State private var townLayer: TownLayer = .all
    @State private var catNeedPresentation = CatNeedPresentation()
    @State private var arrangementPanelHeight: CGFloat = 0
    @State private var saveTransferWorking = false
    #if DEBUG
    @State private var waitingForWelcomeTestRelease = false
    private var holdsWelcomeForTesting: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--ui-testing") && arguments.contains("--welcome-hold-load")
    }
    #endif

    private var homeVisible: Bool { store.activeSheet == nil && !store.isShowingSettings }
    private var catSheetVisible: Binding<Bool> {
        Binding(get: { store.inspectedCatID != nil }, set: { if !$0 { store.inspectedCatID = nil } })
    }

    var body: some View {
        Group {
            if !store.hasEnteredHome {
                #if DEBUG
                WelcomeView(store: store, releaseTestLoad: waitingForWelcomeTestRelease ? {
                    waitingForWelcomeTestRelease = false
                    Task { await store.load() }
                } : nil)
                #else
                WelcomeView(store: store)
                #endif
            } else if let snapshot = store.snapshot {
                shell(snapshot)
            }
        }
        .background(RoomTheme.cream.ignoresSafeArea())
        .fontDesign(.rounded).foregroundStyle(RoomTheme.ink).preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
        .task {
            if store.snapshot == nil {
                #if DEBUG
                if holdsWelcomeForTesting { waitingForWelcomeTestRelease = true }
                else { await store.load() }
                #else
                await store.load()
                #endif
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in store.setForeground(phase == .active) }
        .onChange(of: store.saveSceneGeneration) { _, _ in
            townSelectedPlace = .home
            townLayer = .all
        }
        .sheet(isPresented: catSheetVisible) {
            CatCollectionView(store: store, initialCatID: store.inspectedCatID, initialGrowth: store.inspectedCatShowsGrowth)
        }
        .sheet(isPresented: Binding(get: { store.supplyPicker != nil }, set: { if !$0 { store.supplyPicker = nil } })) {
            if let kind = store.supplyPicker {
                SupplyPickerView(store: store, kind: kind)
                    .safeAreaInset(edge: .top, spacing: 0) { if store.hasSaveFailure { SaveStatusBanner(store: store) } }
                    .saveRecoveryAlert(store: store)
                    .presentationBackground(RoomTheme.cream)
                    .interactiveDismissDisabled(store.isBusy)
            }
        }
        .onChange(of: store.onboarding.isPresented, initial: true) { _, presented in
            if presented {
                moreVisible = false
                store.supplyPicker = nil
                store.activeSheet = nil
                store.isShowingSettings = false
            }
        }
        .saveRecoveryAlert(store: store, isActive: !store.onboarding.isPresented
                          && store.inspectedCatID == nil && store.activeSheet != .town
                          && store.activeSheet != .player && store.supplyPicker == nil && !store.isPresentingExchange
                          && !store.isPresentingAdoptionConfirmation && !store.isPresentingCommunityGift)
    }

    private func shell(_ snapshot: GameSnapshot) -> some View {
        ZStack(alignment: .top) {
            // A keyboard on another page must not resize and cancel a paused cat action.
            GeometryReader { geometry in
                room(snapshot)
                    .frame(width: geometry.size.width, height: max(0, geometry.size.height - 64))
                    .opacity(homeVisible ? 1 : 0)
                    .allowsHitTesting(homeVisible && !moreVisible)
                    .accessibilityHidden(!homeVisible || moreVisible)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            VStack(spacing: 0) {
                if store.hasSaveFailure && (!homeVisible || moreVisible) {
                    SaveStatusBanner(store: store)
                }
                ZStack {
                    Color.clear.allowsHitTesting(false).accessibilityHidden(true)
                    if !homeVisible {
                        destination
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(RoomTheme.cream)
                            .accessibilityHidden(moreVisible)
                    }
                    if moreVisible {
                        GameMoreMenu(store: store, close: { moreVisible = false }, select: select)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    if store.hasSaveFailure && homeVisible && !moreVisible { SaveStatusBanner(store: store) }
                    else if !store.hasSaveFailure, let toast = store.toast, !toast.isEmpty, !moreVisible {
                        Text(toast).font(.system(size: 13, weight: .bold)).lineLimit(6)
                            .multilineTextAlignment(.center).accessibilityLabel(toast)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .gameCard(cornerRadius: 24).padding(.horizontal, 16)
                            .padding(.top, homeVisible ? 92 : 4)
                            .accessibilityIdentifier(homeVisible ? "actionToast" : "sheetToast")
                            .accessibilityAddTraits(.updatesFrequently)
                            .allowsHitTesting(false)
                    }
                    else if !store.hasSaveFailure, !store.onboarding.isPresented,
                            !store.isShowingNeighbors, !store.isShowingMarket, !store.isShowingTownBoard,
                            !moreVisible, store.inspectedCatID == nil,
                            !store.isPresentingAdoptionConfirmation, !store.isDecorating,
                            (homeVisible || store.activeSheet == .upgrade),
                            let offer = store.adoptionReminders.pendingOffer {
                        AdoptionAvailableBanner(store: store, offer: offer)
                            .padding(.horizontal, 16).padding(.top, homeVisible ? 92 : 4)
                    }
                }
                if store.onboarding.isActive && !homeVisible && !moreVisible && !store.isDecorating {
                    GuideResumeBar(store: store)
                        .padding(.horizontal, 14).padding(.vertical, 6).background(RoomTheme.cream)
                }
                Group {
                    if store.isDecorating {
                        HStack(spacing: 14) {
                            Button(GameStrings.text("layout.cancel")) { store.cancelDecorating(); store.activeSheet = nil }
                                .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("layoutCancelButton")
                                .disabled(store.isSavingLayout)
                            Button(GameStrings.text("layout.done")) { store.finishDecorating() }
                                .frame(maxWidth: .infinity).buttonStyle(MintButtonStyle())
                                .accessibilityIdentifier("layoutDoneButton")
                                .disabled(store.isBusy || store.isResolvingLayout || store.placingFurnitureID != nil)
                        }.padding(.horizontal, 16)
                    } else {
                        GameBottomBar(store: store, moreVisible: $moreVisible, select: select)
                            .disabled(saveTransferWorking || store.saveTransferInProgress)
                    }
                }
                .frame(height: 64)
                .background(RoomTheme.paper.ignoresSafeArea(edges: .bottom))
            }
        }
        .overlayPreferenceValue(OnboardingTargetKey.self) { targets in
            if store.onboarding.isPresented {
                GeometryReader { geometry in
                    OnboardingSpotlight(store: store,
                        target: store.onboarding.step.flatMap { targets[$0] }.map { geometry[$0] },
                        size: geometry.size, onExplore: { step in
                            moreVisible = false
                            store.exploreOnboarding(step)
                        })
                }
            }
        }
        .onChange(of: store.isDecorating) { _, editing in
            moreVisible = false
            if !editing { store.activeSheet = nil }
        }
        .overlay {
            if let celebration = store.homeUpgradeCelebration {
                HomeUpgradeCelebrationView(celebration: celebration) {
                    store.homeUpgradeCelebration = nil
                    store.activeSheet = nil
                    store.isShowingSettings = false
                }
                .id(celebration.id)
            }
        }
    }

    @ViewBuilder private var destination: some View {
        if store.isShowingSettings {
            SettingsView(store: store, onSaveTransferWorkingChange: { saveTransferWorking = $0 })
        }
        else {
            switch store.activeSheet {
            case .work: WorkDestinationView(store: store)
            case .player: PlayerProfileView(store: store)
            case .tasks: TaskDestinationView(store: store)
            case .town: TownView(store: store, selectedPlace: $townSelectedPlace, layer: $townLayer)
            case .hospital: HospitalView(store: store, initialCatID: store.hospitalCatID)
            case .shop, .inventory, .upgrade:
                NavigationStack {
                    Group {
                        switch store.activeSheet {
                        case .shop: ShopView(store: store)
                        case .inventory: InventoryView(store: store)
                        case .upgrade: HomeUpgradeView(store: store)
                        default: EmptyView()
                        }
                    }
                    .toolbar {
                        if store.isDecorating {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { store.activeSheet = nil } label: {
                                    Label(GameStrings.text("layout.edit"), systemImage: "chevron.left")
                                }.accessibilityIdentifier("layoutReturnButton")
                            }
                        }
                    }
                }
                .id(store.activeSheet)
                .tint(RoomTheme.darkMint)
            case nil: EmptyView()
            }
        }
    }

    private func select(_ destination: HomeSheet?) {
        guard !saveTransferWorking, !store.saveTransferInProgress else { return }
        moreVisible = false
        store.isShowingSettings = false
        if destination == .town { store.inspectedCatID = nil }
        store.activeSheet = destination
    }

    private func room(_ snapshot: GameSnapshot) -> some View {
        ZStack(alignment: .top) {
            RoomSceneHost(store: store,
                          isActive: scenePhase == .active && homeVisible && !moreVisible
                              && store.inspectedCatID == nil && store.supplyPicker == nil && !store.onboarding.isPresented,
                          reducedMotion: reduceMotion, catNeedPresentation: catNeedPresentation,
                          arrangementBottomInset: store.isDecorating ? arrangementPanelHeight : 0)
                .id("\(store.saveSceneGeneration)-\(store.visibleHomeFloor.rawValue)")
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: store.visibleHomeFloor == .upper ? .bottom : .top).combined(with: .opacity),
                    removal: .opacity))
                .ignoresSafeArea(.container, edges: .top)
            RoomHomeHUD(store: store, catNeedPresentation: catNeedPresentation)
            if store.isDecorating {
                VStack { Spacer(minLength: 0); RoomArrangementPanel(store: store) }
                    .onPreferenceChange(ArrangementPanelHeightKey.self) { arrangementPanelHeight = $0 }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.visibleHomeFloor)
    }
}

#if DEBUG
@MainActor
struct AudioDiagnosticsView: View {
    let store: GameStore
    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           ProcessInfo.processInfo.arguments.contains("--audio-test") {
            Text("Audio diagnostics").font(.system(size: 1)).frame(width: 1, height: 1)
                .accessibilityIdentifier("audioDiagnostics").accessibilityValue(store.audioDiagnostics)
                .allowsHitTesting(false)
        }
    }
}
#endif
