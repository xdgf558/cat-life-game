import SwiftUI
import CatGameCore

struct SettingsSheetView: View {
    @Bindable var store: DiaryAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var audioDraft: AudioSettings = AudioSettings()
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Sound & Haptics (reuses preserved SettingsSoundPage)
                    SettingsSoundPage(
                        settings: $audioDraft,
                        track: store.audio.currentTrack,
                        musicPlaying: store.audio.musicPlaying,
                        saving: store.isSaving,
                        previewDisabled: false,
                        onChange: { store.updateAudioSettings(audioDraft, commit: false) },
                        onCommit: { store.updateAudioSettings(audioDraft, commit: true) },
                        onMusicPreview: { store.audio.toggleMusicPreview() },
                        onEffectsPreview: { store.audio.play(.merge, userInitiated: true) },
                        onCatPreview: { store.audio.play(.catHappy, userInitiated: true) }
                    )

                    // Language picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text(GameStrings.text("settings.language"))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(RoomTheme.ink)

                        Picker(GameStrings.text("settings.language"), selection: Binding<GameLanguage?>(
                            get: { store.state.settings.language },
                            set: { store.updateLanguage($0) }
                        )) {
                            Text(GameStrings.text("settings.langSystem")).tag(GameLanguage?.none)
                            Text(GameStrings.text("settings.langZH")).tag(GameLanguage?.some(.simplifiedChinese))
                            Text(GameStrings.text("settings.langZHT")).tag(GameLanguage?.some(.traditionalChinese))
                            Text(GameStrings.text("settings.langEN")).tag(GameLanguage?.some(.english))
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(14)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(RoomTheme.wood.opacity(0.6), lineWidth: 1))

                    // M1 Mock Ad Switch
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(GameStrings.text("settings.adDebug"), isOn: $store.mockAdsEnabled)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .tint(RoomTheme.mint)
                        Text(GameStrings.text("settings.adDebugDesc"))
                            .font(.caption)
                            .foregroundStyle(RoomTheme.secondary)
                    }
                    .padding(14)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(RoomTheme.wood.opacity(0.6), lineWidth: 1))

                    // Release Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(GameStrings.text("settings.releases"))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(RoomTheme.ink)
                            Spacer()
                            Text(AppVersion.current.localizedDisplay)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RoomTheme.secondary)
                        }
                        Text(GameStrings.text("release.64.title"))
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(RoomTheme.coralDeep)
                        Text(GameStrings.text("release.64.body"))
                            .font(.caption)
                            .foregroundStyle(RoomTheme.secondary)
                    }
                    .padding(14)
                    .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(RoomTheme.wood.opacity(0.6), lineWidth: 1))

                    // Reset progress
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Text(GameStrings.text("settings.reset"))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(SoftPaperButtonStyle())
                }
                .padding(16)
            }
            .background(RoomTheme.cream.ignoresSafeArea())
            .navigationTitle(GameStrings.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(GameStrings.text("common.done")) {
                        store.audio.endMusicPreview()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                audioDraft = store.state.settings.audio
            }
            .onDisappear {
                store.audio.endMusicPreview()
            }
            .alert(GameStrings.text("settings.resetConfirmTitle"), isPresented: $confirmReset) {
                Button(GameStrings.text("common.cancel"), role: .cancel) {}
                Button(GameStrings.text("common.confirm"), role: .destructive) {
                    store.resetProgress()
                    dismiss()
                }
            } message: {
                Text(GameStrings.text("settings.resetConfirmMessage"))
            }
        }
    }
}
