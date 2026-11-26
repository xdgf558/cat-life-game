import SwiftUI
import CatGameCore

struct DiarySheetView: View {
    @Bindable var store: DiaryAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: PhotoCategory?
    @State private var inspectingPhoto: PhotoDef?

    private var filteredPhotos: [PhotoDef] {
        guard let category = selectedCategory else { return DiaryCatalog.photos }
        return DiaryCatalog.photos.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    scrapbookHeaderCard
                    categoryFilterBar

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 102), spacing: 11)], spacing: 14) {
                        ForEach(Array(filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                            polaroidGridCard(photo, index: index)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(16)
            }
            .background(RoomTheme.cream.ignoresSafeArea())
            .navigationTitle(GameStrings.text("diary.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(GameStrings.text("common.done")) { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(RoomTheme.coralDeep)
                }
            }
            .sheet(item: $inspectingPhoto) { photo in
                PhotoDetailSheet(
                    photo: photo,
                    capturedAt: store.state.diary.photoDates[photo.id]
                )
            }
        }
    }

    private var scrapbookHeaderCard: some View {
        let progress = store.photoProgress
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(GameStrings.format("diary.daysTogether", store.daysTogether))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(RoomTheme.ink)
                    Text(GameStrings.format("diary.progressFormat", progress.got, progress.total))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(RoomTheme.coralDeep)
                }
                Spacer()
                AssetOrSymbol(asset: "ui_camera", symbol: "camera.fill", size: 32, tint: RoomTheme.coral)
            }

            GeometryReader { bar in
                ZStack(alignment: .leading) {
                    Capsule().fill(RoomTheme.track)
                    Capsule()
                        .fill(LinearGradient(colors: [RoomTheme.coral, RoomTheme.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: bar.size.width * min(1, CGFloat(progress.got) / CGFloat(max(1, progress.total))))
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(RoomTheme.wood, style: StrokeStyle(lineWidth: 1.4, dash: [6, 4]))
        )
        .shadow(color: RoomTheme.ink.opacity(0.08), radius: 6, y: 3)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(title: GameStrings.text("common.all"), active: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(PhotoCategory.allCases, id: \.self) { category in
                    filterPill(title: GameStrings.photoCategoryName(category), active: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func filterPill(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(active ? .white : RoomTheme.ink)
                .padding(.horizontal, 15)
                .padding(.vertical, 7.5)
                .background(active ? RoomTheme.coral : RoomTheme.paper, in: Capsule())
                .overlay(Capsule().stroke(active ? .clear : RoomTheme.wood.opacity(0.8), lineWidth: 1.1))
                .shadow(color: active ? RoomTheme.coralDeep.opacity(0.45) : .clear, radius: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func polaroidGridCard(_ photo: PhotoDef, index: Int) -> some View {
        let unlocked = store.state.diary.photos.contains(photo.id)
        let tilt: Double = unlocked ? (index.isMultiple(of: 2) ? -1.1 : 1.1) : 0

        return Button {
            if unlocked { inspectingPhoto = photo }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    if unlocked {
                        Image(photo.id)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 82)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(RoomTheme.track.opacity(0.75))
                            .frame(height: 82)
                            .overlay {
                                Image(systemName: "camera.aperture")
                                    .font(.system(size: 20))
                                    .foregroundStyle(RoomTheme.secondary.opacity(0.38))
                            }
                    }

                    if unlocked && photo.isRare {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(RoomTheme.gold, in: Circle())
                            .padding(4)
                    }
                }

                // Authentic thick Polaroid bottom caption chin
                Text(unlocked ? GameStrings.photoTitle(photo.id) : GameStrings.text("diary.lockedHint"))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(unlocked ? RoomTheme.ink : RoomTheme.secondary.opacity(0.75))
                    .lineLimit(1)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 5)
            .background(unlocked ? Color.white : RoomTheme.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(unlocked && photo.isRare ? RoomTheme.gold.opacity(0.85) : RoomTheme.wood.opacity(0.55), lineWidth: unlocked && photo.isRare ? 1.5 : 1)
            )
            .shadow(color: RoomTheme.ink.opacity(unlocked ? 0.13 : 0.04), radius: unlocked ? 5 : 2, y: unlocked ? 3 : 1)
            .rotationEffect(.degrees(tilt))
        }
        .buttonStyle(CraftIconBadgeButtonStyle())
        .disabled(!unlocked)
    }
}

private struct PhotoDetailSheet: View {
    let photo: PhotoDef
    let capturedAt: Int64?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 10)
                ZStack(alignment: .top) {
                    VStack(spacing: 14) {
                        Image(photo.id)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(RoomTheme.wood.opacity(0.35), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(GameStrings.photoTitle(photo.id))
                                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                                    .foregroundStyle(RoomTheme.ink)
                                if photo.isRare {
                                    Text(GameStrings.text("diary.rareBadge"))
                                        .font(.system(size: 10.5, weight: .black))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(RoomTheme.gold, in: Capsule())
                                }
                                Spacer()
                            }

                            Text(GameStrings.photoCaption(photo.id))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(RoomTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let capturedAt {
                                Text(DayClock.date(fromEpochMs: capturedAt).formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RoomTheme.secondary.opacity(0.7))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(RoomTheme.wood.opacity(0.45), lineWidth: 1))
                    .shadow(color: RoomTheme.ink.opacity(0.18), radius: 14, y: 8)

                    WashiTapeStrip(tint: RoomTheme.coral.opacity(0.48), width: 64)
                        .offset(y: -6)
                }
                Spacer()
            }
            .padding(22)
            .background(RoomTheme.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(GameStrings.text("common.close")) { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(RoomTheme.coralDeep)
                }
            }
        }
    }
}
