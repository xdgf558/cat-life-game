import SwiftUI
import CatGameCore

@MainActor
struct SettingsAudioControl: View {
    enum Channel: String {
        case music, effects

        var enabledKeyPath: WritableKeyPath<AudioSettings, Bool> {
            self == .music ? \.musicEnabled : \.effectsEnabled
        }
        var volumeKeyPath: WritableKeyPath<AudioSettings, Double> {
            self == .music ? \.musicVolume : \.effectsVolume
        }
        var symbol: String { self == .music ? "music.note" : "bell.fill" }
        var tint: Color { self == .music ? RoomTheme.lilac : RoomTheme.gold }
        var toggleID: String { self == .music ? "audioMusicToggle" : "audioEffectsToggle" }
        var sliderID: String { self == .music ? "audioMusicVolume" : "audioEffectsVolume" }
        var titleKey: String { "audio.\(rawValue)" }
        var detailKey: String { "audio.\(rawValue)Detail" }
        var volumeTitleKey: String { "audio.\(rawValue)Volume" }
    }

    let channel: Channel
    let compact: Bool
    @Binding var settings: AudioSettings
    let onChange: () -> Void
    let onCommit: () -> Void

    var body: some View {
        if compact {
            VStack(spacing: 4) {
                toggle
                HStack(spacing: 10) {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(RoomTheme.sky)
                        .frame(width: 36).accessibilityHidden(true)
                    slider
                    Text(volumePercent)
                        .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                toggle
                Text(GameStrings.text(channel.detailKey))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(GameStrings.text(channel.volumeTitleKey)).font(.subheadline)
                    Spacer(minLength: 8)
                    Text(volumePercent)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(RoomTheme.darkMint)
                }
                slider
            }
            .padding(18)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var toggle: some View {
        Toggle(isOn: Binding(
            get: { settings[keyPath: channel.enabledKeyPath] },
            set: { value in
                guard settings[keyPath: channel.enabledKeyPath] != value else { return }
                settings[keyPath: channel.enabledKeyPath] = value
                onChange()
                onCommit()
            })) {
            if compact {
                HStack(spacing: 10) {
                    GameIconTile(symbol: channel.symbol, tint: channel.tint,
                                 background: channel.tint.opacity(0.15), size: 36)
                    Text(GameStrings.text(channel.titleKey)).font(.system(size: 15, weight: .heavy))
                }
            } else {
                Text(GameStrings.text(channel.titleKey)).font(.headline)
            }
        }
        .tint(RoomTheme.mint)
        .accessibilityIdentifier(channel.toggleID)
    }

    private var slider: some View {
        Slider(value: Binding(
            get: { settings[keyPath: channel.volumeKeyPath] },
            set: { value in
                guard settings[keyPath: channel.volumeKeyPath] != value else { return }
                settings[keyPath: channel.volumeKeyPath] = value
                onChange()
            }), in: 0...1, step: 0.05,
               onEditingChanged: { editing in if !editing { onCommit() } })
            .tint(RoomTheme.mint)
            .disabled(!settings[keyPath: channel.enabledKeyPath])
            .accessibilityLabel(GameStrings.text(compact ? channel.titleKey : channel.volumeTitleKey))
            .accessibilityValue(volumePercent)
            .accessibilityIdentifier(channel.sliderID)
    }

    private var volumePercent: String {
        "\(Int((settings[keyPath: channel.volumeKeyPath] * 100).rounded()))%"
    }
}
