import Foundation
import Testing
@testable import PrototypeSupport

private enum ProbeFailure: Error { case injected, timeout }

private actor ExportProbe: MP4Exporting {
    var held = false
    var calls = 0
    var failEncode = false
    var failValidation = false
    var savedProgress: (@Sendable (Double) async -> Void)?
    let original = MediaSummary(duration: 3, width: 320, height: 240, nominalFrameRate: 30,
                                videoCodec: "avc1", audioCodec: "aac ", fileBytes: 8)
    func configure(held: Bool = false, encodeFailure: Bool = false, validationFailure: Bool = false) {
        self.held = held; failEncode = encodeFailure; failValidation = validationFailure
    }
    func release() { held = false }
    func emitLate() async { await savedProgress?(0.99) }
    func inspect(_ url: URL) async throws -> MediaSummary { original }
    func export(source: URL, recipe: EditRecipe, destination: URL,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> MediaSummary {
        calls += 1; savedProgress = progress
        await progress(0.4)
        while held { try await Task.sleep(for: .milliseconds(10)) }
        try Task.checkCancellation()
        if failEncode { throw ProbeFailure.injected }
        try Data("test-mp4".utf8).write(to: destination)
        return original
    }
    func validateExport(_ url: URL, edit: SavedTakeEdit) async throws -> MediaSummary {
        if failValidation { throw ExportFailure.invalidOutput }
        let geometry = try CropSelection(sourceSize: original.size, crop: edit.recipe.crop).geometry
        return MediaSummary(duration: edit.recipe.end.seconds - edit.recipe.start.seconds,
            width: Int(geometry.renderSize.width), height: Int(geometry.renderSize.height), nominalFrameRate: 30,
            videoCodec: "avc1", audioCodec: "aac ", fileBytes: 8)
    }
}

private actor ExportEvents {
    var values: [Double] = []
    func append(_ value: Double) { values.append(value) }
}

private struct ExportFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("export-job-\(UUID())")
    let take = UUID()
    let engine = ExportProbe()
    var source: URL { root.appendingPathComponent("original.mov") }
    var jobs: URL { root.appendingPathComponent("jobs") }
    var outputs: URL { root.appendingPathComponent("outputs") }
    func prepare() async throws -> SavedTakeEdit {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("original".utf8).write(to: source)
        let summary = try await engine.inspect(source)
        return try await TakeEditStore(root: root.appendingPathComponent("edits")).save(takeID: take,
            source: TakeEditSource(url: source, summary: summary), recipe: EditRecipe(start: 0.6, end: 2.4,
                crop: .init(x: 0.1, y: 0.2, width: 0.8, height: 0.7), cropPreset: .custom), expectedRevision: 0)
    }
    func store(capacity: Int64 = .max) -> ExportJobStore {
        ExportJobStore(root: jobs, outputs: outputs, media: engine, capacity: { _ in capacity })
    }
    func waitForEncoder() async throws {
        let end = ContinuousClock.now.advanced(by: .seconds(3))
        while await engine.calls == 0 {
            guard ContinuousClock.now < end else { throw ProbeFailure.timeout }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test func cancelledJobDrainsRejectsLateProgressAndRetriesTheFrozenEdit() async throws {
    let f = ExportFixture(); defer { f.clean() }
    let edit = try await f.prepare(), store = f.store(), events = ExportEvents()
    await f.engine.configure(held: true)
    let first = try await store.prepare(id: UUID(), edit: edit)
    let task = Task { try await store.run(id: first.id, source: f.source) { value, _ in await events.append(value) } }
    try await f.waitForEncoder()
    await #expect(throws: ExportFailure.self) { try await store.prepare(id: UUID(), edit: edit) }
    try await store.requestStop(id: first.id, interrupted: false); task.cancel()
    let cancelled = try await task.value
    #expect(cancelled.state == .cancelled)
    let count = await events.values.count
    await f.engine.emitLate()
    #expect(await events.values.count == count)
    #expect(try FileManager.default.contentsOfDirectory(atPath: f.outputs.path).isEmpty)
    await f.engine.release()
    let retry = try await store.prepare(id: UUID(), edit: edit)
    #expect(retry.id != first.id && retry.edit == first.edit)
    let ready = try await store.run(id: retry.id, source: f.source) { _, _ in }
    #expect(ready.state == .ready)
    #expect(try String(contentsOf: f.source, encoding: .utf8) == "original")
    #expect(try await TakeEditStore(root: f.root.appendingPathComponent("edits")).load(takeID: f.take, source: edit.source)?.recipe == edit.recipe)
}

@Test func readyMP4IsDeduplicatedAndLeasedUntilItsPlayerFinishes() async throws {
    let f = ExportFixture(); defer { f.clean() }
    let edit = try await f.prepare(), store = f.store()
    let job = try await store.prepare(id: UUID(), edit: edit)
    #expect(try await store.run(id: job.id, source: f.source) { _, _ in }.state == .ready)
    let lease = try await store.acquireOutput(takeID: f.take, source: f.source)
    await #expect(throws: ExportFailure.self) { try await store.remove(takeID: f.take) }
    await #expect(throws: ExportFailure.self) { try await store.prepare(id: UUID(), edit: edit) }
    #expect(FileManager.default.fileExists(atPath: lease.url.path))
    await store.release(lease)
    #expect(try await store.prepare(id: UUID(), edit: edit).id == job.id)
    #expect(await f.engine.calls == 1)
    try FileManager.default.removeItem(at: lease.url)
    #expect(try await store.load(takeID: f.take)?.state == .interrupted)
    #expect(try await store.prepare(id: UUID(), edit: edit).id != job.id)
}

@Test func relaunchCleansOnlyTheInterruptedJobsKnownFilesAndKeepsOriginals() async throws {
    let f = ExportFixture(); defer { f.clean() }
    let edit = try await f.prepare()
    let job = try await f.store().prepare(id: UUID(), edit: edit)
    let partial = f.outputs.appendingPathComponent(job.id.uuidString + ".partial.mp4")
    let final = f.outputs.appendingPathComponent(job.id.uuidString + ".mp4")
    for file in [partial, partial.deletingPathExtension().appendingPathExtension("encoding.mp4"), final] { try Data("unfinished".utf8).write(to: file) }
    let unrelated = f.outputs.appendingPathComponent("unrelated.mov")
    try Data("keep".utf8).write(to: unrelated)
    let orphan = f.outputs.appendingPathComponent(UUID().uuidString + ".partial.encoding.mp4")
    try Data("abandoned".utf8).write(to: orphan)
    let relaunched = f.store(); try await relaunched.recover()
    let restored = try #require(try await relaunched.load(takeID: f.take))
    #expect(restored.state == .interrupted && restored.edit == edit)
    #expect(!FileManager.default.fileExists(atPath: partial.path) && !FileManager.default.fileExists(atPath: final.path))
    #expect(!FileManager.default.fileExists(atPath: orphan.path))
    #expect(try String(contentsOf: unrelated, encoding: .utf8) == "keep")
    #expect(try String(contentsOf: f.source, encoding: .utf8) == "original")
}

@Test(arguments: ["capacity", "encode", "validation", "publish"])
func exportFailureNeverPublishesOrChangesTheSource(_ failure: String) async throws {
    let f = ExportFixture(); defer { f.clean() }
    let edit = try await f.prepare()
    await f.engine.configure(encodeFailure: failure == "encode", validationFailure: failure == "validation")
    let store = ExportJobStore(root: f.jobs, outputs: f.outputs, media: f.engine,
        capacity: { _ in failure == "capacity" ? 0 : .max }, write: { data, url in
            if failure == "publish", try JSONDecoder().decode(ExportJob.self, from: data).state == .ready {
                throw CocoaError(.fileWriteOutOfSpace)
            }
            try data.write(to: url, options: .atomic)
        })
    let job = try await store.prepare(id: UUID(), edit: edit)
    let result = try await store.run(id: job.id, source: f.source) { _, _ in }
    #expect(result.state == .failed && result.summary == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: f.outputs.path).isEmpty)
    #expect(try String(contentsOf: f.source, encoding: .utf8) == "original")
    #expect(try await f.store().load(takeID: f.take)?.state == .failed)
}

@Test(arguments: [false, true])
func changedOriginalCannotPublishAnExport(duringEncoding: Bool) async throws {
    let f = ExportFixture(); defer { f.clean() }
    let edit = try await f.prepare(), store = f.store()
    await f.engine.configure(held: duringEncoding)
    let job = try await store.prepare(id: UUID(), edit: edit)
    if !duringEncoding { try Data("changed before".utf8).write(to: f.source) }
    let task = Task { try await store.run(id: job.id, source: f.source) { _, _ in } }
    if duringEncoding {
        try await f.waitForEncoder()
        try Data("changed during".utf8).write(to: f.source)
        await f.engine.release()
    }
    #expect(try await task.value.state == .failed)
    #expect(try FileManager.default.contentsOfDirectory(atPath: f.outputs.path).isEmpty)
}

@Test func futureExportRecordsAndTheirFilesArePreserved() async throws {
    let f = ExportFixture(); defer { f.clean() }
    let edit = try await f.prepare(), job = try await f.store().prepare(id: UUID(), edit: edit)
    let record = f.jobs.appendingPathComponent(f.take.uuidString + ".json")
    var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: record)) as? [String: Any])
    json["schemaVersion"] = 2
    let future = try JSONSerialization.data(withJSONObject: json); try future.write(to: record)
    let partial = f.outputs.appendingPathComponent(job.id.uuidString + ".partial.mp4")
    try Data("preserve".utf8).write(to: partial)
    let restored = f.store(); try await restored.recover()
    await #expect(throws: ExportFailure.self) { try await restored.prepare(id: UUID(), edit: edit) }
    #expect(try Data(contentsOf: record) == future)
    #expect(try String(contentsOf: partial, encoding: .utf8) == "preserve")
}
