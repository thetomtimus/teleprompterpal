import Foundation
import PromptingCore

public struct ReaderPreferences: Codable, Equatable, Sendable {
    public enum Alignment: String, Codable, CaseIterable, Sendable { case natural, left, center, right }
    public enum Appearance: String, Codable, CaseIterable, Sendable { case dark, light }
    public var fontSize = 28.0
    public var speed = 30.0
    public var alignment = Alignment.natural
    public var appearance = Appearance.dark
    public var backgroundOpacity = 0.80
    public var readingBand = false
    public var panelPosition = 0.0
    public var panelHeight = 0.55
    public init() {}
    private enum CodingKeys: String, CodingKey {
        case fontSize, speed, alignment, appearance, backgroundOpacity, readingBand, panelPosition, panelHeight
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = try values.decodeIfPresent(Double.self, forKey: .fontSize) ?? 28
        speed = try values.decodeIfPresent(Double.self, forKey: .speed) ?? 30
        alignment = try values.decodeIfPresent(Alignment.self, forKey: .alignment) ?? .natural
        appearance = try values.decodeIfPresent(Appearance.self, forKey: .appearance) ?? .dark
        backgroundOpacity = try values.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.80
        readingBand = try values.decodeIfPresent(Bool.self, forKey: .readingBand) ?? false
        panelPosition = try values.decodeIfPresent(Double.self, forKey: .panelPosition) ?? 0
        panelHeight = try values.decodeIfPresent(Double.self, forKey: .panelHeight) ?? 0.55
        normalize()
    }
    public mutating func normalize() {
        fontSize = fontSize.isFinite ? min(max(fontSize, 20), 72) : 28
        speed = speed.isFinite ? min(max(speed, 10), 240) : 30
        backgroundOpacity = backgroundOpacity.isFinite ? min(max(backgroundOpacity, 0.65), 1) : 0.80
        panelPosition = panelPosition.isFinite ? min(max(panelPosition, 0), 1) : 0
        panelHeight = panelHeight.isFinite ? min(max(panelHeight, 0.30), 0.85) : 0.55
    }
}

public struct ScriptRecord: Codable, Equatable, Identifiable, Sendable {
    public var document: ScriptDocument
    public var anchor: ReadingAnchor
    public var deletedAt: Date?
    public var id: UUID { document.id }
    public init(title: String = "Untitled Script", text: String = "", id: UUID = UUID(), now: Date = Date()) {
        document = .init(id: id, title: title, text: text, updatedAt: now)
        anchor = .init()
    }
    public mutating func edit(title: String, text: String, now: Date = Date()) throws {
        guard document.revision < UInt64.max else { throw LibraryError.revisionOverflow }
        let old = document.text
        if old != text {
            let edit = try ScriptTextEdit.difference(from: old, to: text, baseRevision: document.revision)
            anchor =
                ReadingPositionMapper.map(
                    anchor: anchor, editedRangeUTF16: NSRange(location: edit.range.location, length: edit.range.length),
                    replacement: edit.replacement, preEditDocument: old, postEditDocument: text
                ).anchor
        }
        document.title = title
        document.text = text
        document.revision += 1
        document.updatedAt = now
    }
}

public struct ScriptLibrary: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion = currentSchemaVersion
    public var revision: UInt64 = 0
    public var scripts: [ScriptRecord] = []
    public var preferences = ReaderPreferences()
    public var selectedScriptID: UUID?
    public init() {}
    public mutating func changed() throws {
        guard revision < UInt64.max else { throw LibraryError.revisionOverflow }
        revision += 1
    }
    public func matching(_ query: String, deleted: Bool = false) -> [ScriptRecord] {
        scripts.filter { ($0.deletedAt != nil) == deleted }
            .filter {
                query.isEmpty || $0.document.title.localizedStandardContains(query)
                    || $0.document.text.localizedStandardContains(query)
            }
            .sorted {
                $0.document.updatedAt == $1.document.updatedAt
                    ? $0.id.uuidString < $1.id.uuidString : $0.document.updatedAt > $1.document.updatedAt
            }
    }
}

public enum LibraryError: Error, LocalizedError, Equatable, Sendable {
    case futureSchema(Int)
    case corrupt, conflict, staleSnapshot, notLoaded, tooLarge, invalidUTF8, revisionOverflow
    public var errorDescription: String? {
        switch self {
        case .futureSchema:
            "These scripts were saved by a newer app version. Update the app to edit them. Your files are preserved."
        case .corrupt: "The script library could not be opened. Its files are preserved. Try reopening the app."
        case .conflict:
            "The library changed on disk. Your edits are still on screen. Reopen before making more changes."
        case .staleSnapshot: "A newer set of edits has already been saved."
        case .notLoaded: "The library is not ready. Try opening it again."
        case .tooLarge: "This script is too large. Choose UTF-8 text up to 1 MB; no text has been truncated."
        case .invalidUTF8: "This file is not valid UTF-8 text. Save it as UTF-8 .txt and import it again."
        case .revisionOverflow: "This library cannot accept another revision. Your saved files are preserved."
        }
    }
}

public enum TextImport {
    public static let maximumBytes = 1_048_576
    public static func decode(_ data: Data) throws -> String {
        guard data.count <= maximumBytes else { throw LibraryError.tooLarge }
        guard var text = String(data: data, encoding: .utf8) else { throw LibraryError.invalidUTF8 }
        if text.first == "\u{FEFF}" { text.removeFirst() }
        return text
    }
    public static func read(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(65_536, maximumBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= maximumBytes else { throw LibraryError.tooLarge }
        }
        return try decode(data)
    }
}
