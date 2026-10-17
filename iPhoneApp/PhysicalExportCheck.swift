#if DEBUG
import AVFoundation
import CryptoKit
import Observation
import PrototypeSupport
import SwiftUI

struct PhysicalExportCheckRequest: Equatable, Identifiable {
    enum Mode: String { case prepare, reopen }
    let id: UUID
    let sourceRoot: UUID
    let sourceTake: UUID
    let mode: Mode

    init?(arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(_ prefix: String) -> String? {
            arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
        }
        guard let rawRoot = value("--p2-test-root="), let root = UUID(uuidString: rawRoot),
              let rawSource = value("--p4e-source-root="), let sourceRoot = UUID(uuidString: rawSource),
              let rawTake = value("--p4e-source-take="), let take = UUID(uuidString: rawTake),
              let rawMode = value("--p4e-device-export="), let mode = Mode(rawValue: rawMode), root != sourceRoot,
              !arguments.contains(where: { $0.hasPrefix("--p3d-physical-probe=") || $0 == "--p3d-simulate-capture" })
        else { return nil }
        id = root; self.sourceRoot = sourceRoot; sourceTake = take; self.mode = mode
    }
}

/// Explicit Debug validation only. It copies a designated prior test recording
/// between UUID test roots and uses the production editor/export/delivery code.
/// It never opens a camera, reads the ordinary take library or fabricates a save.
@MainActor @Observable final class PhysicalExportCheck: Identifiable {
    struct Report: Codable {
        var stage = "opening"
        var message = "Opening the isolated export check."
        var sourceSHA: String?
        var finalSourceSHA: String?
        var copySHA: String?
        var preset: MediaSummary?
        var custom: MediaSummary?
        var presetExportSeconds: Double?
        var customExportSeconds: Double?
        var edit: SavedTakeEdit?
        var jobID: UUID?
        var outputSHA: String?
        var filesCopyMatches: Bool?
        var receipts: [DeliveryAttempt] = []
        var checks: [String] = []
    }
    static let takeID = UUID(uuidString: "E4E00000-0000-4000-8000-000000000001")!
    let id: UUID
    let model: PrototypeModel
    var report = Report()
    private let request: PhysicalExportCheckRequest
    private var reportURL: URL?
    private var audioID: UUID?

    init(request: PhysicalExportCheckRequest, model: PrototypeModel) {
        self.request = request; self.model = model; id = request.id
    }

    func run(automaticallyPresentDestinations: Bool = true) async {
        do {
            await model.initialize()
            let storage = await model.store.root.deletingLastPathComponent()
            // This check must match the model's UUID-isolated store exactly.
            guard storage.lastPathComponent == request.id.uuidString else { throw Failure("The export check is not isolated.") }
            reportURL = storage.appendingPathComponent("P4E/result.json")
            if let reportURL, FileManager.default.fileExists(atPath: reportURL.path) {
                report = try JSONDecoder().decode(Report.self, from: Data(contentsOf: reportURL))
            }
            let source = storage.deletingLastPathComponent().appendingPathComponent(request.sourceRoot.uuidString)
                .appendingPathComponent("Takes/\(request.sourceTake.uuidString).mov")
            let before = try await Self.sha(source)
            let audio = UUID(); try await model.capture.preparePlayback(id: audio); audioID = audio
            let existing = try await model.store.load().first { $0.id == Self.takeID }
            let copy: URL
            if let existing { copy = await model.store.url(for: existing) }
            else {
                guard request.mode == .prepare else { throw Failure("No saved export check is available to reopen.") }
                publish("copying", "P4E: copying the designated test recording. No new camera capture.")
                copy = try await model.store.prepare(id: Self.takeID,
                    script: .init(id: id, revision: 1, title: "P4E export check (test recording)"))
                try await Task { @concurrent in try FileManager.default.copyItem(at: source, to: copy) }.value
                try await model.store.complete(id: Self.takeID, summary: model.media.inspect(copy), note: "Copy of a designated earlier camera test; no new capture.")
            }
            report.sourceSHA = report.sourceSHA ?? before
            report.copySHA = try await Self.sha(copy)
            guard before == report.sourceSHA, report.copySHA == before else { throw Failure("The designated source identity changed.") }
            let editor = VideoEditorModel(session: .init(id: UUID(), takeID: Self.takeID, source: copy),
                title: "P4E export check", store: model.edits, media: model.media)
            defer { editor.close() }
            await editor.load()
            guard editor.canSave else { throw Failure(editor.message ?? "The editor could not open.") }
            let saved: SavedTakeEdit
            if existing == nil {
                guard editor.duration >= 3 else { throw Failure("Use a camera test recording at least three seconds long.") }
                editor.setStart(0.5); editor.setEnd(min(editor.duration - 0.5, 8.5))
                var square = try required(editor.cropSelection()); square.select(.square); square.position(vertical: 0.7)
                editor.applyCrop(square)
                let first = try required(await editor.exportSnapshot())
                publish("preset-export", "P4E: exporting the trimmed square preset. Keep the app open.")
                let start = ProcessInfo.processInfo.systemUptime
                try await export(first, source: copy)
                report.presetExportSeconds = ProcessInfo.processInfo.systemUptime - start
                report.preset = model.mp4Exports.job?.summary
                await model.mp4Exports.leave()
                let custom = try CropSelection(sourceSize: editor.sourceSize,
                    crop: .init(x: 0.12, y: 0.14, width: 0.72, height: 0.65), preset: .custom)
                editor.applyCrop(custom)
                saved = try required(await editor.exportSnapshot())
                publish("custom-export", "P4E: exporting the saved custom crop and trim.")
                let customStart = ProcessInfo.processInfo.systemUptime
                try await export(saved, source: copy)
                report.customExportSeconds = ProcessInfo.processInfo.systemUptime - customStart
                report.checks.append("real square-preset and custom-crop exports passed production validation")
            } else {
                saved = try required(await model.edits.load(takeID: Self.takeID,
                    source: TakeEditSource(url: copy, summary: await model.media.inspect(copy))))
                guard editor.draft == saved.recipe, saved == report.edit else { throw Failure("The saved edit did not restore.") }
                await model.mp4Exports.open(edit: saved, source: copy)
                guard model.mp4Exports.phase == .ready, model.mp4Exports.job?.id == report.jobID else {
                    throw Failure("The checked MP4 did not restore without re-encoding.")
                }
                report.checks.append("saved trim/crop and the same checked job restored without encoding")
            }
            report.edit = saved; report.jobID = model.mp4Exports.job?.id
            report.custom = model.mp4Exports.job?.summary
            let output = try required(model.mp4Exports.outputURL)
            report.outputSHA = try await Self.sha(output)
            model.mp4Exports.togglePlayback()
            try await wait(seconds: 15) { self.model.mp4Exports.player.currentTime().seconds > 0.4 }
            model.mp4Exports.pausePlayback()
            report.checks.append("actual exported MP4 playback advanced beyond 0.4 seconds")
            report.finalSourceSHA = try await Self.sha(source)
            guard report.finalSourceSHA == report.sourceSHA, try await Self.sha(copy) == before else { throw Failure("An original changed during editing/export.") }
            if automaticallyPresentDestinations, existing == nil {
                for destination in DeliveryDestination.allCases {
                    publish("waiting-\(destination.rawValue)", destination == .photos
                        ? "P4E: allow adding this test video to Photos if asked."
                        : destination == .files ? "P4E: tap Save in the native Files picker (Teleprompter folder)."
                        : "P4E: choose Copy in the native Share sheet. No message is needed.")
                    let delivery = model.mp4Exports.delivery
                    if delivery.receipt(destination) == nil { delivery.start(destination) }
                    try await wait(seconds: 600) { delivery.receipt(destination)?.state == .completed && !delivery.isBusy }
                    report.receipts = delivery.receipts; persist()
                }
            }
            report.receipts = model.mp4Exports.delivery.receipts
            if automaticallyPresentDestinations {
                guard report.receipts.count == 3, report.receipts.allSatisfy({ $0.state == .completed }) else {
                    throw Failure("The three confirmed delivery receipts did not restore.")
                }
                guard model.mp4Exports.delivery.receipt(.share)?.reference == "com.apple.UIKit.activity.CopyToPasteboard" else {
                    throw Failure("Use the Copy activity for this local Share check.")
                }
                if let name = model.mp4Exports.delivery.receipt(.files)?.reference, (name as NSString).lastPathComponent == name {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: url.path) { report.filesCopyMatches = try await Self.sha(url) == report.outputSHA }
                }
                guard report.filesCopyMatches == true else { throw Failure("The Files callback completed; save in the Teleprompter folder to verify the copied bytes.") }
                report.checks.append("real Photos commit, Files copy with matching SHA-256 and system Share Copy completion")
            }
            publish(automaticallyPresentDestinations ? "passed" : "ready", "P4E export checks passed. MP4 and original are kept; camera tests remain deferred.")
        } catch {
            publish(Task.isCancelled ? "cancelled" : "stopped", "P4E check stopped: \(error.localizedDescription)")
        }
    }

    func close() async {
        await model.mp4Exports.leave()
        if let audioID { self.audioID = nil; await model.capture.finishPlayback(id: audioID) }
    }
    private func export(_ edit: SavedTakeEdit, source: URL) async throws {
        await model.mp4Exports.open(edit: edit, source: source)
        try await wait(seconds: 120) { !self.model.mp4Exports.isBusy }
        guard model.mp4Exports.phase == .ready else { throw Failure(model.mp4Exports.message ?? "The MP4 did not become ready.") }
    }
    private func wait(seconds: Double, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        while !condition() {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw Failure("Timed out waiting for the current export or destination. Existing files are kept.") }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    private func publish(_ stage: String, _ message: String) { report.stage = stage; report.message = message; persist() }
    private func persist() {
        guard let reportURL else { return }
        do {
            try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: reportURL, options: .atomic)
        } catch { report.message = "The test report could not be saved. \(error.localizedDescription)" }
    }
    @concurrent private static func sha(_ url: URL) async throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }
    private func required<T>(_ value: T?) throws -> T { guard let value else { throw Failure("A required saved edit or output is unavailable.") }; return value }
    private struct Failure: Error, LocalizedError { let errorDescription: String?; init(_ text: String) { errorDescription = text } }
}

@MainActor struct PhysicalExportCheckView: View {
    let check: PhysicalExportCheck
    @Environment(\.dismiss) private var dismiss
    @State private var previousIdlePolicy = false
    var body: some View {
        NavigationStack {
            MP4ExportView(controller: check.model.mp4Exports) { dismiss() }
                .safeAreaInset(edge: .bottom) {
                    Text(check.report.message).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(.regularMaterial).accessibilityIdentifier("p4ePhysicalCheckStatus")
                }
        }
        .interactiveDismissDisabled()
        .onAppear { previousIdlePolicy = UIApplication.shared.isIdleTimerDisabled; UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = previousIdlePolicy
            Task { await check.close() }
        }
        .task { await check.run() }
    }
}
#endif
