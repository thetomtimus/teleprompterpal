import Foundation
import ImageIO
import Testing
@testable import PrototypeSupport

private func editFixture() throws -> (URL, URL, TakeEditSource) {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("take-edit-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let original = root.appendingPathComponent("original.mov")
    try Data("Immutable storage fixture, not camera media".utf8).write(to: original)
    let summary = MediaSummary(duration: 12, width: 1920, height: 1080, nominalFrameRate: 30)
    return (root, original, try TakeEditSource(url: original, summary: summary))
}

@Test func savedTrimAndCustomCropReopenWithoutChangingTheOriginal() async throws {
    let (root, original, identity) = try editFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let bytes = try Data(contentsOf: original), id = UUID(), directory = root.appendingPathComponent("Edits")
    let store = TakeEditStore(root: directory)
    #expect(try await store.load(takeID: id, source: identity) == nil)
    let recipe = EditRecipe(start: 1.5, end: 8, crop: .init(x: 0.2, y: 0.1, width: 0.5, height: 0.7))
    let saved = try await store.save(takeID: id, source: identity, recipe: recipe, expectedRevision: 0)
    #expect(saved.revision == 1)
    #expect(try await TakeEditStore(root: directory).load(takeID: id, source: identity) == saved)
    #expect(try Data(contentsOf: original) == bytes)
}

@Test func staleEditorCannotOverwriteARevisionSavedElsewhere() async throws {
    let (root, _, identity) = try editFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), directory = root.appendingPathComponent("Edits")
    let first = TakeEditStore(root: directory), second = TakeEditStore(root: directory)
    _ = try await first.save(takeID: id, source: identity, recipe: .init(end: 10), expectedRevision: 0)
    _ = try await second.load(takeID: id, source: identity)
    let latest = try await first.save(takeID: id, source: identity, recipe: .init(start: 2, end: 9), expectedRevision: 1)
    await #expect(throws: TakeEditFailure.conflict) {
        _ = try await second.save(takeID: id, source: identity, recipe: .init(end: 5), expectedRevision: 1)
    }
    #expect(try await second.load(takeID: id, source: identity) == latest)
}

@Test(arguments: [false, true]) func unreadableAndFutureRecipesArePreserved(future: Bool) async throws {
    let (root, _, identity) = try editFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), directory = root.appendingPathComponent("Edits")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent(id.uuidString + ".json")
    let bytes = Data((future ? "{\"schemaVersion\":99,\"unknown\":true}" : "broken json").utf8)
    try bytes.write(to: path)
    let store = TakeEditStore(root: directory)
    let expected: TakeEditFailure = future ? .newerVersion : .corrupt
    await #expect(throws: expected) { _ = try await store.load(takeID: id, source: identity) }
    await #expect(throws: expected) {
        _ = try await store.save(takeID: id, source: identity, recipe: .init(end: 10), expectedRevision: 0)
    }
    #expect(try Data(contentsOf: path) == bytes)
}

@Test func failedWriteRetainsThePreviousRecipeAndOriginal() async throws {
    let (root, original, identity) = try editFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let directory = root.appendingPathComponent("Edits"), id = UUID()
    let store = TakeEditStore(root: directory)
    let previous = try await store.save(takeID: id, source: identity, recipe: .init(end: 10), expectedRevision: 0)
    let bytes = try Data(contentsOf: original)
    let failing = TakeEditStore(root: directory, write: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
    await #expect(throws: CocoaError.self) {
        _ = try await failing.save(takeID: id, source: identity, recipe: .init(start: 1, end: 8), expectedRevision: 1)
    }
    #expect(try await store.load(takeID: id, source: identity) == previous)
    #expect(try Data(contentsOf: original) == bytes)
}

@Test func replacedOriginalCannotReceiveEditsForAnOlderSource() async throws {
    let (root, original, identity) = try editFixture()
    defer { try? FileManager.default.removeItem(at: root) }
    let id = UUID(), store = TakeEditStore(root: root.appendingPathComponent("Edits"))
    _ = try await store.save(takeID: id, source: identity, recipe: .init(end: 10), expectedRevision: 0)
    try Data("A different original file".utf8).write(to: original)
    let summary = MediaSummary(duration: 12, width: 1920, height: 1080, nominalFrameRate: 30)
    let changed = try TakeEditSource(url: original, summary: summary)
    await #expect(throws: TakeEditFailure.sourceChanged) { _ = try await store.load(takeID: id, source: changed) }
}

@Test(arguments: [false, true]) func timelineFramesAreBoundedAndRespectPreferredRotation(rotated: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("timeline-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appendingPathComponent("sample.mov")
    try await SampleMovie().make(at: original, rotated: rotated)
    let bytes = try Data(contentsOf: original)
    let frames = try await VideoTimeline().frames(source: original, count: 100)
    #expect(frames.count == 12)
    #expect(frames.allSatisfy { $0.seconds >= 0 && $0.seconds < 3 && $0.data.count <= 128 * 1024 })
    for frame in frames {
        let requested = 3 * (Double(frame.id) + 0.5) / 12
        #expect(abs(frame.seconds - requested) <= 1.0 / 30)
        let source = try #require(CGImageSourceCreateWithData(frame.data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(max(image.width, image.height) <= 160)
        #expect(rotated ? image.height > image.width : image.width > image.height)
    }
    #expect(try Data(contentsOf: original) == bytes)
}
