import UIKit

/// Play/pause button rendered with the platform-built-in SF Symbols
/// `play.fill` / `pause.fill`. Tintable via `iconColor`.
///
/// While `isLoading` is `true`, the icon is hidden and a native
/// `UIActivityIndicatorView` is shown in its place. The control stays
/// hit-testable so callers can queue a "play once ready" intent.
final class PlayPauseButton: UIControl {

    var isPlaying: Bool = false {
        didSet {
            guard oldValue != isPlaying else { return }
            // Don't crossfade between play / pause symbols while the icon
            // is hidden behind the spinner — the user can't see it anyway,
            // and once `isLoading` flips back to `false` the imageView is
            // already showing the latest icon, so no animation is needed.
            updateImage(animated: !isLoading)
        }
    }

    var isLoading: Bool = false {
        didSet {
            guard oldValue != isLoading else { return }
            updateLoadingState()
        }
    }

    var iconColor: UIColor = .white {
        didSet {
            imageView.tintColor = iconColor
            activityIndicator.color = iconColor
        }
    }

    private let imageView = UIImageView()
    private let activityIndicator: UIActivityIndicatorView = {
        let style: UIActivityIndicatorView.Style
        if #available(iOS 13.0, *) {
            style = .medium
        } else {
            style = .white
        }
        let view = UIActivityIndicatorView(style: style)
        view.hidesWhenStopped = true
        return view
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
        backgroundColor = .clear
        imageView.tintColor = iconColor
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
        activityIndicator.color = iconColor
        addSubview(activityIndicator)
        updateImage(animated: false)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Size the symbol to ~70% of the button so taps stay generous.
        let inset: CGFloat = 4
        imageView.frame = bounds.insetBy(dx: inset, dy: inset)
        activityIndicator.frame = imageView.frame
        updateImage(animated: false)
    }

    private func updateImage(animated: Bool) {
        let dim = min(imageView.bounds.width, imageView.bounds.height)
        let pointSize = max(8, dim * 0.95)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        let symbolName = isPlaying ? "pause.fill" : "play.fill"
        let image = UIImage(systemName: symbolName, withConfiguration: config)?
            .withRenderingMode(.alwaysTemplate)
        if animated {
            UIView.transition(with: imageView, duration: 0.12, options: .transitionCrossDissolve) {
                self.imageView.image = image
            }
        } else {
            imageView.image = image
        }
    }

    private func updateLoadingState() {
        if isLoading {
            imageView.isHidden = true
            activityIndicator.startAnimating()
        } else {
            imageView.isHidden = false
            activityIndicator.stopAnimating()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.08) { self.alpha = 0.6 }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.12) { self.alpha = 1.0 }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.12) { self.alpha = 1.0 }
    }
}
