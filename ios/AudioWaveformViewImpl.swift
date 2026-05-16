import AVFoundation
import Foundation
import QuartzCore
import UIKit

/// Native composite view rendered inside the Fabric `RCTViewComponentView` shim.
///
/// Layout (left -> right):
///   [ rounded background (optional) ]
///     [ play/pause button | waveform bars | stack(time, speed pill) ]
///
/// The Fabric shim (`AudioWaveformView.mm`) owns this view, sets every prop
/// via `@objc` setters, dispatches commands, and reads the `@objc` callback
/// blocks below to forward events to the C++ event emitter.
@objcMembers
public final class AudioWaveformViewImpl: UIView {

    // MARK: - Subviews

    private let backgroundView = UIView()
    private let playButton = PlayPauseButton()
    private let barsView = WaveformBarsView()
    private let rightStack = UIView()
    private let timeLabel = UILabel()
    private let speedPill = SpeedPillView()

    // MARK: - Audio engine + decoder

    private let engine = AudioPlayerEngine()
    private let decoder = WaveformDecoder()

    // MARK: - Display link (drives waveform repaint at ~30 Hz)

    private var displayLink: CADisplayLink?

    // MARK: - Internal state

    private var currentSourceURL: URL?
    private var amplitudes: [CGFloat] = []
    private var samplesProvided: Bool = false

    private var internalPlaying: Bool = false
    private var internalSpeed: Float = 1.0

    private var initialPositionApplied: Bool = false
    private var pendingScrubMs: Int? = nil

    /// `true` while a touch-and-drag scrub is in progress on the bars view.
    private var isScrubbing: Bool = false
    /// Whether playback was running when the scrub began — restored on release.
    private var resumeAfterScrub: Bool = false

    // MARK: - Reactive props (set by the .mm Fabric shim via `@objc` setters)

    public var playedBarColor: UIColor = .white {
        didSet { barsView.playedBarColor = playedBarColor }
    }

    public var unplayedBarColor: UIColor = UIColor.white.withAlphaComponent(0.5) {
        didSet { barsView.unplayedBarColor = unplayedBarColor }
    }

    public var barWidth: CGFloat = 3 {
        didSet { barsView.barWidth = barWidth }
    }

    public var barGap: CGFloat = 2 {
        didSet { barsView.barGap = barGap }
    }

    public var barRadius: CGFloat = -1 {
        didSet { barsView.barRadius = barRadius }
    }

    public var barCountOverride: Int = 0 {
        didSet { barsView.barCountOverride = barCountOverride }
    }

    public var containerBackgroundColor: UIColor = UIColor(red: 0.204, green: 0.471, blue: 0.965, alpha: 1) {
        didSet { applyBackground() }
    }

    public var containerBorderRadius: CGFloat = 16 {
        didSet { applyBackground() }
    }

    public var showBackground: Bool = true {
        didSet { applyBackground() }
    }

    public var showPlayButton: Bool = true {
        didSet {
            playButton.isHidden = !showPlayButton
            setNeedsLayout()
        }
    }

    public var playButtonColor: UIColor = .white {
        didSet { playButton.iconColor = playButtonColor }
    }

    public var showTime: Bool = true {
        didSet {
            timeLabel.isHidden = !showTime
            setNeedsLayout()
        }
    }

    public var timeColor: UIColor = .white {
        didSet { timeLabel.textColor = timeColor }
    }

    /// Either "count-up" (default) or "count-down".
    public var timeMode: NSString = "count-up" {
        didSet { updateTimeLabel() }
    }

    public var showSpeedControl: Bool = true {
        didSet {
            speedPill.isHidden = !showSpeedControl
            setNeedsLayout()
        }
    }

    public var speedColor: UIColor = .white {
        didSet { speedPill.textColor = speedColor }
    }

    public var speedBackgroundColor: UIColor = UIColor.white.withAlphaComponent(0.25) {
        didSet { speedPill.pillColor = speedBackgroundColor }
    }

    public var speeds: [NSNumber] = [0.5, 1.0, 1.5, 2.0]

    public var defaultSpeed: Float = 1.0 {
        didSet {
            // Only respect `defaultSpeed` until the user (or controlled prop)
            // has actively set a speed.
            if !defaultSpeedApplied {
                applyEffectiveSpeed(defaultSpeed)
            }
        }
    }
    private var defaultSpeedApplied: Bool = false

    public var autoPlay: Bool = false
    public var initialPositionMs: Int = 0
    public var loop: Bool = false {
        didSet { engine.loop = loop }
    }

    /// Whether playback should continue when the host app is backgrounded.
    /// Default `false` — we pause on `UIApplication.didEnterBackground`.
    public var playInBackground: Bool = false {
        didSet {
            if playInBackground {
                engine.setBackgroundPlaybackEnabled(true)
            }
        }
    }

    /// While the app is backgrounded, skip the bars / time-label refreshes
    /// that would otherwise piggy-back on every 30 Hz progress tick. The JS
    /// `onTimeUpdate` event keeps firing regardless. Default `true`.
    public var pauseUiUpdatesInBackground: Bool = true

    /// Controlled "playing" prop: `-1` = uncontrolled, `0` = paused, `1` = playing.
    public var controlledPlaying: Int = -1 {
        didSet { applyControlledState() }
    }

    /// Controlled "speed" prop: `< 0` = uncontrolled, otherwise the rate.
    public var controlledSpeed: Float = -1 {
        didSet { applyControlledState() }
    }

    // MARK: - Source

    /// Set by the .mm shim from `newViewProps.source.uri`. Empty string clears.
    public var sourceURI: NSString = "" {
        didSet {
            guard sourceURI != oldValue else { return }
            applySource()
        }
    }

    // MARK: - Provided samples

    /// When non-nil, `samples` are used directly and native decode is skipped.
    public var providedSamples: [NSNumber]? = nil {
        didSet {
            applyProvidedSamples()
        }
    }

    // MARK: - Event callbacks (set by .mm; forwarded to C++ event emitter)

    public var onLoad: ((Int) -> Void)?
    public var onLoadError: ((NSString) -> Void)?
    public var onPlayerStateChange: ((NSString, Bool, Float, NSString) -> Void)?
    public var onTimeUpdate: ((Int, Int) -> Void)?
    public var onSeek: ((Int) -> Void)?
    public var onEnd: (() -> Void)?

    // MARK: - Init

    private var didEnterBackgroundObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var isBackgrounded: Bool = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        if let token = didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(token)
        }
        // Fabric pools `AudioWaveformView`s so this `deinit` only fires when
        // the pool evicts the view — but `tearDown()` is idempotent and
        // guarantees the engine is stopped even if the .mm shim somehow
        // bypassed `prepareForRecycle`.
        tearDown()
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false

        backgroundView.layer.cornerRadius = containerBorderRadius
        backgroundView.backgroundColor = containerBackgroundColor
        addSubview(backgroundView)

        playButton.addTarget(self, action: #selector(handlePlayButtonTap), for: .touchUpInside)
        playButton.iconColor = playButtonColor
        addSubview(playButton)

        barsView.playedBarColor = playedBarColor
        barsView.unplayedBarColor = unplayedBarColor
        barsView.barWidth = barWidth
        barsView.barGap = barGap
        barsView.barRadius = barRadius
        barsView.onScrubBegan = { [weak self] fraction in self?.handleScrubBegan(fraction: fraction) }
        barsView.onScrubMoved = { [weak self] fraction in self?.handleScrubMoved(fraction: fraction) }
        barsView.onScrubEnded = { [weak self] fraction, cancelled in
            self?.handleScrubEnded(fraction: fraction, cancelled: cancelled)
        }
        addSubview(barsView)

        rightStack.backgroundColor = .clear
        addSubview(rightStack)

        timeLabel.text = "0:00"
        timeLabel.textColor = timeColor
        timeLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        timeLabel.textAlignment = .right
        rightStack.addSubview(timeLabel)

        speedPill.pillColor = speedBackgroundColor
        speedPill.textColor = speedColor
        speedPill.setSpeed(defaultSpeed)
        speedPill.onTap = { [weak self] in self?.handleSpeedPillTap() }
        rightStack.addSubview(speedPill)

        wireEngineCallbacks()
        observeAppBackground()
    }

    private func observeAppBackground() {
        didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }
    }

    private func handleAppDidEnterBackground() {
        isBackgrounded = true
        guard !playInBackground else { return }
        guard engine.isPlaying else { return }
        engine.pause()
    }

    private func handleAppDidBecomeActive() {
        isBackgrounded = false
        // Snap the UI to the engine's current state in case we skipped
        // tick updates while backgrounded.
        let dur = engine.durationMs
        let cur = engine.currentMs
        if dur > 0 {
            barsView.progressFraction = CGFloat(cur) / CGFloat(dur)
        }
        updateTimeLabel(currentMs: cur, durationMs: dur)
        playButton.isPlaying = engine.isPlaying
    }

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = bounds

        let inset: CGFloat = 12
        let height = bounds.height
        var x = inset
        let availableWidth = max(0, bounds.width - inset * 2)
        var remaining = availableWidth

        let buttonSize = min(height * 0.6, 36)
        if showPlayButton {
            playButton.frame = CGRect(
                x: x,
                y: (height - buttonSize) / 2,
                width: buttonSize,
                height: buttonSize
            )
            x += buttonSize + 8
            remaining -= (buttonSize + 8)
        } else {
            playButton.frame = .zero
        }

        // Right side: time + speed
        let rightWidth: CGFloat = (showTime || showSpeedControl) ? 56 : 0
        if rightWidth > 0 {
            rightStack.frame = CGRect(
                x: bounds.width - inset - rightWidth,
                y: 0,
                width: rightWidth,
                height: height
            )
            remaining -= (rightWidth + 8)

            // Stack within the right column.
            let timeHeight: CGFloat = 18
            let pillHeight: CGFloat = 22
            let pillWidth: CGFloat = 44
            let stackContentHeight = (showTime ? timeHeight : 0)
                + (showTime && showSpeedControl ? 4 : 0)
                + (showSpeedControl ? pillHeight : 0)
            var sy = (height - stackContentHeight) / 2
            if showTime {
                timeLabel.frame = CGRect(x: 0, y: sy, width: rightWidth, height: timeHeight)
                sy += timeHeight + (showSpeedControl ? 4 : 0)
            } else {
                timeLabel.frame = .zero
            }
            if showSpeedControl {
                speedPill.frame = CGRect(
                    x: rightWidth - pillWidth,
                    y: sy,
                    width: pillWidth,
                    height: pillHeight
                )
            } else {
                speedPill.frame = .zero
            }
        } else {
            rightStack.frame = .zero
            timeLabel.frame = .zero
            speedPill.frame = .zero
        }

        // Waveform fills the full height between left and right; the bars
        // view itself adds vertical breathing room via `barWidth * 1.5` padding.
        let barsX = x
        let barsWidth = max(0, bounds.width - inset - rightWidth - (rightWidth > 0 ? 8 : 0) - barsX)
        barsView.frame = CGRect(
            x: barsX,
            y: 0,
            width: barsWidth,
            height: height
        )
    }

    // MARK: - Source / samples

    private func applySource() {
        let s = sourceURI as String
        if s.isEmpty {
            currentSourceURL = nil
            amplitudes = []
            barsView.amplitudes = []
            decoder.cancel()
            engine.reset()
            stopDisplayLink()
            return
        }
        guard let url = URL(string: s) else {
            onLoadError?(s as NSString)
            return
        }
        currentSourceURL = url
        initialPositionApplied = false

        // Reset stale waveform so the placeholder bars show during loading
        // rather than the previous source's amplitudes.
        amplitudes = []
        barsView.amplitudes = []
        decoder.cancel()

        engine.setSource(url: url)
        emitPlayerState()

        // Note: waveform decode is intentionally deferred to `engine.onLoad`.
        // For remote URLs the waveform decoder runs its own URLSession
        // download in parallel with AVPlayer's streaming buffer; if both
        // run from `applySource` they fight for bandwidth on the same
        // HTTP connection and the engine takes much longer to flip to
        // `.ready`. By holding off until `onLoad`, AVPlayer gets undivided
        // bandwidth for its initial buffer and the spinner clears as soon
        // as `.readyToPlay` fires (typically 1-2 seconds even on slow
        // connections), and the waveform then fills in progressively.
    }

    private func applyProvidedSamples() {
        guard let provided = providedSamples else {
            samplesProvided = false
            decodeAmplitudesIfPossible()
            return
        }
        if provided.isEmpty {
            samplesProvided = false
            decodeAmplitudesIfPossible()
            return
        }
        samplesProvided = true
        decoder.cancel()
        let parsed = provided.map { CGFloat(truncating: $0) }
        amplitudes = normalise(parsed)
        barsView.amplitudes = amplitudes
    }

    private func decodeAmplitudesIfPossible() {
        guard !samplesProvided else { return }
        guard let url = currentSourceURL else { return }
        // Without a meaningful width yet we can still kick off decode using a
        // sensible default bar count; the bars view downsamples to its own
        // bar count at draw time anyway.
        let provisionalCount = Math.barCountForWidth(
            width: barsView.bounds.width,
            barWidth: barWidth,
            barGap: barGap,
            fallback: 80
        )
        decoder.decode(
            url: url,
            barCount: provisionalCount,
            progress: { [weak self] amps in
                guard let self = self else { return }
                // Show partial waveform as it decodes — same UX as Android.
                self.amplitudes = amps
                self.barsView.amplitudes = amps
            },
            completion: { [weak self] amps in
                guard let self = self else { return }
                self.amplitudes = amps
                self.barsView.amplitudes = amps
            },
            failure: { [weak self] message in
                self?.onLoadError?(message as NSString)
            }
        )
    }

    private func normalise(_ values: [CGFloat]) -> [CGFloat] {
        let maxValue = values.max() ?? 0
        if maxValue <= 0 { return values.map { _ in 0 } }
        if maxValue <= 1 { return values.map { max(0, min(1, $0)) } }
        // Renormalise if the consumer passed something other than 0..1.
        return values.map { max(0, min(1, $0 / maxValue)) }
    }

    // MARK: - Background / appearance

    private func applyBackground() {
        if showBackground {
            backgroundView.isHidden = false
            backgroundView.backgroundColor = containerBackgroundColor
            backgroundView.layer.cornerRadius = containerBorderRadius
            backgroundView.layer.masksToBounds = true
        } else {
            backgroundView.isHidden = true
        }
    }

    // MARK: - Engine / state plumbing

    private func wireEngineCallbacks() {
        engine.onLoad = { [weak self] durationMs in
            guard let self = self else { return }
            self.onLoad?(durationMs)
            // Apply any pending initialPositionMs once the source is ready.
            if !self.initialPositionApplied, self.initialPositionMs > 0 {
                self.engine.seek(toMs: self.initialPositionMs)
                self.initialPositionApplied = true
            } else {
                self.initialPositionApplied = true
            }
            self.emitPlayerState()
            // Apply autoplay / controlled state now that we're ready.
            if self.controlledPlaying == 1 {
                self.engine.play()
                self.startDisplayLink()
            } else if self.controlledPlaying == -1, self.autoPlay {
                self.internalPlaying = true
                self.engine.play()
                self.startDisplayLink()
            }
            self.emitPlayerState()
            // Kick off waveform decode now that AVPlayer has its initial
            // buffer — see `applySource` for rationale. Skipped if the
            // caller already supplied samples.
            if !self.samplesProvided, self.amplitudes.isEmpty {
                self.decodeAmplitudesIfPossible()
            }
        }
        engine.onLoadError = { [weak self] message in
            self?.onLoadError?(message as NSString)
            self?.emitPlayerState(error: message)
        }
        engine.onStateChange = { [weak self] in
            self?.handleEngineStateChange()
        }
        engine.onTimeUpdate = { [weak self] currentMs, durationMs in
            guard let self = self else { return }
            if self.isScrubbing { return }
            // JS event always fires (callers may want it for now-playing UI).
            self.onTimeUpdate?(currentMs, durationMs)
            // Skip the cheap-but-pointless UI work while backgrounded.
            if self.isBackgrounded && self.pauseUiUpdatesInBackground { return }
            self.barsView.progressFraction = durationMs > 0
                ? CGFloat(currentMs) / CGFloat(durationMs)
                : 0
            self.updateTimeLabel(currentMs: currentMs, durationMs: durationMs)
        }
        engine.onEnded = { [weak self] in
            guard let self = self else { return }
            self.internalPlaying = false
            self.onEnd?()
            self.emitPlayerState()
            self.stopDisplayLink()
        }
    }

    private func handleEngineStateChange() {
        // Keep the play/pause icon in sync on every transition. Without this
        // the icon only refreshes from the display-link tick, which means
        // pausing (imperative or controlled) leaves a stale "playing" icon
        // because the display link stops the moment we pause.
        //
        // Order matters: update `isPlaying` *before* `isLoading`. While the
        // spinner is still showing (isLoading=true) the icon swap is a snap
        // (no crossfade); then we drop the spinner and the imageView is
        // already pointing at the right icon. If we did it in the opposite
        // order the imageView would briefly reveal the previous icon and
        // we'd see a 0.12s crossfade flash on every load completion that
        // had a pending tap.
        playButton.isPlaying = engine.isPlaying
        playButton.isLoading = (engine.state == .loading)
        if engine.isPlaying {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
        emitPlayerState()
    }

    private func emitPlayerState(error: String? = nil) {
        let stateString: String
        switch engine.state {
        case .idle: stateString = "idle"
        case .loading: stateString = "loading"
        case .ready: stateString = "ready"
        case .ended: stateString = "ended"
        case .error: stateString = "error"
        }
        let speed = effectiveSpeed()
        onPlayerStateChange?(
            stateString as NSString,
            engine.isPlaying,
            speed,
            (error ?? "") as NSString
        )
    }

    // MARK: - Time label

    private func updateTimeLabel(currentMs: Int? = nil, durationMs: Int? = nil) {
        let cur = currentMs ?? engine.currentMs
        let dur = durationMs ?? engine.durationMs
        let mode = (timeMode as String).lowercased()
        let display: Int
        if mode == "count-down" {
            display = max(0, dur - cur)
        } else {
            display = cur
        }
        let totalSeconds = display / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        timeLabel.text = String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Speed handling

    private func effectiveSpeed() -> Float {
        if controlledSpeed >= 0 { return controlledSpeed }
        return internalSpeed
    }

    /// Picks the next speed in the configured `speeds` list. Used when the
    /// user taps the pill (only changes internal state if uncontrolled).
    private func nextSpeed(after current: Float) -> Float {
        guard !speeds.isEmpty else { return 1.0 }
        let values = speeds.map { $0.floatValue }
        // Find the smallest one strictly greater than the current speed; wrap
        // around to the smallest if we're already at the largest.
        if let next = values.first(where: { $0 > current + 0.001 }) {
            return next
        }
        return values.first ?? 1.0
    }

    private func applyEffectiveSpeed(_ rate: Float) {
        if controlledSpeed < 0 {
            internalSpeed = rate
            defaultSpeedApplied = true
        }
        engine.setRate(rate)
        speedPill.setSpeed(rate)
        emitPlayerState()
    }

    private func applyControlledState() {
        // Speed
        if controlledSpeed >= 0 {
            engine.setRate(controlledSpeed)
            speedPill.setSpeed(controlledSpeed)
        }
        // Playing
        switch controlledPlaying {
        case 0:
            if engine.isPlaying { engine.pause() }
        case 1:
            // The engine's `play()` understands `.loading` and queues a
            // pending start, so we forward the intent regardless of state
            // and let the engine resume playback the moment buffering
            // finishes (or no-op if we're in `.idle` / `.error`).
            engine.play()
            if engine.isPlaying { startDisplayLink() }
        default:
            break
        }
        emitPlayerState()
    }

    // MARK: - Action handlers

    @objc private func handlePlayButtonTap() {
        if controlledPlaying != -1 {
            // Controlled — fire event with the requested *new* state, but don't toggle.
            let newPlaying = !engine.isPlaying
            let speed = effectiveSpeed()
            playButton.isPlaying = engine.isPlaying  // restore visual state
            onPlayerStateChange?(
                stateString() as NSString,
                newPlaying,
                speed,
                ""
            )
            return
        }
        engine.toggle()
        internalPlaying = engine.isPlaying
        playButton.isPlaying = engine.isPlaying
    }

    private func handleSpeedPillTap() {
        let current = effectiveSpeed()
        let next = nextSpeed(after: current)
        if controlledSpeed >= 0 {
            // Controlled — fire event with the requested *new* speed.
            onPlayerStateChange?(
                stateString() as NSString,
                engine.isPlaying,
                next,
                ""
            )
            return
        }
        applyEffectiveSpeed(next)
    }

    private func stateString() -> String {
        switch engine.state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .ready: return "ready"
        case .ended: return "ended"
        case .error: return "error"
        }
    }

    // MARK: - Scrub handlers (forwarded by WaveformBarsView)

    private func handleScrubBegan(fraction: CGFloat) {
        isScrubbing = true
        resumeAfterScrub = engine.isPlaying
        if engine.isPlaying { engine.pause() }
        let positionMs = positionFromFraction(fraction)
        pendingScrubMs = positionMs
        engine.seek(toMs: positionMs)
        updateTimeLabel(currentMs: positionMs, durationMs: engine.durationMs)
    }

    private func handleScrubMoved(fraction: CGFloat) {
        let positionMs = positionFromFraction(fraction)
        pendingScrubMs = positionMs
        engine.seek(toMs: positionMs)
        updateTimeLabel(currentMs: positionMs, durationMs: engine.durationMs)
    }

    private func handleScrubEnded(fraction: CGFloat, cancelled: Bool) {
        isScrubbing = false
        let positionMs = positionFromFraction(fraction)
        pendingScrubMs = nil
        engine.seek(toMs: positionMs)
        updateTimeLabel(currentMs: positionMs, durationMs: engine.durationMs)
        onSeek?(positionMs)
        if !cancelled, resumeAfterScrub, controlledPlaying != 0 {
            engine.play()
            startDisplayLink()
        }
    }

    private func positionFromFraction(_ fraction: CGFloat) -> Int {
        let dur = engine.durationMs
        guard dur > 0 else { return 0 }
        let clamped = max(0, min(1, fraction))
        return Int(clamped * CGFloat(dur))
    }

    // MARK: - Imperative commands (called from .mm)

    public func play() {
        if controlledPlaying != -1 { return }
        engine.play()
        internalPlaying = true
    }

    public func pause() {
        if controlledPlaying != -1 { return }
        engine.pause()
        internalPlaying = false
    }

    public func toggle() {
        if controlledPlaying != -1 { return }
        engine.toggle()
        internalPlaying = engine.isPlaying
    }

    public func seek(toMs ms: Int) {
        engine.seek(toMs: ms)
        updateTimeLabel(currentMs: ms, durationMs: engine.durationMs)
        onSeek?(ms)
    }

    public func setSpeedValue(_ value: Float) {
        if controlledSpeed >= 0 { return }
        applyEffectiveSpeed(value)
    }

    // MARK: - Teardown

    /// Stop playback and release every audio / decode / display-link
    /// resource the view is holding. Called when the React component
    /// unmounts so the underlying `AVPlayer` doesn't keep playing inside
    /// the Fabric view-recycler pool (see `AudioWaveformView.mm`'s
    /// `prepareForRecycle`). Also called from `deinit` so it's safe even
    /// if the pool releases the view directly.
    ///
    /// Idempotent: every step guards against the "already torn down"
    /// state, so calling this twice in a row is a no-op.
    public func tearDown() {
        // Setting `sourceURI` back to `""` runs through `applySource()`,
        // which already does the heavy lifting: cancels the decoder,
        // resets the engine (pauses + replaces the AVPlayerItem with
        // nil + tears down KVO/time observers), and stops the display
        // link. Doing it via the setter also clears the cached previous
        // value so the next mount (which may reuse the same URI from
        // the recycler pool) re-applies the source instead of being
        // short-circuited by the `oldValue == newValue` guard.
        sourceURI = ""
        providedSamples = nil

        // Reset the rest of the bookkeeping state so a recycled view
        // wakes up indistinguishable from a freshly-allocated one.
        internalPlaying = false
        internalSpeed = 1.0
        defaultSpeedApplied = false
        initialPositionApplied = false
        pendingScrubMs = nil
        isScrubbing = false
        resumeAfterScrub = false
        amplitudes = []
        barsView.amplitudes = []
        barsView.progressFraction = 0
        timeLabel.text = "0:00"
        playButton.isPlaying = false
        playButton.isLoading = false
        // Match the `internalSpeed = 1.0` reset above so the pill doesn't
        // briefly flash a stale "2.0x" before the new mount's defaultSpeed
        // prop setter (if any) re-applies the right value.
        speedPill.setSpeed(1.0)
    }

    // MARK: - Display link (~30 Hz repaint while playing or scrubbing)

    private func startDisplayLink() {
        if displayLink != nil { return }
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayTick))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        } else {
            link.preferredFramesPerSecond = 30
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayTick() {
        let dur = engine.durationMs
        guard dur > 0 else { return }
        let cur = engine.currentMs
        if !isScrubbing {
            barsView.progressFraction = CGFloat(cur) / CGFloat(dur)
        }
        playButton.isPlaying = engine.isPlaying
        updateTimeLabel(currentMs: cur, durationMs: dur)
    }
}

// MARK: - Helpers

private enum Math {
    /// Compute a sensible bar count for a given view width.
    static func barCountForWidth(
        width: CGFloat,
        barWidth: CGFloat,
        barGap: CGFloat,
        fallback: Int
    ) -> Int {
        let step = barWidth + barGap
        guard step > 0 else { return fallback }
        if width <= 0 { return fallback }
        return max(8, Int(floor(width / step)))
    }
}
