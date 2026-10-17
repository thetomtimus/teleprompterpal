import Foundation
import PhoneLibrary
import Testing
@testable import TeleprompterPhone

@Test @MainActor func failedFilesystemSaveKeepsDraftAndExplicitRetryPersistsIt() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("p6c-save-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = LibraryModel(root: root)
    await model.initialize()
    // A real file blocks directory creation, rather than a mocked save result.
    try Data("blocked".utf8).write(to: root)
    let text = "Draft 한국어 🎥 survives a failed filesystem write."
    let id = try #require(model.create(title: "Retry draft", text: text))
    await model.flush()
    #expect(model.saveStatus == "Changes not saved")
    #expect(model.message != nil)
    #expect(model.script(id)?.document.text == text)
    try FileManager.default.removeItem(at: root)
    await model.flush()
    #expect(model.saveStatus == "Saved on this iPhone")
    let reopened = LibraryModel(root: root)
    await reopened.initialize()
    #expect(reopened.script(id)?.document.text == text)
}

@Test @MainActor func damagedLibraryRecoversBackupAndWarnsWithoutDiscardingEvidence() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("p6c-backup-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = LibraryModel(root: root)
    await model.initialize()
    let id = try #require(model.create(title: "Saved version", text: "Original 🎥 한국어"))
    await model.flush()
    model.edit(id, title: "Later version", text: "Newer text")
    await model.flush()
    let corrupt = Data("damaged primary".utf8)
    try corrupt.write(to: root.appendingPathComponent("library.json"))
    let recovered = LibraryModel(root: root)
    await recovered.initialize()
    #expect(recovered.ready)
    #expect(recovered.script(id)?.document.text == "Original 🎥 한국어")
    #expect(recovered.message?.contains("Recent changes may be missing") == true)
    let preserved = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Corrupt"), includingPropertiesForKeys: nil)
    #expect(preserved.count == 1)
    #expect(try Data(contentsOf: #require(preserved.first)) == corrupt)
}
