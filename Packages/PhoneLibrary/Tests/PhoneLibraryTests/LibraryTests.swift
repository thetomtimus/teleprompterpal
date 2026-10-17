import Foundation
import PhoneLibrary
import Testing

private func temporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("phone-library-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@Test func scriptsUnicodePositionPreferencesAndTrashSurviveRelaunch() async throws {
    let root = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LibraryStore(root: root)
    var library = try await store.load().library
    var script = ScriptRecord(title: "Lesson", text: "Intro 🎥 한국어 café")
    script.anchor.utf16Offset = 9
    try script.edit(title: "Renamed", text: "New Intro 🎥 한국어 café")
    #expect(script.anchor.utf16Offset == 13)
    library.scripts = [script, ScriptRecord(title: "Deleted", text: "Kept in trash")]
    library.scripts[1].deletedAt = Date()
    library.preferences.fontSize = 36
    library.preferences.speed = 55
    library.selectedScriptID = script.id
    try library.changed()
    try await store.save(library)
    let restored = try await LibraryStore(root: root).load().library
    #expect(restored == library)
    #expect(restored.matching("한국어").map(\.id) == [script.id])
    #expect(restored.matching("", deleted: true).count == 1)
    #expect(restored.scripts[0].document.revision == 1)
}

@Test func corruptPrimaryRestoresPreviousGoodSnapshotAndPreservesCorruptBytes() async throws {
    let root = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LibraryStore(root: root)
    var first = try await store.load().library
    first.scripts = [ScriptRecord(title: "Saved", text: "First version")]
    try first.changed()
    try await store.save(first)
    var second = first
    try second.scripts[0].edit(title: "Saved", text: "Second version")
    try second.changed()
    try await store.save(second)
    let broken = Data("{incomplete".utf8)
    try broken.write(to: root.appendingPathComponent("library.json"))
    let recovery = try await LibraryStore(root: root).load()
    #expect(recovery.recoveredFromBackup)
    #expect(recovery.library == first)
    let quarantines = try FileManager.default.contentsOfDirectory(
        at: root.appendingPathComponent("Corrupt"), includingPropertiesForKeys: nil)
    #expect(quarantines.count == 1)
    #expect(try Data(contentsOf: #require(quarantines.first)) == broken)
}

@Test func futureSchemaAndUnrecoverableCorruptionNeverOverwriteOriginal() async throws {
    for bytes in [Data("{\"schemaVersion\":99,\"unknown\":true}".utf8), Data("broken".utf8)] {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let primary = root.appendingPathComponent("library.json")
        try bytes.write(to: primary)
        let store = LibraryStore(root: root)
        await #expect(throws: (any Error).self) { try await store.load() }
        var empty = ScriptLibrary()
        try empty.changed()
        await #expect(throws: LibraryError.notLoaded) { try await store.save(empty) }
        #expect(try Data(contentsOf: primary) == bytes)
    }
}

private struct RejectPrimaryCommit: LibraryFileSystem {
    let base = LocalLibraryFileSystem()
    func exists(_ url: URL) -> Bool { base.exists(url) }
    func read(_ url: URL) throws -> Data { try base.read(url) }
    func writeAtomically(_ data: Data, to url: URL) throws {
        if url.lastPathComponent == "library.json" { throw CocoaError(.fileWriteOutOfSpace) }
        try base.writeAtomically(data, to: url)
    }
}

@Test func failedCommitRetainsSavedOriginalAndDoesNotAdvanceRevision() async throws {
    let root = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let initialStore = LibraryStore(root: root)
    var initial = try await initialStore.load().library
    initial.scripts = [ScriptRecord(text: "Original")]
    try initial.changed()
    try await initialStore.save(initial)
    let failing = LibraryStore(root: root, files: RejectPrimaryCommit())
    _ = try await failing.load()
    var edited = initial
    try edited.scripts[0].edit(title: "Edit", text: "Keep this unsaved draft")
    try edited.changed()
    await #expect(throws: (any Error).self) { try await failing.save(edited) }
    #expect(try await LibraryStore(root: root).load().library == initial)
    #expect(try await failing.load().library == initial)
}

@Test func outOfOrderSnapshotsAndExternalChangesCannotOverwriteNewerData() async throws {
    let root = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LibraryStore(root: root)
    var older = try await store.load().library
    older.scripts = [ScriptRecord(text: "Older")]
    try older.changed()
    var newer = older
    try newer.scripts[0].edit(title: "Newer", text: "Newest")
    try newer.changed()
    try await store.save(newer)
    await #expect(throws: LibraryError.staleSnapshot) { try await store.save(older) }
    let external = Data("{\"schemaVersion\":99}".utf8)
    try external.write(to: root.appendingPathComponent("library.json"))
    try newer.changed()
    await #expect(throws: LibraryError.conflict) { try await store.save(newer) }
    #expect(try Data(contentsOf: root.appendingPathComponent("library.json")) == external)
}

@Test func textImportIsBoundedStrictUTF8AndPreservesContent() throws {
    let text = "Cafe\u{301} · 한국어 👋🏽\r\nالعربية"
    #expect(try TextImport.decode(Data(("\u{FEFF}" + text).utf8)) == text)
    #expect(throws: LibraryError.invalidUTF8) { try TextImport.decode(Data([0xFF, 0xFE])) }
    #expect(throws: LibraryError.tooLarge) {
        try TextImport.decode(Data(repeating: 65, count: TextImport.maximumBytes + 1))
    }
    let root = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("Large.txt")
    try Data(repeating: 65, count: TextImport.maximumBytes + 1).write(to: source)
    #expect(throws: LibraryError.tooLarge) { try TextImport.read(source) }
}
