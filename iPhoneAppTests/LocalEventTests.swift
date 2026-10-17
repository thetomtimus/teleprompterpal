import Foundation
import PhoneLibrary
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

@Suite(.serialized) struct LocalEventTests {
    @Test func journalDeduplicatesByOperationAndStageAcrossRelaunch() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = LocalEventJournal(root: root), id = UUID()
        let started = event(id, .recordingStarted(camera: .front, orientation: .portrait, access: .inactive))
        await journal.append(started); await journal.append(started)
        await journal.append(event(id, .recordingFinished(outcome: .valid, duration: .underMinute)))
        await journal.append(event(id, .exportResult(stage: .file, outcome: .ready, trimmed: false, cropped: false, ratio: .original)))
        await journal.append(event(id, .exportResult(stage: .photos, outcome: .completed, trimmed: false, cropped: false, ratio: .original)))
        let reopened = LocalEventJournal(root: root)
        await reopened.append(started)
        #expect(await reopened.snapshot().count == 4)
        #expect(await reopened.status == .healthy)
    }

    @Test func journalBoundsRetentionAndRejectsOldOrFutureEvents() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = LocalEventJournal(root: root), now = Date()
        for _ in 0..<505 { await journal.append(event(UUID(), .scriptReady(origin: .createOrPaste, length: .short), at: now), now: now) }
        #expect(await journal.snapshot().count == LocalEventJournal.maximumEvents)
        let file = root.appendingPathComponent("events.json")
        #expect(try Data(contentsOf: file).count <= LocalEventJournal.maximumBytes)
        let before = try Data(contentsOf: file)
        await journal.append(event(UUID(), .scriptReady(origin: .imported, length: .long), at: now.addingTimeInterval(120)), now: now)
        #expect(try Data(contentsOf: file) == before)
        let later = now.addingTimeInterval(31 * 86400)
        await journal.append(event(UUID(), .scriptReady(origin: .imported, length: .short), at: later), now: later)
        #expect(await journal.snapshot().count == 1)
    }

    @Test(arguments: ["corrupt", "future", "oversized"])
    func unreadableJournalsArePreservedAndNeverBreakCallers(kind: String) async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("events.json")
        let bytes = kind == "future" ? Data(#"{"schemaVersion":2,"events":[]}"#.utf8)
            : kind == "oversized" ? Data(repeating: 65, count: LocalEventJournal.maximumBytes + 1) : Data("broken".utf8)
        try bytes.write(to: file)
        let journal = LocalEventJournal(root: root)
        await journal.append(event(UUID(), .scriptReady(origin: .createOrPaste, length: .short)))
        #expect(await journal.status == .unavailable)
        #expect(await journal.snapshot().isEmpty)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test @MainActor func scriptReadyRequiresSuccessfulNonemptyPersistenceAndNeverIncludesContent() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events"))
        let scripts = root.appendingPathComponent("Scripts"), model = LibraryModel(root: scripts, events: events)
        await model.initialize()
        let id = try #require(model.create(title: "PRIVATE TITLE"))
        await model.flush(); await events.flush()
        #expect(await events.journal.snapshot().isEmpty)
        model.edit(id, title: "PRIVATE TITLE", text: String(repeating: "x", count: TextImport.maximumBytes + 1))
        await model.flush(); await events.flush()
        #expect(model.saveStatus == "Changes not saved")
        #expect(await events.journal.snapshot().isEmpty)
        model.edit(id, title: "PRIVATE TITLE", text: "PRIVATE SCRIPT 한국어 🎥")
        await model.flush(); await model.flush()
        model.edit(id, title: "PRIVATE TITLE", text: "PRIVATE SCRIPT revised")
        await model.flush()
        _ = try #require(model.duplicate(id)); await model.flush()
        let input = root.appendingPathComponent("PRIVATE FILE.txt")
        try Data("PRIVATE IMPORT".utf8).write(to: input)
        _ = try #require(await model.importText(input)); await model.flush(); await events.flush()
        let before = await events.journal.snapshot()
        #expect(before.count == 3)
        #expect(before.map(\.payload) == [.scriptReady(origin: .createOrPaste, length: .short),
            .scriptReady(origin: .duplicated, length: .short), .scriptReady(origin: .imported, length: .short)])
        let reopened = LibraryModel(root: scripts, events: events)
        await reopened.initialize()
        reopened.edit(id, title: "Another title", text: "Another edit")
        await reopened.flush(); await events.flush()
        #expect(await events.journal.snapshot() == before)
        let raw = try String(contentsOf: root.appendingPathComponent("Events/events.json"), encoding: .utf8)
        #expect(!raw.contains("PRIVATE") && !raw.contains(input.path) && !raw.contains("한국어"))
    }

    @Test @MainActor func captureEventsRequireDelegatesIgnoreDuplicatesAndKeepFrozenAccess() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events")), capture = TestCapture()
        let model = makeRecorder(root, events: events, capture: capture)
        await model.initialize(); await model.enterCamera()
        model.start(); model.start(); await model.countdownTask?.value; await events.flush()
        #expect(await events.journal.snapshot().isEmpty)
        let request = try #require(await capture.requests.first)
        await model.handle(.started(UUID()))
        await model.handle(.started(request.id)); await model.handle(.started(request.id))
        model.stop()
        try await SampleMovie().make(at: request.url)
        await model.handle(.finished(request.id, request.url, true, nil))
        await model.handle(.finished(request.id, request.url, true, nil))
        await events.flush()
        let rows = await events.journal.snapshot()
        #expect(rows.count == 2 && rows.allSatisfy { $0.operationID == request.id })
        #expect(rows[0].payload == .recordingStarted(camera: .front, orientation: .portrait, access: .inactive))
        #expect(rows[1].payload == .recordingFinished(outcome: .valid, duration: .underMinute, format: .other))
        #expect(model.takes.count == 1 && model.takes.first?.isPlayable == true)
    }

    @Test @MainActor func invalidAndInterruptedCapturesHaveDistinctTerminalOutcomes() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events")), capture = TestCapture()
        let model = makeRecorder(root, events: events, capture: capture)
        await model.initialize(); await model.enterCamera()
        model.start(); await model.countdownTask?.value
        let invalid = try #require(await capture.requests.last)
        await model.handle(.started(invalid.id)); model.stop()
        await model.handle(.finished(invalid.id, invalid.url, false, "PRIVATE ERROR"))
        model.start(); await model.countdownTask?.value
        let interrupted = try #require(await capture.requests.last)
        await model.handle(.started(interrupted.id)); model.interrupt()
        try await SampleMovie().make(at: interrupted.url)
        await model.handle(.finished(interrupted.id, interrupted.url, false, "PRIVATE ERROR"))
        await events.flush()
        let rows = await events.journal.snapshot()
        #expect(rows.filter { $0.payload == .recordingFinished(outcome: .invalidMedia, duration: .unknown) }.count == 1)
        #expect(rows.filter { $0.payload == .recordingFinished(outcome: .interruptedValid, duration: .underMinute, format: .other) }.count == 1)
        let raw = try String(contentsOf: root.appendingPathComponent("Events/events.json"), encoding: .utf8)
        #expect(!raw.contains("PRIVATE ERROR"))
    }

    @Test @MainActor func telemetryWriteFailureCannotStopCaptureOrDiscardItsTake() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocked = root.appendingPathComponent("Blocked")
        try Data("file in place of directory".utf8).write(to: blocked)
        let events = LocalEventRecorder(root: blocked), capture = TestCapture()
        let model = makeRecorder(root, events: events, capture: capture)
        await model.initialize(); await model.enterCamera(); model.start(); await model.countdownTask?.value
        let request = try #require(await capture.requests.first)
        await model.handle(.started(request.id)); await events.flush()
        #expect(await events.journal.status == .unavailable)
        #expect(model.phase == .recording && model.playing)
        model.stop(); try await SampleMovie().make(at: request.url)
        await model.handle(.finished(request.id, request.url, true, nil)); await events.flush()
        #expect(model.phase == .idle && model.takes.first?.isPlayable == true)
    }

    @Test @MainActor func exportReadinessDeliveryAttemptsAndReopenHaveSeparateDedupeKeys() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events"))
        let source = root.appendingPathComponent("PRIVATE original.mov"), media = MediaService()
        try await SampleMovie().make(at: source)
        let original = try Data(contentsOf: source)
        let edit = try await TakeEditStore(root: root.appendingPathComponent("Edits")).save(takeID: UUID(),
            source: TakeEditSource(url: source, summary: media.inspect(source)),
            recipe: .init(start: 0.3, end: 2.7, crop: .centered(ratio: 1, in: .init(width: 320, height: 240))), expectedRevision: 0)
        let jobs = ExportJobStore(root: root.appendingPathComponent("Jobs"), outputs: root.appendingPathComponent("Outputs"))
        let controller = MP4ExportController(store: jobs, photos: P5DEventPhotoSaver(), events: events)
        await controller.open(edit: edit, source: source)
        try await wait { controller.phase == .ready && !controller.isBusy }
        let job = try #require(controller.job)
        let delivery = controller.delivery
        delivery.start(.photos); delivery.start(.photos)
        try await wait { !delivery.isBusy }
        delivery.start(.photos)
        delivery.start(.files); try await wait { delivery.presentation != nil }
        let cancelled = try #require(delivery.presentation?.id)
        delivery.completePresentation(id: cancelled, completed: false)
        delivery.completePresentation(id: cancelled, completed: true, reference: "PRIVATE REFERENCE")
        try await wait { !delivery.isBusy }
        delivery.start(.files); try await wait { delivery.presentation != nil }
        let files = try #require(delivery.presentation?.id)
        delivery.completePresentation(id: cancelled, completed: true)
        delivery.completePresentation(id: files, completed: true, reference: "PRIVATE PATH")
        try await wait { !delivery.isBusy }
        delivery.start(.share); try await wait { delivery.presentation != nil }
        delivery.completePresentation(id: try #require(delivery.presentation?.id), completed: true)
        try await wait { !delivery.isBusy }
        await controller.leave(); await events.flush()
        let before = await events.journal.snapshot()
        #expect(before.count == 5)
        #expect(before.first?.operationID == job.id)
        #expect(before.filter { if case .exportResult(stage: .file, outcome: .ready, trimmed: true, cropped: true, ratio: .square) = $0.payload { true } else { false } }.count == 1)
        #expect(before.filter { if case .exportResult(stage: .files, outcome: .cancelled, trimmed: true, cropped: true, ratio: .square) = $0.payload { true } else { false } }.count == 1)
        let reopenedEvents = LocalEventRecorder(root: root.appendingPathComponent("Events"))
        let reopened = MP4ExportController(store: jobs, events: reopenedEvents)
        await reopened.open(edit: edit, source: source); await reopenedEvents.flush()
        #expect(await reopenedEvents.journal.snapshot() == before)
        #expect(reopened.delivery.photosSaved)
        await reopened.leave()
        #expect(try Data(contentsOf: source) == original)
        let raw = try String(contentsOf: root.appendingPathComponent("Events/events.json"), encoding: .utf8)
        #expect(!raw.contains("PRIVATE") && !raw.contains("synthetic-photo") && !raw.contains(source.path))
    }

    @Test @MainActor func pendingDeliveryRecoveryLogsUnknownWithoutInventingCompletion() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events"))
        let source = root.appendingPathComponent("original.mov"), media = MediaService()
        try await SampleMovie().make(at: source)
        let edit = try await TakeEditStore(root: root.appendingPathComponent("Edits")).save(takeID: UUID(),
            source: TakeEditSource(url: source, summary: media.inspect(source)), recipe: .init(start: 0, end: 3), expectedRevision: 0)
        let jobs = ExportJobStore(root: root.appendingPathComponent("Jobs"), outputs: root.appendingPathComponent("Outputs"))
        let prepared = try await jobs.prepare(id: UUID(), edit: edit)
        let job = try await jobs.run(id: prepared.id, source: source) { _, _ in }
        let deliveries = root.appendingPathComponent("Deliveries")
        let pending = try await DeliveryStore(root: deliveries).begin(exportID: job.id, edit: edit, destination: .files)
        let controller = MP4DeliveryController(exports: jobs, records: DeliveryStore(root: deliveries), events: events)
        await controller.open(job: job, source: source); await controller.open(job: job, source: source)
        await events.flush()
        let rows = await events.journal.snapshot()
        #expect(rows.count == 1 && rows[0].operationID == pending.id)
        #expect(rows[0].payload == .exportResult(stage: .files, outcome: .unknown, trimmed: false, cropped: false, ratio: .original))
    }

    @Test @MainActor func pendingTakeReconciliationEmitsOnlyOneRecoveredOutcome() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events")), capture = TestCapture()
        let captureRoot = root.appendingPathComponent("Capture")
        let store = TakeStore(root: captureRoot.appendingPathComponent("Takes"))
        let id = UUID(), url = try await store.prepare(id: id)
        try await SampleMovie().make(at: url)
        let model = makeRecorder(root, events: events, capture: capture)
        await model.initialize(); await events.flush()
        let before = await events.journal.snapshot()
        #expect(before.count == 1 && before[0].operationID == id)
        #expect(before[0].payload == .recordingFinished(outcome: .recoveredValid, duration: .underMinute, format: .other))
        let next = makeRecorder(root, events: events, capture: TestCapture())
        await next.initialize(); await events.flush()
        #expect(await events.journal.snapshot() == before)
    }

    @Test @MainActor func exportCancellationInterruptionFailureAndRetryKeepTruthfulEvents() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let events = LocalEventRecorder(root: root.appendingPathComponent("Events"))
        let source = root.appendingPathComponent("original.mov"), media = MediaService()
        try await SampleMovie().make(at: source)
        let original = try Data(contentsOf: source)
        let edit = try await TakeEditStore(root: root.appendingPathComponent("Edits")).save(takeID: UUID(),
            source: TakeEditSource(url: source, summary: media.inspect(source)), recipe: .init(start: 0, end: 3), expectedRevision: 0)
        let engine = P5DEventExportEngine()
        let jobs = ExportJobStore(root: root.appendingPathComponent("Jobs"), outputs: root.appendingPathComponent("Outputs"), media: engine)
        let controller = MP4ExportController(store: jobs, events: events)
        await controller.open(edit: edit, source: source)
        try await wait { controller.progress.fraction > 0 }
        controller.cancel(); try await wait { !controller.isBusy }
        #expect(controller.phase == .cancelled)
        controller.retry(); try await wait { controller.progress.fraction > 0 && controller.isBusy }
        controller.interrupt(); try await wait { !controller.isBusy }
        #expect(controller.phase == .interrupted)
        await controller.leave()
        let reopened = MP4ExportController(store: jobs, events: events)
        await reopened.open(edit: edit, source: source)
        await engine.releaseWithOneFailure()
        reopened.retry(); try await wait { !reopened.isBusy }
        #expect(reopened.phase == .failed)
        reopened.retry(); try await wait { reopened.phase == .ready && !reopened.isBusy }
        await reopened.leave(); await events.flush()
        let rows = await events.journal.snapshot()
        #expect(rows.count == 4)
        let outcomes = rows.compactMap { row -> LocalEventPayload.ExportOutcome? in
            if case .exportResult(.file, let outcome, _, _, _) = row.payload { outcome } else { nil }
        }
        #expect(outcomes == [.cancelled, .interrupted, .failed, .ready])
        #expect(Set(rows.map(\.operationID)).count == 4)
        #expect(try Data(contentsOf: source) == original)
    }

    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("p5d-\(UUID())") }
    private func event(_ id: UUID, _ payload: LocalEventPayload, at: Date = Date()) -> LocalEvent {
        .init(operationID: id, at: at, runtime: .simulator, payload: payload)
    }
    @MainActor private func makeRecorder(_ root: URL, events: LocalEventRecorder, capture: TestCapture) -> PrototypeModel {
        PrototypeModel(root: root.appendingPathComponent("Capture"), capture: capture,
            requestPermissions: { .init(camera: .authorized, microphone: .authorized) },
            availableCapacity: { _ in CaptureStoragePolicy.requiredFreeBytes }, countdownTick: {}, events: events, eventAccess: { .inactive })
    }
    @MainActor private func wait(_ predicate: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(20)
        while !predicate(), Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        try #require(predicate(), "P5D operation did not finish")
    }
}

private actor P5DEventPhotoSaver: PhotoLibrarySaving {
    func authorization() -> AddPhotoAuthorization { .allowed }
    func requestAddOnly() -> AddPhotoAuthorization { .allowed }
    func saveVideo(at url: URL) -> String { "PRIVATE PHOTO IDENTIFIER" }
}

private actor P5DEventExportEngine: MP4Exporting {
    private let media = MediaService()
    private var held = true
    private var failNext = false
    func inspect(_ url: URL) async throws -> MediaSummary { try await media.inspect(url) }
    func validateExport(_ url: URL, edit: SavedTakeEdit) async throws -> MediaSummary { try await media.validateExport(url, edit: edit) }
    func releaseWithOneFailure() { held = false; failNext = true }
    func export(source: URL, recipe: EditRecipe, destination: URL,
        progress: @escaping @Sendable (Double) async -> Void) async throws -> MediaSummary {
        await progress(0.1)
        while held { try await Task.sleep(for: .milliseconds(20)) }
        if failNext { failNext = false; throw CocoaError(.fileWriteOutOfSpace) }
        return try await media.export(source: source, recipe: recipe, destination: destination, progress: progress)
    }
}
