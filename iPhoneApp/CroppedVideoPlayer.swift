import AVFoundation
import PrototypeSupport
import SwiftUI

/// Source decoding stays independent of crop gestures. The shared pixel geometry
/// clips/repositions the native video layer without re-encoding or a compositor.
@MainActor struct CroppedVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    let sourceSize: CGSize
    var crop = NormalizedCrop()
    var viewportID = "editorVideoViewport"

    func makeUIView(context: Context) -> CroppedVideoSurface {
        let view = CroppedVideoSurface()
        updateUIView(view, context: context)
        return view
    }
    func updateUIView(_ view: CroppedVideoSurface, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.sourceSize = sourceSize; view.crop = crop
        view.viewport.accessibilityIdentifier = viewportID
        view.setNeedsLayout()
    }
    static func dismantleUIView(_ view: CroppedVideoSurface, coordinator: ()) {
        view.playerLayer.player = nil
    }
}

@MainActor final class CroppedVideoSurface: UIView {
    let viewport = UIView()
    let playerLayer = AVPlayerLayer()
    var sourceSize = CGSize.zero
    var crop = NormalizedCrop()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        viewport.clipsToBounds = true
        viewport.isAccessibilityElement = true
        viewport.accessibilityLabel = "Video preview"
        playerLayer.videoGravity = .resizeAspect
        viewport.layer.addSublayer(playerLayer)
        addSubview(viewport)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layout = try? CropPreviewLayout(sourceSize: sourceSize, crop: crop, available: bounds.size) else {
            viewport.frame = .zero; return
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        viewport.frame = layout.viewport
        playerLayer.frame = layout.sourceFrame
        CATransaction.commit()
    }
}
