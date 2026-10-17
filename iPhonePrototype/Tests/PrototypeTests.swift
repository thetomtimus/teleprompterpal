import PrototypeSupport
import Testing
import UIKit

@testable import TeleprompterPrototype

@Test @MainActor func briefUIKitDeactivationStopsCaptureAndRequiresCameraReentry() {
    let model = PrototypeModel()
    model.cameraMode = true
    model.cameraReady = true
    model.phase = .recording
    model.playing = true
    // Reproduces the brief Home → foreground transition even if SwiftUI coalesces scenePhase.
    NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
    #expect(model.phase == .stopping)
    #expect(!model.playing)
    #expect(!model.cameraReady)
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    #expect(model.phase == .stopping)
}

@Test @MainActor func readerKeepsScrollingAcrossUnrelatedUIUpdatesAndPaceChanges() {
    let probe = ReaderProbe()
    probe.begin()
    var stopCount = 0
    let coordinator = PromptReader.Coordinator(probe: probe) { stopCount += 1 }
    let view = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 210))
    coordinator.view = view
    defer { coordinator.invalidate() }
    let script = Array(repeating: "A long script must keep scrolling during status updates.", count: 100).joined(
        separator: "\n")
    coordinator.update(text: script, fontSize: 28, speed: 30, playing: true, restart: 0)
    coordinator.advance(at: 1)
    coordinator.advance(at: 1 + 1.0 / 60)
    // A status/banner update must not advance the engine to wall time ahead of the next frame.
    coordinator.update(text: script, fontSize: 28, speed: 30, playing: true, restart: 0)
    coordinator.advance(at: 1 + 2.0 / 60)
    #expect(abs(probe.measurements.distancePoints - 1) < 0.000_001)
    coordinator.update(text: script, fontSize: 28, speed: 60, playing: true, restart: 0)
    coordinator.advance(at: 1 + 3.0 / 60)
    #expect(abs(probe.measurements.distancePoints - 2) < 0.000_001)
    #expect(stopCount == 0)
}

@Test @MainActor func readerProbeDoesNotCountDeliberatePauseAsAFrameHitch() {
    let probe = ReaderProbe()
    probe.begin()
    probe.frame(time: 0, offset: 0)
    probe.frame(time: 1.0 / 60, offset: 0.5)
    probe.breakSequence()
    probe.frame(time: 10, offset: 0.5)
    probe.frame(time: 10 + 1.0 / 60, offset: 1)
    #expect(probe.measurements.frameCount == 4)
    #expect(probe.measurements.gapsOver50ms == 0)
    #expect(abs(probe.measurements.activeSeconds - 1.0 / 30) < 0.000_001)
    #expect(probe.measurements.distancePoints == 1)
}

@Test @MainActor func simulatorExplainsUnavailableCameraWithoutStartingCapture() async {
    #if targetEnvironment(simulator)
    let model = PrototypeModel()
    await model.enterCamera()
    #expect(!model.cameraReady)
    #expect(model.phase == .idle)
    #expect(model.message?.contains("Simulator") == true)
    #endif
}
