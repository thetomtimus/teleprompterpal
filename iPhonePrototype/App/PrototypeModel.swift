import AVFoundation
import AVKit
import Observation
import PromptingCore
import PrototypeSupport
import SwiftUI

enum PrototypePhase: String { case idle, countdown, starting, recording, stopping, validating }

private struct CaptureOperation {
    let id: UUID
    let side: CameraSide
    let orientation: CaptureOrientation
    let script: TakeScriptContext?
    let access: LocalEventPayload.Access
}

struct TakeEditingSession: Identifiable, Sendable {
    let id: UUID
    let takeID: UUID
    let source: URL
}

@MainActor @Observable final class PrototypeModel {
    let mp4Exports: MP4ExportController
    var script = PrototypeModel.sampleScript
    var speed = 30.0
    var fontSize = 28.0
    var playing = false { didSet { if !playing { readerProbe.breakSequence() } } }
    var restart = 0
    var cameraMode = false
    var cameraReady = false
    var cameraPreparing = false
    var cameraInfo: CaptureReadiness?
    var side = CameraSide.front
    var orientation = CaptureOrientation.portrait
    var phase = PrototypePhase.idle
    var countdown = 0
    var startedAt: Date?
    var message: String?
    var takes: [PrototypeTake] = []
    var libraryMessage: String?
    var libraryNotice: String?
    private(set) var refreshingTakes = false
    private(set) var openingTake = false
    private(set) var deletingTakeID: UUID?
    var selected: PrototypeTake?
    var editStart = 0.0
    var editEnd = 0.0
    var cropRatio = "Original"
    var player: AVPlayer?
    var exporting = false
    var progress = 0.0
    var exportedURL: URL?
    var initialized = false
    private var initializing = false
    var probeStatus: String?
    var probeRunning = false
    var initialAnchor: ReadingAnchor?
    var takeContext: TakeScriptContext?
    let capture: any CaptureControlling
    let media = MediaService()
    let store: TakeStore
    let thumbnails: TakeThumbnailStore
    let edits: TakeEditStore
    private(set) var editingSession: TakeEditingSession?
    @ObservationIgnored let readerProbe = ReaderProbe()
    @ObservationIgnored private let diagnostics: DeviceDiagnostics
    @ObservationIgnored private let localEvents: LocalEventRecorder?
    @ObservationIgnored private let eventAccess: @MainActor () -> LocalEventPayload.Access
    @ObservationIgnored private var captureBegan = false
    @ObservationIgnored private var diagnosticTask: Task<Void, Never>?
    private let samples = SampleMovie()
    private var operation: CaptureOperation?
    private var activeID: UUID? { operation?.id }
    private var recordRequestIssued = false
    private var interruptionNote: String?
    @ObservationIgnored private(set) var countdownTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewRevision = UUID()
    private var playbackID: UUID?
    private var playbackTakeID: UUID?
    @ObservationIgnored private(set) var playbackReleaseTask: Task<Void, Never>?
    private var cameraGeneration = UUID()
    private var cameraSessionID: UUID?
    #if DEBUG
    private var fixtureRootIsolated = false
    #endif
    @ObservationIgnored private let requestPermissions: @Sendable () async -> CapturePermissions
    @ObservationIgnored private let availableCapacity: @Sendable (URL) async throws -> Int64
    @ObservationIgnored private let countdownTick: @Sendable () async throws -> Void
    @ObservationIgnored private var lifecycleObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var backgroundFinalization = UIBackgroundTaskIdentifier.invalid

    init(root: URL? = nil, capture: any CaptureControlling = CaptureService(),
         requestPermissions: @escaping @Sendable () async -> CapturePermissions = CaptureAuthorization.request,
         availableCapacity: @escaping @Sendable (URL) async throws -> Int64 = CaptureStoragePolicy.availableCapacity,
         countdownTick: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .seconds(1)) },
         events: LocalEventRecorder? = nil,
         eventAccess: @escaping @MainActor () -> LocalEventPayload.Access = { .unconfigured }) {
        localEvents = events
        self.eventAccess = eventAccess
        self.requestPermissions = requestPermissions
        self.availableCapacity = availableCapacity
        self.countdownTick = countdownTick
        var isolatedRoot = root
        #if DEBUG
        if isolatedRoot == nil, let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p2-test-root=") }),
           let id = UUID(uuidString: String(flag.dropFirst("--p2-test-root=".count))) {
            isolatedRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PhoneCaptureTests/\(id.uuidString)", isDirectory: true)
            fixtureRootIsolated = true
        }
        #endif
        #if DEBUG && targetEnvironment(simulator)
        self.capture = root == nil && isolatedRoot != nil
            && SimulatorIntegrationFixture.accepts(SimulatorIntegrationFixture.captureFlag)
            ? SimulatorCaptureController() : capture
        #else
        self.capture = capture
        #endif
        let storageRoot = isolatedRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PromptPrototype", isDirectory: true)
        let exportCache = isolatedRoot?.appendingPathComponent("VideoExports", isDirectory: true)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("VideoExports", isDirectory: true)
        let jobRoot = storageRoot.appendingPathComponent("ExportJobs")
        #if DEBUG && targetEnvironment(simulator)
        if isolatedRoot != nil, SimulatorIntegrationFixture.accepts("--p4c-export-probe") {
            let lowSpace = ProcessInfo.processInfo.arguments.contains("--p4c-scenario=low-space")
            let marker = storageRoot.appendingPathComponent(".export-space-probe-used")
            mp4Exports = MP4ExportController(store: ExportJobStore(root: jobRoot, outputs: exportCache,
                media: SimulatorExportProbe(), capacity: { url in
                    if lowSpace, !FileManager.default.fileExists(atPath: marker.path) {
                        try Data("used".utf8).write(to: marker, options: .atomic); return 0
                    }
                    return try ExportJobStore.availableCapacity(url)
                }), events: events)
        } else {
            mp4Exports = MP4ExportController(store: ExportJobStore(root: jobRoot, outputs: exportCache), events: events)
        }
        #else
        mp4Exports = MP4ExportController(store: ExportJobStore(root: jobRoot, outputs: exportCache), events: events)
        #endif
        diagnostics = DeviceDiagnostics(root: isolatedRoot?.appendingPathComponent("Diagnostics", isDirectory: true))
        store = TakeStore(root: storageRoot.appendingPathComponent("Takes", isDirectory: true))
        edits = TakeEditStore(root: storageRoot.appendingPathComponent("Edits", isDirectory: true))
        thumbnails = TakeThumbnailStore(root: isolatedRoot?.appendingPathComponent("Thumbnails", isDirectory: true)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TakeThumbnails", isDirectory: true))
        if ProcessInfo.processInfo.arguments.contains("--p1-long-script") {
            script = Array(repeating: PrototypeModel.sampleScript, count: 120).joined(separator: "\n\n")
        }
        // SwiftUI can coalesce a rapid inactive → active transition during a busy render.
        // UIKit notifications deliver each transition, including brief Home/Control Center visits.
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            lifecycleObservers.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] notification in
                    let reason = notification.name.rawValue
                    MainActor.assumeIsolated { self?.applicationDeactivated(reason: reason) }
                })
        }
    }

    var busy: Bool { phase != .idle || exporting || mp4Exports.isBusy || mp4Exports.delivery.isBusy || refreshingTakes || openingTake || deletingTakeID != nil || editingSession != nil }
    var canRecord: Bool { initialized && cameraMode && cameraReady && !cameraPreparing && !busy }
    var captureSide: CameraSide { operation?.side ?? side }
    var captureOrientation: CaptureOrientation { operation?.orientation ?? orientation }

    isolated deinit {
        countdownTask?.cancel()
        eventTask?.cancel()
        diagnosticTask?.cancel()
        previewTask?.cancel()
        exportTask?.cancel()
        for token in lifecycleObservers { NotificationCenter.default.removeObserver(token) }
        if backgroundFinalization != .invalid { UIApplication.shared.endBackgroundTask(backgroundFinalization) }
    }

    func initialize() async {
        guard !initialized, !initializing else { return }
        initializing = true
        defer { initializing = false }
        if eventTask == nil {
            eventTask = Task { [weak self, events = capture.events] in
                for await event in events {
                    guard !Task.isCancelled else { return }
                    await self?.handle(event)
                }
            }
        }
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--p3c-stage-take-fixtures"),
               fixtureRootIsolated {
                try await TakeFixtureSeeder.seed(store: store, media: media)
            }
            #endif
            #if DEBUG && targetEnvironment(simulator)
            if fixtureRootIsolated, SimulatorIntegrationFixture.accepts("--p4b-stage-crop-fixtures") {
                try await CropFixtureSeeder.seed(store: store, media: media)
            }
            #endif
            let pending = Set(try await store.load().filter { $0.state == .pending }.map(\.id))
            takes = try await store.reconcile(inspect: media.inspect)
            for take in takes where pending.contains(take.id) {
                localEvents?.emit(.recordingFinished(outcome: take.isPlayable ? .recoveredValid : .recoveryFailed,
                    duration: .seconds(take.summary?.duration), format: take.summary.map(LocalEventPayload.RecordingFormat.media) ?? .unknown), operationID: take.id)
            }
            try? await mp4Exports.store.recover()
            libraryNotice = await store.recoveryNotice
            libraryMessage = nil
            initialized = true
        } catch {
            libraryMessage = "Could not open recordings: \(error.localizedDescription)"
            message = libraryMessage
        }
    }

    func refreshTakeLibrary() async {
        guard !busy, !initializing, selected == nil else { return }
        refreshingTakes = true
        defer { refreshingTakes = false }
        do {
            _ = try await store.reload()
            takes = try await store.reconcile(inspect: media.inspect)
            libraryNotice = await store.recoveryNotice
            libraryMessage = nil
            initialized = true
        } catch {
            initialized = false
            libraryMessage = "Could not check recordings: \(error.localizedDescription)"
        }
    }

    func thumbnailData(for take: PrototypeTake) async throws -> Data {
        try await thumbnails.data(for: take, source: store.url(for: take))
    }

    func openTake(_ take: PrototypeTake) async {
        guard initialized, !busy, take.isPlayable else { return }
        openingTake = true
        defer { openingTake = false }
        libraryMessage = nil
        do {
            guard let current = try await store.load().first(where: { $0.id == take.id }), current.isPlayable else {
                throw PrototypeError.invalidMedia
            }
            let source = await store.url(for: current)
            _ = try await media.inspect(source)
            playing = false
            await leaveCameraForRehearsal()
            let playbackID = UUID()
            try await capture.preparePlayback(id: playbackID)
            self.playbackID = playbackID
            playbackTakeID = current.id
            previewTask?.cancel()
            previewRevision = UUID()
            player?.pause()
            // Direct original playback; the prototype editing route stays separate for P4.
            player = AVPlayer(url: source)
            selected = current
        } catch {
            libraryMessage = "This recording could not be opened. Refresh Videos to check the original."
        }
    }

    func stopPlayback(takeID: UUID? = nil) {
        if let takeID, playbackTakeID != takeID { return }
        mp4Exports.dismiss()
        editingSession = nil
        previewTask?.cancel()
        previewRevision = UUID()
        player?.pause()
        player = nil
        selected = nil
        playbackTakeID = nil
        if let id = playbackID {
            playbackID = nil
            playbackReleaseTask = Task { @concurrent [capture] in await capture.finishPlayback(id: id) }
        }
    }

    func beginEditingTake(id: UUID) async -> TakeEditingSession? {
        guard !busy, let take = selected, take.id == id, take.isPlayable else { return nil }
        let session = TakeEditingSession(id: UUID(), takeID: id, source: await store.url(for: take))
        guard !busy, selected?.id == id else { return nil }
        editingSession = session
        player?.pause(); player = nil
        let previous = playbackID
        playbackID = nil
        if let previous { await capture.finishPlayback(id: previous) }
        guard editingSession?.id == session.id, selected?.id == id else { return nil }
        let lease = UUID()
        do {
            try await capture.preparePlayback(id: lease)
            guard editingSession?.id == session.id, selected?.id == id else {
                await capture.finishPlayback(id: lease)
                return nil
            }
            playbackID = lease
            playbackTakeID = id
            return session
        } catch {
            guard editingSession?.id == session.id else { return nil }
            stopPlayback(takeID: id)
            libraryMessage = "The video editor could not open. Reopen the recording to retry."
            return nil
        }
    }

    func endEditingTake(_ session: TakeEditingSession) {
        guard editingSession?.id == session.id else { return }
        editingSession = nil
        guard selected?.id == session.takeID else { return }
        // Return paused to the immutable original, with the same playback lease.
        player = AVPlayer(url: session.source)
    }

    func deleteTake(id: UUID) async -> Bool {
        guard initialized, !busy else { return false }
        deletingTakeID = id
        defer { deletingTakeID = nil }
        if selected?.id == id { stopPlayback() }
        await playbackReleaseTask?.value
        do {
            try await store.delete(id: id)
            try? await edits.remove(takeID: id)
            try? await mp4Exports.store.remove(takeID: id)
            try? await mp4Exports.delivery.records.remove(takeID: id)
            try? await thumbnails.remove(id: id)
            takes = try await store.load()
            libraryMessage = nil
            return true
        } catch {
            takes = (try? await store.load()) ?? takes
            libraryMessage = "The deletion could not finish. Refresh Videos or retry the deletion."
            return false
        }
    }

    func enterCamera() async {
        guard !busy, !cameraPreparing, selected == nil else { return }
        cameraPreparing = true
        defer { cameraPreparing = false }
        cameraMode = true
        cameraReady = false
        cameraInfo = nil
        let previousSession = cameraSessionID
        let generation = UUID()
        cameraGeneration = generation
        cameraSessionID = generation
        let requestedSide = side
        message = nil
        if let previousSession { await capture.stopPreview(generation: previousSession) }
        guard cameraMode, !busy, cameraGeneration == generation else { return }
        let permissions = await requestPermissions()
        guard cameraMode, !busy, cameraGeneration == generation else { return }
        if let denial = permissions.denialMessage { message = denial; return }
        do {
            try await capture.configure(side: requestedSide, generation: generation)
            guard cameraMode, !busy, cameraGeneration == generation else {
                await capture.stopPreview(generation: generation)
                return
            }
            let info = try await capture.startPreview()
            guard cameraMode, !busy, cameraGeneration == generation else {
                await capture.stopPreview(generation: generation)
                return
            }
            cameraReady = true
            cameraInfo = info
        } catch {
            if cameraGeneration == generation { message = error.localizedDescription }
            await capture.stopPreview(generation: generation)
        }
    }

    func rehearsal() async {
        guard !busy else { return }
        await leaveCameraForRehearsal()
    }

    private func leaveCameraForRehearsal() async {
        cameraMode = false
        let generation = cameraSessionID
        cameraGeneration = UUID()
        cameraReady = false
        cameraInfo = nil
        cameraSessionID = nil
        if let generation { await capture.stopPreview(generation: generation) }
    }

    func start() {
        guard canRecord else { return }
        message = nil
        playing = false
        phase = .countdown
        countdown = 3
        let operation = CaptureOperation(id: UUID(), side: side, orientation: orientation, script: takeContext, access: eventAccess())
        self.operation = operation
        captureBegan = false
        recordRequestIssued = false
        interruptionNote = nil
        countdownTask = Task { [weak self] in
            guard let self else { return }
            var prepared = false
            do {
                try await preflightStorage()
                for remaining in stride(from: 3, through: 1, by: -1) {
                    try Task.checkCancellation()
                    guard activeID == operation.id, phase == .countdown else { throw CancellationError() }
                    countdown = remaining
                    try await countdownTick()
                }
                try Task.checkCancellation()
                guard activeID == operation.id, phase == .countdown else { throw CancellationError() }
                phase = .starting
                try await preflightStorage()
                try Task.checkCancellation()
                guard activeID == operation.id, phase == .starting else { throw CancellationError() }
                let url = try await store.prepare(id: operation.id, script: operation.script)
                prepared = true
                try Task.checkCancellation()
                guard activeID == operation.id, phase == .starting else { throw CancellationError() }
                beginFinalizationAllowance()
                // Once dispatched, keep this identity until the finish callback. Cancelling
                // the waiting Task cannot tell us whether the actor already opened the file.
                recordRequestIssued = true
                try await capture.record(id: operation.id, to: url, orientation: operation.orientation)
            } catch is CancellationError {
                localEvents?.emit(.recordingFinished(outcome: .cancelledBeforeStart, duration: .unknown), operationID: operation.id)
                if prepared { try? await store.markIncomplete(id: operation.id, note: "Cancelled before capture") }
                finishOperation(id: operation.id)
            } catch {
                localEvents?.emit(.recordingFinished(outcome: .startFailed, duration: .unknown), operationID: operation.id)
                if prepared { try? await store.markIncomplete(id: operation.id, note: error.localizedDescription) }
                if activeID == operation.id { message = error.localizedDescription }
                finishOperation(id: operation.id)
            }
        }
    }

    func stop() {
        playing = false
        if phase == .countdown {
            countdownTask?.cancel()
            if let id = activeID {
                localEvents?.emit(.recordingFinished(outcome: .cancelledBeforeStart, duration: .unknown), operationID: id)
                finishOperation(id: id)
            }
            return
        }
        if phase == .starting, !recordRequestIssued { countdownTask?.cancel() }
        guard phase == .starting || phase == .recording else { return }
        recordLifecycle("stop requested")
        phase = .stopping
        let id = activeID
        Task { @concurrent [capture] in await capture.stop(id: id) }
    }

    func applicationDeactivated(reason: String) {
        // Privacy prompts during camera setup must finish before we suspend the session.
        if cameraPreparing, reason == UIApplication.willResignActiveNotification.rawValue { return }
        recordLifecycle(reason)
        interrupt(reason: "Recording ended when the app became inactive.")
    }

    private func beginFinalizationAllowance() {
        guard backgroundFinalization == .invalid else { return }
        backgroundFinalization = UIApplication.shared.beginBackgroundTask(withName: "Finalize camera take") {
            [weak self] in
            MainActor.assumeIsolated {
                self?.recordLifecycle("background allowance expired")
                self?.interrupt()
                self?.endFinalizationAllowance()
            }
        }
    }

    private func endFinalizationAllowance() {
        guard backgroundFinalization != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundFinalization)
        backgroundFinalization = .invalid
    }

    private func recordLifecycle(_ event: String) {
        if let activeID { diagnostics.event(id: activeID, name: event, phase: phase.rawValue) }
    }

    func interrupt(reason: String = "Recording ended when the app became inactive.") {
        playing = false
        let generation = cameraSessionID
        cameraReady = false
        cameraInfo = nil
        cameraGeneration = UUID()
        cameraSessionID = nil
        if activeID != nil, interruptionNote == nil { interruptionNote = reason }
        player?.pause()
        stop()
        cancelExport()
        if let generation {
            Task { @concurrent [capture] in await capture.suspend(generation: generation) }
        }
    }

    private func finishOperation(id: UUID) {
        guard activeID == id else { return }
        operation = nil
        recordRequestIssued = false
        interruptionNote = nil
        countdown = 0
        phase = .idle
        startedAt = nil
        readerProbe.finish()
        diagnosticTask?.cancel()
        endFinalizationAllowance()
    }

    func checkCaptureStorage(id: UUID) async {
        guard activeID == id, phase == .recording else { return }
        do {
            let capacity = try await availableCapacity(store.root)
            guard activeID == id, phase == .recording else { return }
            if capacity < CaptureStoragePolicy.finalizationReserve {
                interrupt(reason: "Recording ended because free space ran low.")
                message = "Free space is running low. Finalizing the current take."
            }
        } catch {
            guard activeID == id, phase == .recording else { return }
            interrupt(reason: "Recording ended because available storage could not be checked.")
            message = "Could not check free space. Finalizing the current take."
        }
    }

    private func preflightStorage() async throws {
        let capacity: Int64
        do { capacity = try await availableCapacity(store.root) }
        catch { throw CaptureFailure.storageUnknown }
        guard capacity >= CaptureStoragePolicy.requiredFreeBytes else { throw CaptureFailure.storage }
    }

    func makeSample() async {
        guard initialized, !busy else { return }
        phase = .validating
        message = nil
        let id = UUID()
        do {
            let url = try await store.prepare(id: id)
            try await samples.make(at: url)
            let summary = try await media.inspect(url)
            try await store.complete(id: id, summary: summary, note: "Synthetic sample • not a camera recording")
            takes = try await store.load()
            phase = .idle
            if let take = takes.first(where: { $0.id == id }) { await select(take) }
        } catch {
            try? await store.markIncomplete(id: id, note: error.localizedDescription)
            phase = .idle
            message = error.localizedDescription
        }
    }

    func select(_ take: PrototypeTake) async {
        guard !busy, take.isPlayable, let summary = take.summary else { return }
        await rehearsal()
        selected = take
        editStart = 0
        editEnd = summary.duration
        cropRatio = "Original"
        exportedURL = nil
        updatePreview()
    }

    var recipe: EditRecipe {
        let ratio: Double? = ["9:16": 9.0 / 16, "16:9": 16.0 / 9, "1:1": 1.0, "4:5": 4.0 / 5][cropRatio]
        let crop = ratio.map { NormalizedCrop.centered(ratio: $0, in: selected?.summary?.size ?? .zero) } ?? .init()
        return EditRecipe(start: editStart, end: editEnd, crop: crop)
    }

    func updatePreview() {
        guard let selected else { return }
        exportedURL = nil
        previewTask?.cancel()
        let revision = UUID()
        previewRevision = revision
        let recipe = recipe
        player?.pause()
        previewTask = Task {
            do {
                let source = await store.url(for: selected)
                let composition = try await media.composition(source: source, recipe: recipe)
                guard !Task.isCancelled, previewRevision == revision else { return }
                let item = AVPlayerItem(url: source)
                item.videoComposition = composition
                item.forwardPlaybackEndTime = CMTime(seconds: recipe.end.seconds, preferredTimescale: 600)
                player = AVPlayer(playerItem: item)
                await player?.seek(
                    to: CMTime(seconds: recipe.start.seconds, preferredTimescale: 600), toleranceBefore: .zero,
                    toleranceAfter: .zero)
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
        }
    }

    func export() {
        guard let selected, !busy else { return }
        exporting = true
        progress = 0
        message = nil
        let recipe = recipe
        exportTask = Task { [self] in
            do {
                let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("PrototypeExports", isDirectory: true)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                let destination = root.appendingPathComponent(UUID().uuidString + ".mp4")
                let source = await store.url(for: selected)
                let exportStarted = Date()
                let summary = try await media.export(source: source, recipe: recipe, destination: destination) {
                    value in
                    await self.setProgress(value)
                }
                try Task.checkCancellation()
                exportedURL = destination
                diagnostics.exported(id: selected.id, seconds: Date().timeIntervalSince(exportStarted), media: summary)
                message = "MP4 ready to save or share. Original take preserved."
            } catch is CancellationError { message = "Export cancelled. Original take preserved." } catch {
                message = error.localizedDescription
            }
            exporting = false
        }
    }

    func cancelExport() { exportTask?.cancel() }
    private func setProgress(_ value: Double) { progress = value }

    func handle(_ event: CaptureEvent) async {
        switch event {
        case .started(let id):
            guard activeID == id, !captureBegan, phase == .starting || phase == .stopping else { return }
            captureBegan = true
            localEvents?.emit(.recordingStarted(camera: captureSide == .front ? .front : .rear,
                orientation: LocalEventPayload.Orientation(rawValue: captureOrientation.rawValue) ?? .portrait,
                access: operation?.access ?? .unknown), operationID: id)
            startedAt = Date()
            readerProbe.begin()
            diagnostics.begin(id: id, camera: captureSide, orientation: captureOrientation)
            recordLifecycle("capture started")
            diagnosticTask?.cancel()
            diagnosticTask = Task { [weak self] in
                while let self, activeID == id, !Task.isCancelled {
                    var snapshot = await capture.snapshot()
                    snapshot.physicalOrientation = UIDevice.current.orientation.rawValue
                    diagnostics.sample(id: id, capture: snapshot, reader: readerProbe.measurements)
                    await checkCaptureStorage(id: id)
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                }
            }
            if phase == .starting {
                phase = .recording
                playing = true
            } else {
                await capture.stop(id: id)
            }
        case .finished(let id, let url, let success, let note):
            guard activeID == id, phase != .validating else { return }
            recordLifecycle("capture finished")
            playing = false
            phase = .validating
            let summary: MediaSummary
            do { summary = try await media.inspect(url) }
            catch {
                localEvents?.emit(.recordingFinished(outcome: .invalidMedia, duration: .unknown), operationID: id)
                try? await store.markIncomplete(id: id, note: error.localizedDescription)
                takes = (try? await store.load()) ?? takes
                message = "Incomplete recording retained: \(error.localizedDescription)"
                diagnostics.finish(id: id, outcome: "incomplete", media: nil, reader: readerProbe.measurements)
                finishOperation(id: id)
                return
            }
            let warning = interruptionNote ?? note
            do {
                try await store.complete(id: id, summary: summary,
                    note: warning ?? (success ? nil : "Interrupted take recovered"),
                    recovery: success && interruptionNote == nil ? nil : .interrupted)
                takes = try await store.load()
                localEvents?.emit(.recordingFinished(outcome: success && interruptionNote == nil ? .valid : .interruptedValid,
                    duration: .seconds(summary.duration), format: .media(summary)), operationID: id)
                diagnostics.finish(
                    id: id, outcome: success && interruptionNote == nil ? "valid" : "interrupted-valid", media: summary,
                    reader: readerProbe.measurements)
                message = warning.map { "Take saved. \($0)" }
                    ?? (success ? "Take saved." : "Playable interrupted take preserved.")
            } catch {
                // Inspection succeeded. A journal failure must not mislabel valid media
                // or delete it; the pending entry can be reconciled on the next launch.
                message = "Playable recording retained, but its details could not be saved. Reopen the app to recover it."
                localEvents?.emit(.recordingFinished(outcome: .journalFailure, duration: .seconds(summary.duration), format: .media(summary)), operationID: id)
                diagnostics.finish(id: id, outcome: "journal-error-valid", media: summary, reader: readerProbe.measurements)
            }
            finishOperation(id: id)
        case .interrupted(let generation, let id, let reason):
            guard cameraSessionID == generation, id == nil || activeID == id else { return }
            interrupt(reason: reason.message)
            message = "\(reason.message) Finalizing any current take. Enter Camera again when ready."
        case .status(let info):
            guard cameraSessionID == info.sessionID, cameraReady else { return }
            cameraInfo = info
        }
    }

    static let sampleScript = """
        Look into the lens and take a breath.

        This is the first camera and prompting test. The script stays on screen while the saved video contains only the camera and microphone.

        Speak at a comfortable pace. You can pause the text without stopping the recording, drag to a different line, or adjust the font and speed.

        Try a second take in landscape. Check the framing, listen to the audio, and compare the original with a trimmed and cropped export.

        한국어 문장도 자연스럽게 읽어 보세요. Emoji test: 👋🏽 🎥 👨‍👩‍👧‍👦. العربية: مرحباً بكم.

        When you reach the end, the prompt pauses. Tap Stop to finish your take.
        """
}
