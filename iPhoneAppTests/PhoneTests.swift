import Foundation
import PhoneLibrary
import PromptingCore
import Testing
import UIKit

@testable import TeleprompterPhone

@Test @MainActor func phoneEditsCheckpointPreferencesAndTrashRestoreAfterRelaunch() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("phone-model-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = LibraryModel(root: root)
    async let first: Void = model.initialize()
    async let second: Void = model.initialize()
    _ = await (first, second)
    let id = try #require(model.create(title: "Draft", text: "🎥 한국어 café"))
    model.checkpoint(.capture(offset: 3, in: "🎥 한국어 café"), scriptID: id)
    model.edit(id, title: "Lesson", text: "Intro 🎥 한국어 café")
    model.setPreferences(font: 40, speed: 65)
    let copy = try #require(model.duplicate(id))
    model.setDeleted(copy, deleted: true)
    await model.flush()
    let reopened = LibraryModel(root: root)
    await reopened.initialize()
    #expect(reopened.ready)
    #expect(reopened.script(id)?.document.text == "Intro 🎥 한국어 café")
    #expect(reopened.script(id)?.anchor.utf16Offset == 9)
    #expect(reopened.library.preferences.fontSize == 40)
    #expect(reopened.library.preferences.speed == 65)
    #expect(reopened.library.matching("", deleted: true).map(\.id) == [copy])
    reopened.setDeleted(copy, deleted: false)
    await reopened.flush()
    #expect(try await LibraryStore(root: root).load().library.matching("").count == 2)
}

@Test @MainActor func nativeReaderRestoresPositionAndCheckpointsAtCoarseIntervals() {
    var checkpoints: [ReadingAnchor] = []
    let reader = PromptReader.Coordinator(probe: ReaderProbe(), checkpoint: { checkpoints.append($0) }, stopped: {})
    let view = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 210))
    reader.view = view
    defer { reader.invalidate() }
    let text = Array(repeating: "A readable script with 한국어 and 🎥 remains intact.", count: 100).joined(separator: "\n")
    reader.update(
        text: text, fontSize: 28, speed: 30, playing: false, restart: 0,
        initialAnchor: .capture(offset: 200, in: text))
    #expect(view.contentOffset.y > 0)
    reader.update(text: text, fontSize: 28, speed: 30, playing: true, restart: 0)
    for frame in 0..<120 { reader.advance(at: 1 + Double(frame) / 60) }
    #expect(checkpoints.count <= 3)
    #expect(checkpoints.last?.utf16Offset ?? 0 > 0)
    reader.update(text: text, fontSize: 28, speed: 30, playing: false, restart: 1)
    #expect(view.contentOffset.y == 0)
    #expect(checkpoints.last?.utf16Offset == 0)
}

@Test @MainActor func failedOversizeSaveKeepsDraftInMemoryAndOriginalOnDisk() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("phone-draft-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let model = LibraryModel(root: root)
    await model.initialize()
    let id = try #require(model.create(text: "Saved original"))
    await model.flush()
    let draft = String(repeating: "a", count: TextImport.maximumBytes + 1)
    model.edit(id, title: "Draft", text: draft)
    await model.flush()
    #expect(model.script(id)?.document.text == draft)
    #expect(model.saveStatus == "Changes not saved")
    #expect(try await LibraryStore(root: root).load().library.scripts[0].document.text == "Saved original")
}

@Test @MainActor func realTextImportPersistsExactUnicodeAndFilenameTitle() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("phone-import-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("한국어 Lesson.txt")
    let text = "한국어 café 🎥\r\nLine two e\u{301} stays composed as typed.\n"
    try Data(text.utf8).write(to: url)
    let model = LibraryModel(root: root.appendingPathComponent("Library"))
    await model.initialize()
    let id = try #require(await model.importText(url))
    await model.flush()
    let saved = try await LibraryStore(root: root.appendingPathComponent("Library")).load().library
    #expect(saved.scripts.first?.id == id)
    #expect(saved.scripts.first?.document.title == "한국어 Lesson")
    #expect(saved.scripts.first?.document.text.utf8.elementsEqual(text.utf8) == true)
}
