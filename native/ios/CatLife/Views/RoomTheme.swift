import SwiftUI
import UIKit

enum RoomTheme {
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.89)
    static let paper = Color(red: 1.0, green: 0.98, blue: 0.94)
    static let mint = Color(red: 0.20, green: 0.68, blue: 0.54)
    static let darkMint = Color(red: 0.08, green: 0.48, blue: 0.37)
    static let paleMint = Color(red: 0.86, green: 0.92, blue: 0.82)
    static let ink = Color(red: 0.38, green: 0.24, blue: 0.15)
    static let secondary = Color(red: 0.51, green: 0.38, blue: 0.27)
    static let wood = Color(red: 0.94, green: 0.79, blue: 0.57)
    static let gold = Color(red: 0.89, green: 0.61, blue: 0.12)
}

struct GameIcon: View {
    var asset: String
    var symbol: String
    var size: CGFloat = 28
    var tint: Color = RoomTheme.ink

    var body: some View {
        Group {
            if !asset.isEmpty, UIImage(named: asset) != nil {
                Image(asset).resizable().scaledToFit()
                    .scaleEffect(asset == "icon-home" ? 1.2 : 1)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.8, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Keep the label inside the actual artwork, which is narrower than the space
/// available in the header. Longer names use two lines without resizing the room.
struct HomeNamePlaque: View {
    let name: String
    var height: CGFloat = 66

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, height * 1983 / 793)
            Image("wood-plaque")
                .resizable().scaledToFit()
                .frame(width: width, height: height)
                .overlay {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 5) {
                            Text(name)
                                .font(.system(size: 25, weight: .heavy, design: .rounded))
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 12)).foregroundStyle(RoomTheme.gold)
                        }
                        Text(name)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .lineLimit(2).minimumScaleFactor(0.75)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: width * 0.76, height: height * 0.60)
                    .offset(y: height * 0.045)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: height)
        .foregroundStyle(RoomTheme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

struct MintButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(minHeight: 48)
            .background(RoomTheme.mint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 2)
            }
            .shadow(color: RoomTheme.darkMint.opacity(0.16), radius: 3, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(RoomTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.8), lineWidth: 1)
            }
            .shadow(color: RoomTheme.ink.opacity(0.08), radius: 2, y: 2)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Compact home actions share a fixed hit area so the last portion changing
/// Feed to Buy food cannot change the room viewport above them.
struct HomeCareButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? .white : RoomTheme.ink)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(prominent ? RoomTheme.mint : RoomTheme.paper,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(prominent ? 0.35 : 0.85), lineWidth: prominent ? 2 : 1)
            }
            .shadow(color: (prominent ? RoomTheme.darkMint : RoomTheme.ink).opacity(0.12), radius: 3, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
