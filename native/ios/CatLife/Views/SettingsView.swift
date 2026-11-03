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

    private enum Destination: Hashable { case homeName, updates, audio }

    var body: some View {
        NavigationStack(path: $path) {
            page {
                GamePageHeading(title: GameStrings.text("settings.title"),
                                subtitle: GameStrings.text("redesign.settings.subtitle"),
                                symbol: "gearshape.fill", tint: RoomTheme.secondary,
                                background: RoomTheme.chipBg)
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("settings.audio")
                    VStack(spacing: 18) {
                        audioControl(.music, compact: true)
                        audioControl(.effects, compact: true)
                        NavigationLink(value: Destination.audio) {
                            HStack {
                                Text(GameStrings.text("redesign.settings.audioDetails"))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(RoomTheme.darkMint).frame(minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("settingsAudioRow")
                    }
                    .padding(16).gameCard()
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("settings.language").accessibilityIdentifier("settingsLanguageTitle")
                    languageSegments
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("redesign.settings.homeGroup")
                    VStack(spacing: 0) {
                        NavigationLink(value: Destination.homeName) {
                            settingRow(symbol: "house.fill", title: "settings.homeName",
                                       value: store.homeDisplayName, tint: RoomTheme.mint)
                        }
                        .accessibilityIdentifier("settingsHomeNameRow")
                        Divider().overlay(RoomTheme.wood.opacity(0.3)).padding(.leading, 66)
                        NavigationLink(value: Destination.updates) {
                            settingRow(symbol: "clock.arrow.circlepath", title: "settings.updates",
                                       value: AppVersion.current.display, tint: RoomTheme.gold)
                        }
                        .accessibilityIdentifier("settingsUpdatesRow")
                    }
                    .buttonStyle(.plain).gameCard()
                }
                HStack(spacing: 8) {
                    Image(systemName: store.hasSaveFailure ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                        .foregroundStyle(store.hasSaveFailure ? RoomTheme.coral : RoomTheme.darkMint)
                    Text(GameStrings.text(store.hasSaveFailure ? "save.writeTitle" : "redesign.settings.localSave"))
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(RoomTheme.secondary)
                    Spacer(minLength: 0)
                    if store.hasSaveFailure {
                        Button(GameStrings.text("save.retry")) { store.retrySaving() }
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(RoomTheme.darkMint)
                            .frame(minHeight: 44).disabled(store.isBusy)
                            .accessibilityIdentifier("settingsRetrySaveButton")
                    }
                }
                .accessibilityIdentifier("settingsSaveState")
                Text(GameStrings.text("home.name") + " · " + AppVersion.current.localizedDisplay)
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(RoomTheme.secondary)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .padding(.bottom, 12)
            }
            .accessibilityIdentifier("settingsScroll")
            .onAppear { loadAudioDraft() }
            .onDisappear { saveAudioDraft() }
            .navigationTitle(GameStrings.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(path.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: Destination.self) { destination in
                Group {
                    switch destination {
                    case .homeName: homeNamePage
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
        .fontDesign(.rounded)
        .foregroundStyle(RoomTheme.ink)
        .tint(RoomTheme.darkMint)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: store.language.rawValue))
        #if DEBUG
        .overlay(alignment: .topLeading) { AudioDiagnosticsView(store: store) }
        #endif
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24, content: content)
                .padding(16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(RoomTheme.cream.ignoresSafeArea())
        .toolbarBackground(RoomTheme.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(GameStrings.text(key)).font(.system(size: 13, weight: .heavy))
            .foregroundStyle(RoomTheme.secondary).padding(.leading, 4)
    }

    private func settingRow(symbol: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            GameIconTile(symbol: symbol, tint: tint, background: tint.opacity(0.15), size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(GameStrings.text(title)).font(.system(size: 15, weight: .heavy))
                Text(value).font(.system(size: 11, weight: .bold)).foregroundStyle(RoomTheme.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
                .foregroundStyle(RoomTheme.secondary).accessibilityHidden(true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }

    private var languageSegments: some View {
        HStack(spacing: 4) {
            ForEach(GameLanguage.allCases, id: \.self) { language in
                Button { store.setLanguage(language) } label: {
                    Text(nativeName(language)).font(.system(size: 12, weight: .heavy))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(language == store.language ? RoomTheme.darkMint : RoomTheme.secondary)
                        .background(language == store.language ? RoomTheme.paper : .clear, in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(store.isBusy)
                .accessibilityIdentifier("languageOption_" + language.rawValue)
                .accessibilityAddTraits(language == store.language ? .isSelected : [])
                #if DEBUG
                .accessibilityValue(ProcessInfo.processInfo.arguments.contains("--ui-testing")
                    ? (language == store.language ? "selected" : "unselected") : "")
                #endif
            }
        }
        .padding(4).background(RoomTheme.chipBg, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsLanguageSegments")
    }

    private func audioControl(_ channel: SettingsAudioControl.Channel, compact: Bool = false) -> some View {
        SettingsAudioControl(channel: channel, compact: compact, settings: $audioDraft,
                             onChange: { hasUnsubmittedAudioChanges = true },
                             onCommit: saveAudioDraft)
    }

    private func loadAudioDraft() {
        guard !hasUnsubmittedAudioChanges, !isSavingAudio else { return }
        audioDraft = store.pendingAudioSettings ?? store.audioSettings
        hasLoadedAudioDraft = true
    }

    private var audioPage: some View {
        page {
            Text(GameStrings.text("audio.hint"))
                .font(.subheadline).foregroundStyle(RoomTheme.secondary)

            VStack(spacing: 18) {
                audioControl(.music)
                audioControl(.effects)
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
            loadAudioDraft()
        }
        .onDisappear { saveAudioDraft() }
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
