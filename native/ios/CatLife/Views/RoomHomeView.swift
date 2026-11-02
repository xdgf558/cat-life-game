import SwiftUI
import CatGameCore

@MainActor
struct RoomHomeView: View {
    @Bindable var store: GameStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    @State private var waitingForWelcomeTestRelease = false

    private var holdsWelcomeForTesting: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--ui-testing") && arguments.contains("--welcome-hold-load")
    }

    #endif

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
                home(snapshot)
            }
        }
        .background(RoomTheme.cream.ignoresSafeArea())
        .fontDesign(.rounded)
        .foregroundStyle(RoomTheme.ink)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: GameLocalization.shared.language.rawValue))
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
        .task {
            if store.snapshot == nil {
                #if DEBUG
                if holdsWelcomeForTesting {
                    // A releasable fixture captures the real loading UI without
                    // delaying normal launches or advancing unfinished progress.
                    waitingForWelcomeTestRelease = true
                } else {
                    await store.load()
                }
                #else
                await store.load()
                #endif
            }
        }
        // Loading may finish after a newer scene-phase notification. Drive
        // the clock only from the current phase, never from a phase captured
        // by the suspended load task.
        .onChange(of: scenePhase, initial: true) { _, phase in store.setForeground(phase == .active) }
        .overlay(alignment: .top) {
            if store.activeSheet == nil && !store.isShowingSettings { SaveStatusBanner(store: store) }
        }
        .sheet(item: $store.activeSheet) { destination in
            if destination == .player {
                PlayerProfileView(store: store)
            } else {
                HomeDestinationSheet(destination: destination, store: store)
            }
        }
        .fullScreenCover(isPresented: $store.isShowingSettings) {
            SettingsView(store: store)
        }
        .saveRecoveryAlert(store: store, isActive: store.activeSheet == nil && !store.isShowingSettings)
    }

    private func home(_ snapshot: GameSnapshot) -> some View {
        VStack(spacing: -20) {
            ZStack(alignment: .top) {
                RoomSceneHost(store: store, isActive: scenePhase == .active && !store.isShowingSettings,
                              reducedMotion: reduceMotion)
                header(snapshot)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .bottom) {
                if let toast = store.toast, !toast.isEmpty {
                    Text(toast)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(RoomTheme.paper.opacity(0.97), in: Capsule())
                        .shadow(color: RoomTheme.ink.opacity(0.12), radius: 4, y: 2)
                        .padding(.horizontal, 16).padding(.bottom, 30)
                        .accessibilityIdentifier("actionToast")
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            VStack(spacing: 0) {
                carePanel(snapshot)
                navigation
            }
            // Build 13 used 161pt for care and 70pt for navigation. Keep that
            // exact footprint so this control rearrangement cannot resize the
            // SpriteKit canvas, its furniture or the cat.
            .frame(height: 231)
            // Keep one room viewport when entering/leaving arrangement. A
            // taller editing panel must not shift furniture or the saved bowl.
            .opacity(store.isDecorating ? 0 : 1)
            .allowsHitTesting(!store.isDecorating)
            .accessibilityHidden(store.isDecorating)
            .overlay {
                if store.isDecorating {
                    layoutPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoomTheme.cream)
                }
            }
            .background(RoomTheme.cream)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .shadow(color: RoomTheme.ink.opacity(0.07), radius: 5, y: -3)
        }
        // The settings keyboard must not resize the covered SpriteKit room:
        // a canvas resize safely cancels care paths and would interrupt a meal.
        // Apply this only to the room; settings retain normal keyboard avoidance.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func header(_ snapshot: GameSnapshot) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HomeNamePlaque(name: store.homeDisplayName)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("homeNamePlaque")

            HStack(spacing: 7) {
                resource(symbol: "pawprint.circle.fill", value: "\(snapshot.player.gold)", tint: RoomTheme.gold)
                    .accessibilityLabel(GameStrings.text("resource.gold"))
                    .accessibilityValue("\(snapshot.player.gold)")
                    .accessibilityIdentifier("goldCount")
                Rectangle().fill(RoomTheme.wood.opacity(0.45))
                    .frame(width: 1, height: 18)
                    .accessibilityHidden(true)
                resource(symbol: "bolt.fill", value: "\(snapshot.player.stamina)/100", tint: RoomTheme.mint)
                    .accessibilityLabel(GameStrings.text("resource.stamina"))
                    .accessibilityValue("\(snapshot.player.stamina)")
                    .accessibilityIdentifier("staminaCount")
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(RoomTheme.paper.opacity(0.98), in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("homeResourceCapsule")
            .padding(.top, 9)
        }
    }

    private func resource(symbol: String, value: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(tint).font(.system(size: 18, weight: .bold))
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
    }

    private func carePanel(_ snapshot: GameSnapshot) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    GameIcon(asset: "cat-avatar", symbol: "cat.fill", size: 52, tint: RoomTheme.gold)
                        .background(RoomTheme.wood.opacity(0.18), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.cat.map(GameStrings.catName) ?? "")
                            .font(.system(size: 23, weight: .heavy, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(store.catStatus)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(RoomTheme.secondary)
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .accessibilityIdentifier("catSatiety")
                            .accessibilityLabel(GameStrings.text("stat.satiety"))
                            .accessibilityValue("\(store.cat?.satiety ?? 0)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("homeCatInfo")

                HStack(spacing: 5) {
                    GameIcon(asset: "bowl-full", symbol: "takeoutbag.and.cup.and.straw.fill",
                             size: 32, tint: RoomTheme.gold)
                    Text(GameStrings.format("resource.food", snapshot.inventory.food))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 10).frame(width: 106, height: 40)
                .background(RoomTheme.wood.opacity(0.14), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("foodCount")
                .accessibilityLabel(GameStrings.text("accessibility.food"))
                .accessibilityValue("\(snapshot.inventory.food)")
            }
            .frame(height: 58)
            .padding(.top, 16)

            Rectangle().fill(RoomTheme.wood.opacity(0.24)).frame(height: 1)
                .padding(.vertical, 10).accessibilityHidden(true)

            GeometryReader { geometry in
                HStack(spacing: 10) {
                    Button { store.feed() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: store.hasFood ? "pawprint.fill" : "basket.fill")
                                .font(.system(size: 21, weight: .semibold))
                            Text(GameStrings.text(store.hasFood ? "care.feed" : "care.shopFood"))
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .lineLimit(1).minimumScaleFactor(0.75)
                        }
                    }
                    .buttonStyle(HomeCareButtonStyle(prominent: true))
                    .frame(width: (geometry.size.width - 20) * 0.39)
                    .accessibilityLabel(GameStrings.text(store.hasFood ? "care.feed" : "care.shopFood"))
                    .accessibilityHint(store.hasFood ? GameStrings.format("care.foodCost", store.foodRequired) : "")
                    .accessibilityIdentifier("feedButton")

                    Button { store.clean() } label: {
                        careActionLabel("care.clean", asset: "icon-clean", symbol: "sparkles")
                    }
                    .buttonStyle(HomeCareButtonStyle())
                    .accessibilityIdentifier("cleanButton")

                    Button { store.play() } label: {
                        careActionLabel("care.play", asset: "icon-play", symbol: "party.popper.fill")
                    }
                    .buttonStyle(HomeCareButtonStyle())
                    .accessibilityIdentifier("playButton")
                }
                .disabled(store.isBusy)
            }
            .frame(height: 48)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 16)
        .frame(height: 161)
        .background(RoomTheme.cream)
    }

    private func careActionLabel(_ key: String, asset: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            GameIcon(asset: asset, symbol: symbol, size: 28, tint: RoomTheme.gold)
            Text(GameStrings.text(key))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private var layoutPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.selectedFurnitureName)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .accessibilityIdentifier("selectedFurnitureName")
                    Text(GameStrings.text("layout.hint"))
                        .font(.system(size: 12))
                        .foregroundStyle(RoomTheme.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Button { store.storeSelectedFurniture() } label: {
                    Label(GameStrings.text("layout.storeFurniture"), systemImage: "backpack.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.canStoreSelectedFurniture ? RoomTheme.darkMint : RoomTheme.secondary)
                .disabled(!store.canStoreSelectedFurniture)
                .accessibilityIdentifier("storeFurnitureButton")
            }
            .frame(height: 48)

            Button { store.openFurnitureInventory() } label: {
                Label(GameStrings.text("layout.furnitureBag"), systemImage: "sofa.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(RoomTheme.paleMint, in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(RoomTheme.darkMint)
            .disabled(store.isSavingLayout || store.isResolvingLayout)
            .accessibilityIdentifier("furnitureInventoryButton")

            HStack(spacing: 14) {
                Button(GameStrings.text("layout.cancel")) { store.cancelDecorating() }
                    .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("layoutCancelButton")
                    .disabled(store.isSavingLayout)
                Button(GameStrings.text("layout.done")) { store.finishDecorating() }
                    .buttonStyle(MintButtonStyle()).accessibilityIdentifier("layoutDoneButton")
                    .disabled(store.isBusy || store.isResolvingLayout || store.placingFurnitureID != nil)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .frame(minHeight: 190)
    }

    private var navigation: some View {
        GeometryReader { geometry in
            // Show a little of the next item so the strip invites a swipe.
            // Only the controls scroll; its existing 70pt footprint is fixed.
            let itemWidth = min(88, max(68, (geometry.size.width - 44) / 4.5))
            let avatar = store.snapshot?.player.profile.avatarID.flatMap(PlayerCatalog.avatar(id:))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    tab("tab.home", asset: "icon-home", symbol: "house.fill", identifier: "tabHome", width: itemWidth, selected: store.activeSheet == nil && !store.isShowingSettings) { }
                    tab("tab.work", asset: "icon-work", symbol: "briefcase.fill", identifier: "tabWork", width: itemWidth, selected: store.activeSheet == .work) { store.activeSheet = .work }
                    tab("tab.shop", asset: "icon-shop", symbol: "storefront.fill", identifier: "tabShop", width: itemWidth, selected: store.activeSheet == .shop) { store.activeSheet = .shop }
                    tab("tab.inventory", asset: "icon-inventory", symbol: "backpack.fill", identifier: "tabInventory", width: itemWidth, selected: store.activeSheet == .inventory) { store.openInventory() }
                    tab("tab.town", asset: "icon-town", symbol: "pawprint.fill", identifier: "tabTown", width: itemWidth, selected: store.activeSheet == .town) { store.activeSheet = .town }
                    tab("tab.player", asset: "", symbol: "person.crop.circle.fill", identifier: "tabPlayer", width: itemWidth, selected: store.activeSheet == .player, avatar: avatar) { store.activeSheet = .player }
                        .accessibilityValue(GameStrings.text(avatar?.nameKey ?? "player.avatar.unselected"))
                    tab("layout.edit", asset: "", symbol: "sofa.fill", identifier: "decorateButton", width: itemWidth, selected: false) { store.beginDecorating() }
                        .accessibilityHint(GameStrings.text("accessibility.decorate"))
                        .disabled(store.isBusy)
                    tab("settings.title", asset: "", symbol: "gearshape.fill", identifier: "settingsButton", width: itemWidth, selected: store.isShowingSettings) { store.openSettings() }
                        .disabled(store.isBusy)
                }
                .padding(.horizontal, 14).padding(.top, 7).padding(.bottom, 8)
            }
            .accessibilityIdentifier("homeNavigationBar")
        }
        .frame(height: 70)
        .background(RoomTheme.paper)
        .disabled(store.isDecorating)
    }

    private func tab(_ title: String, asset: String, symbol: String, identifier: String, width: CGFloat, selected: Bool, avatar: PlayerAvatar? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let avatar {
                    navigationPortrait(avatar)
                } else {
                    GameIcon(asset: asset, symbol: symbol, size: 31, tint: selected ? RoomTheme.mint : RoomTheme.secondary)
                }
                Text(GameStrings.text(title)).font(.system(size: 13, weight: selected ? .bold : .medium))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(width: width, height: 55)
            .foregroundStyle(selected ? RoomTheme.darkMint : RoomTheme.ink)
            .background(selected ? RoomTheme.paleMint.opacity(0.7) : .clear, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func navigationPortrait(_ avatar: PlayerAvatar) -> some View {
        // Reuse the saved appearance's original artwork. Frame its head and
        // shoulders in the existing icon footprint so the face stays legible.
        let iconSize: CGFloat = 31
        let artworkSize = iconSize * 1.85
        return Circle().fill(RoomTheme.paleMint)
            .frame(width: iconSize, height: iconSize)
            .overlay {
                Image(avatar.assetName).resizable().scaledToFit()
                    .frame(width: artworkSize, height: artworkSize)
                    .offset(y: artworkSize / 4)
            }
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

}

#if DEBUG
/// Read-only playback observations, available only to explicitly opted-in UI tests.
@MainActor
struct AudioDiagnosticsView: View {
    let store: GameStore

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           ProcessInfo.processInfo.arguments.contains("--audio-test") {
            Text("Audio diagnostics")
                .font(.system(size: 1)).frame(width: 1, height: 1)
                .accessibilityIdentifier("audioDiagnostics")
                .accessibilityValue(store.audioDiagnostics)
                .allowsHitTesting(false)
        }
    }
}

#endif
