import Foundation
import PrototypeSupport

/// Not observable: logging cannot invalidate the reader or poll on a scrolling tick.
/// A bounded queue moves atomic journal work off the main actor and never blocks capture.
@MainActor final class LocalEventRecorder {
    let journal: LocalEventJournal
    private var pending: [LocalEvent] = []
    private var worker: Task<Void, Never>?
    init(root: URL) { journal = LocalEventJournal(root: root) }

    func emit(_ payload: LocalEventPayload, operationID: UUID) {
        #if targetEnvironment(simulator)
        let runtime = LocalEvent.Runtime.simulator
        #else
        let runtime = LocalEvent.Runtime.deviceLocal
        #endif
        guard pending.count < 64 else { return }
        pending.append(.init(operationID: operationID, runtime: runtime, payload: payload))
        guard worker == nil else { return }
        worker = Task { [self] in
            while !pending.isEmpty {
                let event = pending.removeFirst()
                await journal.append(event)
            }
            worker = nil
        }
    }
    func flush() async { await worker?.value }

    static func configured() -> LocalEventRecorder {
        var root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalEvents", isDirectory: true)
        #if DEBUG
        if let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--p2-test-root=") }),
           let id = UUID(uuidString: String(flag.dropFirst("--p2-test-root=".count))) {
            root = root.appendingPathComponent("UITests/\(id.uuidString)", isDirectory: true)
        }
        #endif
        return .init(root: root)
    }
}

extension LocalEventPayload {
    static func export(stage: ExportStage, outcome: ExportOutcome, edit: SavedTakeEdit) -> Self {
        let crop = edit.recipe.crop
        let cropped = crop != NormalizedCrop()
        let value = crop.width * Double(edit.source.width) / (crop.height * Double(edit.source.height))
        let ratio: Ratio = !cropped ? .original : abs(value - 1) < 0.01 ? .square
            : abs(value - 9.0 / 16) < 0.01 ? .portrait : abs(value - 16.0 / 9) < 0.01 ? .landscape
            : abs(value - 4.0 / 5) < 0.01 ? .fourByFive : .custom
        return .exportResult(stage: stage, outcome: outcome,
            trimmed: edit.recipe.start.seconds > 0 || edit.recipe.end.seconds < edit.source.duration.seconds,
            cropped: cropped, ratio: ratio)
    }
}
