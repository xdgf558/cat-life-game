import Foundation
import CatGameCore

enum GameMusicTrack: String, CaseIterable, Sendable {
    // Home playlist (7)
    case home = "bgm-home"
    case night = "bgm-night"
    case sleep = "bgm-sleep"
    case upstairs = "bgm-upstairs"
    case rainyWindow = "bgm-rainy-window"
    case starlitHearth = "bgm-starlit-hearth"
    case gardenAfternoon = "bgm-garden-afternoon"
    // Workshop playlist (4)
    case work = "bgm-work"
    case town = "bgm-town"
    case promenade = "bgm-promenade"
    case shop = "bgm-shop"

    static let homeTracks: [GameMusicTrack] = [
        .home, .night, .sleep, .upstairs, .rainyWindow, .starlitHearth, .gardenAfternoon
    ]
    static let workshopTracks: [GameMusicTrack] = [
        .work, .town, .promenade, .shop
    ]

    var fileName: String { rawValue }
    var fileExtension: String { "m4a" }
    var isHomeTrack: Bool { Self.homeTracks.contains(self) }

    var sceneKey: String {
        isHomeTrack ? "audio.scene.home" : "audio.scene.workshop"
    }

    var title: String {
        switch self {
        case .home: "Sunlit Little Home"
        case .night: "Lamp-lit Room"
        case .sleep: "Paws at Rest"
        case .upstairs: "Warm Loft Sun"
        case .rainyWindow: "Rainy Window"
        case .starlitHearth: "Starlit Hearth"
        case .gardenAfternoon: "Garden Afternoon"
        case .work: "Little Steps to Payday"
        case .town: "Town Stroll"
        case .promenade: "Cat Town Promenade"
        case .shop: "Bell Over the Door"
        }
    }
}

enum GameSoundEffect: String, CaseIterable, Sendable {
    case tap = "sfx-tap"
    case place = "sfx-place"
    case merge = "sfx-claim"
    case coins = "sfx-coins"
    case purchase = "sfx-purchase"
    case feed = "sfx-feed"
    case catHappy = "cat-happy"
    case pet = "cat-purr"
    case photo = "sfx-pin"
    case levelUp = "sfx-level-up"

    var fileName: String { rawValue }
    var fileExtension: String { "wav" }

    var isCatVoice: Bool {
        self == .catHappy || self == .pet
    }

    var priority: Int {
        switch self {
        case .levelUp, .photo, .coins, .purchase: 3
        case .catHappy, .pet, .merge: 2
        case .feed, .place: 1
        case .tap: 0
        }
    }

    var ducksMusic: Bool {
        isCatVoice || self == .levelUp || self == .photo
    }

    var successHaptic: Bool { self == .levelUp || self == .photo || self == .coins }
    var lightHaptic: Bool { self == .merge || self == .purchase || self == .feed }
}

/// Pure audio policy shared by runtime playback and unit tests.
enum GameAudioPolicy {
    static let simultaneousEffects = 3
    static func isQuietHour(_ hour: Int) -> Bool { hour < 7 || hour >= 22 }

    static func track(_ requested: GameMusicTrack, settings: AudioSettings, hour: Int) -> GameMusicTrack {
        guard settings.sceneMusic else { return .home }
        return requested.isHomeTrack && settings.nightQuiet && isQuietHour(hour) ? .night : requested
    }

    static func musicVolume(settings: AudioSettings, hour: Int, ducked: Bool) -> Float {
        Float(settings.musicVolume * (settings.nightQuiet && isQuietHour(hour) ? 0.7 : 1) * (ducked ? 0.5 : 1))
    }

    static func effectVolume(_ effect: GameSoundEffect, settings: AudioSettings) -> Float {
        if effect.isCatVoice { return settings.catEnabled ? Float(settings.catVolume) : 0 }
        return settings.effectsEnabled ? Float(settings.effectsVolume) : 0
    }

    static func replacementIndex(for incoming: GameSoundEffect, active: [GameSoundEffect]) -> Int? {
        guard active.count >= simultaneousEffects,
              let lowest = active.indices.min(by: { active[$0].priority < active[$1].priority }),
              active[lowest].priority < incoming.priority else { return nil }
        return lowest
    }
}
