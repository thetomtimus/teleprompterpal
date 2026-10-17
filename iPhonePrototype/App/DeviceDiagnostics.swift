import Foundation
import PrototypeSupport
import UIKit

struct ReaderMeasurements: Codable, Sendable {
    var frameCount = 0
    var activeSeconds = 0.0
    var maximumFrameGap = 0.0
    var gapsOver50ms = 0
    var distancePoints = 0.0
    var lastStopReason: String?
    var work: [String: ReaderWorkMeasurements]?
}

struct ReaderWorkMeasurements: Codable, Sendable {
    var count = 0
    var totalSeconds = 0.0
    var maximumSeconds = 0.0
}

@MainActor final class ReaderProbe {
    private var enabled = false
    private var previousTime: Double?
    private var previousOffset: Double?
    private(set) var measurements = ReaderMeasurements()

    func begin() {
        enabled = true
        measurements = .init()
        breakSequence()
    }
    func finish() {
        enabled = false
        breakSequence()
    }
    func breakSequence() {
        previousTime = nil
        previousOffset = nil
    }
    func stopped(reason: String) {
        guard enabled else { return }
        measurements.lastStopReason = reason
        breakSequence()
    }
    func measure<T>(_ name: String, action: () -> T) -> T {
        #if DEBUG
        guard enabled else { return action() }
        let start = CACurrentMediaTime()
        defer { recordWork(name, seconds: CACurrentMediaTime() - start) }
        #endif
        return action()
    }
    func recordWork(_ name: String, seconds: Double) {
        #if DEBUG
        guard enabled else { return }
        var work = measurements.work ?? [:]
        var entry = work[name] ?? .init()
        entry.count += 1; entry.totalSeconds += seconds
        entry.maximumSeconds = max(entry.maximumSeconds, seconds)
        work[name] = entry; measurements.work = work
        #endif
    }
    func frame(time: Double, offset: Double) {
        guard enabled else { return }
        measurements.frameCount += 1
        if let previousTime {
            let gap = time - previousTime
            if gap >= 0 {
                measurements.activeSeconds += gap
                measurements.maximumFrameGap = max(measurements.maximumFrameGap, gap)
                if gap > 0.05 { measurements.gapsOver50ms += 1 }
            }
        }
        if let previousOffset { measurements.distancePoints += max(0, offset - previousOffset) }
        previousTime = time
        previousOffset = offset
    }
}

struct CaptureSnapshot: Codable, Sendable {
    var elapsed: Double
    var thermalState: Int
    var pressure: String
    var width: Int
    var height: Int
    var requestedFPS: Double
    var hdrEnabled: Bool
    var audioInputs: [String]
    var recordingRotationAngle: Double?
    var physicalOrientation: Int?
    var horizonCaptureRotationAngle: Double?
    var reader: ReaderMeasurements?
    var sessionRunning: Bool?
    var outputRecording: Bool?
    var stopRequested: Bool?
    var applicationState: Int?
    var idleTimerDisabled: Bool?
}

struct CaptureLifecycleEvent: Codable, Sendable {
    var elapsed: Double
    var name: String
    var phase: String
    var applicationState: Int?
    var idleTimerDisabled: Bool?
}

struct DeviceRunReport: Codable, Sendable {
    var id: UUID
    var camera: String
    var orientation: String
    var osVersion: String
    var started: Date
    var finished: Date?
    var outcome: String = "recording"
    var capture: [CaptureSnapshot] = []
    var reader = ReaderMeasurements()
    var media: MediaSummary?
    var exportSeconds: Double?
    var exportedMedia: MediaSummary?
    var positionEvidence: String?
    var lifecycle: [CaptureLifecycleEvent]?
}

@MainActor final class DeviceDiagnostics {
    private(set) var reports: [UUID: DeviceRunReport] = [:]
    private let storageRoot: URL?
    init(root: URL? = nil) { storageRoot = root }
    private var root: URL {
        storageRoot ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PromptPrototype/Diagnostics", isDirectory: true)
    }

    func begin(id: UUID, camera: CameraSide, orientation: CaptureOrientation) {
        reports[id] = .init(
            id: id, camera: camera.rawValue, orientation: orientation.rawValue,
            osVersion: UIDevice.current.systemVersion, started: Date())
        reports[id]?.positionEvidence =
            ProcessInfo.processInfo.arguments.contains("--p1-confirm-position=\(orientation.rawValue)")
            ? "operator-confirmed" : "selected orientation / inspect gravity samples"
        persist(id)
    }
    func sample(id: UUID, capture: CaptureSnapshot, reader: ReaderMeasurements) {
        guard var report = reports[id] else { return }
        var snapshot = capture
        snapshot.elapsed = Date().timeIntervalSince(report.started)
        snapshot.reader = reader
        snapshot.applicationState = UIApplication.shared.applicationState.rawValue
        snapshot.idleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        report.capture.append(snapshot)
        report.reader = reader
        reports[id] = report
        persist(id)
    }
    func event(id: UUID, name: String, phase: String) {
        guard var report = reports[id] else { return }
        var events = report.lifecycle ?? []
        events.append(.init(elapsed: Date().timeIntervalSince(report.started), name: name, phase: phase,
            applicationState: UIApplication.shared.applicationState.rawValue,
            idleTimerDisabled: UIApplication.shared.isIdleTimerDisabled))
        report.lifecycle = events
        reports[id] = report
        persist(id)
    }
    func finish(id: UUID, outcome: String, media: MediaSummary?, reader: ReaderMeasurements) {
        guard var report = reports[id] else { return }
        report.finished = Date()
        report.outcome = outcome
        report.media = media
        report.reader = reader
        reports[id] = report
        persist(id)
    }
    func exported(id: UUID, seconds: Double, media: MediaSummary) {
        guard var report = reports[id] else { return }
        report.exportSeconds = seconds
        report.exportedMedia = media
        reports[id] = report
        persist(id)
    }
    private func persist(_ id: UUID) {
        guard let report = reports[id] else { return }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: root.appendingPathComponent(id.uuidString + ".json"), options: .atomic)
        } catch {
            // Diagnostics never change a take's success or remove its original.
            print("P1 diagnostic write failed: \(error.localizedDescription)")
        }
    }
}
