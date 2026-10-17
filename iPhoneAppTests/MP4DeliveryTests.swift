import Foundation
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

// Each test owns its files. Serial execution limits the shared Simulator encoder.
@Suite(.serialized) struct MP4DeliveryTests {
    @Test @MainActor func photosWaitsForCommitDeduplicatesTapsAndKeepsTheExportLeased() async throws {
        let fixture = try await DeliveryFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let photos = ControlledPhotoSaver(held: true)
        let controller = fixture.controller(photos: photos)
        await controller.open(job: fixture.job, source: fixture.source)
        #expect(await photos.authorizationCalls == 0)
        controller.start(.photos); controller.start(.photos)
        try await waitForDelivery { controller.receipt(.photos)?.state == .pending }
        #expect(controller.isBusy && !controller.photosSaved)
        await #expect(throws: ExportFailure.self) { try await fixture.exports.remove(takeID: fixture.job.takeID) }
        await photos.release()
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.photosSaved && controller.receipt(.photos)?.reference == "synthetic-photo")
        controller.start(.photos)
        #expect(await photos.saveCalls == 1)
        #expect(try Data(contentsOf: fixture.source) == fixture.original)
        #expect(try await fixture.exports.load(takeID: fixture.job.takeID)?.id == fixture.job.id)
        _ = try await fixture.exports.invalidateOutput(takeID: fixture.job.takeID, message: "Synthetic cache eviction")
        let prepared = try await fixture.exports.prepare(id: UUID(), edit: fixture.job.edit)
        let recreated = try await fixture.exports.run(id: prepared.id, source: fixture.source) { _, _ in }
        await controller.open(job: recreated, source: fixture.source)
        #expect(recreated.id != fixture.job.id && controller.photosSaved)
        controller.start(.photos)
        #expect(await photos.saveCalls == 1)
        controller.start(.photos, confirmingUnknown: true)
        try await waitForDelivery { !controller.isBusy }
        #expect(await photos.saveCalls == 2)
        try await fixture.exports.remove(takeID: fixture.job.takeID)
    }

    @Test @MainActor func filesAndShareWaitForRealCallbacksAndIgnoreOldOnes() async throws {
        let fixture = try await DeliveryFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let controller = fixture.controller(photos: ControlledPhotoSaver())
        await controller.open(job: fixture.job, source: fixture.source)
        controller.start(.files)
        try await waitForDelivery { controller.presentation != nil }
        let cancelled = try #require(controller.presentation)
        #expect(cancelled.url.isFileURL && FileManager.default.fileExists(atPath: cancelled.url.path))
        #expect(controller.receipt(.files)?.state == .pending)
        await #expect(throws: ExportFailure.self) { try await fixture.exports.remove(takeID: fixture.job.takeID) }
        controller.completePresentation(id: cancelled.id, completed: false)
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.receipt(.files)?.state == .cancelled)
        controller.start(.files)
        try await waitForDelivery { controller.presentation != nil }
        let saved = try #require(controller.presentation)
        controller.completePresentation(id: cancelled.id, completed: true)
        #expect(controller.receipt(.files)?.state == .pending)
        controller.completePresentation(id: saved.id, completed: true, reference: "chosen.mp4")
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.receipt(.files)?.state == .completed)
        controller.start(.share)
        try await waitForDelivery { controller.presentation != nil }
        let shared = try #require(controller.presentation)
        controller.completePresentation(id: shared.id, completed: false, error: "Synthetic receiver failure")
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.receipt(.share)?.state == .failed)
        #expect(controller.receipt(.files)?.state == .completed)
        #expect(try Data(contentsOf: fixture.source) == fixture.original)
    }

    @Test @MainActor func photosDenialLeavesFilesAndShareAvailable() async throws {
        let fixture = try await DeliveryFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let photos = ControlledPhotoSaver(permission: .notDetermined, requested: .denied)
        let controller = fixture.controller(photos: photos)
        await controller.open(job: fixture.job, source: fixture.source)
        controller.start(.photos)
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.photosDenied && controller.receipt(.photos)?.state == .failed)
        #expect(await photos.requestCalls == 1)
        #expect(await photos.saveCalls == 0)
        controller.start(.files)
        try await waitForDelivery { controller.presentation != nil }
        controller.completePresentation(id: try #require(controller.presentation?.id), completed: false)
        try await waitForDelivery { !controller.isBusy }
        controller.start(.share)
        try await waitForDelivery { controller.presentation != nil }
        controller.completePresentation(id: try #require(controller.presentation?.id), completed: true)
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.receipt(.share)?.state == .completed)
        #expect(try Data(contentsOf: fixture.source) == fixture.original)
    }

    @Test @MainActor func relaunchNeverReplaysAPendingSaveAndRequiresExplicitRetry() async throws {
        let fixture = try await DeliveryFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let records = DeliveryStore(root: fixture.root.appendingPathComponent("deliveries"))
        _ = try await records.begin(exportID: fixture.job.id, edit: fixture.job.edit, destination: .photos)
        let photos = ControlledPhotoSaver(), controller = fixture.controller(photos: photos)
        await controller.open(job: fixture.job, source: fixture.source)
        #expect(controller.requiresConfirmation(.photos))
        #expect(await photos.saveCalls == 0)
        controller.start(.photos)
        try await waitForDelivery { !controller.isBusy }
        #expect(await photos.saveCalls == 0)
        controller.start(.photos, confirmingUnknown: true)
        try await waitForDelivery { !controller.isBusy }
        #expect(await photos.saveCalls == 1)
        #expect(controller.photosSaved)
    }

    @Test @MainActor func missingCacheNeverRequestsPhotosPermissionOrRewritesTheOriginal() async throws {
        let fixture = try await DeliveryFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let photos = ControlledPhotoSaver(), controller = fixture.controller(photos: photos)
        await controller.open(job: fixture.job, source: fixture.source)
        let lease = try await fixture.exports.acquireOutput(takeID: fixture.job.takeID, source: fixture.source)
        await fixture.exports.release(lease)
        try FileManager.default.removeItem(at: lease.url)
        controller.start(.photos)
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.needsRecheck && controller.notice != nil)
        #expect(await photos.authorizationCalls == 0)
        #expect(await photos.saveCalls == 0)
        #expect(try Data(contentsOf: fixture.source) == fixture.original)
    }

    @Test @MainActor func failedPhotosSaveRetriesTheSameValidatedMP4() async throws {
        let fixture = try await DeliveryFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let photos = ControlledPhotoSaver(failFirst: true), controller = fixture.controller(photos: photos)
        await controller.open(job: fixture.job, source: fixture.source)
        controller.start(.photos)
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.receipt(.photos)?.state == .failed && !controller.photosSaved)
        controller.start(.photos)
        try await waitForDelivery { !controller.isBusy }
        #expect(controller.photosSaved)
        #expect(await photos.saveCalls == 2)
        #expect(try await fixture.exports.load(takeID: fixture.job.takeID)?.id == fixture.job.id)
        #expect(try Data(contentsOf: fixture.source) == fixture.original)
    }
}

private struct DeliveryFixture {
    let root: URL
    let source: URL
    let original: Data
    let exports: ExportJobStore
    let job: ExportJob
    static func make() async throws -> DeliveryFixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("p4d-\(UUID())")
        let source = root.appendingPathComponent("original.mov"), media = MediaService()
        try await SampleMovie().make(at: source)
        let edit = try await TakeEditStore(root: root.appendingPathComponent("edits")).save(takeID: UUID(),
            source: TakeEditSource(url: source, summary: media.inspect(source)), recipe: .init(start: 0.3, end: 2.7), expectedRevision: 0)
        let exports = ExportJobStore(root: root.appendingPathComponent("jobs"), outputs: root.appendingPathComponent("outputs"))
        let prepared = try await exports.prepare(id: UUID(), edit: edit)
        let ready = try await exports.run(id: prepared.id, source: source) { _, _ in }
        #expect(ready.state == .ready)
        return DeliveryFixture(root: root, source: source, original: try Data(contentsOf: source), exports: exports, job: ready)
    }
    @MainActor func controller(photos: any PhotoLibrarySaving) -> MP4DeliveryController {
        MP4DeliveryController(exports: exports, records: DeliveryStore(root: root.appendingPathComponent("deliveries")), photos: photos)
    }
}
private actor ControlledPhotoSaver: PhotoLibrarySaving {
    var authorizationCalls = 0, requestCalls = 0, saveCalls = 0
    var held: Bool
    var failFirst: Bool
    let permission: AddPhotoAuthorization
    let requested: AddPhotoAuthorization
    init(held: Bool = false, permission: AddPhotoAuthorization = .allowed, requested: AddPhotoAuthorization = .allowed, failFirst: Bool = false) {
        self.held = held; self.permission = permission; self.requested = requested; self.failFirst = failFirst
    }
    func authorization() -> AddPhotoAuthorization { authorizationCalls += 1; return permission }
    func requestAddOnly() -> AddPhotoAuthorization { requestCalls += 1; return requested }
    func saveVideo(at url: URL) async throws -> String {
        saveCalls += 1
        if failFirst { failFirst = false; throw CocoaError(.fileWriteOutOfSpace) }
        while held { try await Task.sleep(for: .milliseconds(10)) }
        return "synthetic-photo"
    }
    func release() { held = false }
}
private enum DeliveryWaitFailure: Error { case timeout }
@MainActor private func waitForDelivery(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(12))
    while !condition() {
        guard ContinuousClock.now < deadline else { throw DeliveryWaitFailure.timeout }
        try await Task.sleep(for: .milliseconds(20))
    }
}
