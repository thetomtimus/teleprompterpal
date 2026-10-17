import AVFoundation
import PhoneLibrary
import PromptingCore
import PrototypeSupport
import Testing
import UIKit

@testable import TeleprompterPhone

private enum IntegrationPose: CaseIterable, Sendable {
    case frontPortrait, frontLeft, frontRight, rearPortrait, rearLeft, rearRight
    var side: CameraSide { [.frontPortrait, .frontLeft, .frontRight].contains(self) ? .front : .rear }
    var orientation: CaptureOrientation {
        switch self {
        case .frontPortrait, .rearPortrait: .portrait
        case .frontLeft, .rearLeft: .landscapeLeft
        case .frontRight, .rearRight: .landscapeRight
        }
    }
}

private let integrationWords = ["Read", "한국어", "漢字", "café", "🎥", "👩🏽‍💻", "مرحبا", "שלום", "carefully", "today"]
private var longIntegrationScript: String {
    (0..<1000).map { _ in integrationWords.joined(separator: " ") }.joined(separator: "\n")
}
private func p3dRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("p3d-\(UUID())") }

@MainActor private func readerView(_ coordinator: PromptReader.Coordinator, text: String,
                                   playing: Bool, anchor: ReadingAnchor? = nil) -> ReaderTextView {
    let view = ReaderTextView(usingTextLayoutManager: false)
    view.layoutManager.allowsNonContiguousLayout = false
    view.frame = CGRect(x: 0, y: 0, width: 360, height: 240)
    view.textContainerInset = .init(top: 12, left: 14, bottom: 80, right: 14)
    view.beforeResize = { coordinator.prepareForResize() }
    view.onLayout = { coordinator.layoutChanged() }
    coordinator.view = view
    coordinator.update(text: text, fontSize: 28, speed: 30, playing: playing, restart: 0, initialAnchor: anchor)
    return view
}

@Test(arguments: IntegrationPose.allCases) @MainActor
private func scriptReaderCapturePlaybackAndCameraReentryPreserveIdentity(pose: IntegrationPose) async throws {
    let root = p3dRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = LibraryModel(root: root.appendingPathComponent("Scripts"))
    await library.initialize()
    let text = longIntegrationScript
    #expect(text.split(whereSeparator: \.isWhitespace).count == 10_000)
    let id = try #require(library.create(title: "Retained 한국어 lesson", text: text))
    let script = try #require(library.script(id))
    let context = TakeScriptContext(id: id, revision: script.document.revision, title: script.document.title)
    let capture = TestCapture()
    let model = PrototypeModel(root: root.appendingPathComponent("Capture"), capture: capture,
        requestPermissions: { .init(camera: .authorized, microphone: .authorized) }, countdownTick: {})
    await model.initialize()
    model.script = text; model.side = pose.side; model.orientation = pose.orientation; model.takeContext = context
    await model.enterCamera()
    let oldGeneration = try #require(model.cameraInfo?.sessionID)
    var anchors: [ReadingAnchor] = []
    let coordinator = PromptReader.Coordinator(probe: model.readerProbe,
        checkpoint: { anchors.append($0); library.checkpoint($0, scriptID: id) }, stopped: { model.playing = false })
    let view = readerView(coordinator, text: text, playing: false,
                          anchor: .capture(offset: text.utf16.count - 1800, in: text))
    defer { coordinator.invalidate() }
    model.start(); await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    #expect(!model.playing && model.phase == .starting)
    model.side = pose.side == .front ? .rear : .front
    model.orientation = pose.orientation == .portrait ? .landscapeRight : .portrait
    library.edit(id, title: "Renamed later", text: text)
    await model.handle(.started(request.id))
    #expect(model.playing && model.phase == .recording)
    #expect(model.captureSide == pose.side && model.captureOrientation == pose.orientation)
    #expect(request.orientation == pose.orientation)
    coordinator.update(text: text, fontSize: 28, speed: 30, playing: model.playing, restart: 0)
    coordinator.advance(at: 1); coordinator.advance(at: 1 + 1.0 / 60)
    let baseline = try #require(anchors.last)
    #expect(abs(baseline.utf16Offset - (text.utf16.count - 1800)) < 200)
    // Reproduce a native rotation arriving before UIKit updates the container.
    // The reader must establish coherent geometry before a playing frame runs.
    view.textContainer.widthTracksTextView = false
    for (index, alignment) in [NSTextAlignment.natural, .center, .right].enumerated() {
        coordinator.update(text: text, fontSize: Double(30 + index * 5), speed: Double(40 + index * 10),
                           playing: model.playing, restart: 0, alignment: alignment)
        view.bounds.size = index == 1 ? CGSize(width: 620, height: 164) : CGSize(width: 280, height: 210)
        view.layoutIfNeeded()
        #expect(abs(view.textContainer.size.width - (view.bounds.width - 28)) < 0.01)
        let time = 2 + Double(index)
        coordinator.advance(at: time)
        let before = view.contentOffset.y
        coordinator.advance(at: time + 1.0 / 60)
        #expect(view.contentOffset.y > before)
        #expect(abs(try #require(anchors.last).utf16Offset - baseline.utf16Offset) < 200)
        #expect(model.phase == .recording && model.playing)
    }
    model.playing = false
    coordinator.update(text: text, fontSize: 40, speed: 60, playing: false, restart: 0)
    model.restart += 1
    coordinator.update(text: text, fontSize: 40, speed: 60, playing: false, restart: model.restart)
    #expect(view.contentOffset.y == 0 && model.phase == .recording)
    model.stop()
    try await SampleMovie().make(at: request.url, rotated: pose.orientation == .portrait)
    let original = try Data(contentsOf: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
    let take = try #require(model.takes.first)
    #expect(take.script == context && take.isPlayable)
    await model.openTake(take)
    #expect(model.selected?.id == take.id)
    #expect((model.player?.currentItem?.asset as? AVURLAsset)?.url == request.url)
    await model.enterCamera()
    #expect(model.selected?.id == take.id && !model.cameraMode)
    model.stopPlayback(takeID: take.id)
    await model.playbackReleaseTask?.value
    await model.enterCamera()
    #expect(model.cameraReady && !model.playing)
    await model.handle(.interrupted(oldGeneration, nil, .audioInterrupted))
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.cameraReady && model.phase == .idle && !model.playing)
    #expect(try Data(contentsOf: request.url) == original)
    coordinator.invalidate()
    await library.flush()
    let reloaded = LibraryModel(root: root.appendingPathComponent("Scripts"))
    await reloaded.initialize()
    #expect(reloaded.script(id)?.document.text == text)
    #expect(reloaded.script(id)?.document.title == "Renamed later")
    #expect(try await model.store.load().first?.script == context)
}

@Test(arguments: ["", "The final sentence. 한국어 🎥 مرحبا"]) @MainActor
func reachingTheScriptEndPausesTextWhileTheTakeKeepsRecording(text: String) async throws {
    let root = p3dRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = PrototypeModel(root: root, capture: capture,
        requestPermissions: { .init(camera: .authorized, microphone: .authorized) }, countdownTick: {})
    await model.initialize(); await model.enterCamera()
    model.start(); await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    await model.handle(.started(request.id))
    let coordinator = PromptReader.Coordinator(probe: model.readerProbe, stopped: { model.playing = false })
    let view = readerView(coordinator, text: text, playing: true)
    defer { coordinator.invalidate() }
    for frame in 0..<600 { coordinator.advance(at: Double(frame) / 60) }
    #expect(!model.playing && model.phase == .recording)
    #expect(await capture.stops.isEmpty)
    coordinator.update(text: text, fontSize: 38, speed: 240, playing: false, restart: 1)
    #expect(view.contentOffset.y == 0 && model.phase == .recording)
    model.stop()
    try await SampleMovie().make(at: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.takes.first?.isPlayable == true)
}

@Test @MainActor func tenMinutesOfLogicalReaderFramesKeepMovingWithoutChangingTheScript() throws {
    let text = longIntegrationScript, probe = ReaderProbe()
    var stops = 0
    let coordinator = PromptReader.Coordinator(probe: probe, stopped: { stops += 1 })
    let view = readerView(coordinator, text: text, playing: true)
    defer { coordinator.invalidate() }
    probe.begin()
    for frame in 0...36_000 { coordinator.advance(at: Double(frame) / 60) }
    #expect(stops == 0)
    #expect(abs(probe.measurements.activeSeconds - 600) < 0.001)
    #expect(abs(probe.measurements.distancePoints - 18_000) < 1)
    #expect(probe.measurements.gapsOver50ms == 0)
    #expect(view.text == text)
    #expect(view.isAccessibilityElement)
    #expect(view.accessibilityElements?.isEmpty == true)
    #expect(view.accessibilityValue == text)
}

private actor IntegrationPermissions {
    var permissions: CapturePermissions
    init(cameraDenied: Bool) {
        permissions = .init(camera: cameraDenied ? .denied : .authorized,
                            microphone: cameraDenied ? .authorized : .denied)
    }
    func read() -> CapturePermissions { permissions }
    func grant() { permissions = .init(camera: .authorized, microphone: .authorized) }
}

@Test(arguments: [false, true]) @MainActor
func settingsGrantNeedsDeliberateCameraReentryWithoutStartingATake(cameraDenied: Bool) async throws {
    let root = p3dRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture(), permissions = IntegrationPermissions(cameraDenied: cameraDenied)
    let model = PrototypeModel(root: root, capture: capture, requestPermissions: { await permissions.read() })
    await model.initialize(); await model.enterCamera()
    #expect(!model.cameraReady && !model.canRecord)
    #expect(await capture.configurations == 0)
    await permissions.grant()
    #expect(!model.cameraReady, "Settings changes alone do not restart capture")
    await model.rehearsal()
    #expect(!model.cameraMode)
    await model.enterCamera()
    #expect(model.cameraReady && model.message == nil)
    #expect(model.phase == .idle && !model.playing)
    #expect(await capture.requests.isEmpty)
}

@Test(.timeLimit(.minutes(1))) @MainActor
func delayedCameraSetupCannotReplaceAnOpenedOriginal() async throws {
    let root = p3dRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = CaptureBarrier(), capture = TestCapture(configuration: barrier)
    let model = PrototypeModel(root: root, capture: capture,
        requestPermissions: { .init(camera: .authorized, microphone: .authorized) })
    await model.initialize()
    #expect(model.initialized)
    let url = try await model.store.prepare(id: UUID())
    try await SampleMovie().make(at: url)
    let take = try #require(try await model.store.load().first)
    try await model.store.complete(id: take.id, summary: model.media.inspect(url))
    await model.refreshTakeLibrary()
    let ready = try #require(model.takes.first)
    let setup = Task { await model.enterCamera() }
    await barrier.waitUntilEntered()
    await model.openTake(ready)
    await barrier.release()
    await setup.value
    #expect(model.selected?.id == ready.id && model.player != nil)
    #expect(!model.cameraReady && !model.cameraMode && !model.cameraPreparing)
    model.stopPlayback(takeID: ready.id)
    await model.playbackReleaseTask?.value
}
