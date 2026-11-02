
import Foundation
final class AVAudioSession: @unchecked Sendable {
    static let instance = AVAudioSession()
    static func sharedInstance() -> AVAudioSession { instance }
    enum Category { case ambient }
    enum Mode { case `default` }
    enum InterruptionType: UInt { case began = 1, ended = 0 }
    enum RouteChangeReason: UInt { case oldDeviceUnavailable = 2 }
    struct InterruptionOptions: OptionSet { let rawValue: UInt; static let shouldResume = Self(rawValue: 1) }
    struct SetActiveOptions: OptionSet { let rawValue: UInt; static let notifyOthersOnDeactivation = Self(rawValue: 1) }
    static let interruptionNotification = Notification.Name("audio.test.interruption")
    static let routeChangeNotification = Notification.Name("audio.test.route")
    static let mediaServicesWereResetNotification = Notification.Name("audio.test.reset")
    static let silenceSecondaryAudioHintNotification = Notification.Name("audio.test.hint")
    private let lock = NSLock()
    private var delay = 0.04
    private var fail = false
    private var calls: [String] = []
    private var active = false
    var secondaryAudioShouldBeSilencedHint: Bool { false }
    func configure(delay: Double, fail: Bool = false) { lock.lock(); self.delay = delay; self.fail = fail; lock.unlock() }
    func state() -> (active: Bool, activationCount: Int, mainCalls: Int) {
        lock.lock(); defer { lock.unlock() }
        return (active, calls.filter { $0 == "on" }.count, calls.filter { $0 == "MAIN" }.count)
    }
    func setCategory(_ category: Category, mode: Mode) throws {
        lock.lock(); if Thread.isMainThread { calls.append("MAIN") }; calls.append("category"); lock.unlock()
    }
    func setActive(_ value: Bool, options: SetActiveOptions = []) throws {
        lock.lock(); if Thread.isMainThread { calls.append("MAIN") }; calls.append(value ? "on" : "off")
        let wait = delay; let shouldFail = fail; lock.unlock()
        if value { Thread.sleep(forTimeInterval: wait) }
        if value && shouldFail { throw NSError(domain: "test", code: 1) }
        lock.lock(); active = value; lock.unlock()
    }
}
let AVAudioSessionInterruptionTypeKey = "type"
let AVAudioSessionInterruptionOptionKey = "options"
let AVAudioSessionRouteChangeReasonKey = "reason"
@MainActor final class AVAudioPlayer {
    var isPlaying = false
    var currentTime: Double = 0
    var volume: Float = 1
    var numberOfLoops = 0
    init(contentsOf url: URL) throws {}
    @discardableResult func prepareToPlay() -> Bool { true }
    func play() -> Bool { isPlaying = true; return true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false }
    func setVolume(_ volume: Float, fadeDuration: Double) { self.volume = volume }
}
struct AudioTestBundle {
    static let main = AudioTestBundle()
    func url(forResource name: String, withExtension ext: String, subdirectory: String) -> URL? {
        URL(fileURLWithPath: "/audio-test/\(name).\(ext)")
    }
}

import Foundation

public enum GameLanguage: String, Codable, CaseIterable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    /// Resolve the first supported system preference. An explicit Chinese
    /// script takes precedence over its region (for example, zh-Hans-TW).
    public static func preferred(in preferredLanguages: [String]) -> GameLanguage {
        for language in preferredLanguages {
            let components = language.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "-")
                .lowercased().split(separator: "-")
            guard let base = components.first else { continue }
            if base == "en" { return .english }
            guard base == "zh" else { continue }
            if components.contains("hant") { return .traditionalChinese }
            if components.contains("hans") { return .simplifiedChinese }
            if components.contains(where: { ["tw", "hk", "mo"].contains($0) }) {
                return .traditionalChinese
            }
            return .simplifiedChinese
        }
        return .simplifiedChinese
    }
}

/// Optional presentation preferences must not invalidate earned game progress.
/// Volume setters keep runtime edits as safe to encode as decoded preferences.
public struct AudioSettings: Codable, Equatable, Sendable {
    public static let defaultMusicVolume = 0.35
    public static let defaultEffectsVolume = 0.65

    public var musicEnabled: Bool
    public var effectsEnabled: Bool
    private var storedMusicVolume: Double
    private var storedEffectsVolume: Double

    public var musicVolume: Double {
        get { storedMusicVolume }
        set { storedMusicVolume = Self.normalized(newValue, fallback: Self.defaultMusicVolume) }
    }

    public var effectsVolume: Double {
        get { storedEffectsVolume }
        set { storedEffectsVolume = Self.normalized(newValue, fallback: Self.defaultEffectsVolume) }
    }

    public init(musicEnabled: Bool = true, effectsEnabled: Bool = true,
                musicVolume: Double = Self.defaultMusicVolume,
                effectsVolume: Double = Self.defaultEffectsVolume) {
        self.musicEnabled = musicEnabled
        self.effectsEnabled = effectsEnabled
        storedMusicVolume = Self.normalized(musicVolume, fallback: Self.defaultMusicVolume)
        storedEffectsVolume = Self.normalized(effectsVolume, fallback: Self.defaultEffectsVolume)
    }

    private enum CodingKeys: String, CodingKey {
        case musicEnabled, effectsEnabled, musicVolume, effectsVolume
    }

    public init(from decoder: Decoder) throws {
        guard let values = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.init()
            return
        }
        self.init(musicEnabled: (try? values.decode(Bool.self, forKey: .musicEnabled)) ?? true,
                  effectsEnabled: (try? values.decode(Bool.self, forKey: .effectsEnabled)) ?? true,
                  musicVolume: (try? values.decode(Double.self, forKey: .musicVolume)) ?? Self.defaultMusicVolume,
                  effectsVolume: (try? values.decode(Double.self, forKey: .effectsVolume)) ?? Self.defaultEffectsVolume)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(musicEnabled, forKey: .musicEnabled)
        try values.encode(effectsEnabled, forKey: .effectsEnabled)
        try values.encode(musicVolume, forKey: .musicVolume)
        try values.encode(effectsVolume, forKey: .effectsVolume)
    }

    private static func normalized(_ volume: Double, fallback: Double) -> Double {
        volume.isFinite ? min(1, max(0, volume)) : fallback
    }
}

public struct GameSettings: Codable, Equatable, Sendable {
    /// nil follows the system preference; a selected language stays in this save.
    public var language: GameLanguage?
    public var audio: AudioSettings

    public init(language: GameLanguage? = nil, audio: AudioSettings = AudioSettings()) {
        self.language = language
        self.audio = audio
    }

    private enum CodingKeys: String, CodingKey { case language, audio }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // An unsupported preference must not discard an otherwise valid game.
        language = (try? values.decode(String.self, forKey: .language))
            .flatMap(GameLanguage.init(rawValue:))
        audio = (try? values.decode(AudioSettings.self, forKey: .audio)) ?? AudioSettings()
    }
}

import Foundation
import Observation

enum GameMusicTrack: String, CaseIterable {
    case home, work, sleep
    var fileName: String { "bgm-\(rawValue)" }
}

enum GameSoundEffect: String, CaseIterable {
    case tap, enter, purchase, place, feed, clean, play, sleep, wake
    case workStart = "work-start"
    case workComplete = "work-complete"
    case catMeow = "cat-meow"
    var fileName: String { "sfx-\(rawValue)" }
}

/// One audio owner per app process. Preferences are committed by GameStore;
/// players and audio-session state are intentionally never part of a game save.
@MainActor
@Observable
final class GameAudioController: NSObject {
    private(set) var settings = AudioSettings()
    private(set) var isForeground = false
    private(set) var currentTrack: GameMusicTrack = .home
    private(set) var musicPlaying = false
    private(set) var effectPlayCount = 0
    private(set) var lastEffect = ""
    private(set) var backgroundPauseCount = 0
    private(set) var assetLoadFailures = 0
    private(set) var interrupted = false
    private(set) var routePaused = false

    @ObservationIgnored private var music: AVAudioPlayer?
    @ObservationIgnored private var loadedTrack: GameMusicTrack?
    @ObservationIgnored private var fadingMusic: AVAudioPlayer?
    @ObservationIgnored private var fadeTask: Task<Void, Never>?
    @ObservationIgnored private var effects: [GameSoundEffect: [AVAudioPlayer]] = [:]
    @ObservationIgnored private var lastPlayed: [GameSoundEffect: TimeInterval] = [:]
    @ObservationIgnored private var ready = false
    @ObservationIgnored private var preparedEffects = false
    @ObservationIgnored private var sessionActive = false
    @ObservationIgnored private var activationInFlight = false
    @ObservationIgnored private var recoveringInterruption = false
    @ObservationIgnored private var sessionGeneration: UInt = 0
    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "com.stationcat.catlife.audio-session")
    @ObservationIgnored private var pendingEffects: [PendingEffect] = []

    private struct PendingEffect {
        let effect: GameSoundEffect
        let requestedAt: TimeInterval
    }

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(receivedInterruption(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(receivedRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(receivedMediaReset(_:)),
                           name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        center.addObserver(self, selector: #selector(receivedSecondaryHint(_:)),
                           name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func configure(settings: AudioSettings, track: GameMusicTrack, foreground: Bool, ready: Bool) {
        if isForeground && !foreground { backgroundPauseCount += 1 }
        let becameActive = !isForeground && foreground
        self.settings = settings
        currentTrack = track
        isForeground = foreground
        self.ready = ready
        if becameActive { routePaused = false }
        if !settings.effectsEnabled || settings.effectsVolume == 0 {
            stopEffects()
            pendingEffects.removeAll()
        }
        for player in effects.values.flatMap({ $0 }) { player.volume = Float(settings.effectsVolume) }
        if !foreground || !ready {
            pauseAll()
            deactivateSession()
            return
        }
        if becameActive { recoverInterruptedSession() }
        reconcileMusic()
    }

    /// Resume on a new explicit action without emitting its effect before the
    /// saved action or scene animation reaches the appropriate sound cue.
    func noteUserInteraction() {
        guard ready, isForeground, routePaused || interrupted else { return }
        routePaused = false
        recoverInterruptedSession()
        reconcileMusic()
    }

    func play(_ effect: GameSoundEffect, userInitiated: Bool = false) {
        guard ready, isForeground else { return }
        if userInitiated { noteUserInteraction() }
        guard !routePaused, !interrupted || recoveringInterruption,
              settings.effectsEnabled, settings.effectsVolume > 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        pendingEffects.removeAll { now - $0.requestedAt > 0.5 }
        let lastRequested = pendingEffects.last(where: { $0.effect == effect })?.requestedAt ?? -100
        guard now - max(lastPlayed[effect] ?? -100, lastRequested) >= minimumGap(for: effect) else { return }
        if !sessionActive {
            // Keep the first fresh cue while activation yields the main actor.
            // Never replay a backlog after a slow activation or a lifecycle change.
            guard pendingEffects.count < 4 else { return }
            pendingEffects.append(PendingEffect(effect: effect, requestedAt: now))
            requestSessionActivation(recoveringInterruption: recoveringInterruption)
            return
        }
        playPreparedEffect(effect)
    }

    private func minimumGap(for effect: GameSoundEffect) -> TimeInterval {
        effect == .catMeow ? 1.2 : (effect == .tap ? 0.065 : 0.15)
    }

    private func playPreparedEffect(_ effect: GameSoundEffect) {
        guard ready, isForeground, sessionActive, !interrupted, !routePaused,
              settings.effectsEnabled, settings.effectsVolume > 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - (lastPlayed[effect] ?? -100) >= minimumGap(for: effect) else { return }
        prepareEffects()
        guard effects.values.flatMap({ $0 }).filter(\.isPlaying).count < 4,
              let player = effects[effect]?.first(where: { !$0.isPlaying }) else { return }
        player.currentTime = 0
        player.volume = Float(settings.effectsVolume)
        if player.play() {
            lastPlayed[effect] = now
            effectPlayCount += 1
            lastEffect = effect.rawValue
        }
    }

    private func prepareEffects() {
        guard !preparedEffects else { return }
        preparedEffects = true
        for effect in GameSoundEffect.allCases {
            effects[effect] = (0..<2).compactMap { _ in makePlayer(effect.fileName) }
        }
    }

    private func reconcileMusic() {
        guard ready, isForeground, !interrupted, !routePaused else { pauseAll(); return }
        guard hasAudibleOutput else {
            pauseAll()
            deactivateSession()
            return
        }
        // Prepare once on welcome/foreground entry even when only effects are
        // enabled, so the first interaction normally already has an active session.
        guard sessionActive else {
            pauseMusic()
            requestSessionActivation()
            return
        }
        guard settings.musicEnabled, settings.musicVolume > 0 else {
            pauseMusic()
            return
        }
        // Ambient mixes with other audio; avoid layering our BGM over a podcast/music app.
        guard !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint else { pauseMusic(); return }
        if loadedTrack != currentTrack || music == nil {
            guard let next = makePlayer(currentTrack.fileName) else { pauseMusic(); return }
            next.numberOfLoops = -1
            next.volume = 0
            guard next.play() else { musicPlaying = false; return }
            fadeTask?.cancel()
            fadingMusic?.stop()
            fadingMusic = music
            fadingMusic?.setVolume(0, fadeDuration: 0.6)
            music = next
            loadedTrack = currentTrack
            next.setVolume(Float(settings.musicVolume), fadeDuration: 0.6)
            fadeTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                self?.fadingMusic?.stop()
                self?.fadingMusic = nil
            }
        } else if let music {
            if !music.isPlaying {
                music.volume = 0
                _ = music.play()
            }
            music.setVolume(Float(settings.musicVolume), fadeDuration: 0.25)
        }
        musicPlaying = music?.isPlaying == true
    }

    private func makePlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = AudioTestBundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Audio") else {
            assetLoadFailures += 1
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            assetLoadFailures += 1
            return nil
        }
    }

    private var hasAudibleOutput: Bool {
        (settings.musicEnabled && settings.musicVolume > 0)
            || (settings.effectsEnabled && settings.effectsVolume > 0)
    }

    private func requestSessionActivation(recoveringInterruption: Bool = false) {
        guard ready, isForeground, !routePaused, hasAudibleOutput,
              !interrupted || recoveringInterruption,
              !sessionActive, !activationInFlight else { return }
        activationInFlight = true
        self.recoveringInterruption = interrupted && recoveringInterruption
        let generation = sessionGeneration
        // Synchronous AVAudioSession calls may wait for system audio services.
        // A serial worker keeps those waits off MainActor on every supported iOS.
        sessionQueue.async { [weak self] in
            let succeeded: Bool
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.ambient, mode: .default)
                try session.setActive(true)
                succeeded = true
            } catch {
                succeeded = false
            }
            Task { @MainActor [weak self] in
                self?.completeSessionActivation(succeeded: succeeded, generation: generation)
            }
        }
    }

    private func completeSessionActivation(succeeded: Bool, generation: UInt) {
        // Invalidation queues deactivation behind any in-flight activation;
        // a stale completion must never publish active state or restart players.
        guard generation == sessionGeneration else { return }
        activationInFlight = false
        let wasRecovering = recoveringInterruption
        recoveringInterruption = false
        guard succeeded else {
            sessionActive = false
            pendingEffects.removeAll()
            musicPlaying = false
            return // Retry only on a later foreground/configuration/user event.
        }
        sessionActive = true
        if wasRecovering { interrupted = false }
        guard ready, isForeground, !interrupted, !routePaused, hasAudibleOutput else {
            pauseAll()
            deactivateSession()
            return
        }
        reconcileMusic()
        if settings.effectsEnabled, settings.effectsVolume > 0 { prepareEffects() }
        let queued = pendingEffects
        pendingEffects.removeAll()
        for request in queued where ProcessInfo.processInfo.systemUptime - request.requestedAt <= 0.5 {
            playPreparedEffect(request.effect)
        }
    }

    private func recoverInterruptedSession() {
        // iOS does not guarantee an ended notification for every interruption.
        // A foreground return or explicit action may try again; an ongoing
        // higher-priority session can reject activation and must stay paused.
        guard interrupted else { return }
        requestSessionActivation(recoveringInterruption: true)
    }

    private func deactivateSession() {
        let needsDeactivation = sessionActive || activationInFlight
        sessionGeneration &+= 1
        sessionActive = false
        activationInFlight = false
        recoveringInterruption = false
        pendingEffects.removeAll()
        guard needsDeactivation else { return }
        sessionQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func pauseMusic() {
        fadeTask?.cancel()
        fadingMusic?.stop()
        fadingMusic = nil
        music?.pause()
        musicPlaying = false
    }

    private func stopEffects() {
        for player in effects.values.flatMap({ $0 }) { player.stop(); player.currentTime = 0 }
    }

    private func pauseAll() { pauseMusic(); stopEffects() }

    @objc nonisolated private func receivedInterruption(_ notification: Notification) {
        let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
        let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
        Task { @MainActor [weak self] in
            guard let self, let type else { return }
            if type == AVAudioSession.InterruptionType.began.rawValue {
                self.interrupted = true
                self.pauseAll()
                self.deactivateSession()
            } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                self.interrupted = false
                if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    self.reconcileMusic()
                } else {
                    self.routePaused = true // Wait for an explicit user action.
                    self.pauseAll()
                    self.deactivateSession()
                }
            }
        }
    }

    @objc nonisolated private func receivedRouteChange(_ notification: Notification) {
        let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
        Task { @MainActor [weak self] in
            guard let self, reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            self.routePaused = true
            self.pauseAll()
            self.deactivateSession()
        }
    }

    @objc nonisolated private func receivedMediaReset(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pauseAll()
            self.deactivateSession()
            self.music = nil
            self.loadedTrack = nil
            self.effects = [:]
            self.preparedEffects = false
            self.interrupted = false
            self.reconcileMusic()
        }
    }

    @objc nonisolated private func receivedSecondaryHint(_ notification: Notification) {
        Task { @MainActor [weak self] in
            // Notifications aren't delivered while we're inactive. Always
            // query the live hint in reconcileMusic rather than caching begin.
            self?.reconcileMusic()
        }
    }
}


extension GameAudioController {
    var testPendingCount: Int { pendingEffects.count }
    var testActivationPending: Bool { activationInFlight }
    func testInterruptionBegan() {
        receivedInterruption(Notification(name: AVAudioSession.interruptionNotification,
            userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.began.rawValue)]))
    }
    func testRouteRemoved() {
        receivedRouteChange(Notification(name: AVAudioSession.routeChangeNotification,
            userInfo: [AVAudioSessionRouteChangeReasonKey: NSNumber(value: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue)]))
    }
}
@main struct AudioStateCheck {
    @MainActor static func settle(_ ms: Int = 100) async { try? await Task.sleep(for: .milliseconds(ms)) }
    @MainActor static func until(_ message: String, _ condition: @MainActor () -> Bool) async {
        for _ in 0..<100 { if condition() { return }; await settle(10) }
        preconditionFailure(message)
    }
    @MainActor static func main() async {
        let session = AVAudioSession.sharedInstance()
        let audio = GameAudioController()
        let normal = AudioSettings()
        func foreground(_ value: Bool, settings: AudioSettings = AudioSettings()) {
            audio.configure(settings: settings, track: .home, foreground: value, ready: true)
        }
        session.configure(delay: 0.15)
        foreground(true)
        audio.play(.enter, userInitiated: true)
        precondition(audio.testPendingCount == 1 && !audio.musicPlaying)
        await settle(25)
        precondition(audio.testActivationPending, "MainActor must yield while the worker waits")
        await until("first fresh cue should play once") { audio.effectPlayCount == 1 && audio.musicPlaying }
        print("PASS fresh first cue and nonblocking activation")

        foreground(false); await settle()
        let beforeCancel = audio.effectPlayCount
        session.configure(delay: 0.2)
        foreground(true); audio.play(.purchase, userInitiated: true); foreground(false)
        await settle(350)
        precondition(!audio.musicPlaying && audio.testPendingCount == 0 && audio.effectPlayCount == beforeCancel && !session.state().active)
        print("PASS background invalidates in-flight activation and queued cue")

        session.configure(delay: 0.65)
        foreground(true); audio.play(.clean, userInitiated: true)
        await until("slow activation should eventually resume BGM") { audio.musicPlaying }
        precondition(audio.effectPlayCount == beforeCancel && audio.testPendingCount == 0)
        print("PASS stale cue older than 0.5 seconds is dropped")

        foreground(false); await settle()
        session.configure(delay: 0.15)
        foreground(true); audio.play(.play, userInitiated: true)
        foreground(true, settings: AudioSettings(musicEnabled: false, effectsEnabled: false))
        await settle(300)
        precondition(!audio.musicPlaying && !session.state().active && audio.effectPlayCount == beforeCancel)
        print("PASS mute invalidates pending activation and playback")

        session.configure(delay: 0.03, fail: true)
        foreground(true)
        await until("activation failure must settle") { !audio.testActivationPending }
        let failures = session.state().activationCount
        await settle(150)
        precondition(session.state().activationCount == failures && !audio.musicPlaying)
        session.configure(delay: 0.03)
        audio.play(.tap, userInitiated: true)
        await until("explicit action should retry once") { audio.musicPlaying && audio.effectPlayCount == beforeCancel + 1 }
        print("PASS activation failure has no retry loop and next explicit cue recovers")

        audio.testInterruptionBegan(); await settle(30)
        precondition(audio.interrupted && !audio.musicPlaying)
        session.configure(delay: 0.03, fail: true)
        audio.noteUserInteraction()
        await until("failed interruption recovery must settle") { !audio.testActivationPending }
        precondition(audio.interrupted && !audio.musicPlaying)
        session.configure(delay: 0.03)
        audio.play(.feed, userInitiated: true)
        await until("successful interruption recovery should restore cue") { !audio.interrupted && audio.musicPlaying && audio.effectPlayCount == beforeCancel + 2 }
        print("PASS interruption clears only after successful reactivation")

        audio.testRouteRemoved(); await settle(30)
        precondition(audio.routePaused && !audio.musicPlaying)
        audio.noteUserInteraction()
        await until("explicit route recovery should restore BGM") { !audio.routePaused && audio.musicPlaying }
        print("PASS route pause recovers without manufacturing an effect")

        foreground(false); await settle()
        session.configure(delay: 0.12)
        foreground(true)
        let beforeBound = audio.effectPlayCount
        for effect in [GameSoundEffect.enter, .purchase, .place, .clean, .play, .wake] { audio.play(effect, userInitiated: true) }
        precondition(audio.testPendingCount == 4)
        await until("bounded queued effects should flush") { audio.effectPlayCount == beforeBound + 4 }
        print("PASS pending effects are bounded to four")

        foreground(false); await settle()
        session.configure(delay: 0.12)
        let beforeRapid = audio.effectPlayCount
        foreground(true); audio.play(.enter, userInitiated: true)
        foreground(false)
        foreground(true); audio.play(.sleep, userInitiated: true)
        await until("new generation should win after old activate/deactivate") { audio.effectPlayCount == beforeRapid + 1 && audio.musicPlaying }
        precondition(audio.lastEffect == "sleep" && session.state().active)
        precondition(session.state().mainCalls == 0, "No AVAudioSession mutation may run on main")
        foreground(false); await settle()
        print("PASS rapid foreground/background restores only the newest generation")
        print("ALL 9 CONTROL-FLOW CHECKS PASSED; platform calls and players are test doubles")
    }
}
