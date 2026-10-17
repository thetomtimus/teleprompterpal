import Foundation

/// Closed categorical schema: callers cannot pass content, paths, receipts or arbitrary properties.
public enum LocalEventPayload: Codable, Equatable, Sendable {
    public enum ScriptOrigin: String, Codable, Sendable { case createOrPaste, imported, duplicated }
    public enum Length: String, Codable, Sendable {
        case short, medium, long
        public static func characters(_ count: Int) -> Self { count < 500 ? .short : count < 5000 ? .medium : .long }
    }
    public enum DurationBucket: String, Codable, Sendable {
        case unknown, underMinute, oneToFiveMinutes, fiveToTenMinutes, overTenMinutes
        public static func seconds(_ value: Double?) -> Self {
            guard let value, value.isFinite, value >= 0 else { return .unknown }
            return value < 60 ? .underMinute : value < 300 ? .oneToFiveMinutes : value <= 600 ? .fiveToTenMinutes : .overTenMinutes
        }
    }
    public enum Camera: String, Codable, Sendable { case front, rear }
    public enum Orientation: String, Codable, Sendable { case portrait, landscapeLeft, landscapeRight }
    public enum Access: String, Codable, Sendable { case unconfigured, inactive, verified, grace, unknown }
    public enum RecordingOutcome: String, Codable, Sendable {
        case valid, interruptedValid, invalidMedia, journalFailure, startFailed, cancelledBeforeStart, recoveredValid, recoveryFailed
    }
    public enum RecordingFormat: String, Codable, Sendable {
        case hd1080p30, other, unknown
        public static func media(_ summary: MediaSummary) -> Self {
            max(summary.width, summary.height) == 1920 && min(summary.width, summary.height) == 1080
                && abs(summary.nominalFrameRate - 30) < 0.1 ? .hd1080p30 : .other
        }
    }
    public enum ExportStage: String, Codable, Sendable { case file, photos, files, share }
    public enum ExportOutcome: String, Codable, Sendable { case ready, completed, cancelled, interrupted, failed, unknown }
    public enum Ratio: String, Codable, Sendable { case original, portrait, landscape, square, fourByFive, custom }
    public enum Plan: String, Codable, Sendable { case monthly, annual, other, unspecified }
    public enum Trial: String, Codable, Sendable { case verifiedFreeTrial, noFreeTrial, notEstablished }
    public enum BillingEnvironment: String, Codable, Sendable { case xcode, sandbox, production, unknown }
    public enum PurchaseAction: String, Codable, Sendable { case purchase, restore }
    public enum PurchaseOutcome: String, Codable, Sendable { case verified, pending, cancelled, unverified, failed, unavailable, restored, none }
    public enum Catalog: String, Codable, Sendable { case available, unavailable, unconfigured }
    public struct Offer: Codable, Equatable, Sendable {
        public let plan: Plan
        public let eligibleTrial: Bool
        public init(plan: Plan, eligibleTrial: Bool) { self.plan = plan; self.eligibleTrial = eligibleTrial }
    }

    case scriptReady(origin: ScriptOrigin, length: Length)
    case recordingStarted(camera: Camera, orientation: Orientation, access: Access)
    case recordingFinished(outcome: RecordingOutcome, duration: DurationBucket, format: RecordingFormat = .unknown)
    case exportResult(stage: ExportStage, outcome: ExportOutcome, trimmed: Bool, cropped: Bool, ratio: Ratio)
    case paywallViewed(catalog: Catalog, offers: [Offer])
    case purchaseResult(action: PurchaseAction, outcome: PurchaseOutcome, plan: Plan, trial: Trial, store: BillingEnvironment)

    public var name: String {
        switch self {
        case .scriptReady: "script_ready"
        case .recordingStarted: "recording_started"
        case .recordingFinished: "recording_finished"
        case .exportResult: "export_result"
        case .paywallViewed: "paywall_viewed"
        case .purchaseResult: "purchase_result"
        }
    }
    fileprivate var stage: String {
        switch self {
        case .exportResult(let stage, _, _, _, _): stage.rawValue
        case .purchaseResult(_, .pending, _, _, _): "pending"
        case .recordingFinished(.recoveredValid, _, _), .recordingFinished(.recoveryFailed, _, _): "recovery"
        default: "terminal"
        }
    }
    fileprivate var bounded: Bool {
        if case .paywallViewed(_, let offers) = self { return offers.count <= 16 }
        return true
    }
}

public struct LocalEvent: Codable, Equatable, Sendable {
    public enum Runtime: String, Codable, Sendable { case simulator, deviceLocal }
    public let operationID: UUID
    public let at: Date
    public let runtime: Runtime
    public let payload: LocalEventPayload
    public init(operationID: UUID, at: Date = Date(), runtime: Runtime, payload: LocalEventPayload) {
        self.operationID = operationID; self.at = at; self.runtime = runtime; self.payload = payload
    }
    fileprivate var key: String { "\(operationID)/\(payload.name)/\(payload.stage)" }
}

/// Best-effort diagnostics only. No network or installation identity. Dedupe lasts for
/// the retained window: at most 500 events / 30 days / 512 KiB, including across relaunch.
/// Unreadable or future journals are preserved and disable writes for that process.
public actor LocalEventJournal {
    private struct File: Codable { var schemaVersion = 1; var events: [LocalEvent] }
    public enum Status: Sendable, Equatable { case healthy, unavailable }
    public static let maximumEvents = 500
    public static let maximumBytes = 512 * 1024
    public let root: URL
    private var loaded = false
    private var events: [LocalEvent] = []
    public private(set) var status: Status = .healthy

    public init(root: URL) { self.root = root }

    public func append(_ event: LocalEvent, now: Date = Date()) {
        load()
        guard status == .healthy, event.payload.bounded, event.at.timeIntervalSince1970.isFinite,
              event.at <= now.addingTimeInterval(60), event.at >= now.addingTimeInterval(-30 * 86400) else { return }
        events.removeAll { $0.at < now.addingTimeInterval(-30 * 86400) }
        guard !events.contains(where: { $0.key == event.key }) else { return }
        var next = events
        next.append(event)
        next = Array(next.suffix(Self.maximumEvents))
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(File(events: next))
            guard data.count <= Self.maximumBytes else { status = .unavailable; return }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var location = root
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try location.setResourceValues(values)
            try data.write(to: root.appendingPathComponent("events.json"), options: .atomic)
            events = next
        } catch { status = .unavailable }
    }

    public func snapshot() -> [LocalEvent] { load(); return events }

    private func load() {
        guard !loaded else { return }; loaded = true
        let file = root.appendingPathComponent("events.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue <= Self.maximumBytes else { status = .unavailable; return }
            let saved = try JSONDecoder().decode(File.self, from: Data(contentsOf: file))
            guard saved.schemaVersion == 1, saved.events.count <= Self.maximumEvents,
                  saved.events.allSatisfy({ $0.payload.bounded && $0.at.timeIntervalSince1970.isFinite }),
                  Set(saved.events.map(\.key)).count == saved.events.count else { status = .unavailable; return }
            events = saved.events
        } catch { status = .unavailable }
    }
}
