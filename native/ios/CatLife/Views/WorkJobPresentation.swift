import SwiftUI
import CatGameCore

@MainActor
enum WorkJobPresentation {
    static func name(_ id: String) -> String {
        GameStrings.text(WorkCatalog.job(id: id) == nil ? "work.name" : "jobs.\(id).name")
    }

    static func duration(_ seconds: Int) -> String {
        seconds % 60 == 0 ? GameStrings.format("work.durationMinutes", seconds / 60)
            : GameStrings.format("work.durationSeconds", seconds / 60, seconds % 60)
    }

    static func symbol(_ id: String) -> String {
        switch id {
        case "job_store": "storefront.fill"
        case "job_petshop": "pawprint.fill"
        case "job_it_engineer": "laptopcomputer"
        case "job_cat_cafe_manager": "cup.and.saucer.fill"
        default: "newspaper.fill"
        }
    }
}

/// A bounded two-column career tile shared by the quick picker and searchable directory.
@MainActor
struct WorkCareerCard: View {
    let job: WorkJob
    var quote: WorkQuote? = nil
    let selected: Bool
    let unlocked: Bool
    let action: () -> Void

    private var accent: Color {
        switch job.id {
        case "job_store": RoomTheme.gold
        case "job_petshop": RoomTheme.coral
        case "job_it_engineer": RoomTheme.sky
        case "job_cat_cafe_manager": RoomTheme.lilac
        default: RoomTheme.darkMint
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    GameIconTile(symbol: unlocked ? WorkJobPresentation.symbol(job.id) : "lock.fill",
                                 tint: unlocked ? accent : RoomTheme.secondary,
                                 background: unlocked ? accent.opacity(0.16) : RoomTheme.track, size: 46)
                    Spacer(minLength: 0)
                    if selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(RoomTheme.mint)
                            .font(.system(size: 19, weight: .bold)).accessibilityHidden(true)
                    }
                }
                Text(WorkJobPresentation.name(job.id)).font(.system(size: 16, weight: .heavy))
                    .lineLimit(2).minimumScaleFactor(0.8).frame(minHeight: 38, alignment: .topLeading)
                    .accessibilityIdentifier("careerJobName_\(job.id)")
                HStack(spacing: 5) {
                    Label("\(job.goldReward)", systemImage: "dollarsign.circle.fill")
                        .foregroundStyle(RoomTheme.gold)
                    Text(WorkJobPresentation.duration(quote?.durationSeconds ?? job.durationMinutes * 60))
                        .foregroundStyle(RoomTheme.secondary)
                }
                .font(.system(size: 12, weight: .heavy)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                Text(unlocked
                     ? GameStrings.format("redesign.work.costExp", quote?.staminaCost ?? job.staminaCost, job.expReward)
                     : GameStrings.format("career.unlock", job.unlockLevel))
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(RoomTheme.secondary)
                    .lineLimit(2).frame(minHeight: 27, alignment: .topLeading)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .gameCard(cornerRadius: 24)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(selected ? RoomTheme.mint : .clear, lineWidth: 3))
            .opacity(unlocked ? 1 : 0.6)
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(WorkJobPresentation.name(job.id))
        .accessibilityValue(unlocked
            ? GameStrings.text(selected ? "career.selected" : "career.available")
            : GameStrings.format("career.unlock", job.unlockLevel))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
