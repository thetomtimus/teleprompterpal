import Foundation
import PrototypeSupport
import Testing
import UIKit

@testable import TeleprompterPhone

actor CaptureBarrier {
    private var released = false
    private var entered = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var observers: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        entered = true
        observers.forEach { $0.resume() }; observers.removeAll()
        if !released { await withCheckedContinuation { waiters.append($0) } }
    }
    func waitUntilEntered() async {
        if !entered { await withCheckedContinuation { observers.append($0) } }
    }
    func release() {
        released = true
        waiters.forEach { $0.resume() }; waiters.removeAll()
    }
}

actor TestCapture: CaptureControlling {
    struct Request: Sendable { let id: UUID; let url: URL; let orientation: CaptureOrientation }
    nonisolated let preview = PreviewSource()
    nonisolated let events: AsyncStream<CaptureEvent>
    private let continuation: AsyncStream<CaptureEvent>.Continuation
    private(set) var requests: [Request] = []
    private(set) var stops: [UUID] = []
    private(set) var configurations = 0
    private(set) var sessionID = UUID()
    private var activeID: UUID?
    private let acceptance: CaptureBarrier?
    private let configuration: CaptureBarrier?
    init(acceptance: CaptureBarrier? = nil, configuration: CaptureBarrier? = nil) {
        self.acceptance = acceptance
        self.configuration = configuration
        let pair = AsyncStream<CaptureEvent>.makeStream()
        events = pair.stream; continuation = pair.continuation
    }
    func configure(side: CameraSide, generation: UUID) async throws {
        configurations += 1
        sessionID = generation
        await configuration?.wait()
    }
    func startPreview() -> CaptureReadiness {
        CaptureReadiness(sessionID: sessionID, cameraName: "Test front camera", microphoneName: "Test microphone")
    }
    func record(id: UUID, to url: URL, orientation: CaptureOrientation) async throws {
        activeID = id
        requests.append(Request(id: id, url: url, orientation: orientation))
        await acceptance?.wait()
    }
    func stop(id: UUID?) { if let id, id == activeID { stops.append(id) } }
    func suspend(generation: UUID?) { if generation == sessionID, let activeID { stops.append(activeID) } }
    func stopPreview(generation: UUID?) {}
    func snapshot() -> CaptureSnapshot {
        CaptureSnapshot(elapsed: 0, thermalState: 0, pressure: "nominal", width: 1920, height: 1080,
                        requestedFPS: 30, hdrEnabled: false, audioInputs: ["test"])
    }
    @available(iOS 27, *) func position(for orientation: CaptureOrientation) -> CapturePosition? { nil }
    func shutdown() { continuation.finish() }
    func preparePlayback(id: UUID) {}
    func finishPlayback(id: UUID) {}
}

private actor TestCapacity {
    var bytes: Int64 = CaptureStoragePolicy.requiredFreeBytes
    func set(_ value: Int64) { bytes = value }
    func read() -> Int64 { bytes }
}

@MainActor private func makeCaptureModel(
    root: URL, capture: TestCapture,
    permissions: @escaping @Sendable () async -> CapturePermissions = { .init(camera: .authorized, microphone: .authorized) },
    capacity: @escaping @Sendable (URL) async throws -> Int64 = { _ in CaptureStoragePolicy.requiredFreeBytes },
    tick: @escaping @Sendable () async throws -> Void = {}
) async -> PrototypeModel {
    let model = PrototypeModel(root: root, capture: capture, requestPermissions: permissions,
                               availableCapacity: capacity, countdownTick: tick)
    await model.initialize()
    await model.enterCamera()
    return model
}

private func captureRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("capture-test-\(UUID())", isDirectory: true)
}

@Test @MainActor func burstStartFreezesTakeContextAndWaitsForTheStartDelegate() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture)
    let context = TakeScriptContext(id: UUID(), revision: 3, title: "Saved title")
    model.orientation = .landscapeLeft
    model.takeContext = context
    model.start()
    model.orientation = .landscapeRight
    model.takeContext = TakeScriptContext(id: UUID(), revision: 9, title: "Changed")
    for _ in 0..<20 { model.start() }
    await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    #expect(await capture.requests.count == 1)
    #expect(request.orientation == .landscapeLeft)
    #expect(model.captureOrientation == .landscapeLeft)
    #expect(try await model.store.load().first?.script == context)
    #expect(model.phase == .starting)
    #expect(!model.playing && model.startedAt == nil)
    await model.handle(.started(UUID()))
    #expect(!model.playing)
    await model.handle(.started(request.id))
    #expect(model.phase == .recording && model.playing)
    model.playing = false
    await model.handle(.started(request.id))
    #expect(!model.playing, "A duplicate start callback must not override a deliberate pause")
    model.stop()
    try await SampleMovie().make(at: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.phase == .idle && model.takes.count == 1)
}

@Test @MainActor func cancelledCountdownCannotResetItsReplacementOperation() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = CaptureBarrier()
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture, tick: {
        await barrier.wait(); try Task.checkCancellation()
    })
    model.start()
    let old = model.countdownTask
    await barrier.waitUntilEntered()
    model.stop()
    #expect(model.phase == .idle)
    model.start()
    let replacement = model.countdownTask
    await barrier.release()
    await old?.value
    await replacement?.value
    #expect(await capture.requests.count == 1)
    #expect(model.phase == .starting)
    let request = try #require(await capture.requests.first)
    try await SampleMovie().make(at: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
}

@Test @MainActor func cancellationAfterDispatchKeepsTheIdentityUntilFinalization() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = CaptureBarrier()
    let capture = TestCapture(acceptance: barrier)
    let model = await makeCaptureModel(root: root, capture: capture)
    model.start()
    await barrier.waitUntilEntered()
    let request = try #require(await capture.requests.first)
    for _ in 0..<20 { model.stop(); model.start() }
    #expect(model.phase == .stopping)
    await barrier.release()
    await model.countdownTask?.value
    #expect(model.phase == .stopping)
    await model.handle(.started(request.id))
    #expect(!model.playing)
    #expect(await capture.stops.contains(request.id))
    try await SampleMovie().make(at: request.url)
    let bytes = try Data(contentsOf: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.phase == .idle)
    #expect(model.takes.first?.state == .ready)
    #expect(try Data(contentsOf: request.url) == bytes)
    #expect(await capture.requests.count == 1)
}

@Test @MainActor func staleDelegatesCannotFinishOrPlayANewerTake() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture)
    model.start(); await model.countdownTask?.value
    let first = try #require(await capture.requests.first)
    try await SampleMovie().make(at: first.url)
    await model.handle(.finished(first.id, first.url, true, nil))
    model.start(); await model.countdownTask?.value
    let second = try #require(await capture.requests.last)
    #expect(first.id != second.id)
    await model.handle(.started(first.id))
    await model.handle(.finished(first.id, first.url, true, nil))
    #expect(model.phase == .starting && !model.playing)
    try await SampleMovie().make(at: second.url)
    await model.handle(.finished(second.id, second.url, true, nil))
    #expect(model.takes.count == 2)
}

@Test(arguments: [false, true]) @MainActor
func permissionDenialKeepsRehearsalAvailable(microphone: Bool) async {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture, permissions: {
        .init(camera: microphone ? .authorized : .denied, microphone: microphone ? .denied : .authorized)
    })
    #expect(!model.cameraReady && !model.canRecord)
    #expect(await capture.configurations == 0)
    #expect(model.message?.contains(microphone ? "microphone" : "camera") == true)
    await model.rehearsal()
    model.playing = true
    #expect(!model.cameraMode && model.playing)
}

@Test @MainActor func backgroundDuringPermissionSetupRequiresIntentionalCameraReentry() async {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let barrier = CaptureBarrier()
    let capture = TestCapture()
    let model = PrototypeModel(root: root, capture: capture, requestPermissions: {
        await barrier.wait(); return .init(camera: .authorized, microphone: .authorized)
    })
    await model.initialize()
    let setup = Task { await model.enterCamera() }
    await barrier.waitUntilEntered()
    model.applicationDeactivated(reason: UIApplication.willResignActiveNotification.rawValue)
    #expect(model.cameraPreparing)
    model.applicationDeactivated(reason: UIApplication.didEnterBackgroundNotification.rawValue)
    await barrier.release()
    await setup.value
    #expect(!model.cameraReady)
    #expect(await capture.configurations == 0)
    await model.enterCamera()
    #expect(model.cameraReady)
    #expect(await capture.configurations == 1)
}

@Test(arguments: CaptureStopReason.allCases) @MainActor
func interruptionPreservesPlayableMediaAndRequiresManualReentry(reason: CaptureStopReason) async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture)
    let generation = try #require(model.cameraInfo?.sessionID)
    model.start(); await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    await model.handle(.started(request.id))
    await model.handle(.interrupted(UUID(), request.id, reason))
    #expect(model.phase == .recording && model.playing, "An old session event is irrelevant")
    await model.handle(.interrupted(generation, request.id, reason))
    #expect(model.phase == .stopping && !model.playing && !model.canRecord)
    try await SampleMovie().make(at: request.url)
    let original = try Data(contentsOf: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.phase == .idle && !model.cameraReady)
    #expect(model.takes.first?.state == .ready)
    #expect(model.takes.first?.note == reason.message)
    #expect(try Data(contentsOf: request.url) == original)
    await model.enterCamera()
    #expect(model.cameraReady && !model.playing)
    await model.handle(.interrupted(generation, nil, reason))
    #expect(model.cameraReady, "A delayed notification from the old session must not suspend reentry")
}

@Test(arguments: [Int64(-1), 1_000_000_000, CaptureStoragePolicy.requiredFreeBytes - 1]) @MainActor
func insufficientHeadroomDoesNotCreateATake(bytes: Int64) async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture, capacity: { _ in bytes })
    model.start(); await model.countdownTask?.value
    #expect(model.phase == .idle && !model.playing)
    #expect(model.message?.contains("2 GB") == true)
    #expect(await capture.requests.isEmpty)
    #expect(try await model.store.load().isEmpty)
}

@Test @MainActor func unavailableStorageFailsClosedBeforeCreatingATake() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture, capacity: { _ in throw CocoaError(.fileReadUnknown) })
    model.start(); await model.countdownTask?.value
    #expect(model.phase == .idle)
    #expect(model.message?.contains("Free space could not be checked") == true)
    #expect(try await model.store.load().isEmpty)
}

@Test @MainActor func lowSpaceDuringCaptureStopsBeforeTheOutputReserve() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capacity = TestCapacity()
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture, capacity: { _ in await capacity.read() })
    model.start(); await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    await model.handle(.started(request.id))
    await capacity.set(CaptureStoragePolicy.finalizationReserve - 1)
    await model.checkCaptureStorage(id: request.id)
    #expect(model.phase == .stopping && !model.cameraReady && !model.playing)
    #expect(CaptureStoragePolicy.finalizationReserve > CaptureStoragePolicy.outputReserve)
    try await SampleMovie().make(at: request.url)
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.takes.first?.note?.contains("free space ran low") == true)
    #expect(model.takes.first?.state == .ready)
}

@Test @MainActor func invalidFinishedMediaIsRetainedAndNeverPublishedReady() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture)
    model.start(); await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    let original = Data("unfinished movie bytes".utf8)
    try original.write(to: request.url)
    await model.handle(.finished(request.id, request.url, false, "Interrupted"))
    #expect(model.phase == .idle)
    #expect(model.takes.first?.state == .incomplete)
    #expect(model.takes.first?.summary == nil)
    #expect(try Data(contentsOf: request.url) == original)
}

@Test @MainActor func journalFailureDoesNotMislabelPlayableMediaAndRelaunchRecoversIt() async throws {
    let root = captureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = TestCapture()
    let model = await makeCaptureModel(root: root, capture: capture)
    model.start(); await model.countdownTask?.value
    let request = try #require(await capture.requests.first)
    try await SampleMovie().make(at: request.url)
    let original = try Data(contentsOf: request.url)
    let journal = root.appendingPathComponent("Takes/takes.json")
    let pendingJournal = try Data(contentsOf: journal)
    try FileManager.default.removeItem(at: journal)
    try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: false)
    await model.handle(.finished(request.id, request.url, true, nil))
    #expect(model.phase == .idle)
    #expect(model.message?.contains("Playable recording retained") == true)
    #expect(try await model.store.load().first?.state == .pending)
    #expect(try Data(contentsOf: request.url) == original)
    try FileManager.default.removeItem(at: journal)
    try pendingJournal.write(to: journal)
    let reopened = PrototypeModel(root: root, capture: TestCapture())
    await reopened.initialize()
    #expect(reopened.takes.first?.state == .ready)
    #expect(try Data(contentsOf: request.url) == original)
}
