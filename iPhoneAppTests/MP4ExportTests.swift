import AVFoundation
import Foundation
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

// These real media tests share Simulator audio/encoder resources.
@Suite(.serialized) struct MP4ExportTests {
@Test func realSimulatorMP4JobProducesValidatedCroppedMedia() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("p4c-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("original.mov"), media = MediaService(), take = UUID()
    try await SampleMovie().make(at: source, orientation: .right, mirrored: true)
    let bytes = try Data(contentsOf: source)
    let identity = try TakeEditSource(url: source, summary: await media.inspect(source))
    let edits = TakeEditStore(root: root.appendingPathComponent("edits"))
    let edit = try await edits.save(takeID: take, source: identity,
        recipe: EditRecipe(start: 0.5, end: 2.5, crop: .init(x: 0.2, y: 0.1, width: 0.6, height: 0.7), cropPreset: .custom), expectedRevision: 0)
    let store = ExportJobStore(root: root.appendingPathComponent("jobs"), outputs: root.appendingPathComponent("outputs"), media: media)
    let job = try await store.prepare(id: UUID(), edit: edit)
    let ready = try await store.run(id: job.id, source: source) { _, _ in }
    #expect(ready.state == .ready, "\(ready.message ?? "no error")")
    let lease = try await store.acquireOutput(takeID: take, source: source)
    let exported = try await media.inspect(lease.url)
    #expect(exported.videoCodec == "avc1" && exported.audioCodec == "aac ")
    #expect(exported.size == CGSize(width: 144, height: 224))
    #expect(abs(exported.duration - 2) <= 1.0 / 30)
    #expect(try Data(contentsOf: source) == bytes)
    await store.release(lease)
}

@Test @MainActor func controllerCancellationRejectsLateCallbacksAndRestoresInterruptedWork() async throws {
    let (root, source, edit) = try await mp4Fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let bytes = try Data(contentsOf: source), engine = ControlledMP4Engine()
    let store = ExportJobStore(root: root.appendingPathComponent("jobs"), outputs: root.appendingPathComponent("outputs"), media: engine)
    let controller = MP4ExportController(store: store)
    await controller.open(edit: edit, source: source)
    try await waitForMP4 { controller.progress.fraction > 0 }
    controller.cancel()
    try await waitForMP4 { !controller.isBusy }
    #expect(controller.phase == .cancelled && controller.outputURL == nil)
    let stopped = controller.progress.fraction
    await engine.emitFirstProgress()
    #expect(controller.progress.fraction == stopped)
    controller.retry()
    try await waitForMP4 { controller.progress.fraction > 0 && controller.isBusy }
    await engine.emitFirstProgress()
    #expect(controller.progress.fraction < 0.9)
    controller.interrupt()
    try await waitForMP4 { !controller.isBusy }
    #expect(controller.phase == .interrupted)
    await controller.leave()
    let restored = MP4ExportController(store: ExportJobStore(root: root.appendingPathComponent("jobs"),
        outputs: root.appendingPathComponent("outputs"), media: engine))
    await restored.open(edit: edit, source: source)
    #expect(restored.phase == .interrupted && !restored.isBusy)
    #expect(await engine.calls == 2)
    await engine.release()
    restored.retry()
    try await waitForMP4 { restored.phase == .ready && !restored.isBusy }
    #expect(restored.outputURL != nil)
    await restored.leave()
    #expect(try Data(contentsOf: source) == bytes)
}

@Test @MainActor func realExportPlaybackReuseAndDeletionRespectOwnership() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("export-owner-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let recorder = PrototypeModel(root: root, capture: SimulatorCaptureController())
    await recorder.initialize()
    let id = UUID(), source = try await recorder.store.prepare(id: id)
    try await SampleMovie().make(at: source)
    try await recorder.store.complete(id: id, summary: recorder.media.inspect(source))
    await recorder.refreshTakeLibrary()
    let take = try #require(recorder.takes.first)
    await recorder.openTake(take)
    let session = try #require(await recorder.beginEditingTake(id: id))
    let model = VideoEditorModel(session: session, title: "Synthetic", store: recorder.edits, media: recorder.media)
    await model.load(); model.setStart(0.3); model.setEnd(2.7)
    let edit = try #require(await model.exportSnapshot())
    await recorder.mp4Exports.open(edit: edit, source: source)
    try await waitForMP4 { recorder.mp4Exports.phase == .ready && !recorder.mp4Exports.isBusy }
    let readyID = try #require(recorder.mp4Exports.job?.id)
    #expect(!(await recorder.deleteTake(id: id)))
    recorder.mp4Exports.togglePlayback()
    try await waitForMP4 { recorder.mp4Exports.player.currentTime().seconds > 0.4 }
    await recorder.mp4Exports.leave()
    await recorder.mp4Exports.open(edit: edit, source: source)
    #expect(recorder.mp4Exports.phase == .ready && recorder.mp4Exports.job?.id == readyID)
    await recorder.mp4Exports.leave()
    model.close(); recorder.endEditingTake(session); recorder.stopPlayback(takeID: id)
    await recorder.playbackReleaseTask?.value
    #expect(await recorder.deleteTake(id: id))
    #expect(!FileManager.default.fileExists(atPath: source.path))
}

@Test(arguments: [false, true]) @MainActor
func stopBeforeTheWorkerStartsPreservesTheRequestedOutcome(interrupted: Bool) async throws {
    let (root, source, edit) = try await mp4Fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let bytes = try Data(contentsOf: source)
    let store = ExportJobStore(root: root.appendingPathComponent("jobs"), outputs: root.appendingPathComponent("outputs"))
    let controller = MP4ExportController(store: store)
    await controller.open(edit: edit, source: source)
    // No yield between starting the worker and stopping it: preparation may
    // be cancelled before the durable job has been created.
    if interrupted { controller.interrupt() } else { controller.cancel() }
    try await waitForMP4 { !controller.isBusy }
    #expect(controller.phase == (interrupted ? .interrupted : .cancelled))
    #expect(controller.outputURL == nil)
    let job = try await store.load(takeID: edit.takeID)
    #expect(job == nil || job?.state == (interrupted ? .interrupted : .cancelled))
    #expect(try Data(contentsOf: source) == bytes)
    await controller.leave()
}

@Test func realAVFoundationCancellationRemovesStagingAndPreservesOriginal() async throws {
    let (root, source, _) = try await mp4Fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let asset = AVURLAsset(url: source), composition = AVMutableComposition()
    let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let audio = try #require(try await asset.loadTracks(withMediaType: .audio).first)
    let videoTrack = try #require(composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid))
    let audioTrack = try #require(composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid))
    for index in 0..<24 {
        let at = CMTime(seconds: Double(index) * 3, preferredTimescale: 600)
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))
        try videoTrack.insertTimeRange(range, of: video, at: at)
        try audioTrack.insertTimeRange(range, of: audio, at: at)
    }
    let longer = root.appendingPathComponent("72-second.mov"), output = root.appendingPathComponent("cancelled.mp4")
    let mux = try #require(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
    try await mux.export(to: longer, as: .mov)
    let bytes = try Data(contentsOf: longer), media = MediaService(), values = MP4ProgressProbe()
    let task = Task { try await media.export(source: longer, recipe: .init(start: 0, end: 72), destination: output) {
        await values.update($0)
    } }
    defer { task.cancel() }
    let deadline = ContinuousClock.now.advanced(by: .seconds(8))
    while await values.fraction <= 0 {
        guard ContinuousClock.now < deadline else { throw MP4WaitFailure.timeout }
        try await Task.sleep(for: .milliseconds(20))
    }
    task.cancel()
    var cancelled = false
    do { _ = try await task.value } catch { cancelled = true }
    #expect(cancelled)
    #expect(!FileManager.default.fileExists(atPath: output.path))
    #expect(!FileManager.default.fileExists(atPath: output.deletingPathExtension().appendingPathExtension("encoding.mp4").path))
    #expect(try Data(contentsOf: longer) == bytes)
}

@Test func validationRejectsRenamedMOVAndMP4sWithTheWrongSavedEdit() async throws {
    let (root, source, edit) = try await mp4Fixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let media = MediaService(), disguised = root.appendingPathComponent("renamed.mp4")
    try FileManager.default.copyItem(at: source, to: disguised)
    await #expect(throws: ExportFailure.self) { try await media.validateExport(disguised, edit: edit) }
    let output = root.appendingPathComponent("valid.mp4")
    _ = try await media.export(source: source, recipe: edit.recipe, destination: output)
    _ = try await media.validateExport(output, edit: edit)
    let store = TakeEditStore(root: root.appendingPathComponent("edits"))
    let cropped = try await store.save(takeID: edit.takeID, source: edit.source,
        recipe: .init(start: 0, end: 3, crop: .init(x: 0, y: 0, width: 0.5, height: 1)), expectedRevision: edit.revision)
    await #expect(throws: ExportFailure.self) { try await media.validateExport(output, edit: cropped) }
    let trimmed = try await store.save(takeID: edit.takeID, source: edit.source,
        recipe: .init(start: 0, end: 2), expectedRevision: cropped.revision)
    await #expect(throws: ExportFailure.self) { try await media.validateExport(output, edit: trimmed) }
}
}

private enum MP4WaitFailure: Error { case timeout }
@MainActor private func waitForMP4(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !condition() {
        guard ContinuousClock.now < deadline else { throw MP4WaitFailure.timeout }
        try await Task.sleep(for: .milliseconds(20))
    }
}
private func mp4Fixture() async throws -> (URL, URL, SavedTakeEdit) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("mp4-fixture-\(UUID())")
    let source = root.appendingPathComponent("original.mov"), media = MediaService()
    try await SampleMovie().make(at: source)
    let edit = try await TakeEditStore(root: root.appendingPathComponent("edits")).save(takeID: UUID(),
        source: TakeEditSource(url: source, summary: await media.inspect(source)), recipe: .init(start: 0, end: 3), expectedRevision: 0)
    return (root, source, edit)
}
private actor MP4ProgressProbe {
    var fraction = 0.0
    func update(_ value: Double) { fraction = value }
}
private actor ControlledMP4Engine: MP4Exporting {
    let media = MediaService()
    var held = true
    var calls = 0
    var callbacks: [@Sendable (Double) async -> Void] = []
    func release() { held = false }
    func emitFirstProgress() async { await callbacks.first?(0.99) }
    func inspect(_ url: URL) async throws -> MediaSummary { try await media.inspect(url) }
    func validateExport(_ url: URL, edit: SavedTakeEdit) async throws -> MediaSummary { try await media.validateExport(url, edit: edit) }
    func export(source: URL, recipe: EditRecipe, destination: URL,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> MediaSummary {
        calls += 1; callbacks.append(progress); await progress(0.4)
        while held { try await Task.sleep(for: .milliseconds(10)) }
        return try await media.export(source: source, recipe: recipe, destination: destination, progress: progress)
    }
}
