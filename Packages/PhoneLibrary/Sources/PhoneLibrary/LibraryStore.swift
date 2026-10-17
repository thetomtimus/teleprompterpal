import Foundation

public protocol LibraryFileSystem: Sendable {
    func exists(_ url: URL) -> Bool
    func read(_ url: URL) throws -> Data
    func writeAtomically(_ data: Data, to url: URL) throws
}

public struct LocalLibraryFileSystem: LibraryFileSystem {
    public init() {}
    public func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    public func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    public func writeAtomically(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = url.deletingLastPathComponent().appendingPathComponent(".\(UUID()).tmp")
        defer { try? FileManager.default.removeItem(at: staging) }
        var options: Data.WritingOptions = [.withoutOverwriting]
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try data.write(to: staging, options: options)
        let handle = try FileHandle(forWritingTo: staging)
        do {
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
        if exists(url) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: staging)
        } else {
            try FileManager.default.moveItem(at: staging, to: url)
        }
    }
}

public struct LibraryLoad: Sendable {
    public var library: ScriptLibrary
    public var recoveredFromBackup: Bool
}

public actor LibraryStore {
    public let root: URL
    private let files: any LibraryFileSystem
    private var current: ScriptLibrary?
    private var diskBytes: Data?
    public init(root: URL, files: any LibraryFileSystem = LocalLibraryFileSystem()) {
        self.root = root
        self.files = files
    }
    private var primary: URL { root.appendingPathComponent("library.json") }
    private var backup: URL { root.appendingPathComponent("library.backup.json") }

    public func load() throws -> LibraryLoad {
        if let current { return .init(library: current, recoveredFromBackup: false) }
        if files.exists(primary) {
            let data = try files.read(primary)
            do {
                let library = try decode(data)
                current = library
                diskBytes = data
                return .init(library: library, recoveredFromBackup: false)
            } catch let error as LibraryError {
                if case .futureSchema = error { throw error }
                return try recover(corrupt: data)
            } catch { return try recover(corrupt: data) }
        }
        if files.exists(backup) { return try recover(corrupt: nil) }
        let empty = ScriptLibrary()
        current = empty
        return .init(library: empty, recoveredFromBackup: false)
    }

    public func save(_ candidate: ScriptLibrary) throws {
        guard let current else { throw LibraryError.notLoaded }
        try validate(candidate)
        if candidate == current { return }
        guard candidate.revision > current.revision else { throw LibraryError.staleSnapshot }
        let actual = files.exists(primary) ? try files.read(primary) : nil
        guard actual == diskBytes else { throw LibraryError.conflict }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(candidate)
        // Back up only validated data. A failed new commit leaves the previous primary intact.
        if let diskBytes { try files.writeAtomically(diskBytes, to: backup) }
        try files.writeAtomically(data, to: primary)
        self.current = candidate
        diskBytes = data
    }

    public func readImportedText(_ url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try TextImport.read(url)
    }

    private func recover(corrupt data: Data?) throws -> LibraryLoad {
        guard files.exists(backup) else { throw LibraryError.corrupt }
        let bytes = try files.read(backup)
        let recovered = try decode(bytes)
        if let data {
            let destination = root.appendingPathComponent("Corrupt/library-\(UUID()).json")
            try files.writeAtomically(data, to: destination)
        }
        try files.writeAtomically(bytes, to: primary)
        current = recovered
        diskBytes = bytes
        return .init(library: recovered, recoveredFromBackup: true)
    }

    private func decode(_ data: Data) throws -> ScriptLibrary {
        // Inspect the version before decoding fields that a future version may have changed.
        struct Header: Decodable { var schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version <= ScriptLibrary.currentSchemaVersion else { throw LibraryError.futureSchema(version) }
        let value = try JSONDecoder().decode(ScriptLibrary.self, from: data)
        try validate(value)
        return value
    }

    private func validate(_ library: ScriptLibrary) throws {
        guard library.schemaVersion == ScriptLibrary.currentSchemaVersion,
            Set(library.scripts.map(\.id)).count == library.scripts.count,
            library.scripts.allSatisfy({ $0.document.schemaVersion == 1 })
        else { throw LibraryError.corrupt }
        guard library.scripts.allSatisfy({ $0.document.text.utf8.count <= TextImport.maximumBytes })
        else { throw LibraryError.tooLarge }
    }
}
