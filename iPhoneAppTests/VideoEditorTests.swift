import AVFoundation
import Foundation
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

private struct EditorWaitFailure: Error {}
@MainActor private func editorWait(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(6))
    while !condition() {
        guard ContinuousClock.now < deadline else { throw EditorWaitFailure() }
        try await Task.sleep(for: .milliseconds(20))
    }
}

@MainActor private struct EditorFixture {
    let root: URL
    let source: URL
    let store: TakeEditStore
    let media = MediaService()
    let id = UUID()
    init() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("editor-\(UUID())")
        source = root.appendingPathComponent("original.mov")
        store = TakeEditStore(root: root.appendingPathComponent("Edits"))
        try await SampleMovie().make(at: source, rotated: true)
    }
    func model() -> VideoEditorModel {
        VideoEditorModel(session: .init(id: UUID(), takeID: id, source: source), title: "한국어 🎥 sample",
                         store: store, media: media)
    }
}

@Test @MainActor func trimmedPreviewAdvancesStopsAtTheEndAndRewindsForReplay() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let original = try Data(contentsOf: fixture.source), model = fixture.model()
    defer { model.close() }
    await model.load()
    #expect(model.ready)
    model.setStart(0.4); model.setEnd(1.2); model.scrub(to: model.start)
    try await editorWait { abs(model.player.currentTime().seconds - 0.4) < 0.02 }
    model.togglePlayback()
    try await editorWait { model.player.currentTime().seconds > 0.55 }
    try await editorWait { !model.transport.isPlaying && abs(model.player.currentTime().seconds - 0.4) < 0.02 }
    #expect(abs((model.player.currentItem?.forwardPlaybackEndTime.seconds ?? 0) - 1.2) < 0.01)
    model.togglePlayback()
    try await editorWait { model.player.currentTime().seconds > 0.55 }
    model.pause()
    #expect(!model.transport.isPlaying)
    await model.reset()
    model.togglePlayback()
    try await editorWait { model.player.currentTime().seconds > 0.5 }
    try await editorWait { !model.transport.isPlaying && model.player.currentTime().seconds < 0.02 }
    #expect(try Data(contentsOf: fixture.source) == original)
}

@Test @MainActor func savedTrimReopensWhileCancelledDraftAndResetLeaveItUntouched() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let first = fixture.model()
    await first.load(); first.setStart(0.5); first.setEnd(2)
    #expect(await first.save()); first.close()
    let second = fixture.model()
    await second.load()
    #expect(second.start == 0.5 && second.end == 2)
    second.setStart(0.8); second.setEnd(1.6); second.close()
    let third = fixture.model()
    await third.load()
    #expect(third.start == 0.5 && third.end == 2)
    await third.reset()
    #expect(third.start == 0 && abs(third.end - 3) < 0.01)
    third.close()
    let fourth = fixture.model()
    await fourth.load()
    #expect(fourth.start == 0.5 && fourth.end == 2)
    fourth.close()
}

@Test @MainActor func trimClampsInvalidInputAndPreservesASavedCustomCrop() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let source = try TakeEditSource(url: fixture.source, summary: await fixture.media.inspect(fixture.source))
    let crop = NormalizedCrop(x: 0.1, y: 0.2, width: 0.8, height: 0.6)
    _ = try await fixture.store.save(takeID: fixture.id, source: source,
        recipe: .init(end: 3, crop: crop), expectedRevision: 0)
    let model = fixture.model()
    defer { model.close() }
    await model.load()
    model.setStart(.nan); model.setEnd(.infinity)
    #expect(model.start == 0 && model.end == 3)
    model.setStart(100); model.setEnd(-100)
    #expect(model.selectionDuration > 0)
    #expect(abs(model.selectionDuration - model.frameStep) <= 1.0 / 600)
    try model.draft.validate(duration: model.duration)
    model.setStart(-100); model.setEnd(100)
    model.setStart(0.5); model.setEnd(2.5)
    #expect(await model.save())
    #expect(try await fixture.store.load(takeID: fixture.id, source: source)?.recipe.crop == crop)
    await model.reset()
    #expect(model.draft.crop == NormalizedCrop())
}

@Test @MainActor func futureSavedEditsLeaveOriginalPreviewAvailableButPreventOverwrite() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let directory = await fixture.store.root
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent(fixture.id.uuidString + ".json")
    let bytes = Data("{\"schemaVersion\":99,\"future\":true}".utf8)
    try bytes.write(to: path)
    let model = fixture.model()
    defer { model.close() }
    await model.load()
    #expect(model.ready && model.writeBlocked && !model.canSave)
    #expect(model.start == 0 && model.end == 3)
    #expect(model.message?.contains("newer") == true)
    #expect(await model.save() == false)
    #expect(try Data(contentsOf: path) == bytes)
}

@Test @MainActor func failedSaveRetainsTheDraftAndCanBeRetried() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let bytes = try Data(contentsOf: fixture.source), model = fixture.model()
    defer { model.close() }
    await model.load(); model.setStart(0.5); model.setEnd(2)
    let root = await fixture.store.root
    try Data("blocked destination".utf8).write(to: root)
    #expect(await model.save() == false)
    #expect(model.start == 0.5 && model.end == 2 && model.hasChanges && model.canSave)
    #expect(model.message?.contains("draft is still here") == true)
    try FileManager.default.removeItem(at: root)
    #expect(await model.save())
    #expect(!model.hasChanges)
    #expect(try Data(contentsOf: fixture.source) == bytes)
}

private actor EditorCapture: CaptureControlling {
    nonisolated let preview = PreviewSource()
    nonisolated let events = AsyncStream<CaptureEvent> { _ in }
    private(set) var lease: UUID?
    private(set) var preparations = 0
    private let barrier: CaptureBarrier?
    init(barrier: CaptureBarrier? = nil) { self.barrier = barrier }
    func configure(side: CameraSide, generation: UUID) {}
    func startPreview() -> CaptureReadiness { .init(sessionID: UUID(), cameraName: "Test", microphoneName: "Test") }
    func record(id: UUID, to url: URL, orientation: CaptureOrientation) throws { throw PrototypeError.busy }
    func stop(id: UUID?) {}
    func suspend(generation: UUID?) {}
    func stopPreview(generation: UUID?) {}
    func snapshot() -> CaptureSnapshot { .init(elapsed: 0, thermalState: 0, pressure: "test", width: 320,
        height: 240, requestedFPS: 30, hdrEnabled: false, audioInputs: []) }
    @available(iOS 27, *) func position(for orientation: CaptureOrientation) -> CapturePosition? { nil }
    func shutdown() {}
    func preparePlayback(id: UUID) async {
        lease = id; preparations += 1
        if preparations == 2 { await barrier?.wait() }
    }
    func finishPlayback(id: UUID) { if lease == id { lease = nil } }
}

@MainActor private func editorRecording(_ capture: EditorCapture) async throws -> (PrototypeModel, URL, URL) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("editor-ownership-\(UUID())")
    let model = PrototypeModel(root: root, capture: capture)
    await model.initialize()
    let source = try await model.store.prepare(id: UUID())
    try await SampleMovie().make(at: source)
    let pending = try #require(try await model.store.load().first)
    try await model.store.complete(id: pending.id, summary: model.media.inspect(source))
    await model.refreshTakeLibrary()
    await model.openTake(try #require(model.takes.first))
    return (model, root, source)
}

@Test @MainActor func editorOwnershipBlocksDeletionAndOldDismissalsCannotEndANewEditor() async throws {
    let capture = EditorCapture()
    let (recorder, root, source) = try await editorRecording(capture)
    defer { try? FileManager.default.removeItem(at: root) }
    let take = try #require(recorder.selected)
    let original = try Data(contentsOf: source), oldLease = try #require(await capture.lease)
    let first = try #require(await recorder.beginEditingTake(id: take.id))
    #expect(recorder.busy && recorder.player == nil)
    #expect(await capture.lease != oldLease)
    #expect(await capture.preparations == 2)
    #expect(await recorder.deleteTake(id: take.id) == false)
    await recorder.enterCamera()
    #expect(!recorder.cameraReady && !recorder.playing)
    recorder.endEditingTake(first)
    #expect(!recorder.busy && recorder.player != nil)
    #expect((recorder.player?.currentItem?.asset as? AVURLAsset)?.url == source)
    #expect(recorder.player?.currentItem?.videoComposition == nil)
    let second = try #require(await recorder.beginEditingTake(id: take.id))
    recorder.endEditingTake(first)
    #expect(recorder.editingSession?.id == second.id)
    recorder.stopPlayback(takeID: take.id)
    await recorder.playbackReleaseTask?.value
    #expect(recorder.editingSession == nil && recorder.selected == nil)
    #expect(await capture.lease == nil)
    #expect(try Data(contentsOf: source) == original)
}

@Test @MainActor func closingDuringEditorPreparationRejectsItsLatePlaybackLease() async throws {
    let barrier = CaptureBarrier(), capture = EditorCapture(barrier: barrier)
    let (recorder, root, _) = try await editorRecording(capture)
    defer { try? FileManager.default.removeItem(at: root) }
    let id = try #require(recorder.selected?.id)
    let opening = Task { await recorder.beginEditingTake(id: id) }
    await barrier.waitUntilEntered()
    recorder.stopPlayback(takeID: id)
    await barrier.release()
    #expect(await opening.value == nil)
    #expect(recorder.editingSession == nil && recorder.selected == nil && recorder.player == nil)
    #expect(await capture.lease == nil)
}

@Test @MainActor func cropDraftApplySaveAndReopenPreserveTrimAndCustomMode() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let original = try Data(contentsOf: fixture.source), model = fixture.model()
    await model.load()
    var selection = try #require(model.cropSelection())
    selection.select(.custom); selection.size(width: 0.61, height: 0.53)
    selection.position(horizontal: 0.8, vertical: 0.2)
    #expect(model.draft.crop == NormalizedCrop())
    model.applyCrop(selection); model.setStart(0.5); model.setEnd(2.5)
    #expect(model.start == 0.5 && model.end == 2.5 && model.draft.cropPreset == .custom)
    #expect(model.draft.crop == selection.crop)
    #expect(model.player.currentItem?.videoComposition == nil)
    #expect(await model.save()); model.close()
    let restored = fixture.model(); await restored.load()
    #expect(restored.draft.crop == selection.crop && restored.draft.cropPreset == .custom)
    #expect(restored.start == 0.5 && restored.end == 2.5)
    var cancelled = try #require(restored.cropSelection())
    cancelled.select(.square)
    #expect(restored.draft.crop == selection.crop)
    restored.close()
    #expect(try Data(contentsOf: fixture.source) == original)
}

@Test @MainActor func croppedSourcePlaybackAdvancesAndResetClearsCropMode() async throws {
    let fixture = try await EditorFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let model = fixture.model(); defer { model.close() }
    await model.load()
    var selection = try #require(model.cropSelection())
    selection.select(.landscape); model.applyCrop(selection)
    model.togglePlayback()
    try await editorWait { model.player.currentTime().seconds > 0.5 }
    #expect(model.player.currentItem?.videoComposition == nil)
    model.pause(); await model.reset()
    #expect(model.draft.crop == NormalizedCrop() && model.draft.cropPreset == nil)
    #expect(model.start == 0 && model.end == 3)
}
