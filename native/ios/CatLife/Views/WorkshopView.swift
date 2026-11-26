import SwiftUI
import CatGameCore

struct WorkshopView: View {
    @Bindable var store: DiaryAppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCell: Int?
    @State private var sellArmedCell: Int?
    @State private var dragFromCell: Int?
    @State private var dragHoverCell: Int?
    @State private var dragTranslation: CGSize = .zero
    @State private var cellFrames: [Int: CGRect] = [:]
    @State private var lastTouchAt = Date()
    @State private var hintPair: (Int, Int)?
    @State private var hintPulse = false

    private let cols = DiaryBalance.default.board.cols
    private let rows = DiaryBalance.default.board.rows

    private var isTutorial: Bool { store.state.tutorialActive }
    private var tutorialStep: TutorialStep { store.state.tutorialStep }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let fullSize = CGSize(width: geo.size.width, height: geo.size.height + safeTop + safeBottom)
            let frame = SceneCanvasLayout.workshopFrame(in: fullSize, safeTop: safeTop)
            let matRect = SceneCanvasLayout.subrect(
                of: frame,
                left: SceneCanvasLayout.workshopMat.left,
                top: SceneCanvasLayout.workshopMat.top,
                right: SceneCanvasLayout.workshopMat.right,
                bottom: SceneCanvasLayout.workshopMat.bottom
            )
            let tableBottomY = frame.minY + frame.height * SceneCanvasLayout.workshopTableBottom

            ZStack(alignment: .topLeading) {
                // Edge fill for wide iPads or short screens
                RoomTheme.edgeBackdrop(for: store.sceneLight).ignoresSafeArea()

                // Unobstructed full-clarity hand-painted workbench artwork
                Image(store.sceneLight.backgroundAssetName(base: "bg_workshop"))
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .ignoresSafeArea()

                // Top Frosted HUD Bar (Energy, Pending Queue, Coins)
                topHudBar
                    .padding(.horizontal, 14)
                    .frame(width: geo.size.width)
                    .position(x: geo.size.width / 2, y: safeTop + 26)

                // Mid Header Strip directly above the painted wooden mat:
                // swaps seamlessly between Pinned Order Receipts and Selected Item Inspector
                midHeaderStrip(width: min(geo.size.width - 24, frame.width - 20))
                    .position(x: geo.size.width / 2, y: max(safeTop + 88, matRect.minY - 40))

                // Precision 6x7 Merge Board aligned INSIDE the painted cream mat!
                mergeMatGrid(in: matRect)
                    .position(x: matRect.midX, y: matRect.midY)

                // Bottom Crafted Workbench Shelf (Diary + 3 Generators + Home)
                bottomCraftShelf(width: min(geo.size.width - 20, frame.width - 12))
                    .position(
                        x: geo.size.width / 2,
                        y: min(fullSize.height - safeBottom - 40, max(tableBottomY + 26, matRect.maxY + 46))
                    )
            }
            .ignoresSafeArea()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                if Date().timeIntervalSince(lastTouchAt) >= 2.5 && dragFromCell == nil {
                    let pair = DiaryBoard.findMergeablePair(store.state)
                    if hintPair?.0 != pair?.0 || hintPair?.1 != pair?.1 { hintPair = pair }
                    if !reduceMotion {
                        withAnimation(.easeInOut(duration: 0.6)) { hintPulse.toggle() }
                    }
                } else if hintPair != nil {
                    hintPair = nil
                }
            }
        }
    }

    // MARK: - Top Frosted HUD Bar

    private var topHudBar: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let energy = store.energyStatus
            HStack(spacing: 8) {
                // Energy glass pill
                HStack(spacing: 5) {
                    AssetOrSymbol(asset: "ui_energy", symbol: "bolt.fill", size: 19, tint: RoomTheme.coral)
                    Text("\(energy.current)/\(DiaryBalance.default.energy.max)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RoomTheme.ink)
                    if energy.msToNext > 0 {
                        let secs = Int((energy.msToNext + 999) / 1000)
                        Text(String(format: "%d:%02d", secs / 60, secs % 60))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(RoomTheme.secondary)
                            .padding(.leading, 1)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(WarmGlassBackground(cornerRadius: 18, tintOpacity: 0.86))

                Spacer(minLength: 4)

                // Pending queue badge when overflow items exist
                if !store.state.board.pending.isEmpty {
                    Button {
                        noteTouch()
                        store.claimPending()
                    } label: {
                        HStack(spacing: 4) {
                            AssetOrSymbol(asset: "ui_pending", symbol: "tray.and.arrow.down.fill", size: 18, tint: RoomTheme.coral)
                            Text(GameStrings.format("workshop.pendingFormat", store.state.board.pending.count))
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(RoomTheme.coralDeep)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(RoomTheme.rewardPaper, in: Capsule())
                        .overlay(Capsule().stroke(RoomTheme.coral, lineWidth: 1.4))
                        .shadow(color: RoomTheme.ink.opacity(0.12), radius: 4, y: 2)
                    }
                    .buttonStyle(CraftIconBadgeButtonStyle())
                }

                // Coins glass pill
                HStack(spacing: 5) {
                    AssetOrSymbol(asset: "ui_coin", symbol: "dollarsign.circle.fill", size: 19, tint: RoomTheme.gold)
                    Text("\(store.state.coins)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RoomTheme.ink)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(WarmGlassBackground(cornerRadius: 18, tintOpacity: 0.86))
            }
        }
    }

    // MARK: - Mid Header Strip (Orders <-> Selected Item Inspector)

    @ViewBuilder
    private func midHeaderStrip(width: CGFloat) -> some View {
        Group {
            if let idx = selectedCell, let item = store.state.board.cells[idx] {
                selectedItemInspector(index: idx, item: item)
            } else if isTutorial {
                tutorialStrip
            } else {
                pinnedOrdersRow
            }
        }
        .frame(width: width, height: 68)
    }

    private var tutorialStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoomTheme.coral, in: Circle())
            Text(GameStrings.text("tutorial.\(tutorialStep.rawValue)"))
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .foregroundStyle(RoomTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
        .background(WarmGlassBackground(cornerRadius: 18, tintOpacity: 0.94))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(RoomTheme.coral.opacity(0.65), lineWidth: 1.5))
    }

    private var pinnedOrdersRow: some View {
        HStack(spacing: 7) {
            ForEach(store.state.orders.active) { order in
                let ready = DiaryOrders.canDeliver(store.state, order: order)
                let checks = DiaryOrders.orderItemsOnBoard(store.state, order: order)
                Button {
                    noteTouch()
                    if ready {
                        store.deliverOrder(order.id)
                    } else {
                        store.activeSheet = .orderDetail(order)
                    }
                } label: {
                    ZStack(alignment: .top) {
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                Image(order.customer.avatarAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(RoomTheme.wood, lineWidth: 1))

                                HStack(spacing: 3) {
                                    ForEach(Array(order.items.enumerated()), id: \.offset) { idx, item in
                                        ZStack(alignment: .bottomTrailing) {
                                            Image(item.assetName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 29, height: 29)
                                            if idx < checks.count && checks[idx] {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(RoomTheme.mint)
                                                    .background(Circle().fill(.white).padding(1))
                                            }
                                        }
                                    }
                                }
                                Spacer(minLength: 0)
                            }

                            HStack(spacing: 3) {
                                if ready {
                                    Text(GameStrings.text("order.deliver"))
                                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 2)
                                        .background(RoomTheme.mint, in: Capsule())
                                } else {
                                    Spacer(minLength: 0)
                                    AssetOrSymbol(asset: "ui_coin", symbol: "dollarsign.circle.fill", size: 12, tint: RoomTheme.gold)
                                    Text("\(order.wage)")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(RoomTheme.ink)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 9)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(ready ? RoomTheme.paleMint : RoomTheme.paper.opacity(0.96))
                                .shadow(color: RoomTheme.ink.opacity(0.12), radius: 4, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ready ? RoomTheme.mint : RoomTheme.wood.opacity(0.85), lineWidth: ready ? 1.8 : 1.1)
                        )

                        // Tiny decorative tape tab
                        Capsule()
                            .fill(ready ? RoomTheme.mint.opacity(0.7) : RoomTheme.gold.opacity(0.45))
                            .frame(width: 22, height: 4)
                            .offset(y: -2)
                    }
                }
                .buttonStyle(CraftIconBadgeButtonStyle())
            }
        }
    }

    private func selectedItemInspector(index: Int, item: MergeItem) -> some View {
        HStack(spacing: 9) {
            Image(item.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .padding(3)
                .background(RoomTheme.cream, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(RoomTheme.wood.opacity(0.6), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(GameStrings.itemName(item))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(RoomTheme.ink)
                        .lineLimit(1)
                    Text(GameStrings.format("common.lvFormat", item.level))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(item.isUsableAtHome ? RoomTheme.coral : RoomTheme.secondary, in: Capsule())
                }
                if isTodayWish(item) {
                    Text(GameStrings.text("wish.itemTag"))
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(RoomTheme.coralDeep)
                } else {
                    Text(GameStrings.chainName(item.chain))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(RoomTheme.secondary)
                }
            }

            Spacer(minLength: 4)

            if item.isUsableAtHome {
                Button(GameStrings.text("workshop.bringHome")) {
                    noteTouch()
                    store.bringHome(cellIndex: index)
                    selectedCell = nil
                }
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoomTheme.mint, in: Capsule())
                .shadow(color: RoomTheme.darkMint.opacity(0.6), radius: 0, y: 2)
                .accessibilityIdentifier("workshopBringHomeButton")
            }

            if !isTutorial {
                let price = DiaryBoard.sellPrice(of: item)
                let armed = sellArmedCell == index
                Button(armed ? GameStrings.format("workshop.sellConfirm", price) : GameStrings.text("workshop.sell")) {
                    noteTouch()
                    if armed {
                        store.sellItem(at: index)
                        selectedCell = nil
                        sellArmedCell = nil
                    } else {
                        sellArmedCell = index
                    }
                }
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .foregroundStyle(armed ? .white : RoomTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(armed ? RoomTheme.coral : RoomTheme.chipBg, in: Capsule())
            }

            Button {
                selectedCell = nil
                sellArmedCell = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(RoomTheme.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GameStrings.text("common.close"))
        }
        .padding(.horizontal, 11)
        .frame(maxHeight: .infinity)
        .background(WarmGlassBackground(cornerRadius: 18, tintOpacity: 0.95))
    }

    private func isTodayWish(_ item: MergeItem) -> Bool {
        guard let wish = store.state.home.wish, !wish.completed else { return false }
        switch wish.goal {
        case .play(let target), .feed(let target): return target == item
        case .pet: return false
        }
    }

    // MARK: - Precision 6x7 Merge Board Inside Painted Mat

    private func mergeMatGrid(in matRect: CGRect) -> some View {
        let inset: CGFloat = 6
        let spacing: CGFloat = 3
        let innerW = matRect.width - inset * 2
        let innerH = matRect.height - inset * 2
        let cellW = floor((innerW - spacing * CGFloat(cols - 1)) / CGFloat(cols))
        let cellH = floor((innerH - spacing * CGFloat(rows - 1)) / CGFloat(rows))
        let tile = max(30, min(cellW, cellH))

        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        let idx = row * cols + col
                        boardTile(index: idx, row: row, col: col, size: tile)
                    }
                }
            }
        }
        .frame(width: matRect.width, height: matRect.height)
        .coordinateSpace(name: "mergeBoard")
        .onPreferenceChange(CellFramePreferenceKey.self) { frames in
            cellFrames = frames
        }
    }

    private func boardTile(index: Int, row: Int, col: Int, size: CGFloat) -> some View {
        let item = store.state.board.cells[index]
        let isSelected = selectedCell == index
        let isDragging = dragFromCell == index
        let isHoverTarget = dragHoverCell == index && dragFromCell != nil && dragFromCell != index
        let canMergeOnHover: Bool = {
            guard isHoverTarget, let from = dragFromCell,
                  let a = store.state.board.cells[from], let b = item else { return false }
            return a == b && a.nextLevel != nil
        }()
        let isHint = hintPair?.0 == index || hintPair?.1 == index
        let isLucky = store.luckyCells.contains(index)
        let isRecentMerge = store.recentMergedCell == index
        let isTarget = item != nil && store.state.target?.item == item
        let checkered = (row + col).isMultiple(of: 2)

        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    canMergeOnHover
                        ? RoomTheme.paleMint
                        : (isSelected ? RoomTheme.paleCoral : (checkered ? RoomTheme.matTileLight : RoomTheme.matTileAlt))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            canMergeOnHover
                                ? RoomTheme.mint
                                : (isSelected ? RoomTheme.coral : (isTarget ? RoomTheme.mint : (isHint ? RoomTheme.gold : RoomTheme.matLine.opacity(0.35)))),
                            lineWidth: (canMergeOnHover || isSelected || isTarget || isHint) ? 2 : 0.8
                        )
                )

            // Golden sparkle burst ring right after a merge
            if isRecentMerge && !reduceMotion {
                Circle()
                    .stroke(RoomTheme.gold.opacity(0.85), lineWidth: 2.5)
                    .frame(width: size * 0.92, height: size * 0.92)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }

            if let item {
                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(3.5)
                    .shadow(
                        color: RoomTheme.ink.opacity(isDragging ? 0.28 : 0.14),
                        radius: isDragging ? 7 : 2,
                        y: isDragging ? 6 : 1.5
                    )
                    .scaleEffect(isDragging ? 1.16 : (isRecentMerge ? 1.15 : (isHint && hintPulse ? 1.08 : 1.0)))
                    .animation(.spring(response: 0.24, dampingFraction: 0.56), value: isRecentMerge)
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                    .offset(isDragging ? dragTranslation : .zero)
                    .zIndex(isDragging ? 80 : 1)

                // Refined jewel level indicator
                if !isDragging {
                    Text("\(item.level)")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(item.isUsableAtHome ? RoomTheme.coral : RoomTheme.woodDeep.opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(2)
                        .allowsHitTesting(false)
                }

                if isLucky {
                    Text(GameStrings.text("workshop.lucky"))
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoomTheme.gold, in: Capsule())
                        .shadow(color: RoomTheme.ink.opacity(0.2), radius: 2, y: 1)
                        .offset(y: -size * 0.46)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(width: size, height: size)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CellFramePreferenceKey.self,
                    value: [index: proxy.frame(in: .named("mergeBoard"))]
                )
            }
        )
        .contentShape(Rectangle())
        .onTapGesture { handleCellTap(index) }
        .highPriorityGesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .named("mergeBoard"))
                .onChanged { value in
                    guard store.state.board.cells[index] != nil else { return }
                    noteTouch()
                    dragFromCell = index
                    selectedCell = index
                    dragTranslation = value.translation
                    dragHoverCell = cellFrames.first(where: { $0.value.contains(value.location) })?.key
                }
                .onEnded { value in
                    defer {
                        dragFromCell = nil
                        dragHoverCell = nil
                        dragTranslation = .zero
                    }
                    guard store.state.board.cells[index] != nil else { return }
                    if let targetIdx = cellFrames.first(where: { $0.value.contains(value.location) })?.key,
                       targetIdx != index {
                        let result = store.moveItem(from: index, to: targetIdx)
                        if result != .invalid {
                            selectedCell = targetIdx
                            sellArmedCell = nil
                        }
                    }
                }
        )
        .zIndex(isDragging ? 100 : 0)
    }

    private func handleCellTap(_ index: Int) {
        noteTouch()
        if let selected = selectedCell, selected != index,
           store.state.board.cells[selected] != nil {
            let a = store.state.board.cells[selected]
            let b = store.state.board.cells[index]
            if b == nil || (a == b && a?.nextLevel != nil) {
                let res = store.moveItem(from: selected, to: index)
                if res != .invalid {
                    selectedCell = index
                    sellArmedCell = nil
                    return
                }
            }
        }
        selectedCell = store.state.board.cells[index] != nil ? index : nil
        sellArmedCell = nil
    }

    // MARK: - Bottom Crafted Shelf (Diary + 3 Generators + Home)

    private func bottomCraftShelf(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            // Diary round craft button
            if !isTutorial {
                Button {
                    noteTouch()
                    store.activeSheet = .diary
                } label: {
                    VStack(spacing: 2) {
                        AssetOrSymbol(asset: "ui_diary", symbol: "book.closed.fill", size: 30, tint: RoomTheme.ink)
                            .frame(width: 48, height: 48)
                            .background(RoomTheme.paper, in: Circle())
                            .overlay(Circle().stroke(RoomTheme.wood, lineWidth: 1.5))
                            .shadow(color: RoomTheme.ink.opacity(0.14), radius: 4, y: 2)
                        Text(GameStrings.text("home.diary"))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(RoomTheme.paper)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(RoomTheme.ink.opacity(0.55), in: Capsule())
                    }
                }
                .buttonStyle(CraftIconBadgeButtonStyle())
                .accessibilityLabel(GameStrings.text("home.diary"))
            }

            // 3 Tactile Hand-Painted Generators
            HStack(spacing: 8) {
                ForEach(MergeChain.allCases, id: \.self) { chain in
                    let unlocked = DiaryProgression.chainUnlocked(store.state, chain: chain)
                    let unlockLv = DiaryProgression.unlockLevel(for: .chain(chain))
                    let tutorialFocus = tutorialStep == .gather && chain == .cloth

                    Button {
                        noteTouch()
                        store.tapGenerator(chain)
                    } label: {
                        VStack(spacing: 1) {
                            ZStack {
                                Circle()
                                    .fill(RoomTheme.warmIvory.opacity(unlocked ? 0.92 : 0.55))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Circle().stroke(
                                            tutorialFocus ? RoomTheme.gold : RoomTheme.wood.opacity(0.85),
                                            lineWidth: tutorialFocus ? 2.5 : 1.4
                                        )
                                    )
                                    .shadow(color: RoomTheme.ink.opacity(0.16), radius: 4, y: 2.5)

                                Image(chain.generatorAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 46, height: 46)
                                    .opacity(unlocked ? 1.0 : 0.36)

                                if !unlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(RoomTheme.ink)
                                        .padding(5)
                                        .background(RoomTheme.paper.opacity(0.9), in: Circle())
                                }
                            }
                            Text(unlocked ? GameStrings.generatorName(chain) : GameStrings.format("common.lvFormat", unlockLv))
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(RoomTheme.paper)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(RoomTheme.ink.opacity(unlocked ? 0.55 : 0.38), in: Capsule())
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CraftIconBadgeButtonStyle())
                    .accessibilityIdentifier("generator_\(chain.rawValue)")
                }
            }

            // Home round craft button
            Button {
                noteTouch()
                store.switchScreen(to: .home)
            } label: {
                VStack(spacing: 2) {
                    AssetOrSymbol(asset: "ui_home", symbol: "house.fill", size: 30, tint: RoomTheme.darkMint)
                        .frame(width: 48, height: 48)
                        .background(RoomTheme.paper, in: Circle())
                        .overlay(Circle().stroke(RoomTheme.mint, lineWidth: 1.8))
                        .shadow(color: RoomTheme.ink.opacity(0.16), radius: 4, y: 2)
                    Text(GameStrings.text("workshop.home"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(RoomTheme.mint, in: Capsule())
                }
            }
            .buttonStyle(CraftIconBadgeButtonStyle())
            .accessibilityIdentifier("workshopHomeButton")
        }
        .frame(width: width)
    }

    private func noteTouch() {
        lastTouchAt = Date()
        hintPair = nil
    }
}

private struct CellFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
