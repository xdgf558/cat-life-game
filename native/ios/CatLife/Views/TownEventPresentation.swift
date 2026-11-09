import SwiftUI
import CatGameCore

@MainActor
enum TownEventAccessibility {
    static func value(_ text: String, diagnostic: String) -> String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return diagnostic }
        #endif
        return text
    }
}

@MainActor
enum TownEventPresentation {
    static func title(_ receipt: TownEventReceipt) -> String {
        GameStrings.text(TownEventCatalog.event(id: receipt.eventID)?.titleKey ?? "townEvents.letter.archivedTitle")
    }

    static func sender(_ neighborID: String) -> String {
        CommunityCatalog.neighbor(id: neighborID).map { GameStrings.text($0.nameKey) }
            ?? GameStrings.text("townEvents.letter.fromTown")
    }

    static func costs(_ choice: TownEventChoice) -> [String] {
        var lines: [String] = []
        if choice.staminaCost > 0 { lines.append(GameStrings.format("townEvents.staminaCost", choice.staminaCost)) }
        if let supply = choice.supplyCost, choice.supplyCount > 0 {
            lines.append(GameStrings.format("townEvents.supplyCost",
                GameStrings.text(SupplyCatalog.definition(for: supply).nameKey), choice.supplyCount))
        }
        if let id = choice.giftID, let gift = CommunityCatalog.gift(id: id) {
            lines.append(GameStrings.format("townEvents.giftCost", GameStrings.text(gift.nameKey), 1))
        }
        return lines
    }

    static func rewards(_ value: TownEventRewards) -> String {
        var parts: [String] = []
        if value.gold > 0 { parts.append("\(GameStrings.text("resource.gold")) +\(value.gold)") }
        let supplies: [(SupplyKind, Int)] = [(.food, value.food), (.litter, value.litter), (.toy, value.toys),
                                            (.premiumFood, value.premiumFood), (.premiumLitter, value.premiumLitter)]
        for (kind, count) in supplies where count > 0 {
            parts.append("\(GameStrings.text(SupplyCatalog.definition(for: kind).nameKey)) +\(count)")
        }
        return parts.joined(separator: " · ")
    }
}

struct TownEventRewardsView: View {
    let receipt: TownEventReceipt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var supplies: [(kind: SupplyKind, count: Int)] {
        [(.food, receipt.rewards.food), (.litter, receipt.rewards.litter), (.toy, receipt.rewards.toys),
         (.premiumFood, receipt.rewards.premiumFood), (.premiumLitter, receipt.rewards.premiumLitter)]
            .filter { $0.count > 0 }
    }
    private var hasItems: Bool { receipt.rewards.gold > 0 || !supplies.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(GameStrings.text("townEvents.received"), systemImage: "gift.fill")
                .font(.subheadline.weight(.heavy)).foregroundStyle(RoomTheme.darkMint)
            if receipt.friendshipGained > 0 {
                Label(GameStrings.format("townEvents.friendshipGain", receipt.friendshipGained), systemImage: "heart.fill")
                    .font(.subheadline.weight(.bold)).foregroundStyle(RoomTheme.friendshipDeep)
            }
            if receipt.stageAfter > receipt.stageBefore,
               let stage = CommunityCatalog.stages.first(where: { $0.level == receipt.stageAfter }) {
                Text(GameStrings.format("townEvents.stageReached", GameStrings.text(stage.nameKey)))
                    .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.friendshipDeep)
            }
            if hasItems {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                          alignment: .leading, spacing: 8) {
                    if receipt.rewards.gold > 0 {
                        reward(GameStrings.text("resource.gold"), amount: receipt.rewards.gold,
                               asset: "", symbol: "dollarsign.circle.fill", tint: RoomTheme.gold)
                    }
                    ForEach(Array(supplies.enumerated()), id: \.offset) { _, row in
                        let supply = SupplyCatalog.definition(for: row.kind)
                        reward(GameStrings.text(supply.nameKey), amount: row.count,
                               asset: supply.assetName, symbol: supply.symbol, tint: RoomTheme.darkMint)
                    }
                }
            } else {
                Text(GameStrings.text("townEvents.noReward")).font(.caption.weight(.semibold))
                    .foregroundStyle(RoomTheme.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoomTheme.paleMint.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .contain).accessibilityIdentifier("townEventActualRewards")
    }

    private func reward(_ name: String, amount: Int, asset: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            GameIcon(asset: asset, symbol: symbol, size: 27, tint: tint)
            Text("\(name) +\(amount)").font(.caption.weight(.heavy)).foregroundStyle(RoomTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TownEventLetterView: View {
    let receipt: TownEventReceipt
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                if let neighbor = CommunityCatalog.neighbor(id: receipt.neighborID) {
                    CommunityPortrait(neighbor: neighbor, size: 58)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(GameStrings.format("townEvents.letterFrom", TownEventPresentation.sender(receipt.neighborID)))
                        .font(.subheadline.weight(.heavy))
                    Text(receipt.completedAt, format: .dateTime.year().month().day())
                        .font(.caption.weight(.bold)).foregroundStyle(RoomTheme.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "pawprint.fill").font(.title2).rotationEffect(.degrees(12))
                    .foregroundStyle(RoomTheme.coral.opacity(0.7)).accessibilityHidden(true)
            }
            Text(TownEventPresentation.title(receipt)).font(.title3.weight(.heavy))
                .accessibilityAddTraits(.isHeader)
            Text(GameStrings.text(receipt.responseKey)).font(.body.weight(.medium)).lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(RoomTheme.wood.opacity(0.4))
            TownEventRewardsView(receipt: receipt)
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26).fill(RoomTheme.paper)
                .shadow(color: RoomTheme.wood.opacity(0.25), radius: 0, y: 5)
        }
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.white, lineWidth: 3))
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { appeared = true } }
        .accessibilityElement(children: .contain).accessibilityIdentifier("townEventLetter")
        .accessibilityValue(TownEventAccessibility.value(TownEventPresentation.title(receipt), diagnostic: receipt.eventID))
    }
}
