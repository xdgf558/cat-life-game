import SwiftUI
import CatGameCore

struct ArrangementPanelHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

enum RoomArrangementOverlayLayout {
    static func center(for frame: CGRect, canvas: CGSize, bottomInset: CGFloat, width: CGFloat) -> CGPoint {
        let half = min(width, max(0, canvas.width - 24)) / 2
        let x = min(max(frame.midX, half + 12), max(half + 12, canvas.width - half - 12))
        let upper: CGFloat = 180 // Leave the native safe area and arrangement/status badges unobscured.
        let lower = max(upper, canvas.height - bottomInset - 38)
        return CGPoint(x: x, y: min(max(frame.minY - 32, upper), lower))
    }
}

@MainActor
struct RoomArrangementOverlay: View {
    let store: GameStore
    let selectedFrame: CGRect
    let canvasSize: CGSize
    let bottomInset: CGFloat

    private var supportsMirroring: Bool { store.selectedFurniture?.kind.supportsMirroring == true }
    private var orientation: FurnitureOrientation { store.selectedFurniture?.orientation ?? .normal }
    private var unavailableKey: String { store.selectedFurniture == nil ? "layout.bowlCannotFlip" : "layout.wallCannotFlip" }

    var body: some View {
        let width = min(232.0, max(0, canvasSize.width - 24))
        let center = RoomArrangementOverlayLayout.center(for: selectedFrame, canvas: canvasSize,
                                                         bottomInset: bottomInset, width: width)
        ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                Button {
                    if supportsMirroring { store.flipSelectedFurniture() }
                    else {
                        store.playFeedback(.softError)
                        store.showFurnitureNotice(unavailableKey)
                    }
                } label: {
                    Label(GameStrings.text("layout.flipShort"), systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(supportsMirroring ? .white : RoomTheme.secondary.opacity(0.45))
                        .background(supportsMirroring ? RoomTheme.mint : RoomTheme.chipBg, in: Capsule())
                }
                .buttonStyle(.plain).accessibilityIdentifier("flipFurnitureButton")
                .accessibilityLabel(GameStrings.text("layout.flipFurniture"))
                .accessibilityValue(GameStrings.text(supportsMirroring ? "layout.orientation.\(orientation.rawValue)" : unavailableKey))
                .accessibilityHint(supportsMirroring ? "" : GameStrings.text("layout.cannotFlipHint"))
                Button { store.storeSelectedFurniture() } label: {
                    Label(GameStrings.text("layout.storeFurniture"), systemImage: "backpack.fill")
                        .font(.system(size: 13, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(RoomTheme.ink)
                        .background(RoomTheme.chipBg, in: Capsule())
                }
                .buttonStyle(.plain).disabled(!store.canStoreSelectedFurniture)
                .accessibilityIdentifier("quickStoreFurnitureButton")
            }
            .padding(5).frame(width: width).gameCard(cornerRadius: 30)
            .position(center)

            if supportsMirroring {
                Label(GameStrings.text(orientation == .normal ? "layout.facing.right" : "layout.facing.left"),
                      systemImage: orientation == .normal ? "arrow.right" : "arrow.left")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoomTheme.mint, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    .position(x: min(max(selectedFrame.midX, 58), max(58, canvasSize.width - 58)),
                              y: min(max(selectedFrame.maxY + 12, center.y + 42),
                                     max(center.y + 42, canvasSize.height - bottomInset - 15)))
                    .accessibilityHidden(true).allowsHitTesting(false)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .disabled(store.isBusy || store.isSavingLayout || store.isResolvingLayout || store.placingFurnitureID != nil)
    }
}
