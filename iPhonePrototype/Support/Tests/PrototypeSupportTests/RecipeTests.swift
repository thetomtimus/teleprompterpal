import CoreGraphics
import Foundation
import Testing

@testable import PrototypeSupport

@Test("Custom crop survives serialization with its size intact")
func customCropRoundTrip() throws {
    let recipe = EditRecipe(start: 0.3, end: 2.1, crop: .init(x: 0.25, y: 0.2, width: 0.5, height: 0.6))
    let restored = try JSONDecoder().decode(EditRecipe.self, from: JSONEncoder().encode(recipe))
    #expect(restored == recipe)
    try restored.validate(duration: 3)
}

@Test(
    "Invalid recipes cannot reach the encoder",
    arguments: [
        EditRecipe(start: 1, end: 1), EditRecipe(start: -1, end: 2), EditRecipe(end: 4),
        EditRecipe(end: 2, crop: .init(width: .nan)), EditRecipe(end: 2, crop: .init(x: 0.8, width: 0.5)),
    ])
func rejectsInvalidRecipe(_ recipe: EditRecipe) {
    #expect(throws: PrototypeError.invalidRecipe) { try recipe.validate(duration: 3) }
}

@Test("Preferred rotation is normalized before a custom crop")
func rotatedGeometry() throws {
    let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)
    let result = try CropGeometry(
        naturalSize: CGSize(width: 320, height: 240), preferredTransform: transform,
        crop: .init(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
    #expect(result.renderSize == CGSize(width: 120, height: 160))
    let sourceBounds = CGRect(x: 0, y: 0, width: 320, height: 240).applying(result.transform)
    #expect(sourceBounds.minX == -60)
    #expect(sourceBounds.minY == -80)
}

@Test("Odd source sizes produce bounded even encoder dimensions")
func evenDimensions() throws {
    let result = try CropGeometry(
        naturalSize: CGSize(width: 321, height: 241), preferredTransform: .identity, crop: .init())
    #expect(result.renderSize == CGSize(width: 320, height: 240))
}

@Test("Journal retains an unfinished original across relaunch")
func journalRelaunch() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = TakeStore(root: root)
    let id = UUID()
    let url = try await first.prepare(id: id)
    try Data([1, 2, 3]).write(to: url)
    let second = TakeStore(root: root)
    let takes = try await second.load()
    #expect(takes.first?.state == .pending)
    try await second.markIncomplete(id: id, note: "Interrupted")
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(try await second.load().first?.state == .incomplete)
}

@Test("P1 manifests without script context still load, and P2 take context survives relaunch")
func legacyJournalAndFrozenScriptContext() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let oldID = UUID()
    let oldJSON = """
        {"schemaVersion":1,"takes":[{"id":"\(oldID)","created":0,"relativePath":"\(oldID).mov","state":"pending"}]}
        """
    try Data(oldJSON.utf8).write(to: root.appendingPathComponent("takes.json"))
    let store = TakeStore(root: root)
    #expect(try await store.load().first?.script == nil)
    let id = UUID()
    let context = TakeScriptContext(id: UUID(), revision: 7, title: "한국어 café 🎥")
    _ = try await store.prepare(id: id, script: context)
    let restored = try await TakeStore(root: root).load()
    #expect(restored.first { $0.id == id }?.script == context)
    #expect(restored.first { $0.id == oldID }?.script == nil)
}
