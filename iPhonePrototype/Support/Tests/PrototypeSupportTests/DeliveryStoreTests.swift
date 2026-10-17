import Foundation
import Testing
@testable import PrototypeSupport

@Test func pendingDeliveryRestoresAsUnknownAndNeedsExplicitConfirmation() async throws {
    let root = deliveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let exportID = UUID(), edit = try await deliveryEdit(root), first = DeliveryStore(root: root)
    let pending = try await first.begin(exportID: exportID, edit: edit, destination: .photos)
    let restored = DeliveryStore(root: root)
    let attempts = try await restored.load(edit: edit)
    #expect(attempts.first?.id == pending.id && attempts.first?.state == .unknown)
    await #expect(throws: DeliveryFailure.self) { try await restored.begin(exportID: exportID, edit: edit, destination: .photos) }
    let retry = try await restored.begin(exportID: exportID, edit: edit, destination: .photos, confirmingUnknown: true)
    #expect(retry.id != pending.id)
    _ = try await restored.finish(id: retry.id, state: .completed, message: "Saved to Photos.", reference: "synthetic")
    await #expect(throws: DeliveryFailure.self) { try await restored.begin(exportID: exportID, edit: edit, destination: .photos) }
}

@Test func deliveryResultsStayIndependentAndRejectLateOrConcurrentCallbacks() async throws {
    let root = deliveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let store = DeliveryStore(root: root), exportID = UUID(), edit = try await deliveryEdit(root)
    let photos = try await store.begin(exportID: exportID, edit: edit, destination: .photos)
    await #expect(throws: DeliveryFailure.self) { try await store.begin(exportID: UUID(), edit: edit, destination: .files) }
    #expect(try await store.finish(id: UUID(), state: .completed, message: "stale") == nil)
    _ = try await store.finish(id: photos.id, state: .completed, message: "Saved to Photos.")
    let files = try await store.begin(exportID: exportID, edit: edit, destination: .files)
    _ = try await store.finish(id: files.id, state: .cancelled, message: "Save to Files cancelled.")
    let share = try await store.begin(exportID: exportID, edit: edit, destination: .share)
    _ = try await store.finish(id: share.id, state: .failed, message: "Receiver failed.")
    #expect(try await store.finish(id: files.id, state: .completed, message: "late") == nil)
    let restored = try await DeliveryStore(root: root).load(edit: edit)
    #expect(restored.count == 3)
    #expect(restored.first { $0.destination == .photos }?.state == .completed)
    #expect(restored.first { $0.destination == .files }?.state == .cancelled)
    #expect(restored.first { $0.destination == .share }?.state == .failed)
    // Cache recreation has a different export UUID but the same saved edit.
    await #expect(throws: DeliveryFailure.self) { try await store.begin(exportID: UUID(), edit: edit, destination: .photos) }
    let otherEdit = try await deliveryEdit(root)
    #expect(try await store.load(edit: otherEdit).isEmpty)
}

@Test func failedDeliveryJournalPublicationPreservesUncertaintyAndAllowsNoAutomaticReplay() async throws {
    let root = deliveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let exportID = UUID(), edit = try await deliveryEdit(root)
    let store = DeliveryStore(root: root, write: { data, url in
        if FileManager.default.fileExists(atPath: url.path) { throw CocoaError(.fileWriteOutOfSpace) }
        try data.write(to: url, options: .atomic)
    })
    let attempt = try await store.begin(exportID: exportID, edit: edit, destination: .files)
    await #expect(throws: (any Error).self) { try await store.finish(id: attempt.id, state: .completed, message: "Saved.") }
    let restored = try await DeliveryStore(root: root).load(edit: edit)
    #expect(restored.first?.state == .unknown)
    let denied = DeliveryStore(root: root.appendingPathComponent("denied"), write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    await #expect(throws: (any Error).self) { try await denied.begin(exportID: exportID, edit: edit, destination: .photos) }
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("denied/\(edit.takeID).\(edit.revision).json").path))
}

@Test(arguments: ["{bad", "{\"schemaVersion\":2}"])
func unreadableOrFutureDeliveryRecordsArePreserved(text: String) async throws {
    let root = deliveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let id = UUID(), edit = try await deliveryEdit(root)
    let file = root.appendingPathComponent("\(edit.takeID).\(edit.revision).json"), bytes = Data(text.utf8)
    try bytes.write(to: file)
    let store = DeliveryStore(root: root)
    await #expect(throws: DeliveryFailure.self) { try await store.begin(exportID: id, edit: edit, destination: .share) }
    try await store.remove(takeID: UUID())
    #expect(try Data(contentsOf: file) == bytes)
}

private func deliveryRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("delivery-\(UUID())") }

@Test func removingATakeOnlyRemovesItsUnderstoodDeliveryRecords() async throws {
    let root = deliveryRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let store = DeliveryStore(root: root), first = UUID(), second = UUID()
    let firstEdit = try await deliveryEdit(root), secondEdit = try await deliveryEdit(root)
    let attempt = try await store.begin(exportID: first, edit: firstEdit, destination: .photos)
    await #expect(throws: DeliveryFailure.self) { try await store.remove(takeID: firstEdit.takeID) }
    _ = try await store.finish(id: attempt.id, state: .completed, message: "Saved.")
    let other = try await store.begin(exportID: second, edit: secondEdit, destination: .files)
    _ = try await store.finish(id: other.id, state: .completed, message: "Saved.")
    let future = root.appendingPathComponent(UUID().uuidString + ".json"), futureData = Data("{\"schemaVersion\":9}".utf8)
    try futureData.write(to: future)
    try await store.remove(takeID: firstEdit.takeID)
    #expect(try await store.load(edit: firstEdit).isEmpty)
    #expect(try await store.load(edit: secondEdit).count == 1)
    #expect(try Data(contentsOf: future) == futureData)
}

private func deliveryEdit(_ root: URL) async throws -> SavedTakeEdit {
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("source-\(UUID()).mov")
    try Data("synthetic".utf8).write(to: source)
    return try await TakeEditStore(root: root.appendingPathComponent("edits")).save(takeID: UUID(),
        source: TakeEditSource(url: source, summary: MediaSummary(duration: 3, width: 320, height: 240, nominalFrameRate: 30)),
        recipe: .init(start: 0, end: 3), expectedRevision: 0)
}
