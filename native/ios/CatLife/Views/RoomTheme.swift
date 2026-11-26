import SwiftUI
import UIKit
import CatGameCore

// MARK: - Warm Watercolor Storybook Palette

enum RoomTheme {
    static let cream = Color(red: 0.985, green: 0.955, blue: 0.90)
    static let paper = Color(red: 1.0, green: 0.985, blue: 0.955)
    static let warmIvory = Color(red: 0.995, green: 0.972, blue: 0.925)
    static let mint = Color(red: 0.25, green: 0.66, blue: 0.52)
    static let darkMint = Color(red: 0.13, green: 0.46, blue: 0.35)
    static let paleMint = Color(red: 0.88, green: 0.95, blue: 0.89)
    static let ink = Color(red: 0.33, green: 0.22, blue: 0.14)
    static let secondary = Color(red: 0.54, green: 0.42, blue: 0.31)
    static let wood = Color(red: 0.88, green: 0.74, blue: 0.56)
    static let woodDeep = Color(red: 0.71, green: 0.54, blue: 0.36)
    static let coral = Color(red: 0.90, green: 0.48, blue: 0.29)
    static let coralDeep = Color(red: 0.73, green: 0.34, blue: 0.18)
    static let paleCoral = Color(red: 0.99, green: 0.91, blue: 0.84)
    static let coralBorder = Color(red: 0.93, green: 0.72, blue: 0.57)
    static let rewardPaper = Color(red: 1.0, green: 0.965, blue: 0.895)
    static let rewardBorder = Color(red: 0.91, green: 0.76, blue: 0.53)
    static let sky = Color(red: 0.37, green: 0.65, blue: 0.82)
    static let lilac = Color(red: 0.56, green: 0.41, blue: 0.67)
    static let track = Color(red: 0.92, green: 0.86, blue: 0.76)
    static let chipBg = Color(red: 0.96, green: 0.91, blue: 0.83)
    static let gold = Color(red: 0.89, green: 0.62, blue: 0.15)
    static let heartPink = Color(red: 0.93, green: 0.46, blue: 0.54)
    static let matTileLight = Color(red: 0.985, green: 0.953, blue: 0.886)
    static let matTileAlt = Color(red: 0.957, green: 0.912, blue: 0.824)
    static let matLine = Color(red: 0.82, green: 0.71, blue: 0.55)

    static func edgeBackdrop(for light: SceneLight) -> Color {
        switch light {
        case .day: Color(red: 0.992, green: 0.835, blue: 0.647)
        case .night: Color(red: 0.56, green: 0.39, blue: 0.24)
        case .rain: Color(red: 0.88, green: 0.76, blue: 0.64)
        }
    }
}

// MARK: - Precision Art-Aligned Scene Geometry (13:6 artwork ratio)

enum SceneCanvasLayout {
    static let backgroundRatio: CGFloat = 13.0 / 6.0

    /// Exact normalized inner cream mat coordinates measured on `bg_workshop.jpg`.
    static let workshopMat = (left: CGFloat(0.062), top: CGFloat(0.384), right: CGFloat(0.938), bottom: CGFloat(0.819))
    static let workshopTableBottom: CGFloat = 0.876

    static func sceneFrame(in size: CGSize, maxCropTop: CGFloat) -> CGRect {
        var w = min(size.width, size.height / ((1 - maxCropTop) * backgroundRatio))
        if w * backgroundRatio < size.height {
            w = size.height / backgroundRatio
        }
        let h = w * backgroundRatio
        return CGRect(x: (size.width - w) / 2, y: size.height - h, width: w, height: h)
    }

    /// Guarantees space above the painted workbench mat for Top HUD + Order Receipts on every screen.
    static func workshopFrame(in size: CGSize, safeTop: CGFloat) -> CGRect {
        let base = sceneFrame(in: size, maxCropTop: 0.28)
        let minMatTop = safeTop + 132
        if base.minY + base.height * workshopMat.top >= minMatTop {
            return base
        }
        let h = (size.height - minMatTop) / (1 - workshopMat.top)
        let w = h / backgroundRatio
        return CGRect(x: (size.width - w) / 2, y: size.height - h, width: w, height: h)
    }

    static func subrect(of frame: CGRect, left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) -> CGRect {
        CGRect(
            x: frame.minX + frame.width * left,
            y: frame.minY + frame.height * top,
            width: frame.width * (right - left),
            height: frame.height * (bottom - top)
        )
    }
}

// MARK: - Reusable Handcrafted Surfaces & Controls

/// Warm frosted ivory capsule that lets hand-painted watercolor scenes breathe underneath.
struct WarmGlassBackground: View {
    var cornerRadius: CGFloat = 20
    var tintOpacity: Double = 0.78

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RoomTheme.warmIvory.opacity(tintOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.9), RoomTheme.wood.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.25
                    )
            }
            .shadow(color: RoomTheme.ink.opacity(0.12), radius: 8, y: 3)
    }
}

/// 9-slice hand-painted watercolor parchment panel using bundled `ui_panel`.
struct WatercolorPanelBackground: View {
    var body: some View {
        if UIImage(named: "ui_panel") != nil {
            Image("ui_panel")
                .resizable(capInsets: EdgeInsets(top: 56, leading: 56, bottom: 56, trailing: 56), resizingMode: .stretch)
                .shadow(color: RoomTheme.ink.opacity(0.24), radius: 18, y: 10)
        } else {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(RoomTheme.paper)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(RoomTheme.woodDeep, lineWidth: 2))
                .shadow(color: RoomTheme.ink.opacity(0.22), radius: 16, y: 8)
        }
    }
}

struct WashiTapeStrip: View {
    var tint: Color = RoomTheme.coral.opacity(0.45)
    var width: CGFloat = 46

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 0.8)
            )
            .frame(width: width, height: 13)
            .rotationEffect(.degrees(-2.5))
    }
}

struct GameIconTile: View {
    let symbol: String
    let tint: Color
    let background: Color
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous).fill(background)
            Image(systemName: symbol)
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct AssetOrSymbol: View {
    let asset: String
    let symbol: String
    var size: CGFloat = 28
    var tint: Color = RoomTheme.ink

    var body: some View {
        Group {
            if !asset.isEmpty, UIImage(named: asset) != nil {
                Image(asset).resizable().scaledToFit()
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.78, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct WarmButtonStyle: ButtonStyle {
    var fill: Color = RoomTheme.coral
    var shadowColor: Color = RoomTheme.coralDeep
    var foreground: Color = .white

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [fill.opacity(0.95), fill],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: shadowColor.opacity(isEnabled ? 0.85 : 0.2), radius: 0, y: configuration.isPressed ? 1 : 3.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.42), lineWidth: 1.4)
            }
            .contentShape(Rectangle())
            .offset(y: configuration.isPressed ? 2.5 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(isEnabled ? 1 : 0.48)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SoftPaperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(RoomTheme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RoomTheme.paper)
                    .shadow(color: RoomTheme.woodDeep.opacity(0.32), radius: 0, y: configuration.isPressed ? 1 : 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(RoomTheme.wood.opacity(0.85), lineWidth: 1.4)
            }
            .contentShape(Rectangle())
            .offset(y: configuration.isPressed ? 2 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct CraftIconBadgeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
