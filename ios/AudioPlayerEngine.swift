import AVFoundation
import Foundation
import UIKit

/// Thin wrapper around `AVPlayer` that exposes the events the rest of the
/// component needs: load lifecycle, periodic time updates, end-of-track,
/// and rate / seek control. All callbacks fire on the main thread.
final class AudioPlayerEngine {

    // MARK: - State

    enum State {
        case idle
        case loading
        case ready
        case ended
        case error
    }

    private(set) var state: State = .idle {
        didSet {
            guard oldValue != state else { return }
            // If the user tapped "play" while we were still loading, apply
            // playback synchronously *before* firing onStateChange so the
            // single notification reflects the final state (state == .ready
            // AND isPlaying == true). Without this we'd fire one event with
            // isPlaying=false (causing a brief play-icon flash) then a
            // second one once startInternal flips it.
            if state == .ready, pendingStart {
                pendingStart = false
                startPlaybackInternal()
            }
            onStateChange?()
        }
    }

    /// "Play once ready" intent recorded during the `.loading` state.
    /// Cleared on pause / reset / source change.
    private var pendingStart: Bool = false

    private(set) var durationMs: Int = 0
    private(set) var currentMs: Int = 0
    /// `true` while the engine is in a "playing" state from the user's POV
    /// (i.e. `play()` was called and we haven't been paused or ended).
    /// We track this explicitly because `AVPlayer.timeControlStatus` flips
    /// between `playing` / `waitingToPlayAtSpecifiedRate` during buffering.
    private(set) var isPlaying: Bool = false
    private(set) var rate: Float = 1.0
    var loop: Bool = false

    // MARK: - Callbacks

    var onLoad: ((Int) -> Void)?
    var onLoadError: ((String) -> Void)?
    var onStateChange: (() -> Void)?
    var onTimeUpdate: ((Int, Int) -> Void)?
    var onEnded: (() -> Void)?

    // MARK: - Private

    private let player = AVPlayer()
    private var currentItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObservation: NSObjectProtocol?

    init() {
        player.actionAtItemEnd = .pause
        // Be eager about playback readiness: AVPlayer's default behaviour
        // is to accumulate a generous forward buffer before flipping
        // `.readyToPlay`, which can keep the loading spinner on screen
        // for many seconds even after enough data has arrived to start
        // playback. With this disabled, `.readyToPlay` fires as soon as
        // the item has decodable samples queued up.
        player.automaticallyWaitsToMinimizeStalling = false
        // The library does not configure AVAudioSession by default to avoid
        // surprises; opt-in via `setBackgroundPlaybackEnabled(true)` instead.
    }

    /// Configure the shared `AVAudioSession` so audio keeps playing when the
    /// host app is backgrounded. Requires the host app to have the "Audio,
    /// AirPlay, and Picture in Picture" Background Mode enabled in Info.plist.
    ///
    /// Calling with `false` is a no-op — once the session category has been
    /// switched to `.playback` we leave it alone (the host app may have its
    /// own audio session management we don't want to step on).
    func setBackgroundPlaybackEnabled(_ enabled: Bool) {
        guard enabled else { return }
        let session = AVAudioSession.sharedInstance()
        // Don't churn the session if it's already in a playback-capable mode.
        if session.category == .playback || session.category == .playAndRecord {
            try? session.setActive(true, options: [])
            return
        }
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            // Silently ignore — host app likely manages its own session.
        }
    }

    deinit {
        teardownObservers()
    }

    // MARK: - Public API

    func setSource(url: URL) {
        teardownObservers()

        pendingStart = false
        state = .loading
        currentMs = 0
        durationMs = 0

        let item = AVPlayerItem(url: url)
        currentItem = item
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    let durSeconds = item.duration.seconds
                    if durSeconds.isFinite, durSeconds > 0 {
                        self.durationMs = Int(durSeconds * 1000)
                    } else {
                        self.durationMs = 0
                    }
                    self.state = .ready
                    self.onLoad?(self.durationMs)
                case .failed:
                    let message = item.error?.localizedDescription ?? "Unknown player error"
                    self.state = .error
                    self.onLoadError?(message)
                default:
                    break
                }
            }
        }

        endObservation = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleEnd()
        }

        player.replaceCurrentItem(with: item)

        let interval = CMTime(value: 1, timescale: 30)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self, self.durationMs > 0 else { return }
            let seconds = time.seconds
            if seconds.isFinite, seconds >= 0 {
                self.currentMs = min(self.durationMs, Int(seconds * 1000))
                self.onTimeUpdate?(self.currentMs, self.durationMs)
            }
        }
    }

    func play() {
        if state == .loading {
            // Audio isn't buffered yet — record the intent and let the
            // state setter resume playback the instant we transition to
            // `.ready`. We deliberately don't fire onStateChange here so
            // the play/pause button stays as the loading spinner instead
            // of briefly flipping to a "pause" icon while still loading.
            pendingStart = true
            return
        }
        guard state == .ready || state == .ended else { return }
        // Already running — skip so we don't fire a redundant
        // onStateChange every time `applyControlledState()` is called.
        if isPlaying && state == .ready { return }
        // Clear any stale pending intent before we drive state changes,
        // so the state-setter doesn't try to "resume" again.
        pendingStart = false
        if state == .ended {
            player.seek(to: .zero)
            currentMs = 0
            state = .ready
        }
        startPlaybackInternal()
        onStateChange?()
    }

    func pause() {
        // Cancel any queued "play once ready" intent — the user explicitly
        // wants playback to stay paused.
        pendingStart = false
        guard isPlaying else { return }
        isPlaying = false
        player.pause()
        onStateChange?()
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    /// Seek to position in milliseconds. Uses an exact-tolerance seek so the
    /// playhead lands on the requested sample even for VBR mp3.
    func seek(toMs ms: Int, completion: (() -> Void)? = nil) {
        let clamped = max(0, min(durationMs, ms))
        currentMs = clamped
        let target = CMTime(value: CMTimeValue(clamped), timescale: 1000)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            completion?()
        }
    }

    func setRate(_ newRate: Float) {
        let clamped = max(0.25, min(4.0, newRate))
        rate = clamped
        if isPlaying {
            player.rate = clamped
        }
    }

    func reset() {
        pendingStart = false
        teardownObservers()
        player.replaceCurrentItem(with: nil)
        currentItem = nil
        isPlaying = false
        currentMs = 0
        durationMs = 0
        state = .idle
    }

    // MARK: - Internal

    /// Common play-start sequence shared by `play()` and the in-line
    /// resume from the `state` setter when transitioning to `.ready`
    /// with a queued tap intent. Does NOT fire `onStateChange` — callers
    /// are responsible for that (so we can batch a single notification).
    private func startPlaybackInternal() {
        isPlaying = true
        player.rate = rate
        // Calling `player.play()` after setting rate keeps the rate sticky
        // even after a previous .pause() reset it to 0.
        player.play()
        player.rate = rate
    }

    private func handleEnd() {
        if loop {
            player.seek(to: .zero)
            currentMs = 0
            if isPlaying {
                player.rate = rate
                player.play()
                player.rate = rate
            }
        } else {
            isPlaying = false
            currentMs = durationMs
            state = .ended
            onTimeUpdate?(currentMs, durationMs)
            onEnded?()
        }
    }

    private func teardownObservers() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObservation = endObservation {
            NotificationCenter.default.removeObserver(endObservation)
        }
        endObservation = nil
    }
}
