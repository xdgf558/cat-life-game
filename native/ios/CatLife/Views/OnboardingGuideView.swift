import SwiftUI

@MainActor
struct OnboardingGuideView: View {
    @Bindable var store: GameStore
    let onExplore: (GameOnboardingStep) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var headingFocused: Bool

    private var locked: Bool { store.isBusy || store.saveTransferInProgress }

    var body: some View {
        if let step = store.onboarding.step {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        progress(step).id("onboardingPageTop")
                        illustration(step)
                        Text(GameStrings.text("onboarding.\(step.rawValue).title"))
                            .font(.title2.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
                            .accessibilityIdentifier("onboardingTitle")
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(1...3, id: \.self) { number in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(number)").font(.caption.weight(.heavy))
                                        .foregroundStyle(RoomTheme.darkMint)
                                        .frame(width: 25, height: 25)
                                        .background(RoomTheme.paleMint, in: Circle()).accessibilityHidden(true)
                                    Text(GameStrings.text("onboarding.\(step.rawValue).tip\(number)"))
                                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard()
                        Button { onExplore(step) } label: {
                            Label(GameStrings.text("onboarding.\(step.rawValue).explore"), systemImage: "arrow.up.right")
                                .font(.headline.weight(.heavy)).frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(MintButtonStyle()).disabled(locked)
                        .accessibilityIdentifier("onboardingExploreButton")
                        Text(GameStrings.text("onboarding.exploreHint"))
                            .font(.caption).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(GameStrings.text("onboarding.revisitHint"))
                            .font(.caption).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("onboardingGuide")
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaInset(edge: .top, spacing: 0) {
                    header.padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
                        .frame(maxWidth: .infinity)
                        .background(RoomTheme.cream)
                        .accessibilityElement(children: .contain).accessibilityIdentifier("onboardingHeader")
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 12) { previousButton; nextButton }
                        } else {
                            HStack(spacing: 12) { previousButton; nextButton }
                        }
                    }
                    .padding(16).background(RoomTheme.cream)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("onboardingFooter")
                }
                .onChange(of: step) { _, _ in
                    proxy.scrollTo("onboardingPageTop", anchor: .top)
                    headingFocused = true
                }
                .onAppear { headingFocused = true }
            }
            .background(RoomTheme.cream).fontDesign(.rounded)
            .foregroundStyle(RoomTheme.ink).tint(RoomTheme.darkMint)
            .environment(\.locale, Locale(identifier: store.language.rawValue))
            .transaction { if reduceMotion { $0.animation = nil } }
        }
    }

    @ViewBuilder private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack { Spacer(minLength: 0); skipButton }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { guideTitle; Spacer(minLength: 8); skipButton }
                VStack(alignment: .leading, spacing: 8) { guideTitle; skipButton }
            }
        }
    }

    private var guideTitle: some View {
        Label(GameStrings.text("settings.onboarding"), systemImage: "sparkles")
            .font(.subheadline.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
    }

    private var skipButton: some View {
        Button { store.playNavigationSound(); store.onboarding.finish() } label: {
            Text(GameStrings.text("onboarding.skip")).font(.subheadline.weight(.bold))
                .fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
        .buttonStyle(.plain).foregroundStyle(RoomTheme.secondary).disabled(locked)
        .accessibilityIdentifier("onboardingSkipButton")
    }

    private func progress(_ step: GameOnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(GameStrings.format("onboarding.progress", store.onboarding.stepIndex + 1,
                                    GameOnboardingStep.allCases.count))
                .font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.secondary)
                .accessibilityIdentifier("onboardingStep").accessibilityValue(step.rawValue)
            HStack(spacing: 6) {
                ForEach(GameOnboardingStep.allCases.indices, id: \.self) { index in
                    Capsule().fill(index <= store.onboarding.stepIndex ? RoomTheme.mint : RoomTheme.track)
                        .frame(height: 6)
                }
            }.accessibilityHidden(true)
        }
    }

    private func illustration(_ step: GameOnboardingStep) -> some View {
        let artwork: (asset: String, symbol: String) = switch step {
        case .care: ("cat-avatar", "pawprint.fill")
        case .work: ("job-flyer-cartoon", "briefcase.fill")
        case .supplies: ("icon-shop", "basket.fill")
        case .tasks: ("town-board-cartoon", "checklist")
        case .town: ("town-street-cartoon", "map.fill")
        }
        return GameIcon(asset: artwork.asset, symbol: artwork.symbol, size: 116, tint: RoomTheme.darkMint)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(RoomTheme.paleMint.opacity(0.65), in: RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white, lineWidth: 2))
            .accessibilityHidden(true)
    }

    private var previousButton: some View {
        Button { store.playNavigationSound(); store.onboarding.previous() } label: {
            Text(GameStrings.text("onboarding.previous")).font(.subheadline.weight(.heavy))
                .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(SoftButtonStyle()).disabled(locked || store.onboarding.stepIndex == 0)
        .opacity(store.onboarding.stepIndex == 0 ? 0.45 : 1)
        .accessibilityIdentifier("onboardingPreviousButton")
    }

    private var nextButton: some View {
        Button { store.playNavigationSound(); store.onboarding.next() } label: {
            Text(GameStrings.text(store.onboarding.step == .town ? "onboarding.complete" : "onboarding.next"))
                .font(.subheadline.weight(.heavy)).frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(SoftButtonStyle()).disabled(locked)
        .accessibilityIdentifier("onboardingNextButton")
    }
}

@MainActor
struct GuideResumeBar: View {
    @Bindable var store: GameStore

    var body: some View {
        if store.onboarding.isActive {
            Button { store.playNavigationSound(); store.onboarding.show() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").accessibilityHidden(true)
                    Text(GameStrings.format("onboarding.resume", store.onboarding.stepIndex + 1,
                                            GameOnboardingStep.allCases.count))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
                .padding(.horizontal, 10).padding(.vertical, 8).frame(minHeight: 44)
                .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RoomTheme.paleMint, lineWidth: 2))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(store.isBusy || store.saveTransferInProgress)
            .accessibilityLabel(GameStrings.format("onboarding.resumeAccessibility", store.onboarding.stepIndex + 1,
                                                  GameOnboardingStep.allCases.count))
            .accessibilityIdentifier("onboardingResumeButton")
        }
    }
}
