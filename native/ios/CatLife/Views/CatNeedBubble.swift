import SwiftUI
import Observation

/// Presentation priorities only; care effects and spending still belong to Core.
enum CatNeed: Equatable {
    case food, buyFood, clean, play, hospital

    static func current(satiety: Int, cleanliness: Int, mood: Int, hasFood: Bool, isIll: Bool = false) -> CatNeed? {
        if isIll { return .hospital }
        if satiety < 50 { return hasFood ? .food : .buyFood }
        if cleanliness < 40 { return .clean }
        if mood < 45 { return .play }
        return nil
    }

    var titleKey: String {
        switch self {
        case .food: "catNeed.food"
        case .buyFood: "catNeed.buyFood"
        case .clean: "catNeed.clean"
        case .play: "catNeed.play"
        case .hospital: "hospital.healthAlert"
        }
    }
    var symbol: String {
        switch self {
        case .food: "takeoutbag.and.cup.and.straw.fill"
        case .buyFood: "basket.fill"
        case .clean: "sparkles"
        case .play: "party.popper.fill"
        case .hospital: "cross.case.fill"
        }
    }
}

/// SpriteKit samples at most 10 times per second and ignores sub-point idle motion.
struct CatNeedAnchorSampler {
    private var sampledAt = -Double.infinity
    private(set) var point: CGPoint?

    mutating func sample(_ proposed: CGPoint?, at time: TimeInterval) -> Bool {
        guard time < sampledAt || time - sampledAt >= 0.1 else { return false }
        sampledAt = time
        if let point, let proposed {
            guard hypot(point.x - proposed.x, point.y - proposed.y) > 1 else { return false }
        } else if point == nil, proposed == nil { return false }
        point = proposed
        return true
    }
}

enum CatNeedBubbleLayout {
    static func position(above anchor: CGPoint, in size: CGSize) -> CGPoint {
        let minimumX = min(100, max(0, size.width / 2))
        let minimumY = min(100, max(0, size.height / 2))
        return CGPoint(x: min(max(minimumX, size.width - 100), max(minimumX, anchor.x)),
                       y: min(max(minimumY, size.height - 200), max(minimumY, anchor.y - 36)))
    }
}

/// Keeping the observed anchor in this leaf isolates motion from the room/HUD view tree.
@MainActor @Observable
final class CatNeedPresentation {
    var anchor: CGPoint?
    var localCatFrame: CGRect?
    var canvasOrigin = CGPoint.zero
    var catFrame: CGRect? { localCatFrame?.offsetBy(dx: canvasOrigin.x, dy: canvasOrigin.y) }
}

@MainActor
struct CatNeedBubble: View {
    let store: GameStore
    let presentation: CatNeedPresentation
    let canvasSize: CGSize
    let isActive: Bool
    let canAct: () -> Bool

    private var need: CatNeed? {
        guard let cat = store.cat else { return nil }
        return CatNeed.current(satiety: cat.satiety, cleanliness: cat.cleanliness,
                               mood: cat.mood, hasFood: store.hasFood, isIll: cat.healthState?.illness != nil)
    }

    var body: some View {
        if isActive, !store.isBusy, !store.isDecorating, let anchor = presentation.anchor, let need {
            Button {
                guard !store.isBusy, !store.isDecorating, need == .hospital || canAct() else { return }
                switch need {
                case .food, .buyFood: store.feed()
                case .clean: store.clean()
                case .play: store.play()
                case .hospital: store.openHospital(catID: store.cat?.id)
                }
            } label: {
                Label(GameStrings.text(need.titleKey), systemImage: need.symbol)
                    .font(.system(.footnote, design: .rounded, weight: .heavy))
                    .lineLimit(2).multilineTextAlignment(.center)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(minHeight: 44).frame(maxWidth: 190)
                    .foregroundStyle(need == .hospital ? RoomTheme.coral : (need == .clean ? RoomTheme.sky : RoomTheme.ink))
                    .background(RoomTheme.paper, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: RoomTheme.ink.opacity(0.16), radius: 5, y: 4)
                    .overlay(alignment: .bottom) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 12)).foregroundStyle(RoomTheme.paper)
                            .offset(y: 7).accessibilityHidden(true)
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("catNeedBubble")
            .accessibilityLabel(GameStrings.text(need.titleKey))
            .position(CatNeedBubbleLayout.position(above: anchor, in: canvasSize))
        }
    }
}
