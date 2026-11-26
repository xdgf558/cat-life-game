import Foundation
import Observation
import CatGameCore

enum AppScreen: Equatable {
    case home
    case workshop
}

enum CatHomePose: String, Equatable {
    case idle
    case happy
    case hungry
    case sleep
    case pet
    case play
    case eat

    func assetName(stage: CatGrowthStage = .kitten) -> String {
        switch stage {
        case .kitten: "cat_\(rawValue)"
        case .junior: "cat_junior_\(rawValue)"
        case .adult: "cat_adult_\(rawValue)"
        }
    }
}

struct LevelUpModalItem: Identifiable, Equatable {
    let id = UUID()
    let level: Int
    let unlocks: [UnlockRule]
}

enum ActiveSheet: Identifiable, Equatable {
    case shop
    case diary
    case settings
    case orderDetail(CustomerOrder)

    var id: String {
        switch self {
        case .shop: "shop"
        case .diary: "diary"
        case .settings: "settings"
        case .orderDetail(let order): "order-\(order.id)"
        }
    }
}

@MainActor
@Observable
final class DiaryAppStore {
    private(set) var state: DiaryGameState
    private(set) var isLoaded = false
    private(set) var isSaving = false
    private(set) var loadError: String?
    private(set) var saveError: String?

    var activeScreen: AppScreen = .home
    var activeRoom: RoomID = .livingroom
    var activeSheet: ActiveSheet?

    // Modals & transient UI feedback
    private(set) var photoQueue: [String] = []
    private(set) var levelUpQueue: [LevelUpModalItem] = []
    private(set) var activeAdOffer: AdOffer?
    private(set) var playingMockAdSlot: AdSlot?
    private(set) var offlineNoteID: String?
    private(set) var showingOfflineNote = false
    private(set) var catBubbleKey: String?
    private(set) var transientCatPose: CatHomePose?
    private(set) var luckyCells: Set<Int> = []
    private(set) var recentMergedCell: Int?

    // Debug / M1 testing toggles (exposed in Settings)
    var mockAdsEnabled: Bool = true {
        didSet { engine.adConfig.adEnabled = mockAdsEnabled }
    }

    let audio = GameAudioController()
    let notices = GameNoticeCenter()
    let mockAdService: MockRewardedAdService

    @ObservationIgnored private let adService: any RewardedAdService
    @ObservationIgnored private let repository: any GameSaveRepository
    @ObservationIgnored private let clock: @Sendable () -> Date
    @ObservationIgnored private var engine: DiaryGameEngine
    @ObservationIgnored private var saveRetry = SaveRetryState()
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var poseTask: Task<Void, Never>?
    @ObservationIgnored private var bubbleTask: Task<Void, Never>?
    @ObservationIgnored private var comboCount = 0
    @ObservationIgnored private var lastMergeAt: TimeInterval = -100
    @ObservationIgnored private var lastBubbleKey: String?
    @ObservationIgnored private var isForeground = true
    @ObservationIgnored private var homeTrack: GameMusicTrack
    @ObservationIgnored private var workshopTrack: GameMusicTrack

    var currentPhotoModalID: String? { photoQueue.first }
    var currentLevelUpModal: LevelUpModalItem? { photoQueue.isEmpty ? levelUpQueue.first : nil }

    var nowMs: Int64 { DayClock.epochMs(clock()) }
    var sceneLight: SceneLight { engine.sceneLight(now: nowMs) }
    var energyStatus: (current: Int, msToNext: Int64) { DiaryEnergy.view(state, now: nowMs, balance: engine.balance) }
    var daysTogether: Int { DayClock.daysTogether(createdAt: state.createdAt, now: nowMs) }
    var photoProgress: (got: Int, total: Int) { DiaryHome.photoProgress(state) }
    var currentMusicTrack: GameMusicTrack { activeScreen == .home ? homeTrack : workshopTrack }

    var displayedCatPose: CatHomePose {
        if let transient = transientCatPose { return transient }
        if DiaryHome.isHungry(state.primaryCat) && !state.tutorialActive { return .hungry }
        if sceneLight == .night && !state.tutorialActive { return .sleep }
        return .idle
    }

    init(
        repository: (any GameSaveRepository)? = nil,
        adService: (any RewardedAdService)? = nil,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.clock = clock
        let resolvedRepo: any GameSaveRepository
        if let repository {
            resolvedRepo = repository
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            resolvedRepo = DiarySaveRepository(directory: base.appendingPathComponent("CatLife", isDirectory: true))
        }
        self.repository = resolvedRepo

        let mock = (adService as? MockRewardedAdService) ?? MockRewardedAdService()
        self.mockAdService = mock
        self.adService = adService ?? mock

        let initial = DiaryGameState.fresh(now: DayClock.epochMs(clock()))
        self.state = initial
        self.engine = DiaryGameEngine(state: initial, adConfig: AdRemoteConfig(adEnabled: true))
        self.homeTrack = GameMusicTrack.homeTracks.randomElement() ?? .home
        self.workshopTrack = GameMusicTrack.workshopTracks.randomElement() ?? .work

        self.mockAdService.onRequestPlayback = { [weak self] slot in
            self?.playingMockAdSlot = slot
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !isLoaded else { return }
        do {
            let loaded = try await repository.loadOrCreate(now: clock())
            engine = DiaryGameEngine(state: loaded, adConfig: AdRemoteConfig(adEnabled: mockAdsEnabled))
            let startOut = engine.start(now: nowMs)
            syncStateAndApply(events: startOut.events, save: false)
            applyLanguagePreference()
            isLoaded = true
            loadError = nil

            let visit = engine.visitHome(now: nowMs)
            syncStateAndApply(events: visit.events, save: true)
            if let note = visit.value.offlineNoteID {
                offlineNoteID = note
                showingOfflineNote = true
            }
            reconcileAudio()
        } catch {
            loadError = GameStrings.text("save.loadFailed")
        }
    }

    func setForeground(_ foreground: Bool) {
        let wasForeground = isForeground
        isForeground = foreground
        if !foreground, isLoaded {
            if activeScreen == .home {
                let out = engine.leaveHome(now: nowMs)
                syncStateAndApply(events: out.events, save: true)
            }
        } else if !wasForeground, foreground, isLoaded {
            let dayOut = engine.refreshDay(now: nowMs)
            if dayOut.didMutate { syncStateAndApply(events: dayOut.events, save: true) }
            if activeScreen == .home {
                let visit = engine.visitHome(now: nowMs)
                syncStateAndApply(events: visit.events, save: true)
                if let note = visit.value.offlineNoteID {
                    offlineNoteID = note
                    showingOfflineNote = true
                }
            }
        }
        reconcileAudio()
    }

    func switchScreen(to screen: AppScreen) {
        guard activeScreen != screen else { return }
        if activeScreen == .home {
            let out = engine.leaveHome(now: nowMs)
            syncStateAndApply(events: out.events, save: true)
        }
        activeScreen = screen
        audio.play(.tap, userInitiated: true)
        if screen == .home {
            let visit = engine.visitHome(now: nowMs)
            syncStateAndApply(events: visit.events, save: true)
            if let note = visit.value.offlineNoteID {
                offlineNoteID = note
                showingOfflineNote = true
            }
        }
        reconcileAudio()
    }

    func selectRoom(_ room: RoomID) {
        guard DiaryProgression.roomUnlocked(state, room: room) else {
            let lv = DiaryProgression.unlockLevel(for: .room(room))
            notices.show(GameStrings.format("room.lockedNotice", lv))
            return
        }
        activeRoom = room
        audio.play(.tap, userInitiated: true)
    }

    // MARK: - Workshop Actions

    func tapGenerator(_ chain: MergeChain) {
        let out = engine.tapGenerator(chain: chain, now: nowMs)
        switch out.value {
        case .generated(let item, let cell):
            syncStateAndApply(events: out.events, save: true)
            audio.play(item.level >= 2 ? .coins : .place, userInitiated: true)
            if item.level >= 2 && cell >= 0 {
                luckyCells.insert(cell)
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(900))
                    self?.luckyCells.remove(cell)
                }
            } else if cell < 0 {
                notices.show(GameStrings.text("workshop.sentToPending"))
            }
        case .locked:
            let lv = DiaryProgression.unlockLevel(for: .chain(chain))
            notices.show(GameStrings.format("workshop.chainLocked", lv))
        case .noEnergy:
            syncStateAndApply(events: out.events, save: false)
            tryPresentMaterialAd(for: chain)
        }
    }

    func moveItem(from: Int, to: Int) -> MoveItemResult {
        let out = engine.moveItem(from: from, to: to, now: nowMs)
        syncStateAndApply(events: out.events, save: out.value != .invalid)
        switch out.value {
        case .merged:
            let uptime = ProcessInfo.processInfo.systemUptime
            comboCount = (uptime - lastMergeAt <= 5.0) ? min(3, comboCount + 1) : 0
            lastMergeAt = uptime
            let pitch = Float(1.0 + 0.06 * Double(comboCount))
            audio.play(.merge, rate: pitch, userInitiated: true)
            recentMergedCell = to
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(420))
                if self?.recentMergedCell == to { self?.recentMergedCell = nil }
            }
        case .moved, .swapped:
            audio.play(.place, userInitiated: true)
        case .invalid:
            break
        }
        return out.value
    }

    func claimPending() {
        let out = engine.claimPending(now: nowMs)
        guard out.value != nil else {
            notices.show(GameStrings.text("workshop.boardFull"))
            return
        }
        syncStateAndApply(events: out.events, save: true)
        audio.play(.place, userInitiated: true)
    }

    func sellItem(at index: Int) {
        let out = engine.sellItem(at: index, now: nowMs)
        guard out.value > 0 else { return }
        syncStateAndApply(events: out.events, save: true)
        audio.play(.coins, userInitiated: true)
        notices.show(GameStrings.format("workshop.soldCoins", out.value))
    }

    func bringHome(cellIndex: Int) {
        let out = engine.bringHome(cellIndex: cellIndex, now: nowMs)
        switch out.value {
        case .brought(let item):
            syncStateAndApply(events: out.events, save: true)
            audio.play(.purchase, userInitiated: true)
            notices.show(GameStrings.format("workshop.broughtHomeNotice", GameStrings.itemName(item)))
            if state.tutorialStep == .play {
                switchScreen(to: .home)
            }
        case .levelTooLow:
            notices.show(GameStrings.text("workshop.bringHomeLevelTooLow"))
        case .empty:
            break
        }
    }

    func setTarget(item: MergeItem, orderID: String? = nil) {
        let out = engine.setTarget(item: item, orderID: orderID, now: nowMs)
        syncStateAndApply(events: out.events, save: true)
        audio.play(.tap, userInitiated: true)
    }

    func clearTarget() {
        let out = engine.clearTarget(now: nowMs)
        syncStateAndApply(events: out.events, save: true)
    }

    func deliverOrder(_ orderID: String) {
        let out = engine.deliverOrder(orderID: orderID, now: nowMs)
        guard case .delivered(_, let wage, let gift, _) = out.value.result else { return }
        syncStateAndApply(events: out.events, save: true)
        audio.play(.coins, userInitiated: true)
        notices.show(GameStrings.format("order.deliveredCoins", wage))
        if let gift {
            notices.show(GameStrings.format("order.customerGift", GameStrings.furnitureName(gift)))
        }
        if let bonus = out.value.bonusOffer,
           adService.isReady(slot: .wage),
           engine.offerStillAllowed(.wage(bonus), now: nowMs) {
            presentAdOffer(.wage(bonus))
        }
    }

    func rerollOrder(_ orderID: String) {
        let out = engine.rerollOrder(orderID: orderID, now: nowMs)
        guard out.value != nil else {
            notices.show(GameStrings.text("order.rerollUsed"))
            return
        }
        syncStateAndApply(events: out.events, save: true)
        audio.play(.tap, userInitiated: true)
        activeSheet = nil
    }

    // MARK: - Home & Shop Actions

    func petCat() {
        let out = engine.pet(now: nowMs)
        switch out.value {
        case .petted:
            syncStateAndApply(events: out.events, save: true)
            audio.play(.pet, userInitiated: true)
            audio.playPetPurrHaptics()
            showTransientPose(.pet, durationMs: 1300)
        case .failed(.cooldown):
            let mood: CatBubbleMood = if DiaryHome.isHungry(state.primaryCat) && !state.tutorialActive {
                .hungry
            } else if sceneLight == .night && !state.tutorialActive {
                .sleep
            } else {
                .normal
            }
            let key = DiaryCatalog.pickBubbleKey(mood: mood, excluding: lastBubbleKey, randomUnit: Double.random(in: 0..<1))
            lastBubbleKey = key
            showBubble(key: key)
            audio.play(.tap, userInitiated: true)
        case .failed:
            break
        }
    }

    func playWithToy(at index: Int) {
        let out = engine.playWithToy(index: index, now: nowMs)
        switch out.value {
        case .played(_, _, let wornOut):
            syncStateAndApply(events: out.events, save: true)
            audio.play(.catHappy, userInitiated: true)
            showTransientPose(.play, durationMs: 1400)
            if wornOut { notices.show(GameStrings.text("home.toyWornOut")) }
        case .failed(.hungry):
            showBubble(key: "bubble.hungry.01")
            notices.show(GameStrings.text("home.hungryRefusePlay"))
        case .failed:
            break
        }
    }

    func feedCat(at index: Int) {
        let out = engine.feed(index: index, now: nowMs)
        switch out.value {
        case .fed:
            syncStateAndApply(events: out.events, save: true)
            audio.play(.feed, userInitiated: true)
            showTransientPose(.eat, durationMs: 1600)
        case .failed:
            break
        }
    }

    func buyFurniture(_ id: FurnitureID) {
        let out = engine.buyFurniture(id: id, now: nowMs)
        switch out.value {
        case .bought(let furniture, _):
            syncStateAndApply(events: out.events, save: true)
            audio.play(.purchase, userInitiated: true)
            notices.show(GameStrings.format("shop.boughtNotice", GameStrings.furnitureName(furniture)))
            // Xiaoju immediately tries newly bought furniture in the current room!
            let settle = engine.settleNewFurniture(now: nowMs)
            syncStateAndApply(events: settle.events, save: true)
            if let def = DiaryCatalog.furnitureDef(furniture) {
                activeRoom = def.room
            }
            activeSheet = nil
        case .notEnoughCoins:
            let wishOut = engine.setWishlist(id, now: nowMs)
            syncStateAndApply(events: wishOut.events, save: true)
            notices.show(GameStrings.format("shop.wishlistPinned", GameStrings.furnitureName(id)))
        case .roomLocked(let room):
            let lv = DiaryProgression.unlockLevel(for: .room(room))
            notices.show(GameStrings.format("room.lockedNotice", lv))
        case .owned, .notForSale:
            break
        }
    }

    func toggleWishlist(_ id: FurnitureID) {
        let next: FurnitureID? = state.home.wishlist == id ? nil : id
        let out = engine.setWishlist(next, now: nowMs)
        syncStateAndApply(events: out.events, save: true)
    }

    // MARK: - Modals & Tutorial

    func dismissCurrentPhotoModal() {
        guard !photoQueue.isEmpty else { return }
        let dismissed = photoQueue.removeFirst()
        if dismissed == DiaryCatalog.tutorialPhotoID && state.tutorialStep == .finish {
            let out = engine.finishTutorial(now: nowMs)
            syncStateAndApply(events: out.events, save: true)
            notices.show(GameStrings.text("tutorial.completedNotice"))
        }
    }

    func dismissCurrentLevelUpModal() {
        guard !levelUpQueue.isEmpty else { return }
        levelUpQueue.removeFirst()
    }

    func toggleOfflineNote() {
        showingOfflineNote.toggle()
    }

    // MARK: - Ads

    private func tryPresentMaterialAd(for chain: MergeChain) {
        guard activeAdOffer == nil else { return }
        let out = engine.materialOfferFor(chain: chain, now: nowMs) { [weak self] _ in
            self?.adService.isReady(slot: .material) == true
        }
        guard let offer = out.value else {
            notices.show(GameStrings.text("workshop.noEnergyNotice"))
            return
        }
        syncStateAndApply(events: out.events, save: true)
        presentAdOffer(.material(offer))
    }

    private func presentAdOffer(_ offer: AdOffer) {
        let out = engine.offerShown(offer, now: nowMs)
        syncStateAndApply(events: out.events, save: true)
        activeAdOffer = offer
    }

    func refuseActiveAd() {
        guard let offer = activeAdOffer else { return }
        activeAdOffer = nil
        let out = engine.refuseAd(slot: offer.slot, now: nowMs)
        syncStateAndApply(events: out.events, save: true)
    }

    func watchActiveAd() {
        guard let offer = activeAdOffer else { return }
        activeAdOffer = nil
        let startOut = engine.startAd(offer: offer, now: nowMs)
        guard let claimID = startOut.value else {
            notices.show(GameStrings.text("ad.unavailable"))
            return
        }
        syncStateAndApply(events: startOut.events, save: true)
        audio.setAdPaused(true)
        Task { [weak self] in
            guard let self else { return }
            let result = await self.adService.play(slot: offer.slot)
            self.playingMockAdSlot = nil
            self.audio.setAdPaused(false)
            let finishOut = self.engine.finishAd(claimID: claimID, result: result, now: self.nowMs)
            self.syncStateAndApply(events: finishOut.events, save: true)
            if finishOut.value {
                self.audio.play(.coins)
                switch offer {
                case .material(let m):
                    self.notices.show(GameStrings.format("ad.rewardMaterials", m.count, GameStrings.itemName(m.item)))
                case .wage(let w):
                    self.notices.show(GameStrings.format("ad.rewardCoins", w.amount))
                }
            } else if result == .failed {
                self.notices.show(GameStrings.text("ad.playFailed"))
            } else {
                self.notices.show(GameStrings.text("ad.closedEarly"))
            }
        }
    }

    func finishMockAdPlayback(with result: AdPlayResult) {
        mockAdService.complete(with: result)
    }

    // MARK: - Settings & Debug Helpers

    func updateAudioSettings(_ newAudio: AudioSettings, commit: Bool) {
        var settings = state.settings
        settings.audio = newAudio
        let out = engine.updateSettings(settings, now: nowMs)
        syncStateAndApply(events: out.events, save: commit)
        reconcileAudio()
    }

    func updateLanguage(_ language: GameLanguage?) {
        var settings = state.settings
        settings.language = language
        let out = engine.updateSettings(settings, now: nowMs)
        syncStateAndApply(events: out.events, save: true)
        applyLanguagePreference()
    }

    func resetProgress() {
        let out = engine.resetProgress(now: nowMs)
        photoQueue.removeAll()
        levelUpQueue.removeAll()
        activeAdOffer = nil
        offlineNoteID = nil
        showingOfflineNote = false
        activeScreen = .home
        activeRoom = .livingroom
        activeSheet = nil
        syncStateAndApply(events: out.events, save: true)
        notices.show(GameStrings.text("settings.resetDone"))
    }

    // MARK: - Internals

    private func syncStateAndApply(events: [DiaryGameEvent], save: Bool) {
        state = engine.state
        for event in events {
            switch event {
            case .photoTaken(_, let photoID):
                if !photoQueue.contains(photoID) { photoQueue.append(photoID) }
                audio.play(.photo)
            case .levelUp(_, let level, let unlocks):
                levelUpQueue.append(LevelUpModalItem(level: level, unlocks: unlocks))
                audio.play(.levelUp)
            case .wishCompleted(_, _, let bonusXP):
                notices.show(GameStrings.format("wish.completedNotice", bonusXP))
            default:
                break
            }
        }
        if save { scheduleSave() }
    }

    private func scheduleSave() {
        let snapshot = state
        let now = clock()
        saveTask?.cancel()
        isSaving = true
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.save(snapshot, now: now)
                self.saveRetry.succeeded()
                self.saveError = nil
            } catch {
                if self.saveRetry.failed(at: now) {
                    self.saveError = GameStrings.text("save.writeFailed")
                }
            }
            self.isSaving = false
        }
    }

    private func applyLanguagePreference() {
        GameLocalization.shared.language = state.settings.language
            ?? GameLanguage.preferred(in: Locale.preferredLanguages)
    }

    private func reconcileAudio() {
        audio.configure(
            settings: state.settings.audio,
            track: currentMusicTrack,
            foreground: isForeground,
            ready: isLoaded,
            now: clock()
        )
    }

    private func showTransientPose(_ pose: CatHomePose, durationMs: Int) {
        poseTask?.cancel()
        transientCatPose = pose
        poseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(durationMs))
            guard let self, !Task.isCancelled else { return }
            self.transientCatPose = nil
        }
    }

    private func showBubble(key: String) {
        bubbleTask?.cancel()
        catBubbleKey = key
        bubbleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            guard let self, !Task.isCancelled else { return }
            self.catBubbleKey = nil
        }
    }
}
