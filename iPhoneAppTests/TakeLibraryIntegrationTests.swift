import AVFoundation
import Foundation
import PhoneLibrary
import PrototypeSupport
import Testing

@testable import TeleprompterPhone

private actor PlaybackCaptureSpy: CaptureControlling {
    nonisolated let preview = PreviewSource()
    nonisolated let events = AsyncStream<CaptureEvent> { _ in }
    private(set) var audioLease: UUID?
    private(set) var preparationCount = 0
    func configure(side: CameraSide, generation: UUID) {}
    func startPreview() -> CaptureReadiness { .init(sessionID: UUID(), cameraName: "Test", microphoneName: "Test") }
    func record(id: UUID, to url: URL, orientation: CaptureOrientation) throws { throw PrototypeError.busy }
    func stop(id: UUID?) {}
    func suspend(generation: UUID?) {}
    func stopPreview(generation: UUID?) {}
    func snapshot() -> CaptureSnapshot {
        .init(elapsed: 0, thermalState: 0, pressure: "nominal", width: 1920, height: 1080,
              requestedFPS: 30, hdrEnabled: false, audioInputs: [])
    }
    @available(iOS 27, *) func position(for orientation: CaptureOrientation) -> CapturePosition? { nil }
    func shutdown() {}
    func preparePlayback(id: UUID) { audioLease = id; preparationCount += 1 }
    func finishPlayback(id: UUID) { if audioLease == id { audioLease = nil } }
}

private func integrationRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("take-integration-\(UUID())") }

@MainActor private func addMovie(_ model: PrototypeModel, context: TakeScriptContext? = nil) async throws -> (UUID, URL) {
    let id = UUID()
    let url = try await model.store.prepare(id: id, script: context)
    try await SampleMovie().make(at: url)
    try await model.store.complete(id: id, summary: model.media.inspect(url))
    return (id, url)
}

@Test @MainActor func scriptTrashRestoreAndOriginalDeletionAreIndependent() async throws {
    let root = integrationRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let library = LibraryModel(root: root.appendingPathComponent("Scripts"))
    await library.initialize()
    let scriptID = try #require(library.create(title: "한국어 Lesson", text: "Keep this script and its 🎥 text."))
    await library.flush()
    let script = try #require(library.script(scriptID))
    let context = TakeScriptContext(id: scriptID, revision: script.document.revision, title: script.document.title)
    let model = PrototypeModel(root: root.appendingPathComponent("Capture"), capture: PlaybackCaptureSpy())
    await model.initialize()
    let (id, source) = try await addMovie(model, context: context)
    let original = try Data(contentsOf: source)
    await model.refreshTakeLibrary()
    library.setDeleted(scriptID, deleted: true)
    await library.flush()
    await model.refreshTakeLibrary()
    #expect(model.takes.first?.script == context)
    #expect(try Data(contentsOf: source) == original)
    library.setDeleted(scriptID, deleted: false)
    library.edit(scriptID, title: "Renamed script", text: script.document.text)
    await library.flush()
    #expect(TakeGroup.grouped(model.takes).first?.title == "한국어 Lesson")
    _ = try await model.thumbnailData(for: #require(model.takes.first))
    #expect(await model.deleteTake(id: id))
    #expect(!FileManager.default.fileExists(atPath: source.path))
    #expect(model.takes.isEmpty)
    let reopened = LibraryModel(root: root.appendingPathComponent("Scripts"))
    await reopened.initialize()
    #expect(reopened.script(scriptID)?.document.text == script.document.text)
    #expect(reopened.script(scriptID)?.deletedAt == nil)
    #expect(reopened.script(scriptID)?.document.title == "Renamed script")
}

@Test @MainActor func originalPlaybackAndScopedDismissalPreserveTheNewSelection() async throws {
    let root = integrationRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let capture = PlaybackCaptureSpy()
    let model = PrototypeModel(root: root, capture: capture)
    await model.initialize()
    let (firstID, firstURL) = try await addMovie(model)
    let (secondID, _) = try await addMovie(model)
    await model.refreshTakeLibrary()
    let first = try #require(model.takes.first { $0.id == firstID })
    let second = try #require(model.takes.first { $0.id == secondID })
    await model.openTake(first)
    #expect((model.player?.currentItem?.asset as? AVURLAsset)?.url == firstURL)
    #expect(model.player?.currentItem?.videoComposition == nil)
    let player = try #require(model.player)
    for _ in 0..<100 where player.currentItem?.status == .unknown {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(player.currentItem?.status == .readyToPlay)
    player.play()
    for _ in 0..<100 where player.currentTime().seconds < 0.25 {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(player.currentTime().seconds >= 0.25)
    player.pause()
    await model.openTake(second)
    model.stopPlayback(takeID: firstID)
    #expect(model.selected?.id == secondID)
    #expect(model.player != nil)
    #expect(await capture.preparationCount == 2)
    model.stopPlayback(takeID: secondID)
    await model.playbackReleaseTask?.value
    #expect(model.player == nil && model.selected == nil)
    #expect(await capture.audioLease == nil)
}

@Test @MainActor func incompleteAndMissingOriginalsNeverOpenOrReturnCachedThumbnails() async throws {
    let root = integrationRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = PrototypeModel(root: root, capture: PlaybackCaptureSpy())
    let badID = UUID()
    let badURL = try await model.store.prepare(id: badID)
    try Data("incomplete".utf8).write(to: badURL)
    await model.initialize()
    let bad = try #require(model.takes.first)
    await model.openTake(bad)
    #expect(model.selected == nil && !bad.isPlayable)
    await #expect(throws: PrototypeError.invalidMedia) { _ = try await model.thumbnailData(for: bad) }
    let (id, url) = try await addMovie(model)
    await model.refreshTakeLibrary()
    let ready = try #require(model.takes.first { $0.id == id })
    _ = try await model.thumbnailData(for: ready)
    try FileManager.default.removeItem(at: url)
    await model.refreshTakeLibrary()
    let missing = try #require(model.takes.first { $0.id == id })
    #expect(missing.state == .missing)
    await model.openTake(missing)
    #expect(model.selected == nil)
    await #expect(throws: PrototypeError.invalidMedia) { _ = try await model.thumbnailData(for: missing) }
}
