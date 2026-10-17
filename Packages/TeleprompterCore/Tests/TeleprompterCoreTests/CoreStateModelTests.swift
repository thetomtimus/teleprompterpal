import Foundation
import XCTest

@testable import TeleprompterCore

final class CoreStateModelTests: XCTestCase {
    private let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000.125)

    func testDefaultTitleAndPreferencesMatchPRD() {
        let document = ScriptDocument(id: fixedID, updatedAt: fixedDate)
        let preferences = TeleprompterPreferences()

        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.title, "Lecture Teleprompter")
        XCTAssertEqual(document.text, "")
        XCTAssertEqual(document.revision, 0)
        XCTAssertEqual(preferences.speedPointsPerSecond, 60)
        XCTAssertEqual(preferences.fontSizePoints, 42)
        XCTAssertEqual(preferences.fontWeight, .regular)
        XCTAssertEqual(preferences.textAlignment, .left)
        XCTAssertTrue(preferences.isActiveBandEnabled)
        XCTAssertTrue(preferences.isFocusModeEnabled)
        XCTAssertFalse(preferences.isLocked)
        XCTAssertNil(preferences.selectedDisplayFingerprint)
    }

    func testFontRangeClampsTo24Through96() {
        XCTAssertEqual(TeleprompterPreferences(fontSizePoints: -1).fontSizePoints, 24)
        XCTAssertEqual(TeleprompterPreferences(fontSizePoints: 200).fontSizePoints, 96)
        XCTAssertEqual(TeleprompterPreferences(fontSizePoints: 43).fontSizePoints, 43)
        XCTAssertEqual(TeleprompterPreferences(fontSizePoints: .nan).fontSizePoints, 42)
    }

    func testSpeedRangeClampsTo10Through240() {
        XCTAssertEqual(TeleprompterPreferences(speedPointsPerSecond: -1).speedPointsPerSecond, 10)
        XCTAssertEqual(TeleprompterPreferences(speedPointsPerSecond: 500).speedPointsPerSecond, 240)
        XCTAssertEqual(TeleprompterPreferences(speedPointsPerSecond: 61).speedPointsPerSecond, 61)
        XCTAssertEqual(
            TeleprompterPreferences(speedPointsPerSecond: .infinity).speedPointsPerSecond,
            60
        )
    }

    func testDefaultShortcutMapMatchesPRD() {
        let modifiers: Set<ShortcutModifier> = [.control, .option]

        XCTAssertEqual(
            KeyboardShortcut.defaultMap,
            [
                .togglePlayback: .init(virtualKeyCode: 49, modifiers: modifiers),
                .increaseSpeed: .init(virtualKeyCode: 126, modifiers: modifiers),
                .decreaseSpeed: .init(virtualKeyCode: 125, modifiers: modifiers),
                .moveBackward: .init(virtualKeyCode: 123, modifiers: modifiers),
                .moveForward: .init(virtualKeyCode: 124, modifiers: modifiers),
                .toggleVisibility: .init(virtualKeyCode: 4, modifiers: modifiers),
                .toggleLock: .init(virtualKeyCode: 37, modifiers: modifiers),
            ]
        )
    }

    func testReadingAnchorClampsWithoutSplittingUnicode() {
        let document = "Cafe\u{301} 한국어 👍🏽 👨‍👩‍👧‍👦"
        let before = String(repeating: "a", count: 80) + "👍" + String(repeating: "b", count: 63)
        let after = String(repeating: "c", count: 63) + "👍" + String(repeating: "d", count: 80)

        let anchor = ReadingAnchor(
            utf16Offset: Int.max,
            contextBefore: before,
            contextAfter: after,
            viewportFraction: 2,
            document: document
        )

        XCTAssertEqual(anchor.utf16Offset, document.utf16.count)
        XCTAssertLessThanOrEqual(anchor.contextBefore.utf16.count, 64)
        XCTAssertLessThanOrEqual(anchor.contextAfter.utf16.count, 64)
        XCTAssertFalse(anchor.contextBefore.unicodeScalars.contains("\u{FFFD}"))
        XCTAssertFalse(anchor.contextAfter.unicodeScalars.contains("\u{FFFD}"))
        XCTAssertEqual(anchor.viewportFraction, 1)

        XCTAssertEqual(ReadingAnchor(utf16Offset: -4, viewportFraction: -.infinity).utf16Offset, 0)
        XCTAssertEqual(ReadingAnchor(viewportFraction: .nan).viewportFraction, 0.5)
    }

    func testCodableRoundTripPreservesUnicodeScript() throws {
        let unicode = "Café Cafe\u{301} · 한국어 · 👍🏽 · 👨‍👩‍👧‍👦"
        let snapshot = makeSnapshot(
            text: unicode,
            panelFrames: [
                PersistedPanelFrame(
                    displayFingerprint: fingerprint(
                        uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                        serial: 1
                    ),
                    frame: .init(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
                )
            ],
            shortcutBindings: [
                ShortcutBinding(
                    action: .togglePlayback,
                    shortcut: .init(virtualKeyCode: 49, modifiers: [.option, .control])
                )
            ]
        )

        let data = try snapshot.canonicalData()
        let decoded = try PersistedSnapshot.canonicalDecoder().decode(
            PersistedSnapshot.self,
            from: data
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let bindings = try XCTUnwrap(object["shortcutBindings"] as? [[String: Any]])
        let shortcut = try XCTUnwrap(bindings.first?["shortcut"] as? [String: Any])

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual((object["document"] as? [String: Any])?["text"] as? String, unicode)
        XCTAssertEqual(shortcut["modifiers"] as? [String], ["Control", "Option"])
    }

    func testPersistedSnapshotExcludesPlayingState() throws {
        let keys = try recursiveKeys(in: makeSnapshot().canonicalData())

        XCTAssertFalse(keys.contains("isPlaying"))
        XCTAssertFalse(keys.contains("playbackPhase"))
        XCTAssertFalse(keys.contains("overlaySession"))
        XCTAssertFalse(keys.contains("pendingEffect"))
        XCTAssertFalse(keys.contains("alert"))
        XCTAssertFalse(keys.contains("warning"))
    }

    func testPersistedSnapshotExcludesRuntimeDisplayID() throws {
        let keys = try recursiveKeys(in: makeSnapshot().canonicalData())

        XCTAssertFalse(keys.contains("sessionID"))
        XCTAssertFalse(keys.contains("currentSessionDisplayID"))
        XCTAssertFalse(keys.contains("isConfirmedInCurrentSession"))
        XCTAssertFalse(keys.contains("recoveryConfirmationState"))
    }

    func testRawDisplayIDIsNotEncoded() throws {
        let data = try makeSnapshot().canonicalData()
        let encoded = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertFalse(encoded.contains("sessionID"))
        XCTAssertFalse(encoded.contains("currentSessionID"))
        XCTAssertFalse(encoded.contains("rawDisplayID"))
    }

    func testExplicitCurrentSessionChoiceDoesNotEnterEncodedSnapshot() throws {
        let selected = DisplaySelection(
            fingerprint: fingerprint(uuid: "selected", serial: 9),
            isConfirmed: true,
            isConfirmedInCurrentSession: true,
            currentSessionID: 4_294_967_000
        )
        XCTAssertEqual(selected.currentSessionID, 4_294_967_000)

        let keys = try recursiveKeys(in: makeSnapshot().canonicalData())
        XCTAssertFalse(keys.contains("sessionID"))
        XCTAssertFalse(keys.contains("currentSessionID"))
        XCTAssertFalse(keys.contains("isConfirmedInCurrentSession"))
    }

    func testCanonicalFrameIdentityIgnoresDisplayNameMetadata() throws {
        let first = DisplayFingerprint(
            uuid: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA",
            vendorID: 1,
            modelID: 2,
            serialNumber: 3,
            isBuiltIn: false,
            lastLocalizedName: "Old Name",
            confidence: .strong
        )
        var renamed = first
        renamed.lastLocalizedName = "New Name"
        let frame = NormalizedPanelFrame(x: 0.1, y: 0.2, width: 0.3, height: 0.4)

        let snapshot = makeSnapshot(
            panelFrames: [
                .init(displayFingerprint: first, frame: frame),
                .init(displayFingerprint: renamed, frame: frame),
            ]
        )

        XCTAssertThrowsError(try snapshot.canonicalData()) { error in
            XCTAssertEqual(
                error as? PersistedSnapshotValidationError,
                .duplicateDisplayFingerprint
            )
        }
    }

    func testCanonicalEncodingIsByteEqualForPermutedInput() throws {
        let firstFingerprint = fingerprint(uuid: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB", serial: 2)
        let secondFingerprint = fingerprint(uuid: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", serial: 1)
        let firstFrame = PersistedPanelFrame(
            displayFingerprint: firstFingerprint,
            frame: .init(x: 0.2, y: 0.3, width: 0.4, height: 0.5)
        )
        let secondFrame = PersistedPanelFrame(
            displayFingerprint: secondFingerprint,
            frame: .init(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        )
        let firstBinding = ShortcutBinding(
            action: .toggleVisibility,
            shortcut: .init(virtualKeyCode: 4, modifiers: [.option, .control])
        )
        let secondBinding = ShortcutBinding(
            action: .togglePlayback,
            shortcut: .init(virtualKeyCode: 49, modifiers: [.control, .option])
        )

        let first = makeSnapshot(
            panelFrames: [firstFrame, secondFrame],
            shortcutBindings: [firstBinding, secondBinding]
        )
        let second = makeSnapshot(
            panelFrames: [secondFrame, firstFrame],
            shortcutBindings: [secondBinding, firstBinding]
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(try first.canonicalData(), try second.canonicalData())
    }

    func testDuplicateFrameAndShortcutEntriesAreRejected() throws {
        let frame = PersistedPanelFrame(
            displayFingerprint: fingerprint(uuid: "duplicate", serial: 10),
            frame: .init(x: 0, y: 0, width: 1, height: 1)
        )
        let binding = ShortcutBinding(
            action: .togglePlayback,
            shortcut: .init(virtualKeyCode: 49, modifiers: [.control, .option])
        )

        let frameData = try makeSnapshot(panelFrames: [frame]).canonicalData()
        var frameObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: frameData) as? [String: Any]
        )
        var frames = try XCTUnwrap(frameObject["panelFrames"] as? [[String: Any]])
        var caseVariantFrame = frames[0]
        var caseVariantFingerprint = try XCTUnwrap(
            caseVariantFrame["displayFingerprint"] as? [String: Any]
        )
        caseVariantFingerprint["uuid"] = "DUPLICATE"
        caseVariantFrame["displayFingerprint"] = caseVariantFingerprint
        frames.append(caseVariantFrame)
        frameObject["panelFrames"] = frames
        let duplicateFrameData = try JSONSerialization.data(withJSONObject: frameObject)

        XCTAssertThrowsError(
            try PersistedSnapshot.canonicalDecoder().decode(
                PersistedSnapshot.self,
                from: duplicateFrameData
            )
        ) { error in
            XCTAssertEqual(error as? PersistedSnapshotValidationError, .duplicateDisplayFingerprint)
        }

        let bindingData = try makeSnapshot(shortcutBindings: [binding]).canonicalData()
        var bindingObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: bindingData) as? [String: Any]
        )
        var bindings = try XCTUnwrap(bindingObject["shortcutBindings"] as? [[String: Any]])
        bindings.append(bindings[0])
        bindingObject["shortcutBindings"] = bindings
        let duplicateBindingData = try JSONSerialization.data(withJSONObject: bindingObject)

        XCTAssertThrowsError(
            try PersistedSnapshot.canonicalDecoder().decode(
                PersistedSnapshot.self,
                from: duplicateBindingData
            )
        ) { error in
            XCTAssertEqual(error as? PersistedSnapshotValidationError, .duplicateShortcutAction)
        }
    }

    func testUnknownShortcutModifierIsMalformed() throws {
        let binding = ShortcutBinding(
            action: .togglePlayback,
            shortcut: .init(virtualKeyCode: 49, modifiers: [.control, .option])
        )
        let data = try makeSnapshot(shortcutBindings: [binding]).canonicalData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var bindings = try XCTUnwrap(object["shortcutBindings"] as? [[String: Any]])
        var shortcut = try XCTUnwrap(bindings[0]["shortcut"] as? [String: Any])
        shortcut["modifiers"] = ["Control", "Hyper"]
        bindings[0]["shortcut"] = shortcut
        object["shortcutBindings"] = bindings
        let malformed = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try PersistedSnapshot.canonicalDecoder().decode(PersistedSnapshot.self, from: malformed)
        )
    }

    func testSnapshotAndDocumentSchemaMustAgree() throws {
        let data = try makeSnapshot().canonicalData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var document = try XCTUnwrap(object["document"] as? [String: Any])
        document["schemaVersion"] = 2
        object["document"] = document
        let malformed = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try PersistedSnapshot.canonicalDecoder().decode(PersistedSnapshot.self, from: malformed)
        ) { error in
            XCTAssertEqual(error as? PersistedSnapshotValidationError, .schemaVersionMismatch)
        }
    }

    func testStabilizationRetainsV1CanonicalSnapshotAfterDiagnosticLockChange() throws {
        var preferences = TeleprompterPreferences(isLocked: false)
        XCTAssertFalse(preferences.isLocked)
        preferences.isLocked = true
        let snapshot = makeSnapshot(
            text: "Generated stabilization fixture",
            preferences: preferences
        )

        let data = try snapshot.canonicalData()
        let decoded = try PersistedSnapshot.canonicalDecoder().decode(
            PersistedSnapshot.self,
            from: data
        )

        XCTAssertEqual(PersistedSnapshot.currentSchemaVersion, 1)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.document.schemaVersion, 1)
        XCTAssertTrue(decoded.preferences.isLocked)
    }

    func testDiagnosticStateNeverEntersPersistedSnapshot() throws {
        let keys = try recursiveKeys(in: makeSnapshot().canonicalData())
        let diagnosticOnlyKeys: Set<String> = [
            "configurationBound",
            "controllerCohort",
            "correlationID",
            "diagnosticEvent",
            "evidencePath",
            "executableSHA256",
            "orderingMode",
            "proofStatus",
            "repetition",
            "sessionCompletion",
            "sessionID",
        ]

        XCTAssertTrue(keys.isDisjoint(with: diagnosticOnlyKeys))
    }

    func testCoreProductionSourcesImportFoundationOnly() throws {
        let testsURL = URL(fileURLWithPath: #filePath)
        let packageURL =
            testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        // PromptingCore is Foundation-only; the desktop layer may depend on that portable module.
        for (target, allowed) in [
            ("PromptingCore", Set(["import Foundation"])),
            ("TeleprompterCore", Set(["import Foundation", "import PromptingCore"])),
        ] {
            let sourcesURL = packageURL.appendingPathComponent("Sources/" + target)
            let enumerator = try XCTUnwrap(
                FileManager.default.enumerator(at: sourcesURL, includingPropertiesForKeys: nil))
            let swiftFiles = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
            XCTAssertFalse(swiftFiles.isEmpty)
            for file in swiftFiles {
                let imports = try String(contentsOf: file, encoding: .utf8)
                    .split(separator: "\n").map(String.init).filter { $0.hasPrefix("import ") }
                XCTAssertFalse(imports.isEmpty)
                XCTAssertTrue(Set(imports).isSubset(of: allowed), "Unexpected imports in \(target)/\(file.lastPathComponent)")
            }
        }
    }

    private func makeSnapshot(
        text: String = "Generated test fixture",
        preferences: TeleprompterPreferences = .init(),
        panelFrames: [PersistedPanelFrame] = [],
        shortcutBindings: [ShortcutBinding] = []
    ) -> PersistedSnapshot {
        let document = ScriptDocument(
            id: fixedID,
            title: "Generated fixture",
            text: text,
            revision: 7,
            updatedAt: fixedDate
        )
        return PersistedSnapshot(
            revision: 11,
            document: document,
            readingAnchor: .init(utf16Offset: 3, viewportFraction: 0.25, document: text),
            preferences: preferences,
            panelFrames: panelFrames,
            shortcutBindings: shortcutBindings
        )
    }

    private func fingerprint(uuid: String, serial: UInt32) -> DisplayFingerprint {
        DisplayFingerprint(
            uuid: uuid,
            vendorID: 1,
            modelID: 2,
            serialNumber: serial,
            isBuiltIn: false,
            lastLocalizedName: "Generated fixture display",
            confidence: .strong
        )
    }

    private func recursiveKeys(in data: Data) throws -> Set<String> {
        var keys: Set<String> = []
        func visit(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                keys.formUnion(dictionary.keys)
                dictionary.values.forEach(visit)
            } else if let array = value as? [Any] {
                array.forEach(visit)
            }
        }
        visit(try JSONSerialization.jsonObject(with: data))
        return keys
    }
}
