import AVFoundation
import Foundation
import Observation
import CatGameCore

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
    #if DEBUG
    private(set) var effectPlayCount = 0
    private(set) var lastEffect = ""
    private(set) var backgroundPauseCount = 0
    private(set) var assetLoadFailures = 0
    #endif
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
        #if DEBUG
        if isForeground && !foreground { backgroundPauseCount += 1 }
        #endif
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
        #if DEBUG
            effectPlayCount += 1
            lastEffect = effect.rawValue
        #endif
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
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf", subdirectory: "Audio") else {
        #if DEBUG
            assetLoadFailures += 1
        #endif
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
        #if DEBUG
            assetLoadFailures += 1
        #endif
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
