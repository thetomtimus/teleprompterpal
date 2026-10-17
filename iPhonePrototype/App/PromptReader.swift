import AVFoundation
import PromptingCore
import SwiftUI
import UIKit

/// Rehearsal and Camera have different compositions but share an exact reading
/// position. Claim before the old view is removed; a late dismantle cannot
/// replace the newer reader's position. No display-link work is added.
@MainActor final class ReaderAnchorHandoff {
    private weak var owner: PromptReader.Coordinator?
    private var latest: ReadingAnchor?
    func claim(_ coordinator: PromptReader.Coordinator) -> ReadingAnchor? {
        let anchor = owner?.currentAnchor() ?? latest
        owner = coordinator
        latest = anchor
        return anchor
    }
    @discardableResult func release(_ coordinator: PromptReader.Coordinator, anchor: ReadingAnchor) -> Bool {
        guard owner === coordinator else { return false }
        latest = anchor
        owner = nil
        return true
    }
}

struct PromptReader: UIViewRepresentable {
    let text: String
    let fontSize: Double
    let speed: Double
    let playing: Bool
    let restart: Int
    let probe: ReaderProbe
    var initialAnchor: ReadingAnchor? = nil
    var checkpoint: @MainActor (ReadingAnchor) -> Void = { _ in }
    var alignment: NSTextAlignment = .natural
    var lightAppearance = false
    var backgroundOpacity = 0.64
    var handoff: ReaderAnchorHandoff? = nil
    let stopped: @MainActor () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(probe: probe, checkpoint: checkpoint, stopped: stopped) }
    func makeUIView(context: Context) -> UITextView {
        let view = ReaderTextView(usingTextLayoutManager: false)
        view.layoutManager.allowsNonContiguousLayout = false
        view.isEditable = false
        view.isSelectable = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.64)
        view.textColor = .white
        view.layer.cornerRadius = 16
        view.textContainerInset = UIEdgeInsets(top: 12, left: 14, bottom: 80, right: 14)
        view.showsVerticalScrollIndicator = false
        view.accessibilityLabel = "Script reader"
        view.accessibilityIdentifier = "promptReader"
        view.delegate = context.coordinator
        context.coordinator.view = view
        context.coordinator.attach(handoff: handoff)
        view.beforeResize = { [weak coordinator = context.coordinator] in coordinator?.prepareForResize() }
        view.onLayout = { [weak coordinator = context.coordinator] in coordinator?.layoutChanged() }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        probe.measure("representable-update") {
            context.coordinator.update(
                text: text, fontSize: fontSize, speed: speed, playing: playing, restart: restart,
                initialAnchor: initialAnchor, alignment: alignment)
            probe.measure("color-update") {
                (view as? ReaderTextView)?.applyAppearance(light: lightAppearance, opacity: backgroundOpacity)
            }
        }
    }

    static func dismantleUIView(_ view: UITextView, coordinator: Coordinator) {
        coordinator.invalidate()
        view.delegate = nil
    }

    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        weak var view: UITextView?
        private var engine = ScrollEngine(speedPointsPerSecond: 30)
        private var link: CADisplayLink?
        private var requestedPlaying = false
        private var needsFrameBaseline = false
        private var lastRestart = 0
        private var lastSize = CGSize.zero
        private var appliedText: String?
        private var appliedFontSize: Double?
        private var appliedAlignment: NSTextAlignment?
        private let stopped: @MainActor () -> Void
        private let probe: ReaderProbe
        private let proxy = FrameProxy()
        private var updating = false
        private var pendingAnchor: ReadingAnchor?
        private var restoredInitialAnchor = false
        private var lastCheckpoint = 0.0
        private var resizeAnchor: ReadingAnchor?
        private let checkpoint: @MainActor (ReadingAnchor) -> Void
        private weak var handoff: ReaderAnchorHandoff?
        #if DEBUG && targetEnvironment(simulator)
        private var layoutTrace: [String] = []
        private let layoutTraceID = UUID()
        #endif

        init(
            probe: ReaderProbe, checkpoint: @escaping @MainActor (ReadingAnchor) -> Void = { _ in },
            stopped: @escaping @MainActor () -> Void
        ) {
            self.probe = probe
            self.checkpoint = checkpoint
            self.stopped = stopped
        }

        func update(
            text: String, fontSize: Double, speed: Double, playing: Bool, restart: Int,
            initialAnchor: ReadingAnchor? = nil, alignment: NSTextAlignment = .natural
        ) {
            guard let view, !updating else { return }
            let updateStart = CACurrentMediaTime()
            defer { probe.recordWork("ui-update", seconds: CACurrentMediaTime() - updateStart) }
            updating = true
            defer { updating = false }
            if !restoredInitialAnchor, pendingAnchor == nil, let initialAnchor { pendingAnchor = initialAnchor }
            let relayout = probe.measure("layout-check") {
                appliedText != text || appliedFontSize != fontSize
                || appliedAlignment != alignment || lastSize != view.bounds.size
            }
            if relayout {
                probe.breakSequence()
                let wasPlaying = engine.phase == .playing && requestedPlaying && playing
                let anchor = resizeAnchor ?? captureAnchor(in: view)
                trace("before-relayout", view: view, anchor: anchor.utf16Offset)
                resizeAnchor = nil
                _ = engine.apply(.pause)
                let changedText = appliedText != text
                if changedText {
                    view.text = text
                    // This read-only prompt is one text element. UIKit's default
                    // paragraph container repeatedly compares the entire attributed
                    // document while enumerating long scripts for accessibility.
                    // Keep the complete plain text available without that expansion.
                    view.isAccessibilityElement = true
                    view.accessibilityElements = []
                    view.accessibilityValue = text
                }
                view.font = .systemFont(ofSize: fontSize, weight: .medium)
                view.textAlignment = alignment
                appliedText = text
                appliedFontSize = fontSize
                appliedAlignment = alignment
                // SwiftUI can deliver the new bounds before UITextView updates
                // its width-tracking container. Restore against the new width
                // now, before the next display frame can use stale geometry.
                if view.bounds.width > 0 {
                    view.textContainer.size.width = max(1, view.bounds.width
                        - view.textContainerInset.left - view.textContainerInset.right)
                }
                view.layoutManager.ensureLayout(for: view.textContainer)
                view.setNeedsLayout()
                view.layoutIfNeeded()
                _ = engine.apply(.setMaximumOffset(maximum(in: view)))
                if !changedText { restore(anchor: anchor, in: view) } else { _ = engine.apply(.restart) }
                lastSize = view.bounds.size
                trace("after-relayout", view: view, anchor: anchor.utf16Offset)
                if !restoredInitialAnchor, view.bounds.height > 0, let pendingAnchor {
                    restore(anchor: pendingAnchor, in: view)
                    restoredInitialAnchor = true
                    self.pendingAnchor = nil
                }
                if wasPlaying { needsFrameBaseline = true }
            }
            if restart != lastRestart {
                _ = engine.apply(.restart)
                lastRestart = restart
                requestedPlaying = false
                view.setContentOffset(.zero, animated: false)
                probe.measure("checkpoint") { checkpoint(captureAnchor(in: view)) }
            }
            if speed != engine.speedPointsPerSecond {
                // UI updates can arrive after a frame's timestamp but before its display-link callback.
                // Keep all playback settlement on the display-link clock; unchanged controls do no work.
                _ = engine.apply(.setSpeed(pointsPerSecond: speed, at: engine.lastUptime ?? 0))
            }
            if playing != requestedPlaying {
                if !playing { checkpoint(captureAnchor(in: view)) }
                requestedPlaying = playing
                _ = engine.apply(.pause)
                needsFrameBaseline = playing
            }
            // Font, alignment, and bounds changes pause the engine to update its maximum.
            // A playing reader must establish a new frame baseline after that pause.
            if playing, engine.phase == .paused { needsFrameBaseline = true }
            let offset = CGPoint(x: 0, y: engine.offset)
            if view.contentOffset != offset { view.setContentOffset(offset, animated: false) }
            if link == nil {
                proxy.owner = self
                let link = CADisplayLink(target: proxy, selector: #selector(FrameProxy.tick(_:)))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common)
                self.link = link
            }
            if let link, link.isPaused == playing { link.isPaused = !playing }
        }

        func layoutChanged() {
            guard !updating, let view, view.bounds.size != lastSize else { return }
            update(
                text: appliedText ?? view.text, fontSize: appliedFontSize ?? Double(view.font?.pointSize ?? 28),
                speed: engine.speedPointsPerSecond, playing: requestedPlaying, restart: lastRestart,
                alignment: view.textAlignment)
        }

        func prepareForResize() {
            guard !updating, let view, view.bounds.height > 0 else { return }
            resizeAnchor = captureAnchor(in: view)
        }

        func tick(_ link: CADisplayLink) {
            guard let view, view.window != nil, !view.isDragging, !view.isDecelerating else { return }
            // Prepare the position for the frame being presented. The previous
            // refresh timestamp falls behind when ProMotion changes cadence.
            probe.measure("frame-work") { advance(at: link.targetTimestamp) }
        }

        func advance(at timestamp: Double) {
            guard let view else { return }
            if needsFrameBaseline {
                _ = engine.apply(.pause)
                _ = engine.apply(.start(at: timestamp))
                needsFrameBaseline = false
            }
            let transition = engine.apply(.tick(at: timestamp))
            probe.frame(time: timestamp, offset: transition.offset)
            if transition.didChangeOffset {
                view.setContentOffset(CGPoint(x: 0, y: transition.offset), animated: false)
            }
            if timestamp - lastCheckpoint >= 1 {
                lastCheckpoint = timestamp
                probe.measure("checkpoint") { checkpoint(captureAnchor(in: view)) }
            }
            if transition.didChangePhase, transition.phase == .paused {
                trace("stopped-\(String(describing: transition.stopReason))", view: view)
                probe.stopped(reason: transition.stopReason.map { String(describing: $0) } ?? "paused")
                link?.isPaused = true
                requestedPlaying = false
                stopped()
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            probe.stopped(reason: "manual-drag")
            _ = engine.apply(.pause)
            requestedPlaying = false
            link?.isPaused = true
            needsFrameBaseline = false
            stopped()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView.isDragging || scrollView.isDecelerating else { return }
            _ = engine.apply(
                .moveBy(points: Double(scrollView.contentOffset.y) - engine.offset, at: CACurrentMediaTime()))
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate, let view { checkpoint(captureAnchor(in: view)) }
        }
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            if let view { checkpoint(captureAnchor(in: view)) }
        }

        func invalidate() {
            if let view {
                let anchor = captureAnchor(in: view)
                if handoff == nil || handoff?.release(self, anchor: anchor) == true { checkpoint(anchor) }
            }
            link?.invalidate()
            link = nil
            _ = engine.apply(.pause)
        }

        func attach(handoff: ReaderAnchorHandoff?) {
            self.handoff = handoff
            if let anchor = handoff?.claim(self) { pendingAnchor = anchor }
        }

        func currentAnchor() -> ReadingAnchor? {
            guard let view, appliedText != nil else { return nil }
            return captureAnchor(in: view)
        }

        private func maximum(in view: UITextView) -> Double {
            max(0, Double(view.contentSize.height - view.bounds.height))
        }

        private func captureAnchor(in view: UITextView) -> ReadingAnchor {
            probe.measure("anchor") { makeAnchor(in: view) }
        }

        private func makeAnchor(in view: UITextView) -> ReadingAnchor {
            let text = appliedText ?? view.text ?? ""
            if view.contentOffset.y <= 0 { return .capture(offset: 0, in: text) }
            guard let position = probe.measure("anchor-hit-test", action: {
                view.closestPosition(to: CGPoint(x: 20, y: view.contentOffset.y + 20))
            }) else {
                return .init()
            }
            let offset = view.offset(from: view.beginningOfDocument, to: position)
            trace("capture", view: view, anchor: offset)
            return probe.measure("anchor-context") { ReadingAnchor.capture(offset: offset, in: text) }
        }

        private func restore(anchor: ReadingAnchor, in view: UITextView) {
            guard
                let position = view.position(
                    from: view.beginningOfDocument, offset: anchor.clamped(to: view.text).utf16Offset)
            else { return }
            let y = view.caretRect(for: position).minY - 20
            trace("restore-y-\(y)", view: view, anchor: anchor.utf16Offset)
            let offset = ReadingPositionMapper.restoredOffset(
                anchorY: Double(y), clipHeight: Double(view.bounds.height),
                viewportFraction: 0, maximumOffset: maximum(in: view))
            _ = engine.apply(.moveBy(points: offset - engine.offset, at: CACurrentMediaTime()))
        }

        private func trace(_ event: String, view: UITextView, anchor: Int? = nil) {
            #if DEBUG && targetEnvironment(simulator)
            guard SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.scriptFlag), layoutTrace.count < 128,
                  let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p2-test-root=") }),
                  let id = UUID(uuidString: String(flag.dropFirst("--p2-test-root=".count))) else { return }
            layoutTrace.append("\(event) anchor=\(anchor ?? -1) bounds=\(view.bounds) content=\(view.contentSize) container=\(view.textContainer.size) font=\(view.font?.pointSize ?? 0) engine=\(engine.offset)/\(engine.maximumOffset) inputSelf=\(view.textInputView === view)")
            let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PhoneCaptureTests/\(id.uuidString)/reader-layout-\(layoutTraceID).txt")
            try? Data(layoutTrace.joined(separator: "\n").utf8).write(to: path, options: .atomic)
            #endif
        }
    }
}

@MainActor final class ReaderTextView: UITextView {
    var onLayout: (@MainActor () -> Void)?
    var beforeResize: (@MainActor () -> Void)?
    private var appliedLightAppearance: Bool?
    private var appliedBackgroundOpacity: Double?

    func applyAppearance(light: Bool, opacity: Double) {
        let changedForeground = appliedLightAppearance != light
        if changedForeground || appliedBackgroundOpacity != opacity {
            backgroundColor = (light ? UIColor.white : UIColor.black).withAlphaComponent(opacity)
            appliedBackgroundOpacity = opacity
        }
        if changedForeground {
            // UITextView rewrites the document's text attributes even when the
            // assigned color is unchanged. A reading checkpoint must not trigger
            // that work across a long script on every second of playback.
            textColor = light ? .black : .white
            appliedLightAppearance = light
        }
    }
    override var bounds: CGRect {
        willSet { if newValue.size != bounds.size { beforeResize?() } }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

@MainActor private final class FrameProxy: NSObject {
    weak var owner: PromptReader.Coordinator?
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}

struct CameraPreview: UIViewRepresentable {
    let source: PreviewSource
    let side: CameraSide
    let orientation: CaptureOrientation
    var probe: ReaderProbe? = nil

    func makeUIView(context: Context) -> PreviewView { PreviewView() }
    func updateUIView(_ view: PreviewView, context: Context) {
        if let probe { probe.measure("preview-update") { source.attach(to: view, side: side) } }
        else { source.attach(to: view, side: side) }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    private var side: CameraSide?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    func configureRotation(side: CameraSide) {
        guard self.side != side else {
            applyRotation()
            return
        }
        self.side = side
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: side == .front ? .front : .back)
        else { return }
        // Read-only device lookup; this view only mutates its own preview connection.
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotation = coordinator
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]
        ) {
            [weak self] _, _ in
            Task { @MainActor [weak self] in self?.applyRotation() }
        }
        applyRotation()
    }

    private func applyRotation() {
        guard let angle = rotation?.videoRotationAngleForHorizonLevelPreview,
            let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle)
        else { return }
        // Reading checkpoints can update this representable once per second.
        // Reapplying an unchanged angle needlessly reconfigures the live preview.
        if connection.videoRotationAngle != angle { connection.videoRotationAngle = angle }
    }
}
