import Foundation
import Darwin

public struct TakeScriptContext: Codable, Equatable, Sendable {
    public let id: UUID
    public let revision: UInt64
    public let title: String
    public init(id: UUID, revision: UInt64, title: String) {
        self.id = id; self.revision = revision; self.title = title
    }
}

public struct PrototypeTake: Codable, Equatable, Identifiable, Sendable {
    public enum State: String, Codable, Sendable { case pending, ready, incomplete, missing, deleting }
    public enum Recovery: String, Codable, Sendable { case recovered, interrupted }
    public var id: UUID
    public var created: Date
    public var relativePath: String
    public var state: State
    public var summary: MediaSummary?
    public var note: String?
    public var script: TakeScriptContext? = nil
    public var recovery: Recovery? = nil
    public var retainedBytes: Int64? = nil

    public var isPlayable: Bool {
        guard state == .ready, let summary else { return false }
        return summary.duration.isFinite && summary.duration > 0 && summary.width > 0 && summary.height > 0
    }
    public var isRecovered: Bool {
        recovery != nil || note?.localizedCaseInsensitiveContains("recover") == true
            || note?.localizedCaseInsensitiveContains("interrupted") == true
            || note?.localizedCaseInsensitiveContains("inactive") == true
    }
}

public enum TakeStoreFailure: Error, LocalizedError, Equatable, Sendable {
    case newerVersion, invalidJournal, changedOnDisk, fileAccess, tooLarge
    public var errorDescription: String? {
        switch self {
        case .newerVersion: "These recordings were saved by a newer app version. Update the app to open them."
        case .invalidJournal: "Recording details could not be read. Original files are retained."
        case .changedOnDisk: "Recording details changed on disk. Reopen the library before changing a take."
        case .fileAccess: "Some recordings could not be accessed. Unlock the iPhone and retry."
        case .tooLarge: "Recording details exceed this version's limit. Original files are retained."
        }
    }
}

public actor TakeStore {
    public let root: URL
    private var takes: [PrototypeTake] = []
    private var loaded = false
    private var journalData: Data?
    private var reconciling = false
    public private(set) var recoveryNotice: String?

    private struct Manifest: Codable {
        var schemaVersion = 2
        var takes: [PrototypeTake]
    }

    public init(root: URL) { self.root = root }

    public func load() throws -> [PrototypeTake] {
        if !loaded {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                do {
                    let data = try readJournal(manifestURL)
                    takes = try decode(data).takes
                    journalData = data
                } catch TakeStoreFailure.newerVersion { throw TakeStoreFailure.newerVersion }
                catch TakeStoreFailure.tooLarge { throw TakeStoreFailure.tooLarge }
                catch {
                    if (error as NSError).domain == NSCocoaErrorDomain,
                       (error as NSError).code == CocoaError.fileReadNoPermission.rawValue { throw TakeStoreFailure.fileAccess }
                    // Preserve the damaged journal before restoring or discovering originals.
                    guard (try? manifestURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                        throw TakeStoreFailure.fileAccess
                    }
                    try FileManager.default.moveItem(at: manifestURL, to: root.appendingPathComponent("damaged-\(UUID()).json"))
                    try restoreBackup()
                    recoveryNotice = "Recording details were recovered. Original files were retained."
                }
            } else if FileManager.default.fileExists(atPath: backupURL.path) {
                try restoreBackup()
                recoveryNotice = "Recording details were restored from a backup."
            }
            loaded = true
        }
        return takes.sorted { $0.created == $1.created ? $0.id.uuidString < $1.id.uuidString : $0.created > $1.created }
    }

    public func reload() throws -> [PrototypeTake] {
        guard !reconciling else { throw PrototypeError.busy }
        loaded = false
        journalData = nil
        takes = []
        recoveryNotice = nil
        return try load()
    }

    public func prepare(id: UUID, script: TakeScriptContext? = nil, created: Date = Date()) throws -> URL {
        _ = try load()
        guard !reconciling, !takes.contains(where: { $0.id == id }),
              (try? FileManager.default.attributesOfItem(atPath: sourceURL(id).path)) == nil else { throw PrototypeError.busy }
        let filename = id.uuidString + ".mov"
        var updated = takes
        updated.append(.init(id: id, created: created, relativePath: filename, state: .pending, script: script))
        try persist(updated)
        takes = updated
        return root.appendingPathComponent(filename)
    }

    public func complete(id: UUID, summary: MediaSummary, note: String? = nil, recovery: PrototypeTake.Recovery? = nil) throws {
        guard !reconciling else { throw PrototypeError.busy }
        guard let index = takes.firstIndex(where: { $0.id == id }) else { throw PrototypeError.invalidMedia }
        var updated = takes
        updated[index].summary = summary
        updated[index].state = .ready
        updated[index].note = note
        updated[index].recovery = recovery
        try persist(updated)
        takes = updated
    }

    public func markIncomplete(id: UUID, note: String) throws {
        guard !reconciling else { throw PrototypeError.busy }
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return }
        var updated = takes
        updated[index].state = .incomplete
        updated[index].note = note
        updated[index].summary = nil
        try persist(updated)
        takes = updated
    }

    public func url(for take: PrototypeTake) -> URL { sourceURL(take.id) }

    /// Runs before capture becomes available. Inspection can suspend, so writers are
    /// excluded until the reconciled snapshot is committed. Files are never truncated.
    public func reconcile(inspect: @Sendable (URL) async throws -> MediaSummary) async throws -> [PrototypeTake] {
        _ = try load()
        guard !reconciling else { throw PrototypeError.busy }
        reconciling = true
        defer { reconciling = false }
        try Task.checkCancellation()
        var updated = takes
        for take in updated where take.state == .deleting {
            do {
                try removeOriginal(take.id)
                updated.removeAll { $0.id == take.id }
            } catch { recoveryNotice = "A recording deletion could not finish. Retry it from Videos." }
        }
        let known = Set(updated.map(\.id))
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey]) {
            guard url.pathExtension == "mov", let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  url.lastPathComponent == id.uuidString + ".mov", !known.contains(id) else { continue }
            updated.append(.init(id: id, created: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast,
                                 relativePath: url.lastPathComponent, state: .pending))
        }
        for index in updated.indices where updated[index].state != .deleting {
            try Task.checkCancellation()
            let url = sourceURL(updated[index].id)
            guard FileManager.default.fileExists(atPath: url.path) else {
                updated[index].state = .missing
                updated[index].summary = nil
                updated[index].retainedBytes = nil
                updated[index].note = "The original file is missing."
                continue
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                updated[index].state = .incomplete
                updated[index].summary = nil
                updated[index].note = "The original path could not be safely read."
                continue
            }
            let bytes = (attributes[.size] as? NSNumber)?.int64Value
            let previouslyPlayable = updated[index].isPlayable
            do {
                let summary = try await inspect(url)
                try Task.checkCancellation()
                updated[index].summary = summary
                updated[index].state = .ready
                if !previouslyPlayable {
                    updated[index].recovery = .recovered
                    updated[index].note = "Recovered after interruption"
                }
                updated[index].retainedBytes = nil
            } catch {
                if Task.isCancelled || error is CancellationError { throw CancellationError() }
                let cocoa = error as NSError
                if cocoa.domain == NSCocoaErrorDomain, cocoa.code == CocoaError.fileReadNoPermission.rawValue {
                    throw TakeStoreFailure.fileAccess
                }
                updated[index].state = .incomplete
                updated[index].summary = nil
                updated[index].retainedBytes = bytes
                updated[index].note = "Incomplete original retained after interruption."
            }
        }
        if updated != takes {
            try Task.checkCancellation()
            try persist(updated)
            takes = updated
        }
        return try load()
    }

    /// Persist intent before unlinking. A crash or failed final publication leaves
    /// a non-playable deleting row, which reconciliation can safely finish later.
    public func delete(id: UUID) throws {
        _ = try load()
        guard !reconciling else { throw PrototypeError.busy }
        guard let index = takes.firstIndex(where: { $0.id == id }) else { return }
        guard takes[index].state != .pending else { throw PrototypeError.busy }
        if takes[index].state != .deleting {
            var updated = takes
            updated[index].state = .deleting
            try persist(updated)
            takes = updated
        }
        try removeOriginal(id)
        let updated = takes.filter { $0.id != id }
        try persist(updated)
        takes = updated
    }

    private var manifestURL: URL { root.appendingPathComponent("takes.json") }
    private var backupURL: URL { root.appendingPathComponent("takes.backup.json") }
    private func sourceURL(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".mov") }

    private func readJournal(_ url: URL) throws -> Data {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let bytes = attributes[.size] as? NSNumber else {
            throw TakeStoreFailure.invalidJournal
        }
        guard bytes.int64Value <= 8 * 1024 * 1024 else { throw TakeStoreFailure.tooLarge }
        return try Data(contentsOf: url)
    }

    private func decode(_ data: Data) throws -> Manifest {
        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = object["schemaVersion"] as? Int, version > 2 { throw TakeStoreFailure.newerVersion }
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard [1, 2].contains(manifest.schemaVersion), Set(manifest.takes.map(\.id)).count == manifest.takes.count,
              manifest.takes.allSatisfy({ $0.relativePath == $0.id.uuidString + ".mov" }) else {
            throw TakeStoreFailure.invalidJournal
        }
        return manifest
    }

    private func restoreBackup() throws {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }
        let data: Data
        let restored: Manifest
        do {
            data = try readJournal(backupURL)
            restored = try decode(data)
        } catch TakeStoreFailure.newerVersion { throw TakeStoreFailure.newerVersion }
        catch TakeStoreFailure.tooLarge { throw TakeStoreFailure.tooLarge }
        catch {
            if (error as NSError).domain == NSCocoaErrorDomain,
               (error as NSError).code == CocoaError.fileReadNoPermission.rawValue { throw TakeStoreFailure.fileAccess }
            guard (try? backupURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { throw TakeStoreFailure.fileAccess }
            try FileManager.default.moveItem(at: backupURL, to: root.appendingPathComponent("damaged-backup-\(UUID()).json"))
            return
        }
        try atomicWrite(data, to: manifestURL)
        takes = restored.takes
        journalData = data
    }

    private func removeOriginal(_ id: UUID) throws {
        let url = sourceURL(id)
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
        catch {
            if (error as NSError).domain == NSCocoaErrorDomain,
               (error as NSError).code == CocoaError.fileReadNoSuchFile.rawValue { return }
            throw error
        }
        // Never recursively remove a directory placed at a movie filename.
        let type = attributes[.type] as? FileAttributeType
        guard type == .typeRegular || type == .typeSymbolicLink else { throw TakeStoreFailure.fileAccess }
        try FileManager.default.removeItem(at: url)
    }

    private func persist(_ updated: [PrototypeTake]) throws {
        if let journalData {
            guard (try? readJournal(manifestURL)) == journalData else { throw TakeStoreFailure.changedOnDisk }
            try atomicWrite(journalData, to: backupURL)
        } else if FileManager.default.fileExists(atPath: manifestURL.path) { throw TakeStoreFailure.changedOnDisk }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Manifest(takes: updated))
        guard data.count <= 8 * 1024 * 1024 else { throw TakeStoreFailure.tooLarge }
        try atomicWrite(data, to: manifestURL)
        journalData = data
    }

    private func atomicWrite(_ data: Data, to destination: URL) throws {
        let staged = root.appendingPathComponent("\(UUID()).stage")
        defer { try? FileManager.default.removeItem(at: staged) }
        try data.write(to: staged, options: .withoutOverwriting)
        let handle = try FileHandle(forWritingTo: staged)
        defer { try? handle.close() }
        try handle.synchronize()
        guard rename(staged.path, destination.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    }
}
