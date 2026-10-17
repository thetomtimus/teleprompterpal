import Foundation
import ImageIO
import Testing

@testable import PrototypeSupport

private func takeTestRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("take-library-\(UUID())") }

@Test func reconciliationFindsOrphansAndSeparatesMissingAndIncompleteOriginals() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root)
    let media = MediaService()
    let pending = UUID(), missing = UUID(), incomplete = UUID(), orphan = UUID()
    let context = TakeScriptContext(id: UUID(), revision: 7, title: "한국어 café 🎥")
    let pendingURL = try await store.prepare(id: pending, script: context)
    try await SampleMovie().make(at: pendingURL)
    let original = try Data(contentsOf: pendingURL)
    let missingURL = try await store.prepare(id: missing)
    try await SampleMovie().make(at: missingURL)
    try await store.complete(id: missing, summary: media.inspect(missingURL))
    try FileManager.default.removeItem(at: missingURL)
    let incompleteURL = try await store.prepare(id: incomplete)
    let raw = Data("unfinished bytes".utf8)
    try raw.write(to: incompleteURL)
    let orphanURL = root.appendingPathComponent(orphan.uuidString + ".mov")
    try await SampleMovie().make(at: orphanURL)
    let orphanBytes = try Data(contentsOf: orphanURL)
    let ignored = root.appendingPathComponent("unrelated.mov")
    try Data("keep this unrelated file".utf8).write(to: ignored)
    let reopened = TakeStore(root: root)
    let results = try await reopened.reconcile(inspect: media.inspect)
    #expect(results.count == 4)
    #expect(results.first { $0.id == pending }?.isPlayable == true)
    #expect(results.first { $0.id == pending }?.script == context)
    #expect(results.first { $0.id == pending }?.recovery == .recovered)
    #expect(results.first { $0.id == orphan }?.isPlayable == true)
    #expect(results.first { $0.id == orphan }?.script == nil)
    #expect(results.first { $0.id == missing }?.state == .missing)
    #expect(results.first { $0.id == missing }?.summary == nil)
    #expect(results.first { $0.id == incomplete }?.state == .incomplete)
    #expect(results.first { $0.id == incomplete }?.retainedBytes == Int64(raw.count))
    #expect(try Data(contentsOf: pendingURL) == original)
    #expect(try Data(contentsOf: orphanURL) == orphanBytes)
    #expect(try Data(contentsOf: incompleteURL) == raw)
    #expect(FileManager.default.fileExists(atPath: ignored.path))
}

@Test func damagedJournalUsesBackupAndFutureJournalRemainsUntouched() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root), media = MediaService()
    let id = UUID()
    let url = try await store.prepare(id: id, script: .init(id: UUID(), revision: 1, title: "Retained title"))
    try await SampleMovie().make(at: url)
    try await store.complete(id: id, summary: media.inspect(url))
    let original = try Data(contentsOf: url)
    let damaged = Data("damaged journal".utf8)
    let journal = root.appendingPathComponent("takes.json")
    try damaged.write(to: journal)
    let recovered = TakeStore(root: root)
    #expect(try await recovered.reconcile(inspect: media.inspect).first?.isPlayable == true)
    #expect(await recovered.recoveryNotice != nil)
    let quarantine = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        .first { $0.lastPathComponent.hasPrefix("damaged-") }
    #expect(try Data(contentsOf: #require(quarantine)) == damaged)
    #expect(try Data(contentsOf: url) == original)
    let future = Data("{\"schemaVersion\":99,\"takes\":[]}".utf8)
    try future.write(to: journal)
    await #expect(throws: TakeStoreFailure.newerVersion) { _ = try await TakeStore(root: root).load() }
    #expect(try Data(contentsOf: journal) == future)
    #expect(try Data(contentsOf: url) == original)
}

@Test func failedDeletionPersistsIntentAndRelaunchFinishesWithoutResurrectingATake() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root), media = MediaService()
    let id = UUID(), url = try await store.prepare(id: id)
    try await SampleMovie().make(at: url)
    try await store.complete(id: id, summary: media.inspect(url))
    let kept = root.appendingPathComponent("kept-original.mov")
    try FileManager.default.moveItem(at: url, to: kept)
    let bytes = try Data(contentsOf: kept)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    let child = url.appendingPathComponent("must-not-be-recursively-deleted")
    try Data("keep".utf8).write(to: child)
    await #expect(throws: TakeStoreFailure.fileAccess) { try await store.delete(id: id) }
    #expect(try await store.load().first?.state == .deleting)
    #expect(try await store.load().first?.isPlayable == false)
    #expect(FileManager.default.fileExists(atPath: child.path))
    #expect(try Data(contentsOf: kept) == bytes)
    let reopened = TakeStore(root: root)
    #expect(try await reopened.reconcile(inspect: media.inspect).first?.state == .deleting)
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: kept, to: url)
    #expect(try await reopened.reconcile(inspect: media.inspect).isEmpty)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(try await TakeStore(root: root).reconcile(inspect: media.inspect).isEmpty)
}

@Test func pendingAndStaleJournalWritesCannotDeleteOrOverwriteOriginals() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = TakeStore(root: root), second = TakeStore(root: root)
    let id = UUID(), url = try await first.prepare(id: id)
    let bytes = Data("not yet finalized".utf8)
    try bytes.write(to: url)
    await #expect(throws: PrototypeError.busy) { try await first.delete(id: id) }
    _ = try await second.load()
    _ = try await first.prepare(id: UUID())
    await #expect(throws: TakeStoreFailure.changedOnDisk) { _ = try await second.prepare(id: UUID()) }
    #expect(try Data(contentsOf: url) == bytes)
    #expect(try await TakeStore(root: root).load().count == 2)
    #expect(try await second.reload().count == 2)
    let collision = UUID(), collisionURL = root.appendingPathComponent(collision.uuidString + ".mov")
    try bytes.write(to: collisionURL)
    await #expect(throws: PrototypeError.busy) { _ = try await first.prepare(id: collision) }
    #expect(try Data(contentsOf: collisionURL) == bytes)
}

private actor InspectionBarrier {
    private var waiting = false
    private var observer: CheckedContinuation<Void, Never>?
    private var resume: CheckedContinuation<Void, Never>?
    func wait() async { waiting = true; observer?.resume(); observer = nil; await withCheckedContinuation { resume = $0 } }
    func entered() async { if !waiting { await withCheckedContinuation { observer = $0 } } }
    func release() { resume?.resume(); resume = nil }
}

@Test func cancelledInspectionDoesNotPublishIncompleteMediaAndExcludesWriters() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root)
    let id = UUID(), url = try await store.prepare(id: id)
    try await SampleMovie().make(at: url)
    let before = try Data(contentsOf: root.appendingPathComponent("takes.json"))
    let barrier = InspectionBarrier()
    let check = Task { try await store.reconcile { url in
        await barrier.wait(); try Task.checkCancellation(); return try await MediaService().inspect(url)
    } }
    await barrier.entered()
    await #expect(throws: PrototypeError.busy) { _ = try await store.prepare(id: UUID()) }
    check.cancel()
    await barrier.release()
    await #expect(throws: CancellationError.self) { _ = try await check.value }
    #expect(try await store.load().first?.state == .pending)
    #expect(try Data(contentsOf: root.appendingPathComponent("takes.json")) == before)
}

@Test func symlinkedOriginalNeverReadsOrDeletesItsExternalTarget() async throws {
    let root = takeTestRoot(), outside = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: outside) }
    try Data("external file".utf8).write(to: outside)
    let store = TakeStore(root: root)
    let id = UUID(), url = try await store.prepare(id: id)
    try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
    let result = try await store.reconcile { _ in Issue.record("A symlink must not reach inspection"); throw PrototypeError.invalidMedia }
    #expect(result.first?.state == .incomplete)
    try await store.delete(id: id)
    #expect(try Data(contentsOf: outside) == Data("external file".utf8))
}

@Test func brokenOriginalSymlinkIsRemovedWithoutResurrection() async throws {
    let root = takeTestRoot(), outside = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root), id = UUID()
    let url = try await store.prepare(id: id)
    try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
    let results = try await store.reconcile { _ in Issue.record("Broken links must not be inspected"); throw PrototypeError.invalidMedia }
    #expect(results.first?.state == .missing)
    try await store.delete(id: id)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).contains(url.lastPathComponent) == false)
    #expect(try await TakeStore(root: root).reconcile(inspect: MediaService().inspect).isEmpty)
}

@Test func oversizedJournalFailsClosedWithoutQuarantiningOrOverwriting() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let journal = root.appendingPathComponent("takes.json")
    let bytes = Data(repeating: 32, count: 8 * 1024 * 1024 + 1)
    try bytes.write(to: journal)
    await #expect(throws: TakeStoreFailure.tooLarge) { _ = try await TakeStore(root: root).load() }
    #expect(try Data(contentsOf: journal) == bytes)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["takes.json"])
}

@Test func groupingUsesRetainedIDsAndTitlesWithoutConflatingSameNamedScripts() {
    let a = UUID(), b = UUID(), date = Date()
    let takes: [PrototypeTake] = [
        .init(id: UUID(), created: date, relativePath: "unused", state: .pending, script: .init(id: a, revision: 1, title: "Old title")),
        .init(id: UUID(), created: date.addingTimeInterval(1), relativePath: "unused", state: .pending, script: .init(id: a, revision: 2, title: "Same title")),
        .init(id: UUID(), created: date, relativePath: "unused", state: .pending, script: .init(id: b, revision: 1, title: "Same title")),
        .init(id: UUID(), created: date, relativePath: "unused", state: .pending),
    ]
    let groups = TakeGroup.grouped(takes)
    #expect(groups.count == 3)
    #expect(groups.first?.id == .script(a))
    #expect(groups.first?.title == "Same title")
    #expect(groups.first?.takes.count == 2)
    #expect(TakeGroup.grouped(takes, query: "Old title").first?.takes.count == 1)
    #expect(groups.contains { $0.id == .unassigned && $0.title == "Other recordings" })
}

@Test(arguments: [false, true]) func thumbnailRotationCacheRegenerationAndOriginalPreservation(rotated: Bool) async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root), media = MediaService()
    let id = UUID(), url = try await store.prepare(id: id)
    try await SampleMovie().make(at: url, rotated: rotated)
    let summary = try await media.inspect(url)
    try await store.complete(id: id, summary: summary)
    let take = try #require(try await store.load().first)
    let original = try Data(contentsOf: url)
    let cacheRoot = root.appendingPathComponent("Cache")
    let cache = TakeThumbnailStore(root: cacheRoot)
    let data = try await cache.data(for: take, source: url)
    let imageSource = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
    #expect(max(image.width, image.height) <= 320)
    #expect(abs(Double(image.width) / Double(image.height) - Double(summary.width) / Double(summary.height)) < 0.01)
    let file = try #require(try FileManager.default.contentsOfDirectory(at: cacheRoot, includingPropertiesForKeys: nil).first)
    try Data("bad cache".utf8).write(to: file)
    let regenerated = try await cache.data(for: take, source: url)
    #expect(CGImageSourceCreateWithData(regenerated as CFData, nil) != nil)
    #expect(try Data(contentsOf: url) == original)
    var incomplete = take; incomplete.state = .incomplete
    await #expect(throws: PrototypeError.invalidMedia) { _ = try await cache.data(for: incomplete, source: url) }
    try await cache.remove(id: id)
    #expect(try FileManager.default.contentsOfDirectory(atPath: cacheRoot.path).isEmpty)
}

@Test func thumbnailCacheEvictsOwnedEntriesAndKeepsUnrelatedFiles() async throws {
    let root = takeTestRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = TakeStore(root: root), media = MediaService()
    let id = UUID(), url = try await store.prepare(id: id)
    try await SampleMovie().make(at: url)
    try await store.complete(id: id, summary: media.inspect(url))
    var take = try #require(try await store.load().first)
    let cacheRoot = root.appendingPathComponent("Cache"), cache = TakeThumbnailStore(root: cacheRoot)
    let data = try await cache.data(for: take, source: url)
    for _ in 0..<260 { try data.write(to: cacheRoot.appendingPathComponent("\(UUID())-thumb-v1-fixture.jpg")) }
    let unrelated = cacheRoot.appendingPathComponent("unrelated-thumb-v1-image.jpg")
    try data.write(to: unrelated)
    take.id = UUID()
    _ = try await cache.data(for: take, source: url)
    let files = try FileManager.default.contentsOfDirectory(atPath: cacheRoot.path)
    #expect(files.count <= 257)
    #expect(FileManager.default.fileExists(atPath: unrelated.path))
}
