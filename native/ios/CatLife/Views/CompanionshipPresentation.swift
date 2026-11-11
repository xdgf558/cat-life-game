import SwiftUI
import CatGameCore

@MainActor
enum CompanionshipPresentation {
    static let pinnableMemories: [CatMemoryKind] = [.favoritePlay, .littleCorner, .settledAfterMove]

    static func guideKey(for memory: CatMemoryKind) -> String {
        "habit67.guide.\(memory.rawValue)"
    }

    static func memoryBody(for memory: CatMemoryKind, cat: CatState) -> String {
        if memory == .settledAfterMove, let style = CatHabitCatalog.definition(for: cat.id)?.style {
            return GameStrings.text("catMemories.settledAfterMove.body.\(style.rawValue)")
        }
        return GameStrings.text(memory.bodyKey)
    }

    static func guidance(for memory: CatMemoryKind, cat: CatState) -> String {
        if memory == .favoritePlay, cat.habits.playConfirmed,
           let preference = CatHabitCatalog.definition(for: cat.id)?.play {
            return GameStrings.format("habit67.guide.favoritePlay.known",
                                      GameStrings.text("catHabits.playConfirmed.\(preference.rawValue)"))
        }
        return GameStrings.text("habit67.guide.\(memory.rawValue).body")
    }

    static func shopGoal(for product: ShopListing, cat: CatState?) -> String? {
        guard let cat else { return nil }
        if product.kind == .furniture, let offer = ShopCatalog.furnitureOffer(id: product.id),
           CatRestPreference(kind: offer.kind) != nil {
            if cat.habits.memories.contains(where: { $0.kind == .settledAfterMove }) {
                return GameStrings.text("habit67.memoryRecorded")
            }
            return GameStrings.format("habit67.shop.restGoal", GameStrings.catName(cat))
        }
        if product.kind == .supply(.toy) {
            return GameStrings.format("habit67.shop.playGoal", GameStrings.catName(cat))
        }
        return nil
    }

    static func neighborDialogue(for cat: CatState?) -> String? {
        guard let cat, let definition = CatHabitCatalog.definition(for: cat.id) else { return nil }
        let name = GameStrings.catName(cat)
        let rest = GameStrings.text("catHabits.restConfirmed.\(definition.rest.rawValue)")
        let play = GameStrings.text("catHabits.playConfirmed.\(definition.play.rawValue)")
        switch (cat.habits.restConfirmed, cat.habits.playConfirmed) {
        case (true, true): return GameStrings.format("habit67.neighbor.both", name, rest, play)
        case (true, false): return GameStrings.format("habit67.neighbor.rest", name, rest)
        case (false, true): return GameStrings.format("habit67.neighbor.play", name, play)
        case (false, false): return GameStrings.format("habit67.neighbor.learning", name)
        }
    }
}

@MainActor
struct PinnedHabitPrompt: View {
    let store: GameStore
    let cat: CatState
    let memory: CatMemoryKind
    private var collapsed: Bool { cat.habits.pinnedHintCollapsed }
    private var completed: Bool { cat.habits.memories.contains { $0.kind == memory } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { _ = await store.setPinnedHabitHintCollapsed(catID: cat.id, collapsed: !collapsed) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill").font(.system(size: 14, weight: .bold))
                        .frame(width: 18).accessibilityHidden(true)
                    Text(GameStrings.text(CompanionshipPresentation.guideKey(for: memory)))
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: collapsed ? "chevron.down" : "chevron.up").font(.system(size: 14, weight: .bold))
                        .frame(width: 18).accessibilityHidden(true)
                }
                .font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.darkMint).frame(minHeight: 44)
            }
            .buttonStyle(.plain).disabled(store.isBusy)
            .accessibilityLabel(GameStrings.format(collapsed ? "habit67.expandGuide" : "habit67.collapseGuide",
                GameStrings.text(CompanionshipPresentation.guideKey(for: memory))))
            .accessibilityIdentifier("habitPinnedHintToggle")
            if !collapsed {
                Text(CompanionshipPresentation.guidance(for: memory, cat: cat))
                    .font(.caption).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if completed {
                    Label(GameStrings.text("habit67.memoryRecorded"), systemImage: "heart.fill")
                        .font(.caption2.weight(.bold)).foregroundStyle(RoomTheme.friendshipDeep)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6).gameCard(cornerRadius: 20)
        .accessibilityElement(children: .contain).accessibilityIdentifier("habitPinnedPrompt")
        .accessibilityValue(TownEventAccessibility.value(GameStrings.catName(cat),
            diagnostic: "\(memory.rawValue)|\(collapsed ? "collapsed" : "expanded")"))
    }
}
