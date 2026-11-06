#if DEBUG
import Foundation
import CatGameCore

/// Fixture parsing and fault injection do not exist in Release builds.
struct GameStoreFixtures {
    var initialSnapshot: GameSnapshot?
    private var futureLoadFailure = false
    private var damagedLoadFailure = false
    var failRestExitOnce = false
    var failWorkCompletionOnce = false
    private var failTaskClaimOnce = false
    private var failCatRenameOnce = false
    private var failCatAdoptionOnce = false
    private var failCatSelectionOnce = false
    private var failTreatmentOnce = false
    private var failUserSaves = false
    private var outageStarted = false

    init(arguments: [String] = [], allowsSeeding: Bool = false, now: Date = Date()) {
        guard arguments.contains("--ui-testing") else { return }
        failUserSaves = arguments.contains("--save-outage-test")
        failRestExitOnce = arguments.contains("--recovery-end-failure-once")
        let reset = allowsSeeding && arguments.contains("--reset-ui-test-save")
        failWorkCompletionOnce = reset && arguments.contains("--career-save-failure-once")
        failTaskClaimOnce = reset && arguments.contains("--task-claim-save-failure-once")
        failCatRenameOnce = reset && arguments.contains("--cat-name-save-failure-once")
        failCatAdoptionOnce = reset && arguments.contains("--cat-adoption-save-failure-once")
        failCatSelectionOnce = reset && arguments.contains("--cat-companion-save-failure-once")
        failTreatmentOnce = reset && arguments.contains("--hospital-save-failure-once")
        guard reset else { return }
        futureLoadFailure = arguments.contains("--save-load-future-fixture")
        damagedLoadFailure = arguments.contains("--save-load-damaged-fixture")
        if futureLoadFailure || damagedLoadFailure { return }
        if arguments.contains("--uitesting-siamese-owned") || arguments.contains("--uitesting-silver-owned") {
            var value = GameSnapshot.fresh(now: now)
            let appearance: CatAppearance = arguments.contains("--uitesting-siamese-owned") ? .siamese : .silver
            let offer = CatCatalog.adoptionOffers.first { $0.appearance == appearance }!
            value.player.level = 8
            value.player.gold = 5000
            value.home.roomLevel = 3
            value.inventory.food = 3
            value.inventory.litter = 2
            value.inventory.toys = 6
            value.cats.append(CatState(id: offer.id, name: offer.name, satiety: 70,
                cleanliness: 80, mood: 80, energy: 85, health: 100, now: now, appearance: appearance))
            value.activeCatID = offer.id
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            initialSnapshot = value
        } else if arguments.contains("--community-fixture") {
            var value = GameSnapshot.fresh(now: now)
            value.player.level = 8
            value.player.gold = 5000
            value.home.roomLevel = 3
            value.inventory.toys = 6
            value.inventory.gifts = ["flower": 2, "drink": 1]
            value.community.relationships["neighbor_mira"] = NeighborRelationship(friendship: 18)
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            initialSnapshot = value
        } else if arguments.contains("--hospital-fixture") {
            var value = GameSnapshot.fresh(now: now)
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            value.player.gold = arguments.contains("--hospital-low-gold") ? 10 : 1000
            value.cats[0].health = 50
            value.cats[0].healthState = CatHealthState(illness: .cold, riskPoints: 8,
                lastEvaluatedAt: now, protectedUntil: now.addingTimeInterval(-3600))
            value.cats.append(CatState(id: CatCatalog.cowCatID, name: "牛奶", satiety: 70,
                cleanliness: 80, mood: 85, energy: 80, health: 90, now: now, appearance: .cow))
            initialSnapshot = value
        } else if arguments.contains("--tasks-level10-fixture") || arguments.contains("--tasks-level-up-fixture") {
            var value = GameSnapshot.fresh(now: now)
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            if arguments.contains("--tasks-level10-fixture") {
                value.player.level = 10
                value.player.completedWorkCount = 10
                value.tasks.dailyWorkCount = 3
                value.tasks.totalFeedCount = 2
                value.tasks.dailyFeedCount = 2
                value.tasks.dailyPlayCount = 2
                value.tasks.dailyCleanCount = 1
                value.tasks.totalCleanCount = 30
                value.community.relationships["neighbor_mira"] = NeighborRelationship(
                    friendship: 40, visitedToday: true, giftsGivenToday: 1,
                    totalVisitCount: 10, totalGiftCount: 10, rewardedStageLevels: [2, 3])
            } else {
                value.player.exp = 99
                _ = GameEngine.feed(&value, catID: value.activeCatID, now: now)
                value.player.completedWorkCount = 2
                value.tasks.dailyWorkCount = 2
            }
            initialSnapshot = value
        } else if arguments.contains(where: {
            ["--uitesting-adoption-ready", "--uitesting-adoption-owned",
             "--uitesting-blue-adoption-ready", "--uitesting-blue-adoption-owned"].contains($0)
        }) {
            let blueReady = arguments.contains("--uitesting-blue-adoption-ready")
            let blueOwned = arguments.contains("--uitesting-blue-adoption-owned")
            var value = GameSnapshot.fresh(now: now)
            value.player.level = blueReady || blueOwned ? 4 : 2
            value.player.gold = 1000
            value.home.roomLevel = blueReady || blueOwned ? 3 : 2
            value.inventory.toys = 6
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            if arguments.contains("--uitesting-adoption-owned") || blueReady || blueOwned {
                value.cats.append(CatState(id: CatCatalog.cowCatID, name: "牛奶", satiety: 55,
                                          cleanliness: 65, mood: 70, intimacy: 20, energy: 60,
                                          health: 95, now: now, appearance: .cow))
            }
            if blueOwned {
                value.cats.append(CatState(id: CatCatalog.blueCatID, name: "蓝影", satiety: 70,
                                          cleanliness: 85, mood: 80, intimacy: 10, energy: 85,
                                          health: 100, now: now, appearance: .blue))
            }
            initialSnapshot = value
        } else if arguments.contains("--cat-collection-fixture") {
            var value = GameSnapshot.fresh(now: now)
            value.cats += (2...9).map { index in
                CatState(id: String(format: "cat_%03d", index), name: "猫咪\(index)",
                         satiety: 60 + index, cleanliness: 70 + index, mood: 80 + index,
                         intimacy: 10 + index, energy: 50 + index, health: 90 + index, now: now)
            }
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            initialSnapshot = value
        } else if arguments.contains("--shop-upgrade-fixture") || arguments.contains("--room-zoom-fixture") {
            var value = GameSnapshot.fresh(now: now)
            value.player.level = 4
            value.player.gold = 5000
            if arguments.contains("--room-zoom-fixture") { value.home.roomLevel = 3 }
            value.settings.audio = AudioSettings(musicEnabled: false, effectsEnabled: false)
            initialSnapshot = value
        } else if let fixture = arguments.first(where: {
            ["--career-completion-fixture", "--career-active-fixture", "--career-level10-fixture",
             "--player-equipped-active-fixture"].contains($0)
        }) {
            let offset: TimeInterval = fixture == "--player-equipped-active-fixture" ? -57 :
                (fixture == "--career-completion-fixture" ? -130 : (fixture == "--career-active-fixture" ? -195 : 0))
            let started = now.addingTimeInterval(offset)
            var value = GameSnapshot.fresh(now: started)
            if fixture == "--player-equipped-active-fixture" {
                _ = GameEngine.equipStarterSet(&value, now: started)
                _ = GameEngine.startWork(&value, now: started)
            } else if fixture == "--career-completion-fixture" {
                value.player.exp = 90
                _ = GameEngine.startWork(&value, now: started)
            } else {
                value.player.level = fixture == "--career-active-fixture" ? 4 : 10
                value.player.stamina = 100
                value.player.mood = 100
                if fixture == "--career-active-fixture" {
                    _ = GameEngine.startWork(&value, jobID: "job_petshop", now: started)
                }
            }
            initialSnapshot = value
        } else if arguments.contains("--recovery-sleep-fixture") {
            let started = now.addingTimeInterval(-1800)
            var value = GameSnapshot.fresh(now: started)
            value.player.stamina = 40
            value.player.mood = 50
            value.player.gold = 180
            value.inventory.food = 4
            _ = GameEngine.startSleep(&value, now: started)
            initialSnapshot = value
        }
    }

    func seedLoadFailureFiles(in directory: URL) throws {
        guard futureLoadFailure || damagedLoadFailure else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let primary = futureLoadFailure
            ? "{\"schemaVersion\":\(GameSnapshot.currentSchemaVersion + 1)}"
            : "UITest damaged primary"
        let backup = futureLoadFailure
            ? "{\"schemaVersion\":\(GameSnapshot.currentSchemaVersion + 1),\"fixtureBackup\":true}"
            : "UITest damaged backup"
        try Data(primary.utf8).write(to: directory.appendingPathComponent("cat-life-native-v1.json"), options: .atomic)
        try Data(backup.utf8).write(to: directory.appendingPathComponent("cat-life-native-v1.backup.json"), options: .atomic)
    }

    func checkStorageProbe() throws {
        if failUserSaves && outageStarted { throw CocoaError(.fileWriteUnknown) }
    }

    mutating func checkSave(_ candidate: GameSnapshot, original: GameSnapshot,
                            exitsRest: Bool) throws {
        if failTreatmentOnce, candidate.player.gold < original.player.gold,
           original.cats.contains(where: { old in
               old.healthState?.illness != nil
                   && candidate.cats.first(where: { $0.id == old.id })?.healthState?.illness == nil
           }) {
            failTreatmentOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failTaskClaimOnce && (candidate.tasks.claimedTaskIDs != original.tasks.claimedTaskIDs
            || candidate.tasks.dailyClaimedTaskIDs != original.tasks.dailyClaimedTaskIDs) {
            failTaskClaimOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failCatAdoptionOnce && candidate.cats.count > original.cats.count {
            failCatAdoptionOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failCatSelectionOnce && candidate.activeCatID != original.activeCatID {
            failCatSelectionOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failCatRenameOnce && candidate.cats.map(\.customName) != original.cats.map(\.customName) {
            failCatRenameOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failUserSaves && (outageStarted || candidate.inventory != original.inventory) {
            outageStarted = true
            throw CocoaError(.fileWriteUnknown)
        }
        if exitsRest && failRestExitOnce {
            failRestExitOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
        if failWorkCompletionOnce, let receipt = candidate.player.lastWorkResult,
           receipt.id != original.player.lastWorkResult?.id {
            failWorkCompletionOnce = false
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
#endif
