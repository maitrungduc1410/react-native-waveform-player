import UIKit

/// Rounded "1.5x" speed-rate label. Tap-to-cycle is wired up via
/// `onTap`; the parent (`AudioWaveformViewImpl`) is responsible for
/// applying the new rate to the audio engine.
final class SpeedPillView: UIView {

    var label: UILabel = UILabel()

    var pillColor: UIColor = UIColor.white.withAlphaComponent(0.25) {
        didSet { backgroundColor = pillColor }
    }

    var textColor: UIColor = .white {
        didSet { label.textColor = textColor }
    }

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = pillColor
        layer.masksToBounds = true
        label.textColor = textColor
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        addSubview(label)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func setSpeed(_ speed: Float) {
        // Format like "1x" / "1.5x" / "0.5x" — drop trailing ".0".
        let rounded = (speed * 10).rounded() / 10
        let isInt = rounded == floor(rounded)
        let text: String = isInt
            ? "\(Int(rounded))x"
            : String(format: "%.1fx", rounded)
        label.text = text
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 6, dy: 0)
        layer.cornerRadius = bounds.height / 2
    }

    @objc private func handleTap() {
        UIView.animate(withDuration: 0.08, animations: { self.alpha = 0.6 }) { _ in
            UIView.animate(withDuration: 0.12) { self.alpha = 1.0 }
        }
        onTap?()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 44, height: 22)
    }
}
