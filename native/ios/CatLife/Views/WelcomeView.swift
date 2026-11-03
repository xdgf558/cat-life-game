import SwiftUI

/// A session entry screen. Loading and saving belong to GameStore;
/// entering the home never creates or reloads a save.
@MainActor
struct WelcomeView: View {
    @Bindable var store: GameStore
    #if DEBUG
    var releaseTestLoad: (() -> Void)?
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 38

    private var ready: Bool { !store.isLoading && !store.loadFailed && store.snapshot != nil }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
    private var percentage: String { "\(Int((store.startupProgress * 100).rounded()))%" }

    var body: some View {
        ZStack {
            artwork.ignoresSafeArea()
            GeometryReader { geometry in
                let fullHeight = geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
                let compact = fullHeight < 740
                let scrolls = dynamicTypeSize.isAccessibilitySize || geometry.size.width > geometry.size.height
                ScrollView {
                    VStack(spacing: 0) {
                        heading(compact: compact)
                            .padding(.top, max(4, fullHeight * (compact ? 0.035 : 0.065) - geometry.safeAreaInsets.top))
                        Spacer(minLength: scrolls ? 180 : 24)
                            .frame(maxWidth: .infinity)
                            // The foreground scroll view otherwise hides the
                            // full-bleed image from VoiceOver's reading order.
                            .accessibilityRepresentation {
                                Image("welcome-arrival")
                                    .accessibilityLabel(GameStrings.text("welcome.hero"))
                                    .accessibilityIdentifier("welcomeHero")
                            }
                        entry(compact: compact)
                            .padding(.bottom, compact ? 16 : 12)
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, compact ? 25 : 28)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .accessibilityIdentifier("welcomeScreen")
    }

    private var artwork: some View {
        GeometryReader { geometry in
            let name = geometry.size.width / geometry.size.height > 0.5
                ? "welcome-arrival-compact" : "welcome-arrival"
            ZStack {
                // Separate wide-phone art preserves full-body proportions on
                // SE. The soft extension is only needed for wider viewports.
                Image(name)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped().blur(radius: 22)
                    .accessibilityHidden(true)
                Image(name)
                    .resizable().scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)
            }
            .clipped()
        }
    }

    private func heading(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 9) {
            Label(GameStrings.text("welcome.kicker"), systemImage: "pawprint.fill")
                .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(RoomTheme.darkMint)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(RoomTheme.paleMint.opacity(0.85), in: Capsule())

            Text(GameStrings.text("home.name"))
                .font(.system(size: compact ? titleSize * 0.91 : titleSize, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(RoomTheme.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.75)
                .accessibilityIdentifier("welcomeTitle")

            Text(GameStrings.text("welcome.subtitle"))
                .font(.system(size: compact ? 13 : 14, weight: .medium, design: .rounded))
                .foregroundStyle(RoomTheme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func entry(compact: Bool) -> some View {
        VStack(spacing: compact ? 9 : 10) {
            VStack(spacing: 7) {
                status
                ProgressView(value: store.startupProgress, total: 1)
                    .tint(RoomTheme.mint)
                    .scaleEffect(x: 1, y: 1.8, anchor: .center)
                    .frame(height: 8)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: store.startupProgress)
                    .accessibilityLabel(GameStrings.text("welcome.progress"))
                    .accessibilityValue(percentage)
                    .accessibilityIdentifier("welcomeProgress")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(store.loadFailed || store.startupNotice != nil ? RoomTheme.paper.opacity(0.94) : .clear,
                        in: RoundedRectangle(cornerRadius: 13))

            if store.loadFailed {
                Button {
                    Task { await store.load() }
                } label: {
                    Label(GameStrings.text("common.retry"), systemImage: "arrow.clockwise")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 26)
                }
                .buttonStyle(MintButtonStyle())
                .accessibilityIdentifier("welcomeRetryButton")
            } else {
                Button { store.enterHome() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "house.fill").font(.system(size: 23, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(GameStrings.text("welcome.enter"))
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.right").font(.body.weight(.bold))
                            .accessibilityHidden(true)
                    }
                    .font(.system(size: compact ? 20 : 22, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: compact ? 24 : 28)
                }
                .buttonStyle(MintButtonStyle())
                .disabled(!ready)
                .opacity(ready ? 1 : 0.6)
                .accessibilityIdentifier("welcomeEnterButton")
            }

            #if DEBUG
            if let releaseTestLoad {
                // Only present in the explicitly held, isolated UI test.
                Button("Release test load", action: releaseTestLoad)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcomeReleaseLoadButton")
            }
            #endif

            Text(GameStrings.format("welcome.version", version))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(RoomTheme.secondary)
                .padding(.top, compact ? 7 : 10)
                .accessibilityIdentifier("welcomeVersion")
                .accessibilityValue("\(version) (\(build))")
        }
    }

    @ViewBuilder private var status: some View {
        if store.loadFailed {
            VStack(spacing: 6) {
                Label(GameStrings.text(store.needsNewerVersion ? "save.newerVersionTitle" : "save.loadTitle"), systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text(GameStrings.text(store.needsNewerVersion ? "save.newerVersionBody" : "save.loadBody"))
                    .font(.footnote)
            }
            .foregroundStyle(RoomTheme.secondary)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("welcomeLoadError")
        } else if store.isLoading {
            HStack(spacing: 8) {
                Text(GameStrings.text(store.startupPhase))
                Spacer(minLength: 4)
                Text(percentage).monospacedDigit()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(RoomTheme.darkMint)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("welcomeLoading")
        } else {
            Label(store.startupNotice ?? GameStrings.text("welcome.ready"),
                  systemImage: store.startupNotice == nil ? "checkmark.circle.fill" : "bell.badge.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoomTheme.darkMint)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("welcomeNotice")
        }
    }
}
