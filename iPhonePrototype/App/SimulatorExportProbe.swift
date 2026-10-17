#if DEBUG && targetEnvironment(simulator)
import Foundation
import PrototypeSupport

/// Explicit UUID-isolated UI-test gate. The actual encoder and validator run
/// after the gate; production export never adds artificial delay or progress.
actor SimulatorExportProbe: MP4Exporting {
    private let media = MediaService()
    func inspect(_ url: URL) async throws -> MediaSummary { try await media.inspect(url) }
    func validateExport(_ url: URL, edit: SavedTakeEdit) async throws -> MediaSummary { try await media.validateExport(url, edit: edit) }
    func export(source: URL, recipe: EditRecipe, destination: URL,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> MediaSummary {
        await progress(0.08)
        try await Task.sleep(for: .seconds(4))
        await progress(0.16)
        try await Task.sleep(for: .seconds(4))
        return try await media.export(source: source, recipe: recipe, destination: destination, progress: progress)
    }
}
#endif
