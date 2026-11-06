import SwiftUI
import CatGameCore

@MainActor
struct RoomHomeHUD: View {
    let store: GameStore
    let catNeedPresentation: CatNeedPresentation
    @State private var controlsHidden = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            if !store.isDecorating && !controlsHidden {
                HStack(alignment: .bottom, spacing: 10) {
                    Spacer(minLength: 0)
                    VStack(spacing: 12) {
                        careButton("care.play", asset: "icon-play", symbol: "party.popper.fill", id: "playButton", size: 58) { store.play() }
                        careButton("care.clean", asset: "icon-clean", symbol: "sparkles", id: "cleanButton", size: 58) { store.clean() }
                        careButton(store.hasFood ? "care.feed" : "care.shopFood", asset: store.hasFood ? "bowl-full" : "", symbol: "basket.fill",
                                   id: "feedButton", size: 76, prominent: true) { store.feed() }
                            .overlay(alignment: .topTrailing) {
                                Text("\(store.snapshot?.inventory.food ?? 0)")
                                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 10).frame(height: 27)
                                    .background(RoomTheme.gold, in: Capsule())
                                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                                    .offset(x: 3, y: -3).allowsHitTesting(false)
                                    .accessibilityLabel(GameStrings.text("accessibility.food"))
                                    .accessibilityValue("\(store.snapshot?.inventory.food ?? 0)")
                                    .accessibilityIdentifier("foodCount")
                            }
                    }
                    .frame(width: 78).disabled(store.isBusy)
                }
                .padding(.horizontal, 14).padding(.bottom, 18)
            }
        }
        .overlay {
            if !store.isDecorating && !controlsHidden {
                RoomCatStatusCard(store: store, presentation: catNeedPresentation)
            }
        }
        .onChange(of: store.onboarding.isPresented) { _, presented in
            if !presented && store.onboarding.step == .care { controlsHidden = false }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            if store.isDecorating {
                VStack(alignment: .leading, spacing: 7) {
                    Label(GameStrings.text("layout.edit"), systemImage: "sofa.fill")
                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 44)
                        .background(RoomTheme.mint, in: Capsule())
                    if store.hasUnsavedLayoutChanges {
                        Label(GameStrings.text("layout.unsaved"), systemImage: "pencil")
                            .font(.system(size: 11, weight: .heavy)).foregroundStyle(RoomTheme.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoomTheme.rewardPaper, in: Capsule())
                            .overlay(Capsule().strokeBorder(RoomTheme.rewardBorder, lineWidth: 1.5))
                            .accessibilityIdentifier("layoutUnsavedChanges")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HomeNamePlaque(name: store.homeDisplayName, height: 62)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("homeNamePlaque")
                    if store.onboarding.isActive && store.activeSheet == nil && !store.isShowingSettings {
                        GuideResumeBar(store: store)
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .lineLimit(1).minimumScaleFactor(0.7).frame(height: 44)
                    } else if !controlsHidden {
                        HomeTaskEntry(store: store)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    resource(symbol: "dollarsign.circle.fill", value: store.snapshot?.player.gold ?? 0,
                             suffix: "", key: "resource.gold", id: "goldCount", tint: RoomTheme.gold)
                    Rectangle().fill(RoomTheme.wood).frame(width: 1, height: 18).accessibilityHidden(true)
                    resource(symbol: "bolt.fill", value: store.snapshot?.player.stamina ?? 0,
                             suffix: "/100", key: "resource.stamina", id: "staminaCount", tint: RoomTheme.mint)
                }
                .font(.system(size: 15, weight: .heavy)).monospacedDigit()
                .padding(.horizontal, 12).frame(height: 40).gameCard(cornerRadius: 24)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("homeResourceCapsule")
                if !store.isDecorating {
                    Button { store.beginDecorating() } label: {
                        Label(GameStrings.text("layout.edit"), systemImage: "sofa.fill")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .buttonStyle(SoftButtonStyle()).frame(width: 86)
                    .accessibilityIdentifier("homeDecorateButton").disabled(store.isBusy)
                    Button { controlsHidden.toggle() } label: {
                        Label(GameStrings.text(controlsHidden ? "hud.showCare" : "hud.hideCare"),
                              systemImage: controlsHidden ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(SoftButtonStyle()).frame(width: 100)
                    .accessibilityIdentifier("homeCareVisibilityButton")
                    .accessibilityValue(controlsHidden ? "hidden" : "visible")
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14).padding(.top, 8)
    }

    private func resource(symbol: String, value: Int, suffix: String, key: String, id: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text("\(value)\(suffix)").lineLimit(1).minimumScaleFactor(0.65)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(GameStrings.text(key))
        .accessibilityValue("\(value)").accessibilityIdentifier(id)
    }

    private func careButton(_ key: String, asset: String, symbol: String, id: String, size: CGFloat,
                            prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                GameIcon(asset: asset, symbol: symbol, size: prominent ? 30 : 25,
                         tint: prominent ? .white : RoomTheme.coral)
                Text(GameStrings.text(key)).font(.system(size: prominent ? 13 : 11, weight: .heavy))
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            .foregroundStyle(prominent ? .white : RoomTheme.ink)
            .frame(width: size, height: size)
            .background {
                Circle().fill(prominent ? RoomTheme.mint : RoomTheme.paper)
                    .shadow(color: prominent ? RoomTheme.darkMint : RoomTheme.ink.opacity(0.15), radius: 0, y: 4)
            }
            .overlay(Circle().strokeBorder(.white.opacity(prominent ? 0.45 : 1), lineWidth: 3))
            .contentShape(Circle())
        }
        .buttonStyle(.plain).accessibilityIdentifier(id).accessibilityLabel(GameStrings.text(key))
    }
}

@MainActor
struct RoomArrangementPanel: View {
    let store: GameStore
    @State private var collapsed = false

    var body: some View {
        VStack(spacing: 8) {
            Button { collapsed.toggle() } label: {
                Label(GameStrings.text(collapsed ? "layout.showTray" : "layout.hideTray"),
                      systemImage: collapsed ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain).foregroundStyle(RoomTheme.darkMint)
            .accessibilityIdentifier("layoutTrayToggle")
            .accessibilityValue(collapsed ? "collapsed" : "expanded")
            if !collapsed {
            HStack(spacing: 10) {
                GameIcon(asset: store.selectedFurniture.map { FurnitureCatalog.metadata(for: $0.kind).assetName } ?? "bowl-empty",
                         symbol: "sofa.fill", size: 42)
                    .scaleEffect(x: store.selectedFurniture?.orientation == .mirrored ? -1 : 1, y: 1)
                    .padding(5).background(RoomTheme.paleCoral, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(GameStrings.format("layout.selected", store.selectedFurnitureName))
                        .font(.system(size: 16, weight: .heavy)).lineLimit(2)
                        .accessibilityIdentifier("selectedFurnitureName")
                        .accessibilityValue(store.selectedFurnitureName)
                    Text(orientationHint).font(.system(size: 11, weight: .bold))
                        .foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("layoutOrientationHint")
                }
                Spacer(minLength: 0)
                Button { store.storeSelectedFurniture() } label: {
                    Image(systemName: "backpack.fill").font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(RoomTheme.darkMint)
                .background(RoomTheme.paper, in: Circle())
                .disabled(!store.canStoreSelectedFurniture).accessibilityIdentifier("storeFurnitureButton")
                .accessibilityLabel(GameStrings.text("layout.storeFurniture"))
            }
            HStack(spacing: 4) {
                orientationButton(.normal)
                orientationButton(.mirrored)
            }
            .padding(4).background(RoomTheme.chipBg, in: Capsule())
            .opacity(supportsMirroring ? 1 : 0.45)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.storedFurniture) { item in
                        Button { store.placeFurniture(id: item.id) } label: {
                            VStack(spacing: 3) {
                                GameIcon(asset: FurnitureCatalog.metadata(for: item.kind).assetName, symbol: "sofa.fill", size: 35)
                                Text(GameStrings.furnitureName(item)).font(.system(size: 10, weight: .bold)).lineLimit(1)
                            }
                            .frame(width: 70, height: 70).background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RoomTheme.wood, style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("layoutStored_\(item.id)")
                        .disabled(store.isBusy || store.isResolvingLayout || store.placingFurnitureID != nil || !store.canPlaceMoreFurniture)
                    }
                    tool("layout.furnitureBag", symbol: "backpack.fill", id: "furnitureInventoryButton") { store.openFurnitureInventory() }
                    tool("homeUpgrade.entry", symbol: "house.and.flag.fill", id: "homeUpgradeButton") { store.openHomeUpgrade() }
                    tool("tab.shop", symbol: "plus.circle.fill", id: "layoutShopButton") { store.activeSheet = .shop }
                }.padding(.vertical, 3)
            }
            }
        }
        .padding(16).background(RoomTheme.cream.opacity(0.97), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: ArrangementPanelHeightKey.self, value: geometry.size.height)
            }
        }
    }

    private var supportsMirroring: Bool { store.selectedFurniture?.kind.supportsMirroring == true }
    private var orientationHint: String {
        guard supportsMirroring, let item = store.selectedFurniture else {
            return GameStrings.text(store.selectedFurniture == nil ? "layout.bowlCannotFlip" : "layout.wallCannotFlip")
        }
        return GameStrings.format("layout.orientationHint", GameStrings.text("layout.orientation.\(item.orientation.rawValue)"))
    }

    private func orientationButton(_ orientation: FurnitureOrientation) -> some View {
        let selected = supportsMirroring && store.selectedFurniture?.orientation == orientation
        return Button {
            if supportsMirroring {
                if !selected { store.flipSelectedFurniture() }
            } else {
                store.playFeedback(.softError)
                store.showFurnitureNotice(store.selectedFurniture == nil ? "layout.bowlCannotFlip" : "layout.wallCannotFlip")
            }
        } label: {
            Label(GameStrings.text("layout.orientation.\(orientation.rawValue)"),
                  systemImage: orientation == .normal ? "arrow.right" : "arrow.left")
                .font(.system(size: 12, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(selected ? RoomTheme.darkMint : RoomTheme.secondary)
                .background(selected ? RoomTheme.paper : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy || store.isSavingLayout || store.isResolvingLayout || store.placingFurnitureID != nil)
        .accessibilityIdentifier("furnitureOrientation_\(orientation.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(supportsMirroring ? GameStrings.text("layout.orientation.\(store.selectedFurniture?.orientation.rawValue ?? "normal")") : orientationHint)
        .accessibilityHint(supportsMirroring ? "" : GameStrings.text("layout.cannotFlipHint"))
    }

    private func tool(_ key: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 25, weight: .bold))
                Text(GameStrings.text(key)).font(.system(size: 10, weight: .bold)).lineLimit(2)
            }
            .foregroundStyle(RoomTheme.darkMint).frame(width: 70, height: 70)
            .background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
        .disabled(store.isBusy || store.isResolvingLayout || store.placingFurnitureID != nil)
    }
}
