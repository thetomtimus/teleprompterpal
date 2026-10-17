import Foundation
import PromptingCore
import TeleprompterCore
import Testing

@Test func compatibilityAliasesPreserveDocumentJSONAndMacDefaults() throws {
    let document = PromptingCore.ScriptDocument(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        text: "한국어 👨‍👩‍👧‍👦 café", updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let mac: TeleprompterCore.ScriptDocument = document
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    #expect(try encoder.encode(document) == encoder.encode(mac))
    #expect(mac.title == "Lecture Teleprompter")
    #expect(mac.schemaVersion == 1)
    #expect(try JSONDecoder().decode(PromptingCore.ScriptDocument.self, from: encoder.encode(mac)) == document)
}

@Test func sharedEditPreservesUnicodeAndRejectsSplitSurrogatesAndStaleRevision() throws {
    let text = "A🎥한국어"
    let edit = try PromptingCore.ScriptTextEdit.replacing(
        in: text, range: .init(location: 3, length: 0), with: "👋🏽", baseRevision: 7)
    #expect(try edit.applying(to: text, revision: 7) == "A🎥👋🏽한국어")
    #expect(throws: PromptingCore.ScriptTextEditError.invalidRevision) {
        try edit.applying(to: text, revision: 6)
    }
    #expect(throws: PromptingCore.ScriptTextEditError.invalidRange) {
        try PromptingCore.ScriptTextEdit.replacing(
            in: text, range: .init(location: 2, length: 0), with: "x", baseRevision: 7)
    }
}

@Test(arguments: [("A😀B", "A😃B"), ("Cafe\u{301}", "Café"), ("한국어 👨‍👩‍👧‍👦", "새 한국어 👨‍👩‍👧‍👦")])
func minimalEditRoundTripsCommittedNativeEditorUnicode(old: String, new: String) throws {
    let edit = try PromptingCore.ScriptTextEdit.difference(from: old, to: new, baseRevision: 2)
    #expect(try edit.applying(to: old, revision: 2) == new)
    #expect(!edit.replacement.unicodeScalars.contains("\u{FFFD}"))
}
