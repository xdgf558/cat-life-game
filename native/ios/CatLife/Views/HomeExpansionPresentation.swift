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

    var body: some View {
        Button {
            Task { await store.changeHomeFloor(to: destination) }
        } label: {
            VStack(spacing: 2) {
                Text(GameStrings.text("homeFloor.\(store.visibleHomeFloor.rawValue)"))
                    .font(.caption2.weight(.heavy)).foregroundStyle(RoomTheme.secondary)
                GameIcon(asset: "room-stairs-cartoon", symbol: "stairs", size: 56, tint: RoomTheme.darkMint)
                HStack(spacing: 3) {
                    Text(GameStrings.text("homeFloor.to.\(destination.rawValue)"))
                    Image(systemName: store.visibleHomeFloor == .ground ? "arrow.up" : "arrow.down")
                }
                .font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
            }
            .padding(9).frame(minWidth: 76)
            .background(RoomTheme.paper.opacity(0.97), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white, lineWidth: 2))
            .shadow(color: RoomTheme.ink.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!store.canChangeHomeFloor || !roomReady)
        .opacity(store.canChangeHomeFloor && roomReady ? 1 : 0.6)
        .accessibilityIdentifier("homeStairsButton")
        .accessibilityLabel(GameStrings.text("homeFloor.to.\(destination.rawValue)"))
        .accessibilityValue(GameStrings.text("homeFloor.\(store.visibleHomeFloor.rawValue)"))
        .accessibilityHint(GameStrings.text(store.isDecorating ? "homeFloor.finishLayout" : "homeFloor.hint"))
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
                GameIcon(asset: "town-home-cartoon", symbol: "house.fill", size: 100, tint: RoomTheme.darkMint)
                    .scaleEffect(appeared ? 1 : 0.8)
                    .animation(reduceMotion ? nil : .spring(duration: 0.45), value: appeared)
                Text(GameStrings.text("homeUpgrade.successTitle")).font(.title2.weight(.heavy))
                Text(GameStrings.format("homeUpgrade.level", celebration.level))
                    .font(.title.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
                if let level = HomeCatalog.level(celebration.level) {
                    Text(GameStrings.format("homeUpgrade.capacity", level.capacity)).font(.headline)
                    Text(GameStrings.text(celebration.level == 6 ? "homeUpgrade.upperUnlocked" : "homeUpgrade.successBody"))
                        .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(RoomTheme.secondary)
                }
                Button(GameStrings.text("homeUpgrade.enjoy"), action: dismiss)
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
