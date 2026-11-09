import SwiftUI
import CatGameCore

struct HomeUpgradeCelebration: Identifiable, Equatable {
    let id = UUID()
    let level: Int
}

/// A landing outside the furniture canvas, so adding a floor never displaces
/// an old layout or puts a new obstacle underneath a sleeping cat.
@MainActor
struct HomeStairLanding: View {
    let store: GameStore
    var roomReady = true
    private var destination: HomeFloor { store.visibleHomeFloor == .ground ? .upper : .ground }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floats = false

    var body: some View {
        Button {
            if !roomReady && !store.isDecorating { store.showFurnitureNotice("homeFloor.waitCare") }
            else { Task { await store.changeHomeFloor(to: destination) } }
        } label: {
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: store.visibleHomeFloor == .ground ? "arrow.up" : "arrow.down")
                    Text(GameStrings.text("homeFloor.to.\(destination.rawValue)"))
                }
                .font(.caption2.weight(.heavy)).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 4)
                .background(RoomTheme.mint, in: Capsule()).overlay(Capsule().stroke(.white, lineWidth: 2))
                .offset(y: !reduceMotion && floats ? -3 : 0)
                GameIcon(asset: "room-stairs-cartoon", symbol: "stairs", size: 52, tint: RoomTheme.darkMint)
            }
            .padding(4).frame(minWidth: 76).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy || store.isChangingHomeFloor)
        .opacity(store.canChangeHomeFloor && roomReady ? 1 : 0.6)
        .accessibilityIdentifier("homeStairsButton")
        .accessibilityLabel(GameStrings.text("homeFloor.to.\(destination.rawValue)"))
        .accessibilityValue(GameStrings.text("homeFloor.\(store.visibleHomeFloor.rawValue)"))
        .accessibilityHint(GameStrings.text(store.isDecorating ? "homeFloor.finishLayout" : "homeFloor.hint"))
        .task(id: reduceMotion) {
            floats = false
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { floats = true }
        }
    }
}

@MainActor
struct HomeUpgradeCelebrationView: View {
    let celebration: HomeUpgradeCelebration
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            RoomTheme.ink.opacity(0.35).ignoresSafeArea().accessibilityHidden(true)
            if !reduceMotion {
                GeometryReader { geometry in
                    ForEach(0..<28, id: \.self) { index in
                        RoundedRectangle(cornerRadius: index.isMultiple(of: 3) ? 5 : 2)
                            .fill([RoomTheme.mint, RoomTheme.gold, RoomTheme.coral, RoomTheme.paper][index % 4])
                            .frame(width: 6, height: index.isMultiple(of: 3) ? 6 : 11)
                            .rotationEffect(.degrees(appeared ? Double(index * 47) : 0))
                            .position(x: geometry.size.width * CGFloat((index * 37 % 91) + 5) / 100,
                                      y: appeared ? geometry.size.height * 0.85 : geometry.size.height * 0.25)
                            .opacity(appeared ? 0 : 1)
                            .animation(.easeOut(duration: 1.7).delay(Double(index % 7) * 0.045), value: appeared)
                    }
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    ZStack {
                        ForEach(0..<16, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 2).fill(RoomTheme.gold.opacity(0.28))
                                .frame(width: 12, height: 66).offset(y: -58).rotationEffect(.degrees(Double(index) * 22.5))
                        }
                    }.frame(width: 190, height: 190)
                        .rotationEffect(.degrees(!reduceMotion && appeared ? 35 : 0))
                        .animation(reduceMotion ? nil : .linear(duration: 12).repeatForever(autoreverses: false), value: appeared)
                    GameIcon(asset: "town-home-cartoon", symbol: "house.fill", size: 112, tint: RoomTheme.darkMint)
                        .padding(10).background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 30))
                        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white, lineWidth: 3))
                        .overlay(alignment: .topTrailing) {
                            Text("Lv\(celebration.level)").font(.headline.weight(.heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6).background(RoomTheme.gold, in: Capsule())
                                .overlay(Capsule().strokeBorder(.white, lineWidth: 3)).offset(x: 10, y: -7)
                        }
                }.frame(height: 165)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .animation(reduceMotion ? nil : .spring(duration: 0.45), value: appeared)
                Text(GameStrings.text("homeUpgrade.successTitle")).font(.title2.weight(.heavy))
                Text(GameStrings.text("homeUpgrade.successBody")).font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Text("Lv\(max(1, celebration.level - 1))").padding(10).background(RoomTheme.track, in: Capsule())
                    Image(systemName: "arrow.right").foregroundStyle(RoomTheme.mint)
                    Text("Lv\(celebration.level)").padding(10).background(RoomTheme.gold.opacity(0.22), in: Capsule())
                }.font(.title3.weight(.heavy))
                if let level = HomeCatalog.level(celebration.level) {
                    if celebration.level == 6 {
                        HStack(spacing: 12) {
                            Image(systemName: "stairs").font(.title)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(GameStrings.text("homeUpgrade.upperOpened")).font(.headline.weight(.heavy))
                                Text(GameStrings.text("homeUpgrade.upperUnlocked")).font(.caption.weight(.bold))
                            }.fixedSize(horizontal: false, vertical: true)
                        }.foregroundStyle(RoomTheme.friendshipDeep).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoomTheme.friendshipPaper, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(RoomTheme.friendshipBorder, lineWidth: 2))
                    }
                    Text(GameStrings.format(level.floors.count == 2 ? "homeUpgrade.floorCapacity" : "homeUpgrade.capacity",
                                            level.floors.count == 2 ? level.floorCapacity : level.capacity))
                        .font(.subheadline.weight(.heavy)).foregroundStyle(RoomTheme.darkMint).multilineTextAlignment(.center)
                }
                Button(action: dismiss) {
                    Text(GameStrings.text("homeUpgrade.enjoy")).font(.headline.weight(.heavy)).frame(maxWidth: .infinity)
                }
                    .buttonStyle(MintButtonStyle()).accessibilityIdentifier("homeUpgradeCelebrationDone")
            }
            .padding(26).frame(maxWidth: 340).gameCard(cornerRadius: 32).padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize).defaultScrollAnchor(.center)
            .accessibilityIdentifier("homeUpgradeCelebrationScroll")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeUpgradeCelebration")
        .accessibilityAddTraits(.isModal)
        .onAppear { appeared = true }
    }
}
