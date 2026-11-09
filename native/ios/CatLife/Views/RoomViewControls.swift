import SwiftUI

@MainActor
struct RoomViewControls: View {
    let angle: RoomViewAngle
    let isWholeRoomView: Bool
    let canChangeView: Bool
    var compact = false
    var showsFindCat = true
    let turn: (Int) -> Void
    let showWholeRoom: () -> Void
    let focusCat: () -> Void

    private var angleKey: String {
        switch angle {
        case .left: "roomView.angle.left"
        case .front: "roomView.angle.front"
        case .right: "roomView.angle.right"
        }
    }

    private var viewDescription: String {
        GameStrings.format("roomView.current", GameStrings.text(angleKey),
                           GameStrings.text(isWholeRoomView ? "roomView.whole" : "roomView.close"))
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(viewDescription)
                .font(.caption2.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("roomViewStatus")
            HStack(spacing: 2) {
                turnButton(-1, symbol: "arrow.uturn.backward", key: "roomView.turnLeft",
                           identifier: "roomViewLeftButton", atLimit: angle == .left)
                Button(action: isWholeRoomView ? focusCat : showWholeRoom) {
                    Image(systemName: isWholeRoomView ? "plus.magnifyingglass" : "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityIdentifier("roomOverviewButton")
                .accessibilityLabel(GameStrings.text(isWholeRoomView ? "roomView.showClose" : "roomView.showWhole"))
                .accessibilityValue(viewDescription)
                turnButton(1, symbol: "arrow.uturn.forward", key: "roomView.turnRight",
                           identifier: "roomViewRightButton", atLimit: angle == .right)
                if showsFindCat && !compact { findCatButton }
            }
            if showsFindCat && compact { findCatButton }
        }
        .padding(5)
        .background(RoomTheme.paper.opacity(0.97), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white, lineWidth: 1.5))
        .buttonStyle(.plain).foregroundStyle(RoomTheme.ink)
        .disabled(!canChangeView)
        .opacity(canChangeView ? 1 : 0.6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("roomViewControls")
        // Keep the map tools inside their touch targets; full descriptions remain available to VoiceOver.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var findCatButton: some View {
        Button(action: focusCat) {
            Label(GameStrings.text("homeUpgrade.focusCat"), systemImage: "scope")
                .labelStyle(.iconOnly).font(.body.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityIdentifier("focusCatButton")
        .accessibilityHint(GameStrings.text("homeUpgrade.zoomHint"))
    }

    private func turnButton(_ steps: Int, symbol: String, key: String,
                            identifier: String, atLimit: Bool) -> some View {
        Button { turn(steps) } label: {
            Image(systemName: symbol).font(.body.weight(.semibold))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .disabled(atLimit).opacity(atLimit ? 0.35 : 1)
        .accessibilityLabel(GameStrings.text(key))
        .accessibilityIdentifier(identifier)
    }
}
