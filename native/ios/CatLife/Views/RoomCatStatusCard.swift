import SwiftUI
import CatGameCore

/// Includes walking, eating and rest frames: HUD avoidance never pauses with care.
struct CatVisualFrameSampler {
    private var sampledAt = -Double.infinity
    private(set) var frame: CGRect?

    mutating func sample(_ proposed: CGRect?, at time: TimeInterval) -> Bool {
        guard time < sampledAt || time - sampledAt >= 0.1 else { return false }
        sampledAt = time
        if let frame, let proposed {
            guard abs(frame.minX - proposed.minX) > 1 || abs(frame.minY - proposed.minY) > 1
                    || abs(frame.width - proposed.width) > 1 || abs(frame.height - proposed.height) > 1 else { return false }
        } else if frame == nil, proposed == nil { return false }
        frame = proposed
        return true
    }
}

enum RoomCatStatusLayout {
    static func frame(in size: CGSize, compact: Bool) -> CGRect {
        if compact {
            // The home plaque and 44-point daily-goal entry occupy the first
            // 122 points. Keep the compact cat card below both touch targets.
            return CGRect(x: 14, y: 134, width: min(260, max(160, size.width - 130)), height: 64)
        }
        return CGRect(x: 14, y: max(0, size.height - 172), width: max(180, size.width - 116), height: 154)
    }

    static func shouldCompact(catFrame: CGRect?, fullCard: CGRect, wasCompact: Bool = false) -> Bool {
        guard let catFrame else { return true }
        // Separate entry/exit margins stop idle breathing at the boundary from flipping the card.
        let margin: CGFloat = wasCompact ? 28 : 12
        return fullCard.insetBy(dx: -margin, dy: -margin).intersects(catFrame)
    }
}

@MainActor
struct RoomCatStatusCard: View {
    let store: GameStore
    let presentation: CatNeedPresentation
    @State private var wasCompact = true

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            let full = RoomCatStatusLayout.frame(in: geometry.size, compact: false)
            let compact = RoomCatStatusLayout.shouldCompact(catFrame: presentation.catFrame,
                fullCard: full.offsetBy(dx: origin.x, dy: origin.y), wasCompact: wasCompact)
            let rect = RoomCatStatusLayout.frame(in: geometry.size, compact: compact)
            VStack(spacing: compact ? 0 : 12) {
                identity(compact: compact)
                if !compact {
                    HStack(spacing: 8) {
                        GameStatRing(value: store.cat?.satiety ?? 0, title: GameStrings.text("stat.satiety"), size: 38)
                        Spacer(minLength: 0)
                        GameStatRing(value: store.cat?.cleanliness ?? 0, title: GameStrings.text("stat.cleanliness"), size: 38)
                        Spacer(minLength: 0)
                        GameStatRing(value: store.cat?.mood ?? 0, title: GameStrings.text("stat.mood"), size: 38)
                        Spacer(minLength: 0)
                        Button { store.openHospital(catID: store.cat?.id) } label: {
                            GameStatRing(value: store.cat?.health ?? 0, title: GameStrings.text("stat.health"), size: 38)
                                .frame(minWidth: 44, minHeight: 44)
                        }.buttonStyle(.plain).accessibilityIdentifier("homeCatHealthButton")
                    }.padding(.horizontal, 3)
                }
            }
            .padding(compact ? 10 : 14)
            .frame(width: rect.width, height: rect.height)
            .gameCard(cornerRadius: compact ? 22 : 26)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("homeCatInfo")
            .accessibilityValue(compact ? "compact" : "expanded")
            .position(x: rect.midX, y: rect.midY)
            .onChange(of: compact, initial: true) { _, value in wasCompact = value }
        }
    }

    private func identity(compact: Bool) -> some View {
        HStack(spacing: 9) {
            Button { store.inspectCat() } label: {
                GameIcon(asset: CatArtwork.asset("cat-avatar", appearance: store.cat?.appearance ?? .orange),
                         symbol: "cat.fill", size: compact ? 34 : 40, tint: RoomTheme.gold)
                    .frame(width: 44, height: 44).background(RoomTheme.wood.opacity(0.25), in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if store.cat?.healthState?.illness != nil {
                            Image(systemName: "cross.circle.fill").font(.system(size: 16, weight: .bold))
                                .foregroundStyle(RoomTheme.coral, RoomTheme.paper).accessibilityHidden(true)
                        }
                    }
            }
            .buttonStyle(.plain).accessibilityLabel(GameStrings.text("catProfile.title"))
            .accessibilityIdentifier("homeCatProfileButton")
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: store.cat.map(GameStrings.catName) ?? "")
                    .font(.system(size: compact ? 16 : 20, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityIdentifier("homeCatName")
                    .accessibilityValue(Text(verbatim: store.cat.map(GameStrings.catName) ?? ""))
                Text(store.catStatus).font(.system(size: 12, weight: .bold))
                    .foregroundStyle(store.cat?.healthState?.illness != nil || (store.cat?.satiety ?? 100) < 50
                                     ? RoomTheme.coral : RoomTheme.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityIdentifier("catSatiety").accessibilityLabel(GameStrings.text("stat.satiety"))
                    .accessibilityValue("\(store.cat?.satiety ?? 0)")
            }
            Spacer(minLength: 0)
            if let illness = store.cat?.healthState?.illness {
                Button { store.openHospital(catID: store.cat?.id) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "cross.case.fill")
                        if !compact {
                            Text(GameStrings.text("health.illness.\(illness.rawValue).name"))
                                .lineLimit(2).minimumScaleFactor(0.8)
                        }
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(RoomTheme.coralDeep)
                    .padding(.horizontal, 7).padding(.vertical, 7)
                    .background(RoomTheme.paleCoral, in: Capsule())
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(GameStrings.text("health.illness.\(illness.rawValue).name"))
                .accessibilityHint(GameStrings.text("hospital.healthDetails"))
                .accessibilityIdentifier("homeCatIllnessButton")
            }
        }
    }
}
