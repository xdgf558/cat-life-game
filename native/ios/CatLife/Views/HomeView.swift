import SwiftUI
import CatGameCore

struct HomeView: View {
    @Bindable var store: DiaryAppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var catPressed = false
    @State private var idleBreathe = false
    @State private var heartBursts: [FloatingHeart] = []

    private var cat: DiaryCatState { store.state.primaryCat }
    private var stage: CatGrowthStage { CatGrowthStage.stage(forLevel: cat.level) }
    private var tutorialStep: TutorialStep { store.state.tutorialStep }
    private var isTutorial: Bool { store.state.tutorialActive }

    private var roomFurniture: [PlacedFurniture] {
        store.state.home.layout
            .filter { $0.room == store.activeRoom }
            .sorted { lhs, rhs in
                let lLayer = layerOrder(DiaryCatalog.furnitureDef(lhs.id)?.layer ?? .floor)
                let rLayer = layerOrder(DiaryCatalog.furnitureDef(rhs.id)?.layer ?? .floor)
                if lLayer != rLayer { return lLayer < rLayer }
                return lhs.bottom < rhs.bottom
            }
    }

    private func layerOrder(_ layer: FurnitureLayer) -> Int {
        switch layer { case .flat: 0; case .wall: 1; case .floor: 2 }
    }

    var body: some View {
        GeometryReader { geo in
            let fullSize = CGSize(
                width: geo.size.width,
                height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            )
            let frame = SceneCanvasLayout.sceneFrame(in: fullSize, maxCropTop: 0.16)

            ZStack {
                RoomTheme.edgeBackdrop(for: store.sceneLight).ignoresSafeArea()

                // Precision-framed hand-painted room canvas
                ZStack {
                    Image(store.sceneLight.backgroundAssetName(base: store.activeRoom.backgroundBaseKey))
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    // Subtle atmospheric vignette in night/rain
                    if store.sceneLight == .night {
                        RadialGradient(
                            colors: [.clear, Color.black.opacity(0.24)],
                            center: .center,
                            startRadius: frame.width * 0.28,
                            endRadius: frame.height * 0.62
                        )
                        .allowsHitTesting(false)
                    } else if store.sceneLight == .rain && !reduceMotion {
                        RainShimmerOverlay()
                            .allowsHitTesting(false)
                    }

                    // Placed furniture grounded with soft shadows
                    ForEach(roomFurniture) { placed in
                        let size = furnitureSize(placed.id, frameWidth: frame.width)
                        let px = frame.minX + frame.width * placed.x
                        let py = frame.minY + frame.height * placed.bottom - size * 0.42
                        ZStack {
                            if (DiaryCatalog.furnitureDef(placed.id)?.layer ?? .floor) == .floor {
                                Ellipse()
                                    .fill(RoomTheme.ink.opacity(0.16))
                                    .frame(width: size * 0.72, height: size * 0.16)
                                    .blur(radius: 5)
                                    .offset(y: size * 0.40)
                            }
                            Image(placed.id.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size, height: size)
                                .scaleEffect(x: placed.flip ? -1 : 1, y: 1)
                        }
                        .position(x: px, y: py)
                        .allowsHitTesting(false)
                    }

                    // Offline note pin on wall
                    if store.offlineNoteID != nil, !isTutorial, store.activeRoom == .livingroom {
                        Button {
                            store.toggleOfflineNote()
                        } label: {
                            AssetOrSymbol(asset: "ui_note_pin", symbol: "note.text", size: 42, tint: RoomTheme.coral)
                                .shadow(color: RoomTheme.ink.opacity(0.25), radius: 5, y: 3)
                        }
                        .buttonStyle(CraftIconBadgeButtonStyle())
                        .position(
                            x: frame.minX + frame.width * 0.86,
                            y: frame.minY + frame.height * 0.35
                        )
                        .accessibilityLabel(GameStrings.text("home.offlineNoteTitle"))
                    }

                    // Interactive Xiaoju grounded on the wooden floor
                    catActorView(in: frame)
                }
                .ignoresSafeArea()

                // Refined Floating Chrome (respecting iPhone safe area)
                VStack(spacing: 10) {
                    topChrome

                    if isTutorial {
                        tutorialCoachPill
                    }

                    if store.showingOfflineNote, let noteID = store.offlineNoteID {
                        offlineNoteCard(noteID)
                    }

                    Spacer()

                    if !isTutorial && DiaryProgression.roomUnlocked(store.state, room: .bedroom) {
                        roomSegmentedPill
                    }

                    floatingBottomDock
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                idleBreathe = true
            }
        }
    }

    private func furnitureSize(_ id: FurnitureID, frameWidth: CGFloat) -> CGFloat {
        switch DiaryCatalog.furnitureDef(id)?.layer ?? .floor {
        case .flat: return frameWidth * 0.42
        case .wall: return frameWidth * 0.30
        case .floor: return frameWidth * 0.31
        }
    }

    private func catActorView(in frame: CGRect) -> some View {
        let catSize = frame.width * 0.41 * stage.displayScale
        let cx = frame.minX + frame.width * 0.50
        let cy = frame.minY + frame.height * 0.69

        return ZStack {
            // Soft sunlit floor shadow beneath Xiaoju
            Ellipse()
                .fill(RoomTheme.ink.opacity(0.20))
                .frame(width: catSize * 0.68, height: catSize * 0.16)
                .blur(radius: 7)
                .offset(y: catSize * 0.38)

            // Tutorial tap halo when meeting Xiaoju
            if tutorialStep == .meet && !reduceMotion {
                Circle()
                    .stroke(RoomTheme.coral.opacity(0.55), lineWidth: 3)
                    .frame(width: catSize * 0.85, height: catSize * 0.85)
                    .scaleEffect(idleBreathe ? 1.12 : 0.96)
                    .opacity(idleBreathe ? 0.25 : 0.8)
            }

            Image(store.displayedCatPose.assetName(stage: stage))
                .resizable()
                .scaledToFit()
                .frame(width: catSize, height: catSize)
                .scaleEffect(
                    x: catPressed ? 1.06 : 1.0,
                    y: catPressed ? 0.93 : (idleBreathe && !reduceMotion ? 1.018 : 1.0),
                    anchor: .bottom
                )
                .animation(.spring(response: 0.24, dampingFraction: 0.52), value: catPressed)
                .onTapGesture {
                    catPressed = true
                    spawnHearts()
                    store.petCat()
                    Task {
                        try? await Task.sleep(for: .milliseconds(160))
                        catPressed = false
                    }
                }
                .accessibilityLabel(GameStrings.text("home.tapCatHint"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("homeCatButton")

            // Floating hearts when petted
            ForEach(heartBursts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundStyle(RoomTheme.heartPink)
                    .shadow(color: .white.opacity(0.6), radius: 2)
                    .offset(x: heart.offsetX, y: heart.rising ? -catSize * 0.62 + heart.offsetY : -catSize * 0.22)
                    .opacity(heart.rising ? 0 : 0.95)
                    .scaleEffect(heart.rising ? 1.15 : 0.65)
            }

            // Reaction speech bubble
            if let bubbleKey = store.catBubbleKey {
                VStack(spacing: 0) {
                    Text(GameStrings.text(bubbleKey))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(RoomTheme.ink)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background(WarmGlassBackground(cornerRadius: 16, tintOpacity: 0.92))
                    BubbleTail()
                        .fill(RoomTheme.paper.opacity(0.95))
                        .frame(width: 12, height: 6)
                }
                .offset(y: -catSize * 0.54)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .position(x: cx, y: cy)
    }

    private func spawnHearts() {
        guard !reduceMotion else { return }
        let base = [
            FloatingHeart(offsetX: -26, offsetY: -10, size: 15),
            FloatingHeart(offsetX: 4, offsetY: -22, size: 18),
            FloatingHeart(offsetX: 28, offsetY: -6, size: 13),
        ]
        heartBursts.append(contentsOf: base)
        let ids = Set(base.map(\.id))
        withAnimation(.easeOut(duration: 0.9)) {
            for idx in heartBursts.indices where ids.contains(heartBursts[idx].id) {
                heartBursts[idx].rising = true
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(950))
            heartBursts.removeAll { ids.contains($0.id) }
        }
    }

    // MARK: - Top Chrome

    private var topChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                // Sleek Frosted Cat Bond Badge
                HStack(spacing: 9) {
                    ZStack {
                        Circle()
                            .fill(RoomTheme.paleCoral)
                            .frame(width: 34, height: 34)
                        AssetOrSymbol(asset: "ui_heart", symbol: "heart.fill", size: 22, tint: RoomTheme.coral)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(GameStrings.text("cat.xiaoju"))
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(RoomTheme.ink)
                            Text(GameStrings.format("common.lvFormat", cat.level))
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6.5)
                                .padding(.vertical, 1.5)
                                .background(RoomTheme.coral, in: Capsule())
                        }
                        let xp = DiaryProgression.xpProgress(for: cat)
                        HStack(spacing: 8) {
                            GeometryReader { bar in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(RoomTheme.track)
                                    Capsule()
                                        .fill(LinearGradient(colors: [RoomTheme.coral, RoomTheme.gold], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: bar.size.width * min(1, CGFloat(xp.current) / CGFloat(max(1, xp.target))))
                                }
                            }
                            .frame(width: 68, height: 6)

                            compactGauge(symbol: "fork.knife", value: Int(cat.satiety.rounded()), tint: cat.satiety < 25 ? RoomTheme.coral : RoomTheme.mint)
                            compactGauge(symbol: "sun.max.fill", value: Int(cat.mood.rounded()), tint: RoomTheme.gold)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(WarmGlassBackground(cornerRadius: 22, tintOpacity: 0.84))

                Spacer(minLength: 4)

                // Coins Capsule
                HStack(spacing: 4) {
                    AssetOrSymbol(asset: "ui_coin", symbol: "dollarsign.circle.fill", size: 18, tint: RoomTheme.gold)
                    Text("\(store.state.coins)")
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RoomTheme.ink)
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(WarmGlassBackground(cornerRadius: 20, tintOpacity: 0.84))

                if !isTutorial {
                    Button {
                        store.activeSheet = .settings
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(RoomTheme.ink)
                            .frame(width: 40, height: 40)
                            .background(WarmGlassBackground(cornerRadius: 20, tintOpacity: 0.84))
                    }
                    .buttonStyle(CraftIconBadgeButtonStyle())
                    .accessibilityLabel(GameStrings.text("settings.title"))
                    .accessibilityIdentifier("homeSettingsButton")
                }
            }

            // Tilted Sticky Note for Today's Wish
            if let wish = store.state.home.wish, !isTutorial {
                Button {
                    store.notices.show(GameStrings.wishHint(wish.goal, bonusXP: DiaryBalance.default.cat.wishBonusXP))
                } label: {
                    ZStack(alignment: .top) {
                        HStack(spacing: 6) {
                            Image(systemName: wish.completed ? "checkmark.seal.fill" : "sparkle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(wish.completed ? RoomTheme.mint : RoomTheme.coral)
                            Text("\(GameStrings.text("wish.title")) · \(GameStrings.wishLabel(wish.goal))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(RoomTheme.ink)
                            if wish.completed {
                                Text(GameStrings.text("wish.doneBadge"))
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(RoomTheme.darkMint)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(RoomTheme.paleMint, in: Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 7)
                        .background(RoomTheme.rewardPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RoomTheme.rewardBorder, lineWidth: 1.2))
                        .shadow(color: RoomTheme.ink.opacity(0.12), radius: 5, y: 3)

                        WashiTapeStrip(tint: RoomTheme.gold.opacity(0.45), width: 34)
                            .offset(y: -5)
                    }
                }
                .buttonStyle(CraftIconBadgeButtonStyle())
                .rotationEffect(.degrees(-1.1))
                .padding(.leading, 4)
            }
        }
    }

    private func compactGauge(symbol: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 2.5) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(RoomTheme.secondary)
        }
    }

    private var tutorialCoachPill: some View {
        HStack(spacing: 9) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoomTheme.coral, in: Circle())
            Text(GameStrings.text(tutorialStep == .gather ? "tutorial.goWorkshop" : "tutorial.\(tutorialStep.rawValue)"))
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .foregroundStyle(RoomTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(WarmGlassBackground(cornerRadius: 18, tintOpacity: 0.92))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(RoomTheme.coral.opacity(0.65), lineWidth: 1.5))
    }

    private func offlineNoteCard(_ noteID: String) -> some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top, spacing: 10) {
                AssetOrSymbol(asset: "ui_note_pin", symbol: "note.text", size: 28, tint: RoomTheme.coral)
                VStack(alignment: .leading, spacing: 3) {
                    Text(GameStrings.text("home.offlineNoteTitle"))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(RoomTheme.secondary)
                    Text(GameStrings.text(noteID))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(RoomTheme.ink)
                }
                Spacer()
                Button {
                    store.toggleOfflineNote()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(RoomTheme.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(GameStrings.text("common.close"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(RoomTheme.rewardPaper.opacity(0.97), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(RoomTheme.rewardBorder, lineWidth: 1.4))
            .shadow(color: RoomTheme.ink.opacity(0.14), radius: 8, y: 4)

            WashiTapeStrip(tint: RoomTheme.coral.opacity(0.45), width: 46)
                .offset(y: -6)
        }
        .padding(.top, 4)
    }

    private var roomSegmentedPill: some View {
        HStack(spacing: 4) {
            ForEach([RoomID.livingroom, .bedroom], id: \.self) { room in
                let selected = store.activeRoom == room
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        store.selectRoom(room)
                    }
                } label: {
                    Text(GameStrings.roomName(room))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(selected ? .white : RoomTheme.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule().fill(RoomTheme.coral)
                                    .shadow(color: RoomTheme.coralDeep.opacity(0.45), radius: 0, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(WarmGlassBackground(cornerRadius: 24, tintOpacity: 0.84))
    }

    // MARK: - Airy Floating Bottom Dock

    private var floatingBottomDock: some View {
        let progress = store.photoProgress
        return HStack(spacing: 8) {
            if !isTutorial {
                dockNavButton(
                    asset: "ui_diary",
                    symbol: "book.closed.fill",
                    label: GameStrings.text("home.diary"),
                    miniBadge: "\(progress.got)/\(progress.total)"
                ) {
                    store.activeSheet = .diary
                }
                .accessibilityIdentifier("homeDiaryButton")

                dockNavButton(
                    asset: "ui_shop",
                    symbol: "storefront.fill",
                    label: GameStrings.text("home.shop"),
                    miniBadge: nil
                ) {
                    store.activeSheet = .shop
                }
                .accessibilityIdentifier("homeShopButton")

                RoundedRectangle(cornerRadius: 1)
                    .fill(RoomTheme.wood.opacity(0.55))
                    .frame(width: 1.5, height: 42)
            }

            // Recessed Warm Tray for Toys & Food
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if store.state.home.toys.isEmpty && store.state.home.food.isEmpty {
                        Text(GameStrings.text("home.trayEmpty"))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(RoomTheme.secondary)
                            .padding(.horizontal, 8)
                    } else {
                        ForEach(Array(store.state.home.toys.enumerated()), id: \.offset) { idx, toy in
                            trayTile(item: toy.item, durabilityDots: toy.usesLeft) {
                                store.playWithToy(at: idx)
                            }
                        }
                        ForEach(Array(store.state.home.food.enumerated()), id: \.offset) { idx, food in
                            trayTile(item: food, durabilityDots: nil) {
                                store.feedCat(at: idx)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(RoomTheme.cream.opacity(0.65), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RoomTheme.wood.opacity(0.45), lineWidth: 1))

            // Elevated Coral Workshop CTA
            Button {
                store.switchScreen(to: .workshop)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text(GameStrings.text("home.workshop"))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: 66, height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RoomTheme.coral.opacity(0.92), RoomTheme.coral],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: RoomTheme.coralDeep.opacity(0.9), radius: 0, y: 3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.42), lineWidth: 1.4)
                }
                .overlay {
                    if tutorialStep == .gather && !reduceMotion {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(RoomTheme.gold, lineWidth: 2.5)
                            .scaleEffect(idleBreathe ? 1.08 : 1.0)
                            .opacity(idleBreathe ? 0.35 : 0.95)
                    }
                }
            }
            .buttonStyle(CraftIconBadgeButtonStyle())
            .accessibilityIdentifier("homeWorkshopButton")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(WarmGlassBackground(cornerRadius: 26, tintOpacity: 0.88))
    }

    private func dockNavButton(asset: String, symbol: String, label: String, miniBadge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    AssetOrSymbol(asset: asset, symbol: symbol, size: 30, tint: RoomTheme.ink)
                        .frame(width: 44, height: 42)
                        .background(RoomTheme.paper, in: Circle())
                        .overlay(Circle().stroke(RoomTheme.wood.opacity(0.75), lineWidth: 1.2))
                        .shadow(color: RoomTheme.ink.opacity(0.08), radius: 3, y: 2)
                    if let miniBadge {
                        Text(miniBadge)
                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1)
                            .background(RoomTheme.coral, in: Capsule())
                            .offset(x: 5, y: -3)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(RoomTheme.ink)
                    .lineLimit(1)
            }
            .frame(width: 50)
        }
        .buttonStyle(CraftIconBadgeButtonStyle())
    }

    private func trayTile(item: MergeItem, durabilityDots: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .shadow(color: RoomTheme.ink.opacity(0.14), radius: 2, y: 1.5)

                if let dots = durabilityDots {
                    HStack(spacing: 3) {
                        ForEach(0..<DiaryBalance.default.cat.toyUses, id: \.self) { i in
                            Circle()
                                .fill(i < dots ? RoomTheme.coral : RoomTheme.track)
                                .frame(width: 5, height: 5)
                        }
                    }
                } else {
                    Text(GameStrings.itemName(item))
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(RoomTheme.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 54, height: 56)
            .background(RoomTheme.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(RoomTheme.wood.opacity(0.75), lineWidth: 1))
            .shadow(color: RoomTheme.ink.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(CraftIconBadgeButtonStyle())
    }
}

private struct FloatingHeart: Identifiable {
    let id = UUID()
    let offsetX: CGFloat
    let offsetY: CGFloat
    let size: CGFloat
    var rising = false
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct RainShimmerOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<18 {
                    let seed = Double(i) * 137.5
                    let x = CGFloat((seed.truncatingRemainder(dividingBy: 100.0) / 100.0)) * size.width
                    let speed = 180.0 + Double(i % 4) * 40.0
                    let y = CGFloat(((phase * speed + seed * 9.0).truncatingRemainder(dividingBy: Double(size.height * 0.52))))
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - 5, y: y + 18))
                    ctx.stroke(p, with: .color(.white.opacity(0.22)), lineWidth: 1.1)
                }
            }
        }
    }
}
