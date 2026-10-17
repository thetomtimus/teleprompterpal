import Foundation

public protocol MP4Exporting: Sendable {
    func inspect(_ url: URL) async throws -> MediaSummary
    func export(source: URL, recipe: EditRecipe, destination: URL,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> MediaSummary
    func validateExport(_ url: URL, edit: SavedTakeEdit) async throws -> MediaSummary
}

extension MediaService: MP4Exporting {}

public struct ExportJob: Codable, Equatable, Identifiable, Sendable {
    public enum State: String, Codable, Sendable { case exporting, cancelling, cancelled, interrupted, failed, ready }
    public var schemaVersion = 1
    public let id: UUID
    public let edit: SavedTakeEdit
    public let created: Date
    public var state: State
    public var stopReason: State?
    public var summary: MediaSummary?
    public var message: String?
    public var takeID: UUID { edit.takeID }
}

public struct ExportOutputLease: Sendable {
    public let id: UUID
    public let jobID: UUID
    public let url: URL
    public let summary: MediaSummary
}

public enum ExportFailure: Error, LocalizedError, Sendable {
    case busy, invalidRecord, newerVersion, invalidOutput, missingOutput, sourceChanged
    public var errorDescription: String? {
        switch self {
        case .busy: "Another export or MP4 preview is still using this file. Close it and retry."
        case .invalidRecord: "Export details could not be read. They are preserved; your original and saved edits are safe."
        case .newerVersion: "These export details need a newer app version. Your original and saved edits are safe."
        case .invalidOutput: "The MP4 did not pass validation. Your original and saved edits are safe. Retry the export."
        case .missingOutput: "The temporary MP4 is no longer available. Export it again from your saved edit."
        case .sourceChanged: "The original changed after this edit was saved. Reopen the recording before exporting."
        }
    }
}

/// Durable intent lives separately from disposable MP4s. A single app-owned actor
/// serializes jobs; only UUID-derived files inside its output directory are removed.
public actor ExportJobStore {
    public nonisolated let root: URL
    public let outputs: URL
    private let media: any MP4Exporting
    private let capacity: @Sendable (URL) throws -> Int64
    private let write: @Sendable (Data, URL) throws -> Void
    private var active: ExportJob?
    private var leases: [UUID: UUID] = [:]

    public init(root: URL, outputs: URL, media: any MP4Exporting = MediaService(),
                capacity: @escaping @Sendable (URL) throws -> Int64 = ExportJobStore.availableCapacity) {
        self.root = root; self.outputs = outputs; self.media = media; self.capacity = capacity
        write = { try $0.write(to: $1, options: .atomic) }
    }

    init(root: URL, outputs: URL, media: any MP4Exporting,
         capacity: @escaping @Sendable (URL) throws -> Int64,
         write: @escaping @Sendable (Data, URL) throws -> Void) {
        self.root = root; self.outputs = outputs; self.media = media; self.capacity = capacity; self.write = write
    }

    public static func availableCapacity(_ url: URL) throws -> Int64 {
        try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage ?? 0
    }

    public static func requiredCapacity(for edit: SavedTakeEdit) -> Int64 {
        let seconds = edit.recipe.end.seconds - edit.recipe.start.seconds
        let geometry = try? CropSelection(sourceSize: CGSize(width: edit.source.width, height: edit.source.height),
                                          crop: edit.recipe.crop)
        let pixels = (geometry?.geometry.renderSize.width ?? 1920) * (geometry?.geometry.renderSize.height ?? 1080)
        let estimate = min(Double(Int64.max / 4), max(Double(edit.source.fileBytes), seconds * pixels * 30 * 0.16 / 8))
        return Int64(estimate) * 2 + 128 * 1024 * 1024
    }

    public func recover() throws {
        guard active == nil, leases.isEmpty else { return }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var known = Set<UUID>(), complete = true
        for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        where file.pathExtension == "json" {
            guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else { complete = false; continue }
            // Preserve individual corrupt/future records; opening that take explains the problem.
            do { if let job = try load(takeID: id) { known.insert(job.id) } }
            catch { complete = false }
        }
        // A crash can follow journal replacement but precede old-cache removal.
        // Only collect canonical app filenames when every record is understood.
        guard complete, FileManager.default.fileExists(atPath: outputs.path) else { return }
        for file in try FileManager.default.contentsOfDirectory(at: outputs, includingPropertiesForKeys: nil) {
            for suffix in [".partial.encoding.mp4", ".partial.mp4", ".mp4"] where file.lastPathComponent.hasSuffix(suffix) {
                let stem = String(file.lastPathComponent.dropLast(suffix.count))
                if let id = UUID(uuidString: stem), id.uuidString == stem, !known.contains(id) {
                    try FileManager.default.removeItem(at: file)
                }
                break
            }
        }
    }

    public func load(takeID: UUID) throws -> ExportJob? {
        guard let job = try read(takeID) else { return nil }
        guard active?.id != job.id else { return active }
        if job.state == .exporting || job.state == .cancelling {
            var recovered = job
            recovered.state = job.stopReason == .cancelled ? .cancelled : .interrupted
            recovered.summary = nil
            recovered.message = recovered.state == .cancelled ? "Export cancelled. Your original and saved edit are kept."
                : "Export was interrupted. Retry when you’re ready; your original and saved edit are kept."
            try clean(job, includeOutput: true)
            try persist(recovered)
            return recovered
        }
        if job.state == .ready, !regular(output(job)) {
            var missing = job; missing.state = .interrupted; missing.summary = nil
            missing.message = ExportFailure.missingOutput.localizedDescription
            try persist(missing); return missing
        }
        if job.state != .ready { try clean(job, includeOutput: true) }
        return job
    }

    public func prepare(id: UUID, edit: SavedTakeEdit) throws -> ExportJob {
        guard active == nil, leases.isEmpty else { throw ExportFailure.busy }
        try Task.checkCancellation()
        try edit.recipe.validate(duration: edit.source.duration.seconds)
        guard edit.revision > 0 else { throw ExportFailure.invalidRecord }
        let previous = try load(takeID: edit.takeID)
        if let previous, previous.edit == edit, previous.state == .ready { return previous }
        let job = ExportJob(id: id, edit: edit, created: Date(), state: .exporting)
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: true)
        try persist(job)
        active = job
        if let previous { try? clean(previous, includeOutput: true) }
        return job
    }

    public func run(id: UUID, source: URL,
                    progress: @escaping @Sendable (Double, Bool) async -> Void) async throws -> ExportJob {
        guard let job = active, job.id == id else { throw ExportFailure.busy }
        defer { if active?.id == id { active = nil } }
        do {
            try Task.checkCancellation()
            let sourceSummary = try await media.inspect(source)
            guard try TakeEditSource(url: source, summary: sourceSummary) == job.edit.source else {
                throw ExportFailure.sourceChanged
            }
            guard try capacity(outputs) >= Self.requiredCapacity(for: job.edit) else { throw PrototypeError.insufficientSpace }
            try checkActive(id)
            _ = try await media.export(source: source, recipe: job.edit.recipe, destination: partial(job)) { [weak self] value in
                guard let self, await self.acceptsProgress(id) else { return }
                if value.isFinite { await progress(min(0.95, max(0, value * 0.95)), false) }
            }
            try checkActive(id)
            await progress(0.96, true)
            let result = try await media.validateExport(partial(job), edit: job.edit)
            try checkActive(id)
            guard try TakeEditSource(url: source, summary: sourceSummary) == job.edit.source else {
                throw ExportFailure.sourceChanged
            }
            try FileManager.default.moveItem(at: partial(job), to: output(job))
            var ready = job; ready.state = .ready; ready.summary = result
            do { try persist(ready) }
            catch { try? FileManager.default.removeItem(at: output(job)); throw error }
            return ready
        } catch {
            var stopped = active ?? job
            stopped.state = stopped.stopReason ?? (Task.isCancelled || error is CancellationError ? .cancelled : .failed)
            stopped.summary = nil
            stopped.message = stopped.state == .interrupted ? "Export stopped when the app left the foreground. Retry when you’re ready."
                : stopped.state == .cancelled ? "Export cancelled. Your original and saved edit are kept."
                : "Export failed. \(error.localizedDescription)"
            try? clean(job, includeOutput: true)
            try persist(stopped)
            return stopped
        }
    }

    public func requestStop(id: UUID, interrupted: Bool) throws {
        guard var job = active, job.id == id else { return }
        job.state = .cancelling; job.stopReason = interrupted ? .interrupted : .cancelled
        active = job
        try persist(job)
    }

    public func acquireOutput(takeID: UUID, source: URL) async throws -> ExportOutputLease {
        guard active == nil, let job = try load(takeID: takeID), job.state == .ready else { throw ExportFailure.missingOutput }
        let token = UUID(); leases[token] = job.id
        do {
            let summary = try await media.inspect(source)
            guard try TakeEditSource(url: source, summary: summary) == job.edit.source else { throw ExportFailure.sourceChanged }
            let validated = try await media.validateExport(output(job), edit: job.edit)
            return ExportOutputLease(id: token, jobID: job.id, url: output(job), summary: validated)
        } catch { leases[token] = nil; throw error }
    }

    public func release(_ lease: ExportOutputLease) { leases[lease.id] = nil }

    public func invalidateOutput(takeID: UUID, message: String) throws -> ExportJob? {
        guard active == nil, leases.isEmpty, var job = try read(takeID) else { return nil }
        try clean(job, includeOutput: true)
        job.state = .failed; job.summary = nil; job.message = message
        try persist(job); return job
    }

    public func remove(takeID: UUID) throws {
        guard active == nil, leases.isEmpty else { throw ExportFailure.busy }
        if let job = try read(takeID) { try clean(job, includeOutput: true) }
        let file = path(takeID)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func acceptsProgress(_ id: UUID) -> Bool { active?.id == id && active?.state == .exporting }
    private func checkActive(_ id: UUID) throws {
        try Task.checkCancellation()
        guard acceptsProgress(id) else { throw CancellationError() }
    }
    private func path(_ take: UUID) -> URL { root.appendingPathComponent(take.uuidString + ".json") }
    private func output(_ job: ExportJob) -> URL { outputs.appendingPathComponent(job.id.uuidString + ".mp4") }
    private func partial(_ job: ExportJob) -> URL { outputs.appendingPathComponent(job.id.uuidString + ".partial.mp4") }
    private func regular(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType) == .typeRegular
    }
    private func clean(_ job: ExportJob, includeOutput: Bool) throws {
        guard !leases.values.contains(job.id) else { throw ExportFailure.busy }
        let files = [partial(job), partial(job).deletingPathExtension().appendingPathExtension("encoding.mp4")]
            + (includeOutput ? [output(job)] : [])
        for file in files where FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
    private func persist(_ job: ExportJob) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try write(encoder.encode(job), path(job.takeID))
    }
    private func read(_ takeID: UUID) throws -> ExportJob? {
        let file = path(takeID)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        guard regular(file), let bytes = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber,
              bytes.intValue <= 128 * 1024 else { throw ExportFailure.invalidRecord }
        let data = try Data(contentsOf: file)
        struct Version: Decodable { let schemaVersion: Int }
        guard let version = try? JSONDecoder().decode(Version.self, from: data) else { throw ExportFailure.invalidRecord }
        guard version.schemaVersion <= 1 else { throw ExportFailure.newerVersion }
        guard version.schemaVersion == 1, let job = try? JSONDecoder().decode(ExportJob.self, from: data),
              job.takeID == takeID, job.edit.schemaVersion == 1, job.edit.revision > 0,
              job.stopReason == nil || job.stopReason == .cancelled || job.stopReason == .interrupted,
              job.state != .ready || job.summary != nil else { throw ExportFailure.invalidRecord }
        try job.edit.recipe.validate(duration: job.edit.source.duration.seconds)
        return job
    }
}
