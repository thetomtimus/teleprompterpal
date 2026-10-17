import Foundation

public enum DeliveryDestination: String, Codable, CaseIterable, Identifiable, Sendable {
    case photos, files, share
    public var id: String { rawValue }
    public var title: String { switch self { case .photos: "Photos"; case .files: "Files"; case .share: "Share" } }
}

public struct DeliveryAttempt: Codable, Equatable, Identifiable, Sendable {
    public enum State: String, Codable, Sendable { case pending, completed, cancelled, failed, unknown }
    public let id: UUID
    public let exportID: UUID
    public let takeID: UUID
    public let destination: DeliveryDestination
    public let created: Date
    public var state: State
    public var message: String
    public var reference: String?
}

public enum DeliveryFailure: Error, LocalizedError, Sendable {
    case busy, invalidRecord, newerVersion, uncertain, alreadySaved
    public var errorDescription: String? {
        switch self {
        case .busy: "A save or share is still in progress. Wait for it to finish."
        case .invalidRecord: "Delivery details could not be read. They are preserved. Check the destination before saving another copy."
        case .newerVersion: "Delivery details need a newer app version. Check the destination before saving another copy."
        case .uncertain: "The previous delivery may have finished. Check the destination before trying again."
        case .alreadySaved: "This MP4 has already been saved to Photos."
        }
    }
}

/// A result is separate from MP4 readiness. Pending work is never replayed on launch.
public actor DeliveryStore {
    private struct Journal: Codable {
        var schemaVersion = 1
        let edit: SavedTakeEdit
        var attempts: [DeliveryAttempt]
    }
    public let root: URL
    private var active: DeliveryAttempt?
    private var activeEdit: SavedTakeEdit?
    private let write: @Sendable (Data, URL) throws -> Void

    public init(root: URL) {
        self.root = root; write = { try $0.write(to: $1, options: .atomic) }
    }
    init(root: URL, write: @escaping @Sendable (Data, URL) throws -> Void) {
        self.root = root; self.write = write
    }

    public func load(edit: SavedTakeEdit) throws -> [DeliveryAttempt] {
        guard var journal = try read(takeID: edit.takeID, revision: edit.revision) else { return [] }
        guard journal.edit == edit else { throw DeliveryFailure.invalidRecord }
        var changed = false
        for index in journal.attempts.indices where journal.attempts[index].state == .pending && journal.attempts[index].id != active?.id {
            journal.attempts[index].state = .unknown
            journal.attempts[index].message = "The previous \(journal.attempts[index].destination.title) result is unknown. Check the destination before trying again."
            changed = true
        }
        if changed { try persist(journal) }
        return journal.attempts
    }

    public func begin(exportID: UUID, edit: SavedTakeEdit, destination: DeliveryDestination,
                      confirmingUnknown: Bool = false) throws -> DeliveryAttempt {
        guard active == nil else { throw DeliveryFailure.busy }
        var attempts = try load(edit: edit)
        if let previous = attempts.first(where: { $0.destination == destination }) {
            if previous.state == .unknown, !confirmingUnknown { throw DeliveryFailure.uncertain }
            if destination == .photos, previous.state == .completed, !confirmingUnknown { throw DeliveryFailure.alreadySaved }
        }
        let attempt = DeliveryAttempt(id: UUID(), exportID: exportID, takeID: edit.takeID, destination: destination,
            created: Date(), state: .pending, message: destination == .photos ? "Saving to Photos…" : "Waiting for \(destination.title)…")
        attempts.removeAll { $0.destination == destination }; attempts.append(attempt)
        try persist(Journal(edit: edit, attempts: attempts))
        active = attempt; activeEdit = edit
        return attempt
    }

    public func finish(id: UUID, state: DeliveryAttempt.State, message: String, reference: String? = nil) throws -> DeliveryAttempt? {
        guard var attempt = active, let activeEdit, attempt.id == id, state != .pending else { return nil }
        defer { active = nil; self.activeEdit = nil }
        guard var journal = try read(takeID: activeEdit.takeID, revision: activeEdit.revision), journal.edit == activeEdit,
              let index = journal.attempts.firstIndex(where: { $0.id == id }) else { throw DeliveryFailure.invalidRecord }
        attempt.state = state; attempt.message = message; attempt.reference = reference
        journal.attempts[index] = attempt
        try persist(journal)
        return attempt
    }

    public func remove(takeID: UUID) throws {
        guard active == nil else { throw DeliveryFailure.busy }
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where file.pathExtension == "json" {
            let parts = file.deletingPathExtension().lastPathComponent.split(separator: ".")
            guard parts.count == 2, let id = UUID(uuidString: String(parts[0])), id == takeID,
                  let revision = UInt64(parts[1]),
                  let journal = try? read(takeID: id, revision: revision), journal.edit.takeID == takeID else { continue }
            try FileManager.default.removeItem(at: file)
        }
    }

    private func path(takeID: UUID, revision: UInt64) -> URL { root.appendingPathComponent("\(takeID.uuidString).\(revision).json") }
    private func persist(_ journal: Journal) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try write(encoder.encode(journal), path(takeID: journal.edit.takeID, revision: journal.edit.revision))
    }
    private func read(takeID: UUID, revision: UInt64) throws -> Journal? {
        let file = path(takeID: takeID, revision: revision)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.intValue <= 64 * 1024 else { throw DeliveryFailure.invalidRecord }
        let data = try Data(contentsOf: file)
        struct Version: Decodable { let schemaVersion: Int }
        guard let version = try? JSONDecoder().decode(Version.self, from: data) else { throw DeliveryFailure.invalidRecord }
        guard version.schemaVersion <= 1 else { throw DeliveryFailure.newerVersion }
        guard version.schemaVersion == 1, let journal = try? JSONDecoder().decode(Journal.self, from: data),
              journal.edit.schemaVersion == 1, journal.edit.takeID == takeID, journal.edit.revision == revision, revision > 0,
              journal.attempts.count <= 3,
              Set(journal.attempts.map(\.destination)).count == journal.attempts.count,
              Set(journal.attempts.map(\.id)).count == journal.attempts.count,
              journal.attempts.allSatisfy({ $0.takeID == takeID && $0.message.utf8.count <= 8192 })
        else { throw DeliveryFailure.invalidRecord }
        try journal.edit.recipe.validate(duration: journal.edit.source.duration.seconds)
        return journal
    }
}
