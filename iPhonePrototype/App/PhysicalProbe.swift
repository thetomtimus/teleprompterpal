import Foundation
import PrototypeSupport
import UIKit

/// Debug-only opt-in runner for a paired device when XCTest UI authentication is unavailable.
/// It uses the same model actions as the interface and never grants system permissions.
extension PrototypeModel {
    func runPhysicalProbeIfRequested() async {
        #if DEBUG && !targetEnvironment(simulator)
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p1-probe=") }),
            let mode = PhysicalProbeMode(rawValue: String(argument.dropFirst("--p1-probe=".count)))
        else { return }
        probeRunning = true
        defer { probeRunning = false }
        var ids: [UUID] = []
        do {
            guard initialized else { throw PhysicalProbeError.failed(message ?? "Take journal unavailable") }
            if mode == .standby {
                probeStatus = "Physical camera tests ready. Waiting for the next check; no recording."
                persistProbe(mode: mode, stage: "waiting", ids: [])
                try await Task.sleep(for: .seconds(300))
                probeStatus = "Physical test standby finished."
                persistProbe(mode: mode, stage: "complete", ids: [])
                return
            }
            if mode == .matrix {
                if ProcessInfo.processInfo.arguments.contains("--p1-resume-matrix") {
                    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("PromptPrototype/probe-matrix.json")
                    let previous = try JSONDecoder().decode(PhysicalProbeResult.self, from: Data(contentsOf: root))
                    guard previous.mode == "matrix", previous.takeIDs.count < 6,
                        previous.takeIDs.allSatisfy({ id in takes.contains { $0.id == id && $0.state == .ready } })
                    else { throw PhysicalProbeError.failed("Previous matrix cannot be resumed") }
                    ids = previous.takeIDs
                }
                var positionIndex = 0
                for camera in CameraSide.allCases {
                    for angle in CaptureOrientation.allCases {
                        if positionIndex < ids.count {
                            positionIndex += 1
                            continue
                        }
                        if side != camera || !cameraReady {
                            side = camera
                            await enterCamera()
                            guard canRecord else { throw PhysicalProbeError.failed(message ?? "Camera unavailable") }
                        }
                        probeStatus =
                            "NEXT: \(camera.rawValue) camera. \(angle.holdInstruction). Recording starts automatically when positioned."
                        try await probeWait(
                            seconds: 180,
                            failure: "Phone rotation timed out: \(angle.holdInstruction). Saved takes are kept."
                        ) {
                            if ProcessInfo.processInfo.arguments.contains("--p1-confirm-position=\(angle.rawValue)") {
                                self.persistProbe(
                                    mode: mode, stage: "operator confirmed \(camera.rawValue) / \(angle.rawValue)",
                                    ids: ids)
                                return true
                            }
                            if #available(iOS 27, *) {
                                guard let position = await self.capture.position(for: angle) else { return false }
                                self.persistProbe(
                                    mode: mode,
                                    stage:
                                        "waiting \(camera.rawValue) / \(angle.rawValue): gravity \(Int(position.actual)), target \(Int(position.expected))",
                                    ids: ids)
                                return position.matches
                            }
                            return angle.matchesPhysicalOrientation
                        }
                        try await Task.sleep(for: .seconds(3))
                        let take = try await probeTake(camera: camera, angle: angle, seconds: 5, automaticStop: false)
                        ids.append(take.id)
                        positionIndex += 1
                        persistProbe(mode: mode, stage: "captured", ids: ids)
                    }
                }
            } else {
                var camera = CameraSide.front
                var angle = CaptureOrientation.portrait
                if mode == .short {
                    if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p1-camera=") }) {
                        guard let value = CameraSide(rawValue: String(argument.dropFirst("--p1-camera=".count))) else {
                            throw PhysicalProbeError.failed("Unknown camera test selection")
                        }
                        camera = value
                    }
                    if let argument = ProcessInfo.processInfo.arguments.first(where: {
                        $0.hasPrefix("--p1-orientation=")
                    }) {
                        guard
                            let value = CaptureOrientation(
                                rawValue: String(argument.dropFirst("--p1-orientation=".count)))
                        else {
                            throw PhysicalProbeError.failed("Unknown camera orientation selection")
                        }
                        angle = value
                    }
                }
                let take = try await probeTake(
                    camera: camera, angle: angle, seconds: mode == .long ? 600 : (mode == .termination ? 120 : 15),
                    automaticStop: mode == .long)
                ids.append(take.id)
            }
            guard let id = ids.last, let take = takes.first(where: { $0.id == id }), let summary = take.summary else {
                throw PhysicalProbeError.failed("No validated camera take")
            }
            probeStatus = "P1 \(mode.rawValue): exporting trimmed square MP4"
            persistProbe(mode: mode, stage: "exporting", ids: ids)
            await select(take)
            editStart = summary.duration * 0.1
            cropRatio = "1:1"
            updatePreview()
            export()
            try await probeWait(seconds: 300) { !self.exporting }
            guard exportedURL != nil else { throw PhysicalProbeError.failed(message ?? "Export failed") }
            selected = nil
            probeStatus = "P1 \(mode.rawValue) complete: \(ids.count) camera take(s), trimmed MP4 ready"
            persistProbe(mode: mode, stage: "complete", ids: ids)
        } catch {
            stop()
            probeStatus = "P1 \(mode.rawValue) stopped: \(error.localizedDescription)"
            persistProbe(mode: mode, stage: "failed", ids: ids, error: error.localizedDescription)
        }
        #endif
    }

    #if DEBUG && !targetEnvironment(simulator)
    private func probeTake(camera: CameraSide, angle: CaptureOrientation, seconds: Double, automaticStop: Bool)
        async
        throws -> PrototypeTake
    {
        side = camera
        orientation = angle
        restart += 1
        probeStatus = "P1: \(camera.rawValue) / \(angle.rawValue), allow permissions if requested"
        await enterCamera()
        guard canRecord else { throw PhysicalProbeError.failed(message ?? "Camera unavailable") }
        let previous = Set(takes.map(\.id))
        start()
        try await probeWait(seconds: 20) { self.phase == .recording || self.phase == .idle }
        guard phase == .recording else { throw PhysicalProbeError.failed(message ?? "Recording did not start") }
        probeStatus = "P1: recording \(camera.rawValue) / \(angle.rawValue) for \(Int(seconds)) seconds"
        if automaticStop {
            probeStatus =
                "Recording ten minutes. Clap both hands at chin height, in the middle of the camera view, now. Keep the phone still afterward."
            var requestedFinalClap = false
            try await probeWait(seconds: seconds + 50) {
                if !requestedFinalClap, let start = self.startedAt, Date().timeIntervalSince(start) >= seconds - 15 {
                    requestedFinalClap = true
                    self.probeStatus =
                        "FINAL SYNC MARK: clap both hands at chin height in the camera view now. Recording stops automatically in 15 seconds."
                }
                return self.phase == .idle
            }
        } else {
            try await Task.sleep(for: .seconds(seconds))
            guard phase == .recording else { throw PhysicalProbeError.failed(message ?? "Capture interrupted") }
            stop()
            try await probeWait(seconds: 45) { self.phase == .idle }
        }
        guard let take = takes.first(where: { !previous.contains($0.id) && $0.state == .ready }) else {
            throw PhysicalProbeError.failed(message ?? "Camera file did not validate")
        }
        guard let summary = take.summary,
            readerProbe.measurements.activeSeconds >= summary.duration * 0.9
        else { throw PhysicalProbeError.failed("Prompt did not scroll continuously during this camera test") }
        let expected = angle == .portrait ? (1080, 1920) : (1920, 1080)
        guard summary.width == expected.0, summary.height == expected.1 else {
            throw PhysicalProbeError.failed("Output dimensions do not match the selected capture orientation")
        }
        return take
    }

    private func probeWait(
        seconds: Double, failure: String = "Timed out waiting for camera/export", until condition: () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while !(await condition()) {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else {
                throw PhysicalProbeError.failed(failure)
            }
            try await Task.sleep(for: .milliseconds(200))
        }
    }

    private func persistProbe(mode: PhysicalProbeMode, stage: String, ids: [UUID], error: String? = nil) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PromptPrototype", isDirectory: true)
        do {
            let report = PhysicalProbeResult(
                mode: mode.rawValue, stage: stage, takeIDs: ids, error: error, updated: Date())
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(
                to: root.appendingPathComponent("probe-\(mode.rawValue).json"), options: .atomic)
        } catch { print("P1 probe report could not be written: \(error.localizedDescription)") }
    }
    #endif
}

extension CaptureOrientation {
    fileprivate var holdInstruction: String {
        switch self {
        case .portrait: "hold upright, charging port at the bottom"
        case .landscapeLeft: "hold sideways, charging port on the left"
        case .landscapeRight: "hold sideways, charging port on the right"
        }
    }

    @MainActor fileprivate var matchesPhysicalOrientation: Bool {
        switch self {
        case .portrait: UIDevice.current.orientation == .portrait
        case .landscapeLeft: UIDevice.current.orientation == .landscapeRight
        case .landscapeRight: UIDevice.current.orientation == .landscapeLeft
        }
    }
}

private enum PhysicalProbeMode: String { case short, matrix, long, termination, standby }
private struct PhysicalProbeResult: Codable {
    let mode: String
    let stage: String
    let takeIDs: [UUID]
    let error: String?
    let updated: Date
}
private enum PhysicalProbeError: LocalizedError {
    case failed(String)
    var errorDescription: String? { if case .failed(let detail) = self { detail } else { nil } }
}
