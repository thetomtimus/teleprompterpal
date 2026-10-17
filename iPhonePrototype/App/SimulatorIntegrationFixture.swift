#if DEBUG && targetEnvironment(simulator)
import Foundation
import PrototypeSupport

/// Explicit opt-in, UUID-isolated Simulator validation only. No device or Release entry point.
enum SimulatorIntegrationFixture {
    static let scriptFlag = "--p3d-stage-script"
    static let captureFlag = "--p3d-simulate-capture"
    static let title = "Simulator integration sample"
    static var text: String {
        let words = ["Read", "한국어", "漢字", "café", "🎥", "👩🏽‍💻", "مرحبا", "שלום", "carefully", "today"]
        return Array(repeating: words.joined(separator: " "), count: 1000).joined(separator: "\n")
    }
    static func accepts(_ flag: String, arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        guard arguments.contains(flag),
              let root = arguments.first(where: { $0.hasPrefix("--p2-test-root=") }),
              UUID(uuidString: String(root.dropFirst("--p2-test-root=".count))) != nil else { return false }
        return true
    }
}

/// Exercises native app transitions with an actual synthetic MOV, never a live
/// camera. Preview remains empty; framing, sensor orientation and sync need hardware.
actor SimulatorCaptureController: CaptureControlling {
    nonisolated let preview = PreviewSource()
    nonisolated let events: AsyncStream<CaptureEvent>
    private let continuation: AsyncStream<CaptureEvent>.Continuation
    private let playback = CaptureService()
    private var generation = UUID()
    private var side = CameraSide.front
    private var ready = false
    private var active: (id: UUID, url: URL)?
    private var preparing = false
    private var stopRequested = false

    init() {
        let pair = AsyncStream<CaptureEvent>.makeStream()
        events = pair.stream; continuation = pair.continuation
    }
    func configure(side: CameraSide, generation: UUID) throws {
        guard active == nil else { throw CaptureFailure.busy }
        self.generation = generation; self.side = side; ready = true
    }
    func startPreview() throws -> CaptureReadiness {
        guard ready else { throw CaptureFailure.noCamera }
        return .init(sessionID: generation, cameraName: "Simulated \(side.rawValue) camera",
            microphoneName: "Synthetic sample audio",
            warning: "Simulator test: synthetic 320 × 240 movie. No camera or microphone capture.")
    }
    func record(id: UUID, to url: URL, orientation: CaptureOrientation) async throws {
        guard ready, active == nil else { throw CaptureFailure.busy }
        active = (id, url); preparing = true; stopRequested = false
        do { try await SampleMovie().make(at: url, orientation: orientation == .portrait ? .right : .up, timingMarkers: true) }
        catch { active = nil; preparing = false; throw error }
        preparing = false
        continuation.yield(.started(id))
        if stopRequested { finish() }
    }
    func stop(id: UUID?) {
        guard let active, id == nil || id == active.id else { return }
        stopRequested = true
        if !preparing { finish() }
    }
    private func finish() {
        guard let active else { return }
        self.active = nil
        continuation.yield(.finished(active.id, active.url, true, nil))
    }
    func suspend(generation: UUID?) {
        guard generation == nil || generation == self.generation else { return }
        ready = false; stop(id: active?.id)
    }
    func stopPreview(generation: UUID?) {
        guard generation == nil || generation == self.generation, active == nil else { return }
        ready = false
    }
    func snapshot() -> CaptureSnapshot {
        .init(elapsed: 0, thermalState: 0, pressure: "synthetic", width: 320, height: 240,
              requestedFPS: 30, hdrEnabled: false, audioInputs: ["Synthetic sample audio"],
              sessionRunning: false, outputRecording: active != nil, stopRequested: stopRequested)
    }
    @available(iOS 27, *) func position(for orientation: CaptureOrientation) -> CapturePosition? { nil }
    func shutdown() async { suspend(generation: nil); await playback.shutdown(); continuation.finish() }
    func preparePlayback(id: UUID) async throws { try await playback.preparePlayback(id: id) }
    func finishPlayback(id: UUID) async { await playback.finishPlayback(id: id) }
}
#endif
