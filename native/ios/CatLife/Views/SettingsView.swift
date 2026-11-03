import SwiftUI
import CatGameCore

/// A two-level settings flow. Language changes update the existing navigation
/// stack and room in place; neither the save nor the SpriteKit scene is rebuilt.
@MainActor
struct SettingsView: View {
    @Bindable var store: GameStore
    @State private var path: [Destination] = []
    @State private var homeNameDraft = ""
    @State private var savedNameDraft: String?
    @State private var nameMessageKey: String?
    @State private var isSavingHomeName = false
    @State private var audioDraft = AudioSettings()
    @State private var isSavingAudio = false
    @State private var hasLoadedAudioDraft = false
    @State private var hasUnsubmittedAudioChanges = false
    @State private var audioSaveGeneration = 0
    @FocusState private var nameFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private enum Destination: Hashable { case homeName, language, updates, audio }

    var body: some View {
        NavigationStack(path: $path) {
            page {
                HStack(spacing: 16) {
                    GameIcon(asset: "cat-avatar", symbol: "cat.fill", size: 64, tint: RoomTheme.gold)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(GameStrings.text("home.name"))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text(GameStrings.text("settings.subtitle"))
                            .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)

                VStack(spacing: 0) {
                    NavigationLink(value: Destination.homeName) {
                        settingRow(symbol: "house.fill", title: "settings.homeName",
                                   detail: "settings.homeNameDetail", value: store.homeDisplayName)
                    }
                    .accessibilityIdentifier("settingsHomeNameRow")
                    Divider().overlay(RoomTheme.wood.opacity(0.3)).padding(.leading, 70)
                    NavigationLink(value: Destination.language) {
                        settingRow(symbol: "globe", title: "settings.language",
                                   detail: "settings.languageDetail", value: nativeName(store.language))
                    }
                    .accessibilityIdentifier("settingsLanguageRow")
                    Divider().overlay(RoomTheme.wood.opacity(0.3)).padding(.leading, 70)
                    NavigationLink(value: Destination.updates) {
                        settingRow(symbol: "clock.arrow.circlepath", title: "settings.updates",
                                   detail: "settings.updatesDetail", value: AppVersion.current.display)
                    }
                    .accessibilityIdentifier("settingsUpdatesRow")
                    Divider().overlay(RoomTheme.wood.opacity(0.3)).padding(.leading, 70)
                    NavigationLink(value: Destination.audio) {
                        settingRow(symbol: "speaker.wave.2.fill", title: "settings.audio",
                                   detail: "settings.audioDetail", value: audioSummary)
                    }
                    .accessibilityIdentifier("settingsAudioRow")
                }
                .buttonStyle(.plain)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
            }
            .navigationTitle(GameStrings.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if path.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.body.weight(.semibold))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(GameStrings.text("common.close"))
                        .accessibilityIdentifier("settingsCloseButton")
                    }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                Group {
                    switch destination {
                    case .homeName: homeNamePage
                    case .language: languagePage
                    case .updates: updatesPage
                    case .audio: audioPage
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { if !path.isEmpty { path.removeLast() } } label: {
                            Label(GameStrings.text("common.back"), systemImage: "chevron.left")
                                .font(.body.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("settingsBackButton")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { SaveStatusBanner(store: store) }
        .fontDesign(.rounded)
        .foregroundStyle(RoomTheme.ink)
        .tint(RoomTheme.darkMint)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
        .saveRecoveryAlert(store: store)
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24, content: content)
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(RoomTheme.cream.ignoresSafeArea())
        .toolbarBackground(RoomTheme.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func settingRow(symbol: String, title: String, detail: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RoomTheme.darkMint)
                .frame(width: 40, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(GameStrings.text(title)).font(.headline)
                Text(GameStrings.text(detail))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium)).foregroundStyle(RoomTheme.darkMint)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RoomTheme.secondary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var languagePage: some View {
        page {
            Text(GameStrings.text("settings.languageHint"))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)
            VStack(spacing: 0) {
                ForEach(GameLanguage.allCases, id: \.self) { language in
                    if language != GameLanguage.allCases.first {
                        Divider().overlay(RoomTheme.wood.opacity(0.3)).padding(.horizontal, 18)
                    }
                    languageRow(language)
                }
            }
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
        }
        .navigationTitle(GameStrings.text("settings.language"))
    }

    private var audioSummary: String {
        let settings = store.audioSettings
        return GameStrings.format("settings.audioSummary",
            settings.musicEnabled ? audioPercent(settings.musicVolume) : GameStrings.text("audio.off"),
            settings.effectsEnabled ? audioPercent(settings.effectsVolume) : GameStrings.text("audio.off"))
    }

    private var audioPage: some View {
        page {
            Text(GameStrings.text("audio.hint"))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)

            VStack(spacing: 18) {
                audioCard(title: "audio.music", detail: "audio.musicDetail", volumeTitle: "audio.musicVolume",
                          enabled: \.musicEnabled, volume: \.musicVolume,
                          toggleID: "audioMusicToggle", sliderID: "audioMusicVolume")
                audioCard(title: "audio.effects", detail: "audio.effectsDetail", volumeTitle: "audio.effectsVolume",
                          enabled: \.effectsEnabled, volume: \.effectsVolume,
                          toggleID: "audioEffectsToggle", sliderID: "audioEffectsVolume")
                Button { store.previewSoundEffect() } label: {
                    Label(GameStrings.text("audio.preview"), systemImage: "play.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 26)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(!audioDraft.effectsEnabled || audioDraft.effectsVolume == 0
                          || isSavingAudio || hasUnsubmittedAudioChanges
                          || store.pendingAudioSettings != nil || audioDraft != store.audioSettings)
                .accessibilityIdentifier("audioPreviewButton")
            }

            if isSavingAudio || (store.pendingAudioSettings != nil && !store.audioSettingsSaveFailed) {
                ProgressView(GameStrings.text("common.saving"))
                    .font(.footnote).tint(RoomTheme.darkMint)
                    .accessibilityIdentifier("audioSaveStatus")
            }

            Text(GameStrings.text("audio.systemHint"))
                .font(.footnote).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("audioSettingsScroll")
        .navigationTitle(GameStrings.text("settings.audio"))
        .onAppear {
            // A page can reappear while its previous request is waiting behind
            // another save. Keep that draft, or restore the Store's latest intent
            // when opening a new editor after a failed or unfinished write.
            guard !hasUnsubmittedAudioChanges, !isSavingAudio else { return }
            audioDraft = store.pendingAudioSettings ?? store.audioSettings
            hasLoadedAudioDraft = true
        }
        .onDisappear { saveAudioDraft() }
    }

    private func audioCard(title: String, detail: String, volumeTitle: String,
                           enabled: WritableKeyPath<AudioSettings, Bool>,
                           volume: WritableKeyPath<AudioSettings, Double>,
                           toggleID: String, sliderID: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(GameStrings.text(title), isOn: Binding(
                get: { audioDraft[keyPath: enabled] },
                set: { value in
                    guard audioDraft[keyPath: enabled] != value else { return }
                    audioDraft[keyPath: enabled] = value
                    hasUnsubmittedAudioChanges = true
                    saveAudioDraft()
                }))
                .font(.headline).tint(RoomTheme.mint)
                .accessibilityIdentifier(toggleID)
            Text(GameStrings.text(detail))
                .font(.footnote).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(GameStrings.text(volumeTitle)).font(.subheadline)
                Spacer(minLength: 8)
                Text(audioPercent(audioDraft[keyPath: volume]))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(RoomTheme.darkMint)
            }
            Slider(value: Binding(get: { audioDraft[keyPath: volume] },
                                  set: { value in
                                      guard audioDraft[keyPath: volume] != value else { return }
                                      audioDraft[keyPath: volume] = value
                                      hasUnsubmittedAudioChanges = true
                                  }),
                   in: 0...1, step: 0.05,
                   onEditingChanged: { editing in if !editing { saveAudioDraft() } })
                .tint(RoomTheme.mint)
                .disabled(!audioDraft[keyPath: enabled])
                .accessibilityLabel(GameStrings.text(volumeTitle))
                .accessibilityValue(audioPercent(audioDraft[keyPath: volume]))
                .accessibilityIdentifier(sliderID)
        }
        .padding(18)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func audioPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func saveAudioDraft() {
        guard hasLoadedAudioDraft, hasUnsubmittedAudioChanges else { return }
        let proposed = audioDraft
        hasUnsubmittedAudioChanges = false
        // Selecting the saved value can still supersede an older in-flight
        // request. Only skip a true no-op with no pending intent in the Store.
        guard proposed != store.audioSettings || store.pendingAudioSettings != nil || isSavingAudio else { return }
        audioSaveGeneration += 1
        let generation = audioSaveGeneration
        isSavingAudio = true
        Task {
            guard audioSaveGeneration == generation else { return }
            _ = await store.updateAudioSettings(proposed)
            guard audioSaveGeneration == generation else { return }
            // Never copy an older completion over a newer slider/toggle edit.
            // Failed intent remains in the Store and the persistent save banner
            // offers retry even after this destination has disappeared.
            isSavingAudio = false
        }
    }

    private var homeNamePage: some View {
        page {
            Text(GameStrings.text("homeName.hint"))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)
            VStack(alignment: .leading, spacing: 14) {
                Text(GameStrings.text("homeName.fieldLabel")).font(.headline)
                TextField(GameStrings.text("homeName.placeholder"), text: $homeNameDraft)
                    .font(.title3.weight(.semibold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    // Periodic game synchronization must not dismiss the
                    // keyboard or interrupt a Chinese input composition.
                    .disabled(isSavingHomeName)
                    .submitLabel(.done)
                    .focused($nameFieldFocused)
                    .onSubmit { nameFieldFocused = false }
                    .padding(14)
                    .background(RoomTheme.cream, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(GameStrings.text("homeName.fieldLabel"))
                    .accessibilityIdentifier("homeNameField")
                HStack(alignment: .top) {
                    Text(GameStrings.text("homeName.unsavedHint"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary)
                    Spacer(minLength: 8)
                    Text(GameStrings.format("homeName.count", trimmedNameCount, HomeNameRules.maximumLength))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(trimmedNameCount > HomeNameRules.maximumLength ? Color.red : RoomTheme.secondary)
                }
                if !homeNameDraft.isEmpty && HomeNameRules.normalized(homeNameDraft) == nil {
                    Text(GameStrings.text("homeName.invalid"))
                        .font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("homeNameValidation")
                }
            }
            .padding(18)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 10) {
                Text(GameStrings.text("homeName.preview"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                HomeNamePlaque(name: HomeNameRules.normalized(homeNameDraft) ?? store.homeDisplayName)
                    .accessibilityIdentifier("homeNamePreview")
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Button {
                    guard !isSavingHomeName else { return }
                    nameFieldFocused = false
                    let proposed = homeNameDraft
                    isSavingHomeName = true
                    Task {
                        defer { isSavingHomeName = false }
                        if await store.setHomeName(proposed) {
                            homeNameDraft = store.snapshot?.home.name ?? ""
                            savedNameDraft = homeNameDraft
                            nameMessageKey = "homeName.saved"
                        }
                    }
                } label: {
                    Text(GameStrings.text("homeName.save"))
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(store.isBusy || isSavingHomeName || HomeNameRules.normalized(homeNameDraft) == nil
                          || HomeNameRules.normalized(homeNameDraft) == store.snapshot?.home.name)
                .accessibilityIdentifier("homeNameSaveButton")

                Button {
                    guard !isSavingHomeName else { return }
                    nameFieldFocused = false
                    isSavingHomeName = true
                    Task {
                        defer { isSavingHomeName = false }
                        if await store.setHomeName(nil) {
                            homeNameDraft = ""
                            savedNameDraft = ""
                            nameMessageKey = "homeName.resetDone"
                        }
                    }
                } label: {
                    Text(GameStrings.text("homeName.reset")).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RoomTheme.darkMint)
                .disabled(store.isBusy || isSavingHomeName || (store.snapshot?.home.name == nil && homeNameDraft.isEmpty))
                .accessibilityIdentifier("homeNameResetButton")

                if homeNameDraft == savedNameDraft, let nameMessageKey {
                    Label(GameStrings.text(nameMessageKey), systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(RoomTheme.darkMint)
                        .accessibilityIdentifier("homeNameStatus")
                }
            }
        }
        .navigationTitle(GameStrings.text("settings.homeName"))
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            homeNameDraft = store.snapshot?.home.name ?? ""
            savedNameDraft = nil
            nameMessageKey = nil
        }
    }

    private var trimmedNameCount: Int {
        homeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private func languageRow(_ language: GameLanguage) -> some View {
        let selected = language == store.language
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #endif
        return Button { store.setLanguage(language) } label: {
            HStack(spacing: 16) {
                Text(nativeName(language)).font(.body.weight(.semibold))
                Spacer(minLength: 10)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(selected ? RoomTheme.darkMint : RoomTheme.wood)
                    .accessibilityHidden(true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy)
        .accessibilityIdentifier("languageOption_" + language.rawValue)
        #if DEBUG
        .accessibilityValue(testing ? (selected ? "selected" : "unselected") : "")
        #endif
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var updatesPage: some View {
        page {
            VStack(alignment: .leading, spacing: 12) {
                Label(GameStrings.text("settings.currentVersion"), systemImage: "pawprint.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.darkMint)
                Text(AppVersion.current.localizedDisplay)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .accessibilityIdentifier("currentAppVersion")
                    .accessibilityLabel(GameStrings.text("settings.currentVersion"))
                    .accessibilityValue(AppVersion.current.display)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoomTheme.paleMint, in: RoundedRectangle(cornerRadius: 24))

            VStack(alignment: .leading, spacing: 6) {
                Text(GameStrings.text("settings.recentUpdates")).font(.headline)
                Text(GameStrings.text("settings.recentUpdatesHint"))
                    .font(.footnote).foregroundStyle(RoomTheme.secondary)
            }
            VStack(spacing: 14) {
                ForEach(AppRelease.recent) { release in
                    releaseCard(release)
                }
            }
        }
        .navigationTitle(GameStrings.text("settings.updates"))
    }

    private func releaseCard(_ release: AppRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(GameStrings.format("settings.versionFormat", release.version, String(release.build)))
                    .font(.subheadline.weight(.bold))
                Spacer(minLength: 0)
                if release.build == AppVersion.current.buildNumber {
                    Text(GameStrings.text("settings.currentRelease"))
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.darkMint)
                }
            }
            Text(release.localizedDate).font(.caption).foregroundStyle(RoomTheme.secondary)
            Text(GameStrings.text("releases.\(release.build).title")).font(.headline)
            Text(GameStrings.text("releases.\(release.build).body"))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("releaseNote_\(release.build)")
    }

    private func nativeName(_ language: GameLanguage) -> String {
        switch language {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        }
    }
}

private struct AppVersion: Sendable {
    let version: String
    let build: String
    static let current = AppVersion(
        version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
        build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
    var display: String { "\(version) (\(build))" }
    var buildNumber: Int { Int(build) ?? 0 }
    @MainActor var localizedDisplay: String { GameStrings.format("settings.versionFormat", version, build) }
}

private struct AppRelease: Identifiable, Sendable {
    let build: Int
    let version: String
    let date: String
    var id: Int { build }

    // Keep release history as data. Only the latest three entries for this
    // installed binary are rendered; older entries have no hidden UI elements.
    private static let history: [AppRelease] = [
        .init(build: 29, version: "0.6.1", date: "2026-11-03"),
        .init(build: 28, version: "0.6.0", date: "2026-11-03"),
        .init(build: 27, version: "0.5.4", date: "2026-11-03"),
        .init(build: 26, version: "0.5.3", date: "2026-11-02"),
        .init(build: 25, version: "0.5.2", date: "2026-11-02"),
        .init(build: 24, version: "0.5.1", date: "2026-11-02"),
        .init(build: 23, version: "0.5.0", date: "2026-11-02"),
        .init(build: 22, version: "0.4.3", date: "2026-11-02"),
        .init(build: 21, version: "0.4.2", date: "2026-11-02"),
        .init(build: 20, version: "0.4.1", date: "2026-11-02"),
        .init(build: 19, version: "0.4.0", date: "2026-11-02"),
        .init(build: 18, version: "0.3.0", date: "2026-11-02"),
        .init(build: 17, version: "0.2.0", date: "2026-11-01"),
        .init(build: 16, version: "0.1.3", date: "2026-11-01"),
        .init(build: 15, version: "0.1.2", date: "2026-11-01"),
        .init(build: 14, version: "0.1.1", date: "2026-11-01"),
        .init(build: 13, version: "0.1.0", date: "2026-11-01"),
        .init(build: 12, version: "0.1.0", date: "2026-11-01"),
        .init(build: 11, version: "0.1.0", date: "2026-11-01"),
        .init(build: 10, version: "0.1.0", date: "2026-10-31")
    ]
    static var recent: [AppRelease] {
        Array(history.filter { $0.build <= AppVersion.current.buildNumber }
            .sorted { $0.build > $1.build }.prefix(3))
    }

    @MainActor var localizedDate: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let value = parser.date(from: date) else { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: GameLocalization.shared.language.rawValue)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        return formatter.string(from: value)
    }
}
