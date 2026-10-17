import Foundation
import Photos
import Synchronization

enum AddPhotoAuthorization: Equatable, Sendable { case notDetermined, allowed, denied }
protocol PhotoLibrarySaving: Sendable {
    func authorization() async -> AddPhotoAuthorization
    func requestAddOnly() async -> AddPhotoAuthorization
    func saveVideo(at url: URL) async throws -> String
}

struct SystemPhotoLibrarySaver: PhotoLibrarySaving {
    static func configured(root: URL) -> any PhotoLibrarySaving {
        #if DEBUG && targetEnvironment(simulator)
        if SimulatorIntegrationFixture.accepts("--p4d-delivery-probe=photo-pending") {
            return SimulatorPendingPhotoSaver(marker: root.appendingPathComponent(".p4d-photo-probe-used"))
        }
        #endif
        return Self()
    }
    func authorization() async -> AddPhotoAuthorization { Self.convert(PHPhotoLibrary.authorizationStatus(for: .addOnly)) }
    func requestAddOnly() async -> AddPhotoAuthorization { Self.convert(await PHPhotoLibrary.requestAuthorization(for: .addOnly)) }
    func saveVideo(at url: URL) async throws -> String {
        let identifier = PhotoIdentifier()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            // Photos copies the file; it must not move the leased export.
            request.addResource(with: .video, fileURL: url, options: nil)
            identifier.value.withLock { $0 = request.placeholderForCreatedAsset?.localIdentifier }
        }
        guard let result = identifier.value.withLock({ $0 }) else { throw ExportPhotoFailure.missingConfirmation }
        return result
    }
    private static func convert(_ status: PHAuthorizationStatus) -> AddPhotoAuthorization {
        switch status { case .notDetermined: .notDetermined; case .authorized, .limited: .allowed; default: .denied }
    }
}
private final class PhotoIdentifier: Sendable { let value = Mutex<String?>(nil) }
enum ExportPhotoFailure: Error, LocalizedError {
    case missingConfirmation
    var errorDescription: String? { "Photos did not return a save confirmation. Check Photos before trying again." }
}

#if DEBUG && targetEnvironment(simulator)
/// Only an explicit UUID-scoped native test holds the first save before Photos.
private actor SimulatorPendingPhotoSaver: PhotoLibrarySaving {
    let marker: URL
    let system = SystemPhotoLibrarySaver()
    init(marker: URL) { self.marker = marker }
    func authorization() async -> AddPhotoAuthorization { await system.authorization() }
    func requestAddOnly() async -> AddPhotoAuthorization { await system.requestAddOnly() }
    func saveVideo(at url: URL) async throws -> String {
        if !FileManager.default.fileExists(atPath: marker.path) {
            try Data("used".utf8).write(to: marker, options: .atomic)
            try await Task.sleep(for: .seconds(30))
        }
        return try await system.saveVideo(at: url)
    }
}
#endif
