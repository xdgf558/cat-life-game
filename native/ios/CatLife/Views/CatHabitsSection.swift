import SwiftUI
import CatGameCore

enum HabitRoomPromptLayout {
    static func frame(above anchor: CGRect, within bounds: CGRect, height: CGFloat) -> CGRect {
        let width = min(300, max(0, bounds.width))
        let height = min(max(0, height), max(0, bounds.height))
        let x = min(bounds.maxX - width, max(bounds.minX, anchor.midX - width / 2))
        let y = min(bounds.maxY - height, max(bounds.minY, anchor.minY - height - 10))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

@MainActor
struct CatHabitsSection: View {
    let store: GameStore
    let cat: CatState
    @State private var choosing = false
    @State private var pinning = false

    var body: some View {
        if let definition = CatHabitCatalog.definition(for: cat.id) {
            VStack(alignment: .leading, spacing: 14) {
                Label(GameStrings.text("catHabits.title"), systemImage: "pawprint.fill").font(.headline.weight(.heavy))
                    .foregroundStyle(RoomTheme.darkMint).accessibilityAddTraits(.isHeader)
                Text(GameStrings.text("catHabits.style.\(definition.style.rawValue)"))
                    .font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                habitRow("catHabits.rest", value: cat.habits.restConfirmed
                         ? GameStrings.text("catHabits.restConfirmed.\(definition.rest.rawValue)") : GameStrings.text("catHabits.learning"),
                         count: cat.habits.restClueSessionIDs.count, id: "habitRestProgress")
                habitRow("catHabits.play", value: cat.habits.playConfirmed
                         ? GameStrings.text("catHabits.playConfirmed.\(definition.play.rawValue)") : GameStrings.text("catHabits.learning"),
                         count: cat.habits.playClueSessionIDs.count, id: "habitPlayProgress")
                if let hint = latestHint {
                    Text(hint).font(.subheadline.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoomTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("habitLatestHint")
                }
                if cat.intimacy >= 75 && !(cat.habits.playConfirmed && cat.habits.restConfirmed) {
                    Text(GameStrings.text("catHabits.longtimeHint")).font(.footnote).foregroundStyle(RoomTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let receipt = cat.habits.lastRestObservation, canChoose(receipt) {
                    Button { choose(receipt) } label: {
                        Label(GameStrings.text(cat.habits.cornerFurnitureID == nil ? "catHabits.chooseCorner" : "catHabits.changeCorner"), systemImage: "house.fill")
                            .font(.subheadline.weight(.heavy)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
                    }.buttonStyle(SoftButtonStyle()).disabled(choosing || store.isBusy)
                        .accessibilityIdentifier("habitChooseCorner")
                }
                if let id = cat.habits.cornerFurnitureID, let item = store.snapshot?.inventory.furniture.first(where: { $0.id == id }) {
                    Label(GameStrings.format("catHabits.corner", GameStrings.furnitureName(item)), systemImage: "heart.fill")
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.friendshipDeep).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("habitCorner")
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 25)
                .accessibilityElement(children: .contain).accessibilityIdentifier("catHabitsSection")
            memories
        }
    }
    private var memories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(GameStrings.text("catMemories.title"), systemImage: "book.closed.fill").font(.headline.weight(.heavy))
                .foregroundStyle(RoomTheme.friendshipDeep).accessibilityAddTraits(.isHeader)
            if cat.habits.memories.isEmpty {
                Text(GameStrings.text("catMemories.empty")).font(.subheadline).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(cat.habits.memories) { memory in
                    HStack(alignment: .top, spacing: 10) {
                        GameIcon(asset: CatArtwork.asset("cat-avatar", appearance: cat.appearance), symbol: "cat.fill", size: 36)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(GameStrings.text(memory.kind.titleKey)).font(.subheadline.weight(.heavy))
                            Text(CompanionshipPresentation.memoryBody(for: memory.kind, cat: cat)).font(.caption.weight(.semibold)).foregroundStyle(RoomTheme.secondary)
                            Text(CatGrowthPresentation.date(memory.createdAt)).font(.caption2).foregroundStyle(RoomTheme.secondary)
                            if memory.kind.isPinnable {
                                Button { pin(cat.habits.pinnedMemory == memory.kind ? nil : memory.kind) } label: {
                                    Label(GameStrings.text(cat.habits.pinnedMemory == memory.kind ? "habit67.unpin" : "habit67.pin"),
                                          systemImage: cat.habits.pinnedMemory == memory.kind ? "pin.slash" : "pin")
                                        .font(.caption.weight(.bold)).frame(minHeight: 44)
                                }
                                .buttonStyle(.plain).foregroundStyle(RoomTheme.darkMint).disabled(pinning || store.isBusy)
                                .accessibilityIdentifier("habitMemoryPin_\(memory.kind.rawValue)")
                            }
                        }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(RoomTheme.friendship)
                    }.padding(12).background(RoomTheme.friendshipPaper, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityElement(children: .contain).accessibilityIdentifier("catMemory_\(memory.id)")
                }
            }
            pinnedGuide
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).gameCard(cornerRadius: 25)
            .accessibilityElement(children: .contain).accessibilityIdentifier("catMemoriesSection")
    }
    private var pinnedGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(RoomTheme.track)
            Text(GameStrings.text("habit67.pinTitle")).font(.subheadline.weight(.heavy))
                .foregroundStyle(RoomTheme.darkMint)
            if let memory = cat.habits.pinnedMemory {
                Label(GameStrings.text(CompanionshipPresentation.guideKey(for: memory)), systemImage: "pin.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("habitPinnedGuide")
                    .accessibilityValue(TownEventAccessibility.value(GameStrings.text(CompanionshipPresentation.guideKey(for: memory)),
                        diagnostic: "\(memory.rawValue)|\(cat.habits.pinnedHintCollapsed ? "collapsed" : "expanded")"))
            }
            Text(GameStrings.text("habit67.pinHint")).font(.caption).foregroundStyle(RoomTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(CompanionshipPresentation.pinnableMemories, id: \.self) { memory in
                    Button { pin(memory) } label: {
                        Label(GameStrings.text(CompanionshipPresentation.guideKey(for: memory)),
                              systemImage: cat.habits.pinnedMemory == memory ? "checkmark" : "pin")
                    }.accessibilityIdentifier("habitPin_\(memory.rawValue)")
                }
                if cat.habits.pinnedMemory != nil {
                    Button(GameStrings.text("habit67.unpin"), role: .destructive) { pin(nil) }
                        .accessibilityIdentifier("habitUnpin")
                }
            } label: {
                Label(GameStrings.text(cat.habits.pinnedMemory == nil ? "habit67.chooseGuide" : "habit67.changeGuide"), systemImage: "pin")
                    .font(.subheadline.weight(.bold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(SoftButtonStyle()).disabled(pinning || store.isBusy)
            .accessibilityIdentifier("habitGuideMenu")
        }
    }

    private func pin(_ memory: CatMemoryKind?) {
        guard !pinning else { return }
        pinning = true
        Task { _ = await store.pinHabitMemory(catID: cat.id, memory: memory); pinning = false }
    }

    private func habitRow(_ title: String, value: String, count: Int, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(GameStrings.text(title)).font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
            Text(value).font(.subheadline.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
            if count > 0 && count < 2 { Text(GameStrings.format("catHabits.clues", count)).font(.caption).foregroundStyle(RoomTheme.darkMint) }
        }.accessibilityElement(children: .combine).accessibilityIdentifier(id)
            .accessibilityValue(TownEventAccessibility.value(value, diagnostic: "\(count)/2"))
    }
    private var latestHint: String? {
        let rest = cat.habits.lastRestObservation
        let play = cat.habits.lastPlayObservation
        if let play, rest == nil || play.observedAt >= rest!.completedAt {
            return GameStrings.text("catHabits.playHint.\(play.rhythm.rawValue).\(play.matched ? "match" : "compare")")
        }
        guard let rest else { return nil }
        var text = GameStrings.text("catHabits.restHint.\(rest.kind.rawValue).\(rest.matched ? "match" : "compare")")
        if !rest.matched, let preference = CatHabitCatalog.definition(for: cat.id)?.rest,
           store.snapshot?.home.furniture.contains(where: { placement in
               store.snapshot?.inventory.furniture.contains(where: { $0.id == placement.itemID && $0.kind == preference.furnitureKind }) == true
           }) != true {
            text += "\n" + GameStrings.text("catHabits.missing.\(preference.rawValue)")
        }
        return text
    }
    private func canChoose(_ receipt: CatRestObservationReceipt) -> Bool {
        cat.habits.cornerFurnitureID != receipt.furnitureID && store.snapshot?.home.furniture.contains(where: {
            $0.itemID == receipt.furnitureID && $0.floor == receipt.location.floor && $0.position == receipt.location.position
        }) == true
    }
    private func choose(_ receipt: CatRestObservationReceipt) {
        choosing = true
        Task { _ = await store.chooseHabitCorner(catID: cat.id, observationID: receipt.id); choosing = false }
    }
}

@MainActor
struct HabitCornerOfferView: View {
    let store: GameStore
    let catID: String
    let receipt: CatRestObservationReceipt
    var body: some View {
        VStack(spacing: 7) {
            if !store.habitStudyMode {
                Text(GameStrings.text("catHabits.restHint.\(receipt.kind.rawValue).\(receipt.matched ? "match" : "compare")"))
                    .font(.caption).foregroundStyle(RoomTheme.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(GameStrings.text(store.cat?.habits.cornerFurnitureID == nil ? "catHabits.chooseCorner" : "catHabits.changeCorner"))
                .font(.caption.weight(.heavy)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(GameStrings.text("catHabits.later")) { store.dismissHabitCorner(catID: catID, observationID: receipt.id) }
                    .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("habitCornerLater")
                Button { Task { _ = await store.chooseHabitCorner(catID: catID, observationID: receipt.id) } } label: {
                    Text(GameStrings.text("catHabits.keepCorner")).font(.caption.weight(.heavy)).frame(maxWidth: .infinity)
                }.buttonStyle(MintButtonStyle()).accessibilityIdentifier("habitCornerKeep")
            }.font(.caption.weight(.bold)).disabled(store.isBusy)
        }.padding(10).gameCard(cornerRadius: 20).accessibilityElement(children: .contain).accessibilityIdentifier("habitCornerOffer")
    }
}
