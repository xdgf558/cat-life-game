import SwiftUI
import SpriteKit
import UIKit
import CatGameCore

@MainActor
struct CatPlayTogetherView: View {
    let store: GameStore
    let session: CatPlaySession
    @State private var controller: CatPlayTogetherController?

    var body: some View {
        Group {
            if let controller { CatPlayTogetherContent(store: store, controller: controller) }
            else { ProgressView(GameStrings.text("catHabits.playOpened")).frame(maxWidth: .infinity, maxHeight: .infinity).background(RoomTheme.cream) }
        }
        .task {
            if controller == nil { controller = CatPlayTogetherController(store: store, session: session) }
        }
    }
}

@MainActor
private struct CatPlayTogetherContent: View {
    let store: GameStore
    let controller: CatPlayTogetherController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var cat: CatState? { store.snapshot?.cats.first { $0.id == controller.session.catID } }
    private var effectiveReducedMotion: Bool {
        #if DEBUG
        reduceMotion || (ProcessInfo.processInfo.arguments.contains("--ui-testing")
                         && ProcessInfo.processInfo.arguments.contains("--reduce-motion-test"))
        #else
        reduceMotion
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let receipt = controller.result {
                    if store.habitStudyMode && !controller.continuedStudy {
                        VStack(spacing: 18) {
                            Image(systemName: "pawprint.fill").font(.largeTitle).foregroundStyle(RoomTheme.mint)
                            Text(GameStrings.text("catHabits.studyQuestion")).font(.headline.weight(.heavy))
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            Button { controller.continuedStudy = true } label: {
                                Text(GameStrings.text("catHabits.continue")).font(.headline).frame(maxWidth: .infinity)
                            }.buttonStyle(MintButtonStyle()).accessibilityIdentifier("playTogetherContinue")
                        }.padding(24).gameCard()
                    } else { result(receipt) }
                } else if controller.ending {
                    ProgressView(GameStrings.text("catHabits.saving")).padding(30)
                } else {
                    stage
                    if !store.habitStudyMode || effectiveReducedMotion {
                        Text(GameStrings.text("catHabits.motion.\(controller.phase)"))
                            .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.darkMint)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("playTogetherReaction")
                    }
                    Text(GameStrings.text("catHabits.dragHint")).font(.caption).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if controller.session.isTutorial {
                        Text(GameStrings.text(tutorialHint)).font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoomTheme.rewardPaper, in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityIdentifier("playTogetherTutorialHint")
                            .accessibilityValue(TownEventAccessibility.value(GameStrings.text(tutorialHint),
                                diagnostic: String(store.snapshot?.catPlay.tutorialRhythms.count ?? 0)))
                    }
                    Text(GameStrings.text(controller.current.paidAt != nil ? "catHabits.paidHint"
                                          : controller.session.isTutorial ? "catHabits.freeHint" : "catHabits.costHint"))
                        .font(.footnote).foregroundStyle(RoomTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    if controller.working { ProgressView(GameStrings.text("catHabits.saving")) }
                }
                if controller.failed || store.hasSaveFailure {
                    VStack(spacing: 12) {
                        Text(GameStrings.text("catHabits.saveFailed")).font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.coralDeep)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(GameStrings.text("save.retry")) { controller.retry(); store.retrySaving() }.buttonStyle(SoftButtonStyle())
                        Button(GameStrings.text("catGrowth.goHome")) { close() }.buttonStyle(SoftButtonStyle())
                    }.padding(16).gameCard().accessibilityIdentifier("playTogetherSaveFailed")
                }
            }.padding(16).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("playTogetherScroll")
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                if controller.result == nil && !controller.ending {
                    if dynamicTypeSize.isAccessibilitySize { VStack(spacing: 8) { controls } }
                    else { HStack(spacing: 12) { controls } }
                }
                Button {
                    if controller.result != nil { close() } else { controller.finish() }
                } label: {
                    Text(GameStrings.text(controller.result != nil ? "catGrowth.goHome" : "catHabits.finish"))
                        .font(.headline.weight(.heavy)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
                }.buttonStyle(MintButtonStyle()).disabled(controller.ending && controller.result == nil && !store.hasSaveFailure)
                    .accessibilityIdentifier("playTogetherFinishButton")
            }
            .padding(16).background(RoomTheme.cream).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityElement(children: .contain).accessibilityIdentifier("playTogetherActionBar")
        }
        .background(RoomTheme.cream.ignoresSafeArea()).fontDesign(.rounded).foregroundStyle(RoomTheme.ink)
        .environment(\.locale, Locale(identifier: store.language.rawValue)).interactiveDismissDisabled(true)
        .saveRecoveryAlert(store: store)
        .task {
            controller.scene.reducedMotion = effectiveReducedMotion
            while !Task.isCancelled && controller.result == nil {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
                controller.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in controller.setVisible(phase == .active) }
        .onChange(of: effectiveReducedMotion) { _, value in controller.scene.reducedMotion = value }
        .onChange(of: controller.phase) { _, value in
            if UIAccessibility.isVoiceOverRunning && ["pouncing", "waiting", "tooFast"].contains(value) {
                UIAccessibility.post(notification: .announcement, argument: GameStrings.text("catHabits.motion.\(value)"))
            }
        }
        .onDisappear { controller.finish() }
    }
    private var header: some View {
        HStack(spacing: 12) {
            Text(GameStrings.text("catHabits.playTogether")).font(.title2.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let cat { GameIcon(asset: CatArtwork.asset("cat-avatar", appearance: cat.appearance), symbol: "cat.fill", size: 32) }
            Text(controller.result == nil ? GameStrings.format("catHabits.seconds", Int(ceil(controller.remaining)))
                 : GameStrings.text("catHabits.resultTitle")).font(.subheadline.weight(.heavy)).monospacedDigit()
        }.padding(16).background(RoomTheme.cream).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
    private var stage: some View {
        GeometryReader { geometry in
            CatPlayCanvas(scene: controller.scene, size: geometry.size, active: scenePhase == .active)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 280)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 28)).clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white, lineWidth: 3))
        .accessibilityElement(children: .ignore).accessibilityLabel(GameStrings.text("catHabits.stageAccessibility"))
        .accessibilityValue(TownEventAccessibility.value(GameStrings.text("catHabits.motion.\(controller.phase)"),
            diagnostic: "\(controller.phase)|\(controller.scene.pounces)|\(controller.current.effects.toysSpent)|\(controller.current.observedRhythms.count)"))
        .accessibilityIdentifier("playTogetherStage")
        .accessibilityAction(named: Text(GameStrings.text("catHabits.control.slowMove"))) { controller.control(.slowMove) }
        .accessibilityAction(named: Text(GameStrings.text("catHabits.control.moveAndPause"))) { controller.control(.moveAndPause) }
    }
    @ViewBuilder private var controls: some View {
        ForEach(CatPlayRhythm.allCases, id: \.self) { rhythm in
            Button { controller.control(rhythm) } label: {
                Text(GameStrings.text("catHabits.control.\(rhythm.rawValue)"))
                    .font(.subheadline.weight(.heavy)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(SoftButtonStyle()).disabled(controller.phase == "pouncing")
                .accessibilityIdentifier("playTogether_\(rhythm.rawValue)")
        }
    }
    private var tutorialHint: String {
        let tried = store.snapshot?.catPlay.tutorialRhythms ?? []
        if !tried.contains(.slowMove) { return "catHabits.tutorial.slow" }
        if !tried.contains(.moveAndPause) { return "catHabits.tutorial.pause" }
        return "catHabits.tutorial.done"
    }
    @ViewBuilder private func result(_ receipt: CatPlayReceipt) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(GameStrings.text("catHabits.resultTitle"), systemImage: "heart.fill").font(.title3.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
            if receipt.session.isTutorial {
                Text(GameStrings.text("catHabits.freeHint")).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            } else if receipt.session.paidAt == nil {
                Text(GameStrings.text("catHabits.noSpend")).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            } else {
                Text(GameStrings.format("catHabits.toysSpent", receipt.session.effects.toysSpent)).font(.headline)
                    .accessibilityIdentifier("playTogetherToyCost").accessibilityValue(String(receipt.session.effects.toysSpent))
                ForEach(effectLines(receipt.session.effects), id: \.self) { Text($0).font(.subheadline.weight(.bold)) }
            }
            if receipt.session.isTutorial && store.snapshot?.catPlay.tutorialCompleted == true {
                Text(GameStrings.text("catHabits.restNextHint")).font(.subheadline).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).gameCard()
            .accessibilityElement(children: .contain).accessibilityIdentifier("playTogetherResult")
            .accessibilityValue(TownEventAccessibility.value(GameStrings.text("catHabits.resultTitle"),
                diagnostic: "\(receipt.catID)|\(receipt.session.observedRhythms.count)|\(receipt.session.effects.toysSpent)"))
        if let cat { CatHabitsSection(store: store, cat: cat) }
    }
    private func effectLines(_ value: CatPlayEffects) -> [String] {
        [("catHabits.catMood", value.catMood), ("stat.bond", value.intimacy), ("catHabits.playerMood", value.playerMood)]
            .filter { $0.1 > 0 }.map { GameStrings.text($0.0) + " +\($0.1)" }
            + (value.energySpent > 0 ? [GameStrings.text("rest.energy") + " −\(value.energySpent)"] : [])
    }
    private func close() {
        controller.finish(); store.isShowingPlayTogether = false
        store.isShowingSettings = false; store.inspectedCatID = nil; store.activeSheet = nil
    }
}

@MainActor
private struct CatPlayCanvas: UIViewRepresentable {
    let scene: CatPlayTogetherScene
    let size: CGSize
    let active: Bool
    func makeUIView(context: Context) -> SKView {
        let view = SKView(); view.backgroundColor = .clear; view.preferredFramesPerSecond = 30
        view.isAccessibilityElement = false; view.accessibilityElementsHidden = true
        scene.size = size; view.presentScene(scene); view.isPaused = !active
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        if abs(scene.size.width - size.width) > 0.01 || abs(scene.size.height - size.height) > 0.01 { scene.size = size }
        view.isPaused = !active; scene.isPaused = !active
    }
    static func dismantleUIView(_ view: SKView, coordinator: ()) { view.isPaused = true }
}
