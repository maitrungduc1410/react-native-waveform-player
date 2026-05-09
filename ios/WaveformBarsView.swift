import UIKit

/// Custom UIView that draws the audio waveform as a row of vertical rounded-rect
/// bars with a "played" / "unplayed" two-tone fill.
///
/// Drawing model:
///   1. Build a single cached `UIBezierPath` containing every bar's rounded-rect
///      whenever the amplitudes / size / bar geometry change.
///   2. On every `draw(_:)`:
///        a. Fill the cached path in `unplayedBarColor`.
///        b. Save state -> clip to `[0, progressX, bounds.height]` ->
///           fill the same cached path in `playedBarColor` -> restore state.
///      The bar straddling the playhead is partial-highlighted naturally because
///      the rounded-rect geometry is identical in both passes; only the right
///      edge is cropped by the clip.
///
/// Touch handling is **immediate** (no slop, no long-press timeout): scrubbing
/// starts on `touchesBegan` and the host view receives the proportional position
/// via the `onScrubBegan/Moved/Ended` callbacks.
final class WaveformBarsView: UIView {

    // MARK: - Visual configuration (set by AudioWaveformViewImpl)

    var amplitudes: [CGFloat] = [] {
        didSet { setTargetAmplitudes(amplitudes) }
    }

    var playedBarColor: UIColor = .white {
        didSet { setNeedsDisplay() }
    }

    var unplayedBarColor: UIColor = UIColor.white.withAlphaComponent(0.5) {
        didSet { setNeedsDisplay() }
    }

    var barWidth: CGFloat = 3 {
        didSet { invalidatePath() }
    }

    var barGap: CGFloat = 2 {
        didSet { invalidatePath() }
    }

    /// `< 0` means "auto" = barWidth / 2.
    var barRadius: CGFloat = -1 {
        didSet { invalidatePath() }
    }

    /// `<= 0` means "auto from view width".
    var barCountOverride: Int = 0 {
        didSet { invalidatePath() }
    }

    /// Fraction of the waveform that has been played, in [0, 1].
    /// Updated at ~30 Hz while playing. The cached bar path makes the
    /// per-frame redraw essentially free, so we always invalidate.
    var progressFraction: CGFloat = 0 {
        didSet {
            if oldValue != progressFraction {
                setNeedsDisplay()
            }
        }
    }

    // MARK: - Touch / scrub callbacks

    /// All callbacks pass a fraction in [0, 1] (the touch's x divided by
    /// the view's width).
    var onScrubBegan: ((CGFloat) -> Void)?
    var onScrubMoved: ((CGFloat) -> Void)?
    var onScrubEnded: ((CGFloat, _ cancelled: Bool) -> Void)?

    // MARK: - Private state

    private var cachedPath: UIBezierPath?
    private var cachedSize: CGSize = .zero

    /// What's actually drawn this frame. During an amplitudes update, these
    /// values smoothly interpolate between `startAmps` and `targetAmps`.
    private var displayedAmps: [CGFloat] = []
    private var startAmps: [CGFloat] = []
    private var targetAmps: [CGFloat] = []
    private var amplitudeAnimationStart: CFTimeInterval = 0
    private var amplitudeDisplayLink: CADisplayLink?
    /// How long each new partial-amplitudes update animates for.
    private static let amplitudeAnimationDuration: CFTimeInterval = 0.2

    // MARK: - Init

    private lazy var scrubRecognizer: UILongPressGestureRecognizer = {
        // `minimumPressDuration = 0` makes the gesture activate immediately on
        // touch-down. `allowableMovement = .greatestFiniteMagnitude` keeps it
        // alive through any drag distance.
        //
        // Long-press is the canonical iOS pattern for "claim the touch
        // immediately so a parent UIScrollView can't cancel it" — once a
        // long-press recognizer has begun, UIScrollView's pan can no longer
        // hijack the touch sequence (which is what was causing scrubbing to
        // fail when the bars view was nested inside a ScrollView).
        let r = UILongPressGestureRecognizer(target: self, action: #selector(handleScrubGesture(_:)))
        r.minimumPressDuration = 0
        r.allowableMovement = .greatestFiniteMagnitude
        r.cancelsTouchesInView = false
        return r
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = true
        addGestureRecognizer(scrubRecognizer)
    }

    deinit {
        amplitudeDisplayLink?.invalidate()
        amplitudeDisplayLink = nil
    }

    // MARK: - Layout / path caching

    override func layoutSubviews() {
        super.layoutSubviews()
        if cachedSize != bounds.size {
            invalidatePath()
        }
    }

    private func invalidatePath() {
        cachedPath = nil
        cachedSize = .zero
        setNeedsDisplay()
    }

    private func ensureCachedPath() -> UIBezierPath? {
        if let path = cachedPath, cachedSize == bounds.size {
            return path
        }
        let path = buildBarPath()
        cachedPath = path
        cachedSize = bounds.size
        return path
    }

    /// Uniform amplitude used to render the "loading" skeleton when no real
    /// amplitudes have been decoded yet. Small enough to read clearly as a
    /// placeholder, big enough to be obviously visible.
    private static let placeholderAmplitude: CGFloat = 0.2

    /// Build a composite `UIBezierPath` of every bar's rounded-rect. This is
    /// rebuilt whenever amplitudes / size / bar geometry change (and on every
    /// frame while an amplitude animation is running), so the hot 30 Hz
    /// playback redraw can reuse the cached path.
    ///
    /// When no amplitudes have ever been delivered (decoder hasn't produced
    /// the first partial yet) we render a uniform low-amplitude skeleton so
    /// the user sees the bar pattern immediately instead of an empty card.
    private func buildBarPath() -> UIBezierPath? {
        let totalWidth = bounds.width
        let totalHeight = bounds.height
        guard totalWidth > 0, totalHeight > 0 else { return nil }

        let step = barWidth + barGap
        guard step > 0 else { return nil }

        let autoCount = Int(floor(totalWidth / step))
        let barCount = barCountOverride > 0
            ? min(barCountOverride, autoCount)
            : autoCount
        guard barCount > 0 else { return nil }

        let verticalPadding = barWidth * 1.5
        let drawableHeight = totalHeight - verticalPadding * 2
        guard drawableHeight > 0 else { return nil }
        let minBarHeight = barWidth
        let radius = barRadius < 0 ? barWidth / 2 : barRadius
        // `displayedAmps` already substitutes `placeholderAmplitude` for any
        // not-yet-decoded bar in `setTargetAmplitudes`, so trailing bars stay
        // at skeleton height instead of dropping to `minBarHeight`.
        let usePlaceholder = displayedAmps.isEmpty

        let path = UIBezierPath()
        for i in 0..<barCount {
            let amp: CGFloat
            if usePlaceholder {
                amp = Self.placeholderAmplitude
            } else {
                let ampIndex = i * displayedAmps.count / barCount
                amp = displayedAmps[min(max(ampIndex, 0), displayedAmps.count - 1)]
            }
            let barHeight = max(minBarHeight, amp * drawableHeight)
            let x = CGFloat(i) * step
            let y = verticalPadding + (drawableHeight - barHeight) / 2.0
            let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: radius))
        }
        return path
    }

    // MARK: - Amplitude animation

    /// Update the animation targets when new amplitudes arrive. Each new
    /// partial smoothly grows from the currently-displayed values to the
    /// new target over `amplitudeAnimationDuration` (ease-out cubic). Bars
    /// expand symmetrically from the centre because the bar geometry is
    /// already centre-aligned (`y = verticalPadding + (drawableHeight - h)/2`).
    private func setTargetAmplitudes(_ newAmps: [CGFloat]) {
        if newAmps.isEmpty {
            stopAmplitudeAnimation()
            displayedAmps = []
            startAmps = []
            targetAmps = []
            invalidatePath()
            return
        }

        // Treat zero amplitude as "not yet decoded" — keep those bars at the
        // skeleton placeholder height instead of letting them snap to
        // `minBarHeight` between partials.
        let processed: [CGFloat] = newAmps.map { $0 > 0 ? $0 : Self.placeholderAmplitude }

        if displayedAmps.count != processed.count {
            // First non-empty payload (or barCount changed). Seed the
            // current values with the placeholder skeleton so the animation
            // grows from skeleton -> real shape.
            displayedAmps = [CGFloat](repeating: Self.placeholderAmplitude, count: processed.count)
        }

        startAmps = displayedAmps
        targetAmps = processed
        amplitudeAnimationStart = CACurrentMediaTime()
        startAmplitudeAnimation()
    }

    private func startAmplitudeAnimation() {
        if amplitudeDisplayLink != nil { return }
        let link = CADisplayLink(target: self, selector: #selector(handleAmplitudeTick))
        link.add(to: .main, forMode: .common)
        amplitudeDisplayLink = link
    }

    private func stopAmplitudeAnimation() {
        amplitudeDisplayLink?.invalidate()
        amplitudeDisplayLink = nil
    }

    @objc private func handleAmplitudeTick() {
        let elapsed = CACurrentMediaTime() - amplitudeAnimationStart
        let t = max(0, min(1, elapsed / Self.amplitudeAnimationDuration))
        let eased = Self.easeOutCubic(CGFloat(t))
        let count = min(displayedAmps.count, min(startAmps.count, targetAmps.count))
        for i in 0..<count {
            displayedAmps[i] = startAmps[i] + (targetAmps[i] - startAmps[i]) * eased
        }
        invalidatePath()
        if t >= 1 {
            stopAmplitudeAnimation()
        }
    }

    private static func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let inv = 1 - t
        return 1 - inv * inv * inv
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let path = ensureCachedPath() else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Pass 1: fill all bars in the unplayed color.
        unplayedBarColor.setFill()
        path.fill()

        // Pass 2: clip to [0, progressX] and fill the same path in the played color.
        let clamped = max(0, min(1, progressFraction))
        let progressX = clamped * bounds.width
        guard progressX > 0 else { return }

        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: 0, width: progressX, height: bounds.height))
        playedBarColor.setFill()
        path.fill()
        ctx.restoreGState()
    }

    // MARK: - Touch handling (immediate scrub via long-press gesture)

    @objc private func handleScrubGesture(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: self)
        let fraction = clampFraction(location.x / max(1, bounds.width))
        switch recognizer.state {
        case .began:
            progressFraction = fraction
            setNeedsDisplay()
            onScrubBegan?(fraction)
        case .changed:
            progressFraction = fraction
            setNeedsDisplay()
            onScrubMoved?(fraction)
        case .ended:
            progressFraction = fraction
            setNeedsDisplay()
            onScrubEnded?(fraction, false)
        case .cancelled, .failed:
            onScrubEnded?(progressFraction, true)
        default:
            break
        }
    }

    private func clampFraction(_ value: CGFloat) -> CGFloat {
        if value.isNaN { return 0 }
        return max(0, min(1, value))
    }
}
