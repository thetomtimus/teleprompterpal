#if DEBUG
import Foundation
import PhoneLibrary
import PromptingCore
import PrototypeSupport
import UIKit

struct PhysicalStudioProbeRequest: Equatable {
    enum Mode: String { case short, long, pose, interruption, steady }
    let rootID: UUID
    let mode: Mode
    let camera: CameraSide
    let orientation: CaptureOrientation

    init?(arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(_ prefix: String) -> String? {
            arguments.first(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) }
        }
        guard let rawRoot = value("--p2-test-root="), let root = UUID(uuidString: rawRoot),
              let rawMode = value("--p3d-physical-probe="), let mode = Mode(rawValue: rawMode),
              let camera = CameraSide(rawValue: value("--p3d-camera=") ?? "front"),
              let orientation = CaptureOrientation(rawValue: value("--p3d-orientation=") ?? "portrait")
        else { return nil }
        rootID = root; self.mode = mode; self.camera = camera; self.orientation = orientation
    }
}

#if !targetEnvironment(simulator)
/// Opt-in physical checks in the actual studio when XCTest authentication is unavailable.
/// No synthetic controller, permission override or ordinary-library write is used.
@MainActor final class PhysicalStudioProbe {
    private let request: PhysicalStudioProbeRequest
    private let library: LibraryModel
    private let model: PrototypeModel
    private let openReader: @MainActor (UUID) -> Void
    private let closeReader: @MainActor () -> Void
    private var checks: [String] = []
    private var ids: [UUID] = []
    private var scriptID: UUID?

    init(request: PhysicalStudioProbeRequest, library: LibraryModel, model: PrototypeModel,
         openReader: @escaping @MainActor (UUID) -> Void, closeReader: @escaping @MainActor () -> Void) {
        self.request = request; self.library = library; self.model = model
        self.openReader = openReader; self.closeReader = closeReader
    }

    func run() async {
        let previousIdlePolicy = UIApplication.shared.isIdleTimerDisabled
        model.probeRunning = true
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            model.probeRunning = false
            UIApplication.shared.isIdleTimerDisabled = previousIdlePolicy
        }
        do {
            guard library.ready, model.initialized else { throw Failure("Libraries did not open") }
            let title = "P3D physical camera checks"
            let id: UUID
            if let existing = library.library.scripts.first(where: { $0.document.title == title }) {
                id = existing.id
            } else {
                let words = "Read 한국어 漢字 café 🎥 👩🏽‍💻 مرحبا שלום carefully today."
                guard let created = library.create(title: title,
                    text: Array(repeating: words, count: 1000).joined(separator: "\n")) else {
                    throw Failure("Could not stage the isolated test script")
                }
                id = created
            }
            scriptID = id
            library.setPreferences(ReaderPreferences())
            library.checkpoint(.init(), scriptID: id)
            await library.flush()
            openReader(id)
            publish("opening", "P3D: preparing the physical camera. Keep the phone unlocked.")
            try await Task.sleep(for: .seconds(2))
            model.side = request.camera; model.orientation = request.orientation
            await model.enterCamera()
            try await wait(seconds: 25) { self.model.canRecord || self.model.message != nil }
            guard model.canRecord else { throw Failure(model.message ?? "Camera unavailable") }
            if request.mode == .short {
                model.start()
                try await Task.sleep(for: .milliseconds(500))
                guard model.phase == .countdown else { throw Failure("Countdown was not available to cancel") }
                model.stop()
                try await wait(seconds: 15) { self.model.phase == .idle }
                guard model.takes.isEmpty else { throw Failure("Cancelled countdown created a take") }
                checks.append("countdown cancellation created no take")
            }

            let previous = Set(model.takes.map(\.id))
            model.start()
            try await wait(seconds: 25) { self.model.phase == .recording || self.model.phase == .idle }
            guard model.phase == .recording else { throw Failure(model.message ?? "Recording did not start") }
            publish("recording", request.mode == .long
                ? "TEN-MINUTE TEST: clap visibly at chin height now. Keep the phone steady."
                : "P3D: recording. Say a sentence; keep the camera view clear.")
            if request.mode == .interruption {
                try await Task.sleep(for: .seconds(5))
                publish("waiting-interruption", "Press Home or lock the phone now. Then unlock and return to this app.")
                try await wait(seconds: 180) { self.model.phase == .idle }
                guard !model.cameraReady, !model.playing else { throw Failure("Interruption did not require camera reentry") }
                checks.append("actual inactivity finalized capture without automatic camera or text resume")
            } else {
                let duration = request.mode == .long ? 600.0 : (request.mode == .steady ? 60.0 : 15.0)
                var changed = false, finalClap = false
                try await wait(seconds: duration + 50) {
                    let elapsed = Date().timeIntervalSince(self.model.startedAt ?? Date())
                    if !changed, elapsed >= 5 {
                        changed = true
                        var preferences = self.library.library.preferences
                        preferences.fontSize = 34; preferences.speed = 40
                        preferences.alignment = .right; preferences.readingBand = true
                        preferences.panelHeight = 0.6; preferences.panelPosition = 0.3
                        self.library.setPreferences(preferences)
                        self.model.fontSize = preferences.fontSize; self.model.speed = preferences.speed
                        self.checks.append("live font, pace, alignment, reading band and panel preferences applied")
                    }
                    if self.request.mode == .long, !finalClap, elapsed >= 585 {
                        finalClap = true
                        self.publish("final-clap", "FINAL CLAP: both hands at chin height in the preview now. Stops automatically soon.")
                    }
                    if self.request.mode != .long, elapsed >= duration, self.model.phase == .recording {
                        self.model.stop()
                    }
                    if self.model.phase == .recording, elapsed >= 7, !self.model.playing {
                        throw Failure("The physical reader paused before the expected end")
                    }
                    return self.model.phase == .idle
                }
            }
            guard let take = model.takes.first(where: { !previous.contains($0.id) && $0.isPlayable }),
                  let summary = take.summary else { throw Failure(model.message ?? "No playable original was published") }
            ids.append(take.id)
            let expected = request.orientation == .portrait ? (1080, 1920) : (1920, 1080)
            guard summary.width == expected.0, summary.height == expected.1 else {
                throw Failure("Original dimensions do not match the selected orientation")
            }
            guard model.readerProbe.measurements.activeSeconds >= summary.duration * 0.9 else {
                throw Failure("Reader active time is below 90% of the recorded duration")
            }
            if request.mode == .long, summary.duration < 595 { throw Failure("Sustained recording ended early") }
            checks.append("playable original dimensions and reader continuity validated on device")
            publish("saved", "P3D: original saved. Checking playback and camera reentry.")
            try await wait(seconds: 180) { UIApplication.shared.applicationState == .active }
            guard !model.playing else { throw Failure("Text resumed after finalization") }
            closeReader()
            try await Task.sleep(for: .seconds(1))
            await model.openTake(take)
            guard model.selected?.id == take.id, let player = model.player else {
                throw Failure(model.libraryMessage ?? "Original playback did not open")
            }
            player.play()
            try await Task.sleep(for: .seconds(2))
            guard player.currentTime().seconds > 0 else { throw Failure("Original playback did not advance") }
            checks.append("native original player advanced")
            publish("review", "Review the original for upright framing; front video should be unmirrored.")
            try await Task.sleep(for: .seconds(request.mode == .pose ? 15 : 3))
            model.stopPlayback(takeID: take.id)
            await model.playbackReleaseTask?.value
            try await Task.sleep(for: .seconds(1))
            openReader(id)
            try await Task.sleep(for: .seconds(1))
            await model.enterCamera()
            guard model.canRecord, !model.playing else { throw Failure(model.message ?? "Camera reentry failed") }
            checks.append("explicit camera reentry succeeded without starting text or recording")
            await library.flush()
            publish("complete", "P3D \(request.mode.rawValue) COMPLETE. Original retained; no recording active.")
            // Keep the explicit test screen awake while the host collects its report.
            try await Task.sleep(for: .seconds(180))
        } catch {
            model.stop()
            publish("failed", "P3D test stopped: \(error.localizedDescription)", error: error.localizedDescription)
        }
    }

    private func wait(seconds: Double, until condition: () async throws -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while try await !condition() {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw Failure("Timed out at \(model.probeStatus ?? "camera check")") }
            if UIApplication.shared.applicationState == .active, !UIApplication.shared.isIdleTimerDisabled {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            try await Task.sleep(for: .milliseconds(250))
        }
    }

    private func publish(_ stage: String, _ status: String, error: String? = nil) {
        model.probeStatus = status
        let report = Result(rootID: request.rootID, mode: request.mode.rawValue,
            camera: request.camera.rawValue, orientation: request.orientation.rawValue,
            stage: stage, takeIDs: ids, checks: checks, scriptID: scriptID,
            applicationState: UIApplication.shared.applicationState.rawValue,
            idleTimerDisabled: UIApplication.shared.isIdleTimerDisabled, error: error, updated: Date())
        do {
            let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PhoneCaptureTests/\(request.rootID.uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: root.appendingPathComponent("p3d-physical.json"), options: .atomic)
        } catch { print("P3D diagnostic publication failed: \(error.localizedDescription)") }
    }

    private struct Result: Codable {
        let rootID: UUID
        let mode: String
        let camera: String
        let orientation: String
        let stage: String
        let takeIDs: [UUID]
        let checks: [String]
        let scriptID: UUID?
        let applicationState: Int
        let idleTimerDisabled: Bool
        let error: String?
        let updated: Date
    }
    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
#endif
#endif
