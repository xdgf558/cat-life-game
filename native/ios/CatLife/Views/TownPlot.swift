import SwiftUI

struct TownPlot: View {
    let place: TownPlace
    let selected: Bool
    let inLayer: Bool
    let sickCount: Int
    var availableAdoption = false
    var availableExchanges = 0
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var canAdopt: Bool { place == .adoption && availableAdoption }

    private var needsAttention: Bool { place == .hospital && sickCount > 0 }
    private var status: String {
        if place == .market { return GameStrings.format("market.availableCount", availableExchanges) }
        if canAdopt { return GameStrings.text("cat.adoptionAvailable") }
        if needsAttention { return GameStrings.format("town.sickCount", sickCount) }
        return GameStrings.text(place.isFuture ? "town.comingSoon" : place.statusKey(sickCount: sickCount))
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                GameIcon(asset: place.asset, symbol: place.symbol, size: 38, tint: place.tint)
                Text(GameStrings.text(place.titleKey)).font(.system(size: 12, weight: .heavy))
                    .lineLimit(2).minimumScaleFactor(0.75).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 3).frame(maxWidth: .infinity).frame(height: 72)
            .foregroundStyle(RoomTheme.ink)
            .background {
                RoundedRectangle(cornerRadius: 20).fill(place.tile)
                    .shadow(color: place.isFuture || place.isEmpty ? .clear : RoomTheme.ink.opacity(0.12), radius: 0, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20).strokeBorder(
                    place.isEmpty ? TownPalette.emptyEdge : (place.isFuture ? TownPalette.communityEdge : .white),
                    style: StrokeStyle(lineWidth: place.isFuture || place.isEmpty ? 2 : 3,
                                       dash: place.isFuture || place.isEmpty ? [5, 4] : []))
            }
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 24).strokeBorder(RoomTheme.gold, lineWidth: 3).padding(-4)
                }
            }
            .overlay(alignment: .topTrailing) {
                if place.isFuture || needsAttention || canAdopt || place == .market {
                    Text(status)
                        .font(.system(size: 10, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(.white).padding(.horizontal, 7).frame(height: 22)
                        .background(place == .market ? (availableExchanges > 0 ? RoomTheme.mint : RoomTheme.secondary)
                            : canAdopt ? RoomTheme.mint : (place.isFuture ? RoomTheme.lilac : RoomTheme.coral), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                        .background {
                            if needsAttention, !reduceMotion {
                                Capsule().stroke(RoomTheme.coral.opacity(pulse ? 0 : 0.5), lineWidth: 3)
                                    .scaleEffect(pulse ? 1.15 : 1)
                            }
                        }
                        .offset(x: 3, y: -12).accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topLeading) {
                if place == .home {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 27, weight: .bold))
                        .foregroundStyle(RoomTheme.mint, RoomTheme.paper).offset(x: 8, y: -10)
                        .accessibilityHidden(true)
                }
            }
            .opacity(inLayer ? 1 : 0.25).contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain).accessibilityIdentifier(place.accessibilityIdentifier)
        .accessibilityLabel(GameStrings.text(place.titleKey))
        .accessibilityValue(status)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .onChange(of: needsAttention && !reduceMotion, initial: true) { _, animate in
            if animate {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
            } else { pulse = false }
        }
    }
}
