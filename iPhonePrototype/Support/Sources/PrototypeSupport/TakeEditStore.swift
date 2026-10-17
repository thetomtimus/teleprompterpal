import Foundation

public struct TakeEditSource: Codable, Equatable, Sendable {
    public let duration: MediaTime
    public let width: Int
    public let height: Int
    public let fileBytes: Int64
    public let modified: Date

    public init(url: URL, summary: MediaSummary) throws {
        // URL resource values can be cached on a reused URL after replacement.
        // Read fresh file attributes before associating an edit with its source.
        let values = try FileManager.default.attributesOfItem(atPath: url.path)
        guard values[.type] as? FileAttributeType == .typeRegular, let bytes = values[.size] as? NSNumber,
              let modified = values[.modificationDate] as? Date, summary.duration.isFinite,
              summary.duration > 0, summary.width > 0, summary.height > 0 else {
            throw PrototypeError.invalidMedia
        }
        duration = MediaTime(seconds: summary.duration)
        width = summary.width; height = summary.height
        fileBytes = bytes.int64Value; self.modified = modified
    }
}

public struct SavedTakeEdit: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public let takeID: UUID
    public let revision: UInt64
    public let source: TakeEditSource
    public let recipe: EditRecipe
}

public enum TakeEditFailure: Error, LocalizedError, Equatable, Sendable {
    case corrupt, newerVersion, sourceChanged, conflict, revisionOverflow

    public var errorDescription: String? {
        switch self {
        case .corrupt: "Saved edits could not be read. They are preserved, and the original is still available."
        case .newerVersion: "These edits need a newer app version. You can still review the original."
        case .sourceChanged: "This original has changed since its edits were saved. The saved edits are preserved."
        case .conflict: "Saved edits changed elsewhere. Reopen the editor before saving."
        case .revisionOverflow: "These edits cannot accept another revision. Your saved edits are preserved."
        }
    }
}

/// Persistent edit sidecars are independent of the immutable original/take journal.
/// One shared actor owns writes in the app; revisions reject stale editor drafts.
public actor TakeEditStore {
    public let root: URL
    private let write: @Sendable (Data, URL) throws -> Void

    public init(root: URL) {
        self.root = root
        write = Self.atomicWrite
    }

    init(root: URL, write: @escaping @Sendable (Data, URL) throws -> Void) {
        self.root = root; self.write = write
    }

    public func load(takeID: UUID, source: TakeEditSource) throws -> SavedTakeEdit? {
        let url = path(takeID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let count = values.fileSize, count <= 64 * 1024 else {
            throw TakeEditFailure.corrupt
        }
        let data = try Data(contentsOf: url)
        struct Version: Decodable { let schemaVersion: Int }
        let version: Version
        do { version = try JSONDecoder().decode(Version.self, from: data) }
        catch { throw TakeEditFailure.corrupt }
        guard version.schemaVersion <= 1 else { throw TakeEditFailure.newerVersion }
        guard version.schemaVersion == 1 else { throw TakeEditFailure.corrupt }
        let edit: SavedTakeEdit
        do { edit = try JSONDecoder().decode(SavedTakeEdit.self, from: data) }
        catch { throw TakeEditFailure.corrupt }
        guard edit.takeID == takeID, edit.revision > 0 else { throw TakeEditFailure.corrupt }
        guard edit.source == source else { throw TakeEditFailure.sourceChanged }
        do { try edit.recipe.validate(duration: source.duration.seconds) }
        catch { throw TakeEditFailure.corrupt }
        return edit
    }

    public func save(takeID: UUID, source: TakeEditSource, recipe: EditRecipe,
                     expectedRevision: UInt64) throws -> SavedTakeEdit {
        try recipe.validate(duration: source.duration.seconds)
        let previous = try load(takeID: takeID, source: source)
        guard (previous?.revision ?? 0) == expectedRevision else { throw TakeEditFailure.conflict }
        if let previous, previous.recipe == recipe { return previous }
        guard expectedRevision < .max else { throw TakeEditFailure.revisionOverflow }
        let edit = SavedTakeEdit(takeID: takeID, revision: expectedRevision + 1, source: source, recipe: recipe)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(edit)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try write(data, path(takeID))
        return edit
    }

    public func remove(takeID: UUID) throws {
        let url = path(takeID)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func path(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".json") }

    private static func atomicWrite(_ data: Data, to destination: URL) throws {
        // Atomic replacement never writes through a partial sidecar or into the original.
        try data.write(to: destination, options: .atomic)
        #if os(iOS)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                               ofItemAtPath: destination.path)
        #endif
    }
}
