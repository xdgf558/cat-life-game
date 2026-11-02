import Foundation
import Observation
import CatGameCore

enum HomeSheet: String, Identifiable {
    case work, shop, inventory, town, player
    var id: String { rawValue }
}

enum InventoryCategory: String {
    case supplies, furniture
}

struct RoomFeedback: Equatable {
    let id = UUID()
    let kind: ActionKind
}

@MainActor
@Observable
final class GameStore {
    private(set) var snapshot: GameSnapshot? { didSet { syncAudio() } }
    private(set) var isLoading = true
    // Completed startup work, not an elapsed-time animation or save field.
    private(set) var startupProgress: Double = 0
    private(set) var startupPhase = "welcome.loadingSave"
    private(set) var isBusy = false
    private(set) var loadFailed = false
    // Welcome presentation belongs to this process, not the durable game save.
    private(set) var hasEnteredHome = false
    private(set) var startupNotice: String?
    var showSaveError = false
    var activeSheet: HomeSheet? {
        didSet {
            syncAudio()
            if oldValue != activeSheet { playNavigationSound() }
        }
    }
    var isShowingSettings = false {
        didSet { if oldValue != isShowingSettings { playNavigationSound() } }
    }
    var inventoryCategory: InventoryCategory = .supplies
    private(set) var now = Date()
    private(set) var toast: String?
    private(set) var feedback: RoomFeedback?
    private(set) var isDecorating = false {
        didSet { if oldValue != isDecorating { playNavigationSound() } }
    }
    private(set) var isSavingLayout = false
    private(set) var isResolvingLayout = false
    private(set) var draftBowlPosition: NormalizedPoint?
    private(set) var draftFurniture: [FurniturePlacement]?
    private(set) var selectedFurnitureID: String?
    private(set) var placingFurnitureID: String?
    private(set) var restingFurnitureID: String?
    private(set) var pendingWorkResultID: String?

    @ObservationIgnored private let repository: any GameSaveRepository
    @ObservationIgnored private let audio = GameAudioController()
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var lastSyncCheck = Date.distantPast
    @ObservationIgnored private var foreground = false
    @ObservationIgnored private var pendingSynchronization = false
    @ObservationIgnored private var loadingInProgress = false
    @ObservationIgnored private var presentedRestSessionID: String?
    @ObservationIgnored private var restTransitions: [RestTransition] = []
    @ObservationIgnored private var restRetryTask: Task<Void, Never>?
    @ObservationIgnored private var saveRetry = SaveRetryState()
    #if DEBUG
    @ObservationIgnored private var fixtures = GameStoreFixtures()
    #endif

    private struct RestTransition {
        let id = UUID()
        let catID: String
        let furnitureID: String?
        let sessionID: String
        let occurredAt: Date
    }

    private struct SaveContext {
        let original: GameSnapshot
        var candidate: GameSnapshot
        let transitions: [RestTransition]
    }

    init(directory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        let saveDirectory = directory ?? base.appendingPathComponent(testing ? "CatLife-UITests" : "CatLife", isDirectory: true)
        fixtures = GameStoreFixtures(arguments: arguments, allowsSeeding: directory == nil)
        if testing && arguments.contains("--reset-ui-test-save") && directory == nil {
            try? FileManager.default.removeItem(at: saveDirectory)
        }
        #else
        let saveDirectory = directory ?? base.appendingPathComponent("CatLife", isDirectory: true)
        #endif
        repository = FileSaveRepository(directory: saveDirectory)
    }

    init(repository: any GameSaveRepository) {
        self.repository = repository
    }

    var cat: CatState? { snapshot?.cats.first }
    var audioSettings: AudioSettings { snapshot?.settings.audio ?? AudioSettings() }

    private func syncAudio() {
        let track: GameMusicTrack
        if !hasEnteredHome { track = .home }
        else if snapshot?.player.activeSleep != nil { track = .sleep }
        else if snapshot?.player.activeWork != nil || activeSheet == .work { track = .work }
        else { track = .home }
        audio.configure(settings: audioSettings, track: track, foreground: foreground,
                        ready: snapshot != nil && !isLoading && !loadFailed)
    }

    func playNavigationSound() { audio.play(.tap, userInitiated: true) }
    func previewSoundEffect() { audio.play(.catMeow, userInitiated: true) }
    func playSceneSound(_ sound: GameSoundEffect) { audio.play(sound) }

    #if DEBUG
    /// Read-only diagnostics are exposed only by the isolated audio UI test.
    var audioDiagnostics: String {
        let value: [String: Any] = [
            "musicEnabled": audioSettings.musicEnabled, "effectsEnabled": audioSettings.effectsEnabled,
            "musicVolume": audioSettings.musicVolume, "effectsVolume": audioSettings.effectsVolume,
            "isForeground": audio.isForeground, "musicPlaying": audio.musicPlaying,
            "currentTrack": audio.currentTrack.rawValue, "effectPlayCount": audio.effectPlayCount,
            "lastEffect": audio.lastEffect, "backgroundPauseCount": audio.backgroundPauseCount,
            "assetLoadFailures": audio.assetLoadFailures
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    #endif

    @discardableResult
    func updateAudioSettings(_ settings: AudioSettings) async -> Bool {
        guard !isBusy, !isDecorating, var context = saveContext() else { return false }
        var candidate = context.candidate
        guard candidate.settings.audio != settings else { return true }
        candidate.settings.audio = settings
        isBusy = true
        defer { isBusy = false; drainPendingSynchronization() }
        do {
            context.candidate = candidate
            try await commit(context)
            return true
        } catch {
            recordSaveFailure()
            return false
        }
    }
    var foodRequired: Int { cat?.isPregnant == true ? 2 : 1 }
    var hasFood: Bool { (snapshot?.inventory.food ?? 0) >= foodRequired }

    var sceneSnapshot: GameSnapshot? {
        guard var value = snapshot else { return nil }
        if let draftBowlPosition { value.home.bowlPosition = draftBowlPosition }
        if let draftFurniture { value.home.furniture = draftFurniture }
        return value
    }

    var storedFurniture: [FurnitureItem] {
        guard let value = sceneSnapshot else { return [] }
        let placed = Set(value.home.furniture.map(\.itemID))
        return value.inventory.furniture.filter { !placed.contains($0.id) }
    }

    var placedFurnitureCount: Int { sceneSnapshot?.home.furniture.count ?? 0 }

    var selectedFurniture: FurnitureItem? {
        guard let id = selectedFurnitureID,
              placingFurnitureID == id || sceneSnapshot?.home.furniture.contains(where: { $0.itemID == id }) == true else { return nil }
        return snapshot?.inventory.furniture.first { $0.id == id }
    }

    var selectedFurnitureName: String {
        selectedFurniture.map(GameStrings.furnitureName) ?? GameStrings.text("layout.bowl")
    }

    var canStoreSelectedFurniture: Bool {
        isDecorating && selectedFurniture != nil && placingFurnitureID == nil
            && !isBusy && !isSavingLayout && !isResolvingLayout
    }

    var catStatus: String {
        guard let cat else { return "" }
        if restingFurnitureID != nil {
            return GameStrings.format("rest.recovering", cat.energy)
        }
        if cat.satiety < 50 { return GameStrings.text("cat.hungry") }
        if cat.cleanliness < 40 { return GameStrings.text("cat.cleanNeeded") }
        if cat.mood < 40 { return GameStrings.text("cat.playNeeded") }
        if cat.satiety >= 95 { return GameStrings.text("cat.full") }
        return GameStrings.text("cat.content")
    }

    // Capture the physical arrival/exit time immediately. Save operations are
    // serialized; waiting for an unrelated write must not extend a short rest.
    func setRestingFurniture(id: String?, sessionID: String) {
        guard let cat else { return }
        if let id {
            guard presentedRestSessionID != sessionID else { return }
            restingFurnitureID = id
            presentedRestSessionID = sessionID
        } else if presentedRestSessionID == sessionID {
            restingFurnitureID = nil
            presentedRestSessionID = nil
        }
        restTransitions.append(RestTransition(catID: cat.id, furnitureID: id,
                                               sessionID: sessionID, occurredAt: Date()))
        processNextRestTransition()
    }

    private func processNextRestTransition() {
        guard !isBusy, !restTransitions.isEmpty,
              saveRetry.permitsAutomaticAttempt(at: Date()), let context = saveContext() else { return }
        if context.candidate == context.original {
            acknowledgeTransitions(context.transitions)
            drainPendingSynchronization()
            return
        }
        isBusy = true
        Task {
            do {
                try await commit(context)
            } catch {
                recordSaveFailure()
            }
            isBusy = false
            drainPendingSynchronization()
        }
    }

    /// Replay physical rest events before the wall clock or a player action.
    /// Failed exits retain their captured time without blocking navigation.
    private func saveContext() -> SaveContext? {
        guard let original = snapshot else { return nil }
        var candidate = original
        let transitions = restTransitions
        for transition in transitions {
            if let furnitureID = transition.furnitureID {
                _ = GameEngine.startCatRest(&candidate, catID: transition.catID,
                    furnitureID: furnitureID, sessionID: transition.sessionID, now: transition.occurredAt)
            } else {
                _ = GameEngine.endCatRest(&candidate, catID: transition.catID,
                    sessionID: transition.sessionID, now: transition.occurredAt)
            }
        }
        return SaveContext(original: original, candidate: candidate, transitions: transitions)
    }

    private func acknowledgeTransitions(_ transitions: [RestTransition]) {
        let ids = Set(transitions.map(\.id))
        restTransitions.removeAll { ids.contains($0.id) }
    }

    private func commit(_ context: SaveContext) async throws {
        #if DEBUG
        try fixtures.checkSave(context.candidate, original: context.original,
                               exitsRest: context.transitions.contains { $0.furnitureID == nil })
        #endif
        try await repository.save(context.candidate)
        snapshot = context.candidate
        acknowledgeTransitions(context.transitions)
        saveRetry.succeeded()
        restRetryTask?.cancel()
        restRetryTask = nil
        if let receipt = context.candidate.player.lastWorkResult,
           receipt.id != context.original.player.lastWorkResult?.id {
            pendingWorkResultID = receipt.id
            audio.play(.workComplete)
            showNotice(GameStrings.format("action.workFinished", receipt.goldReward))
        }
    }

    private func recordSaveFailure(showAlert: Bool = true) {
        let firstFailure = saveRetry.failed(at: Date())
        if showAlert && firstFailure { showSaveError = true }
        restRetryTask?.cancel()
        restRetryTask = nil
        guard saveRetry.failures < SaveRetryState.maximumAutomaticAttempts else { return }
        let delay = max(0, saveRetry.nextAttempt.timeIntervalSinceNow)
        restRetryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }
            self.restRetryTask = nil
            self.synchronize(showNotice: false)
        }
    }

    func retrySaving() {
        // Explicit retry is independent of the exhausted automatic budget.
        synchronize(showNotice: true, userInitiated: true)
    }

    func showFurnitureNotice(_ key: String) { showNotice(GameStrings.text(key)) }

    func enterHome() {
        guard snapshot != nil, !isLoading, !loadFailed, !hasEnteredHome else { return }
        hasEnteredHome = true
        syncAudio()
        audio.play(pendingWorkResultID == nil ? .enter : .workComplete, userInitiated: true)
        if let notice = startupNotice {
            startupNotice = nil
            showNotice(notice)
        }
    }

    func load() async {
        guard !loadingInProgress, !isBusy else { return }
        loadingInProgress = true
        isBusy = true
        isLoading = true
        loadFailed = false
        startupProgress = 0
        startupPhase = "welcome.loadingSave"
        defer {
            loadingInProgress = false
            isLoading = false
            isBusy = false
            syncAudio()
            drainPendingSynchronization()
        }
        let loaded: GameSnapshot
        let loadDisposition: SaveLoadDisposition
        do {
            #if DEBUG
            if let fixture = fixtures.initialSnapshot {
                try await repository.save(fixture)
                fixtures.initialSnapshot = nil
            }
            #endif
            loaded = try await repository.loadOrCreate(now: Date())
            loadDisposition = await repository.lastLoadDisposition
        } catch {
            loadFailed = true
            snapshot = nil
            return
        }
        // A successful read remains usable even if reconciliation cannot write.
        snapshot = loaded
        GameLocalization.shared.language = loaded.settings.language
            ?? GameLanguage.preferred(in: Locale.preferredLanguages)
        startupProgress = 1.0 / 3
        startupPhase = "welcome.syncing"
        await Task.yield()
        let loadDate = Date()
        let hadCatRest = loaded.cats.contains { $0.activeRest != nil }
        for cat in loaded.cats {
            if let rest = cat.activeRest {
                restTransitions.append(RestTransition(catID: cat.id, furnitureID: nil,
                    sessionID: rest.id, occurredAt: loadDate))
            }
        }
        if var context = saveContext() {
            _ = GameEngine.synchronize(&context.candidate, now: loadDate)
            if context.candidate != context.original {
                do { try await commit(context) }
                catch { recordSaveFailure() }
            }
        }
        startupProgress = 2.0 / 3
        startupPhase = "welcome.preparingRoom"
        await RoomScene.preloadWelcomeResources()
        startupProgress = 1
        startupPhase = "welcome.ready"
        now = Date()
        lastSyncCheck = now
        var notices: [String] = []
        if case .recoveredBackup = loadDisposition { notices.append(GameStrings.text("save.recovered")) }
        if hadCatRest { notices.append(GameStrings.text("rest.loadEnded")) }
        if !notices.isEmpty { showNotice(notices.joined(separator: "\n")) }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        syncAudio()
        now = Date()
        timerTask?.cancel()
        timerTask = nil
        if snapshot != nil { synchronize(showNotice: active) }
        guard active else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                guard let self else { break }
                self.now = Date()
                guard self.snapshot != nil else { continue }
                let workDue = self.snapshot?.player.activeWork.map { $0.endsAt <= self.now } ?? false
                let restDue = self.snapshot?.cats.contains { $0.activeRest.map { $0.endsAt <= self.now } ?? false } ?? false
                if workDue || restDue || self.now.timeIntervalSince(self.lastSyncCheck) >= 60 {
                    self.synchronize(showNotice: true)
                }
            }
        }
    }

    func feed() {
        guard !isDecorating, !isBusy, let cat else { return }
        audio.noteUserInteraction()
        guard hasFood else { showNotice(GameStrings.text("care.needFood")); activeSheet = .shop; return }
        perform(returnsToRoom: activeSheet == .inventory) { state, now in
            GameEngine.feed(&state, catID: cat.id, now: now)
        }
    }

    func clean() {
        guard !isDecorating, !isBusy, let cat else { return }
        audio.noteUserInteraction()
        guard (snapshot?.inventory.litter ?? 0) > 0 else { showNotice(GameStrings.text("care.needLitter")); activeSheet = .shop; return }
        perform(returnsToRoom: activeSheet == .inventory) { state, now in
            GameEngine.clean(&state, catID: cat.id, now: now)
        }
    }

    func play() {
        guard !isDecorating, !isBusy, let cat else { return }
        audio.noteUserInteraction()
        guard (snapshot?.inventory.toys ?? 0) > 0 else { showNotice(GameStrings.text("care.needToy")); activeSheet = .shop; return }
        perform(returnsToRoom: activeSheet == .inventory) { state, now in
            GameEngine.play(&state, catID: cat.id, now: now)
        }
    }

    func buyFood() { perform { GameEngine.buyFood(&$0, quantity: 1, now: $1) } }
    func buyLitter() { perform { GameEngine.buyLitter(&$0, quantity: 1, now: $1) } }
    func buyToy() { perform { GameEngine.buyToy(&$0, quantity: 1, now: $1) } }
    func startWork(jobID: String = "job_flyer") {
        perform { GameEngine.startWork(&$0, jobID: jobID, now: $1) }
    }

    func consumeWorkResultPresentation() {
        pendingWorkResultID = nil
    }
    func startSleep() { perform { GameEngine.startSleep(&$0, now: $1) } }
    func wakeUp() { perform { GameEngine.wakeUp(&$0, now: $1) } }

    func beginDecorating() {
        guard !isBusy, let snapshot else { return }
        guard !isDecorating else { return }
        draftBowlPosition = snapshot.home.bowlPosition
        draftFurniture = snapshot.home.furniture
        selectedFurnitureID = nil
        placingFurnitureID = nil
        isResolvingLayout = false
        isDecorating = true
    }

    func openInventory() {
        guard !isSavingLayout else { return }
        inventoryCategory = .supplies
        activeSheet = .inventory
    }

    var language: GameLanguage { GameLocalization.shared.language }
    var homeDisplayName: String { snapshot?.home.name ?? GameStrings.text("home.title") }
    var playerDisplayName: String { snapshot?.player.profile.name ?? GameStrings.text("player.name.default") }

    @discardableResult
    func renamePlayer(to rawName: String?) async -> Bool {
        guard !isBusy, !isDecorating, var context = saveContext() else { return false }
        var candidate = context.candidate
        let name: String?
        if let rawName {
            guard let normalized = PlayerNameRules.normalized(rawName) else { return false }
            name = normalized
        } else {
            name = nil
        }
        guard candidate.player.profile.name != name else { return true }
        // This cosmetic change must preserve the latest career, equipment,
        // home and sound preferences, and publish only after a durable write.
        candidate.player.profile.name = name
        isBusy = true
        defer { isBusy = false; drainPendingSynchronization() }
        do {
            context.candidate = candidate
            try await commit(context)
            audio.play(.tap, userInitiated: true)
            return true
        } catch {
            recordSaveFailure(showAlert: false)
            // The name editor keeps the draft and presents an inline error.
            // Its saved display name remains unchanged for a safe retry.
            return false
        }
    }

    func selectAvatar(_ id: String) {
        perform { GameEngine.selectAvatar(&$0, avatarID: id, now: $1) }
    }

    func equipItem(_ id: String) {
        perform { GameEngine.equipItem(&$0, itemID: id, now: $1) }
    }

    func unequipSlot(_ slot: EquipmentSlot) {
        perform { GameEngine.unequipSlot(&$0, slot: slot, now: $1) }
    }

    func equipStarterSet() {
        perform { GameEngine.equipStarterSet(&$0, now: $1) }
    }

    func openSettings() {
        guard !isBusy, !isDecorating else { return }
        isShowingSettings = true
    }

    func setLanguage(_ language: GameLanguage) {
        guard !isBusy, var context = saveContext(),
              context.candidate.settings.language != language else { return }
        var candidate = context.candidate
        // Use the same serialized save path as care and room changes. Only
        // publish the new preference after a successful atomic save, so an
        // unsuccessful write never presents a language that won't survive restart.
        isBusy = true
        candidate.settings.language = language
        Task {
            do {
                context.candidate = candidate
                try await commit(context)
                GameLocalization.shared.language = language
                showNotice(GameStrings.text("settings.languageSaved"))
            } catch {
                recordSaveFailure()
            }
            isBusy = false
            drainPendingSynchronization()
        }
    }

    @discardableResult
    func setHomeName(_ rawName: String?) async -> Bool {
        guard !isBusy, !isDecorating, var context = saveContext() else { return false }
        var candidate = context.candidate
        let name: String?
        if let rawName {
            guard let normalized = HomeNameRules.normalized(rawName) else { return false }
            name = normalized
        } else {
            // Restoring the localized default is explicit; invalid/empty input
            // must never accidentally erase an existing custom name.
            name = nil
        }
        guard candidate.home.name != name else { return true }
        candidate.home.name = name
        isBusy = true
        defer {
            isBusy = false
            drainPendingSynchronization()
        }
        do {
            context.candidate = candidate
            try await commit(context)
            return true
        } catch {
            recordSaveFailure()
            return false
        }
    }

    func openFurnitureInventory() {
        guard !isSavingLayout, !isResolvingLayout else { return }
        inventoryCategory = .furniture
        activeSheet = .inventory
    }

    func setLayoutResolving(_ resolving: Bool) {
        isResolvingLayout = isDecorating && resolving
    }

    func moveBowl(to point: NormalizedPoint) {
        // Realtime autosaves must not discard a user's in-progress layout draft.
        // Only an explicit layout commit freezes further edits.
        guard isDecorating, !isSavingLayout else { return }
        draftBowlPosition = point
    }

    func selectFurniture(id: String?) {
        guard isDecorating, !isSavingLayout else { return }
        guard let id else { selectedFurnitureID = nil; return }
        guard snapshot?.inventory.furniture.contains(where: { $0.id == id }) == true,
              draftFurniture?.contains(where: { $0.itemID == id }) == true else { return }
        selectedFurnitureID = id
    }

    func moveFurniture(id: String, to point: NormalizedPoint) {
        guard isDecorating, !isSavingLayout, var furniture = draftFurniture,
              snapshot?.inventory.furniture.contains(where: { $0.id == id }) == true,
              point.x.isFinite, point.y.isFinite,
              (0...1).contains(point.x), (0...1).contains(point.y) else { return }
        if let index = furniture.firstIndex(where: { $0.itemID == id }) {
            furniture[index].position = point
        } else {
            guard placingFurnitureID == id else { return }
            furniture.append(FurniturePlacement(itemID: id, position: point))
        }
        draftFurniture = furniture
        selectedFurnitureID = id
    }

    func storeSelectedFurniture() {
        guard canStoreSelectedFurniture, let id = selectedFurnitureID else { return }
        draftFurniture?.removeAll { $0.itemID == id }
        selectedFurnitureID = nil
        showNotice(GameStrings.text("layout.stored"))
    }

    func placeFurniture(id: String) {
        guard !isBusy, !isSavingLayout, !isResolvingLayout,
              storedFurniture.contains(where: { $0.id == id }) else { return }
        if !isDecorating { beginDecorating() }
        guard isDecorating else { return }
        activeSheet = nil
        selectedFurnitureID = id
        placingFurnitureID = id
        isResolvingLayout = true
    }

    func finishFurniturePlacement(id: String, succeeded: Bool) {
        guard isDecorating, placingFurnitureID == id else { return }
        placingFurnitureID = nil
        isResolvingLayout = false
        if succeeded, draftFurniture?.contains(where: { $0.itemID == id }) == true {
            selectedFurnitureID = id
            showNotice(GameStrings.text("layout.placed"))
        } else {
            draftFurniture?.removeAll { $0.itemID == id }
            selectedFurnitureID = nil
            showNotice(GameStrings.text("layout.noSpace"))
        }
    }

    func cancelDecorating() {
        guard !isSavingLayout else { return }
        clearLayoutDraft()
    }

    private func clearLayoutDraft() {
        draftBowlPosition = nil
        draftFurniture = nil
        selectedFurnitureID = nil
        placingFurnitureID = nil
        isResolvingLayout = false
        isDecorating = false
    }

    func finishDecorating() {
        guard isDecorating, !isResolvingLayout, placingFurnitureID == nil,
              let point = draftBowlPosition, let furniture = draftFurniture else { return }
        perform(finishesLayout: true) {
            GameEngine.setRoomLayout(&$0, bowlPosition: point, furniture: furniture, now: $1)
        }
    }

    func inspectCat() {
        guard !isDecorating else { return }
        audio.play(.catMeow, userInitiated: true)
        activeSheet = .town
    }

    private func perform(finishesLayout: Bool = false, returnsToRoom: Bool = false,
                         _ action: @escaping (inout GameSnapshot, Date) -> ActionOutcome) {
        guard !isBusy, var context = saveContext() else { return }
        isBusy = true
        isSavingLayout = finishesLayout
        let actionDate = Date()
        now = actionDate
        _ = GameEngine.synchronize(&context.candidate, now: actionDate)
        let outcome = action(&context.candidate, actionDate)
        guard context.candidate != context.original || outcome.succeeded else {
            isBusy = false
            isSavingLayout = false
            showNotice(message(for: outcome))
            drainPendingSynchronization()
            return
        }
        Task {
            do {
                try await commit(context)
                if finishesLayout && outcome.succeeded { clearLayoutDraft() }
                if outcome.succeeded {
                    if returnsToRoom && activeSheet == .inventory { activeSheet = nil }
                    feedback = RoomFeedback(kind: outcome.kind)
                    playCommittedSound(outcome.kind)
                }
                showNotice(message(for: outcome))
            } catch {
                recordSaveFailure()
            }
            isBusy = false
            isSavingLayout = false
            drainPendingSynchronization()
        }
    }

    private func synchronize(showNotice: Bool, userInitiated: Bool = false) {
        guard snapshot != nil else { return }
        guard !isBusy else { pendingSynchronization = true; return }
        guard userInitiated || saveRetry.permitsAutomaticAttempt(at: Date()) else { return }
        guard var context = saveContext() else { return }
        lastSyncCheck = Date()
        _ = GameEngine.synchronize(&context.candidate, now: lastSyncCheck)
        // Advancing only the sync timestamp does not require a disk write.
        var comparable = context.candidate
        comparable.meta.lastSyncAt = context.original.meta.lastSyncAt
        guard comparable != context.original else {
            acknowledgeTransitions(context.transitions)
            return
        }
        isBusy = true
        Task {
            do { try await commit(context) }
            catch { recordSaveFailure() }
            isBusy = false
            drainPendingSynchronization()
        }
    }

    private func drainPendingSynchronization() {
        guard !isBusy else { return }
        if !restTransitions.isEmpty {
            processNextRestTransition()
            return
        }
        guard pendingSynchronization else { return }
        pendingSynchronization = false
        synchronize(showNotice: foreground)
    }

    private func playCommittedSound(_ kind: ActionKind) {
        switch kind {
        case .purchase: audio.play(.purchase, userInitiated: true)
        case .workStarted: audio.play(.workStart, userInitiated: true)
        case .workFinished: audio.play(.workComplete)
        case .layout: audio.play(.place, userInitiated: true)
        case .sleepStarted: audio.play(.sleep, userInitiated: true)
        case .sleepEnded: audio.play(.wake, userInitiated: true)
        case .none: audio.play(.tap, userInitiated: true)
        // Care sounds are emitted by the actor at the actual contact/gesture.
        case .feed, .clean, .play, .catRestStarted, .catRestEnded: break
        }
    }

    private func showNotice(_ message: String) {
        guard hasEnteredHome else {
            // Loading and foreground synchronization can finish while the player
            // is still on the welcome screen. Start the toast only on entry.
            startupNotice = message
            return
        }
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.toast = nil
        }
    }

    private func message(for outcome: ActionOutcome) -> String {
        if outcome.succeeded {
            switch outcome.kind {
            case .feed: return GameStrings.text("action.feed")
            case .clean: return GameStrings.text("action.clean")
            case .play: return GameStrings.text("action.play")
            case .purchase: return GameStrings.text("action.purchase")
            case .workStarted:
                if let active = snapshot?.player.activeWork, let job = WorkCatalog.job(id: active.jobID) {
                    if let quote = active.quote, quote.durationSeconds != quote.baseDurationSeconds {
                        return GameStrings.text("work.benefitsApplied") + " · "
                            + GameStrings.format("work.durationSeconds", quote.durationSeconds / 60, quote.durationSeconds % 60)
                    }
                    return GameStrings.format("career.started", GameStrings.text("jobs.\(job.id).name"), job.durationMinutes)
                }
                return GameStrings.text("action.workStarted")
            case .workFinished: return GameStrings.format("action.workFinished", outcome.amount)
            case .sleepStarted, .sleepEnded, .catRestStarted, .catRestEnded:
                return GameStrings.text(outcome.messageKey)
            case .layout: return GameStrings.text("layout.saved")
            case .none: return GameStrings.text(outcome.messageKey)
            }
        }
        switch outcome.messageKey {
        case "player.avatarMissing", "equipment.itemMissing", "equipment.notOwned",
             "sleep.workActive", "work.sleeping", "rest.invalidFurniture",
             "work.jobMissing", "work.levelRequired", "work.progressLimit":
            return GameStrings.text(outcome.messageKey)
        case "room.invalidPosition", "room.invalidFurnitureLayout": return GameStrings.text("layout.invalid")
        case "shop.goldRequired": return GameStrings.text("action.insufficientGold")
        case "work.staminaRequired": return GameStrings.text("action.insufficientStamina")
        case "care.foodRequired": return GameStrings.text("care.needFood")
        case "care.litterRequired": return GameStrings.text("care.needLitter")
        case "care.toyRequired": return GameStrings.text("care.needToy")
        case "shop.inventoryFull": return GameStrings.text("action.full")
        default: return GameStrings.text("action.failed")
        }
    }
}
