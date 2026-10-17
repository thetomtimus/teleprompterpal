import Foundation
import Observation
import PrototypeSupport

struct DeliveryPresentation: Identifiable {
    let id: UUID
    let destination: DeliveryDestination
    let url: URL
}

@MainActor @Observable final class MP4DeliveryController {
    let records: DeliveryStore
    private let exports: ExportJobStore
    private let photos: any PhotoLibrarySaving
    @ObservationIgnored private let events: LocalEventRecorder?
    private(set) var receipts: [DeliveryAttempt] = []
    private(set) var isBusy = false
    private(set) var loading = false
    private(set) var blocked = false
    private(set) var notice: String?
    private(set) var photosDenied = false
    private(set) var needsRecheck = false
    var presentation: DeliveryPresentation?
    @ObservationIgnored private var job: ExportJob?
    @ObservationIgnored private var source: URL?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var attempt: DeliveryAttempt?
    @ObservationIgnored private var lease: ExportOutputLease?
    @ObservationIgnored private var finishing = false
    @ObservationIgnored private var worker: Task<Void, Never>?

    init(exports: ExportJobStore, records: DeliveryStore, photos: any PhotoLibrarySaving = SystemPhotoLibrarySaver(),
         events: LocalEventRecorder? = nil) {
        self.exports = exports; self.records = records; self.photos = photos
        self.events = events
    }

    func open(job: ExportJob, source: URL) async {
        guard !isBusy else { return }
        let request = UUID(); generation = request
        self.job = job; self.source = source
        receipts = []; notice = nil; blocked = false; needsRecheck = false; photosDenied = false; loading = true
        defer { if generation == request { loading = false } }
        do {
            let loaded = try await records.load(edit: job.edit)
            guard generation == request else { return }
            receipts = loaded
            for receipt in loaded where receipt.state == .unknown { recordResult(receipt, outcome: .unknown) }
        } catch {
            guard generation == request else { return }
            blocked = true; notice = error.localizedDescription
        }
    }

    func receipt(_ destination: DeliveryDestination) -> DeliveryAttempt? { receipts.first { $0.destination == destination } }
    func requiresConfirmation(_ destination: DeliveryDestination) -> Bool { receipt(destination)?.state == .unknown }
    var photosSaved: Bool { receipt(.photos)?.state == .completed }

    func start(_ destination: DeliveryDestination, confirmingUnknown: Bool = false) {
        guard !isBusy, !loading, !blocked, let job, let source, job.state == .ready else { return }
        guard destination != .photos || !photosSaved || confirmingUnknown else { return }
        isBusy = true; finishing = false; notice = nil; needsRecheck = false
        let request = UUID(); generation = request
        worker = Task { [self] in
            do {
                let acquired = try await exports.acquireOutput(takeID: job.takeID, source: source)
                guard generation == request else { await exports.release(acquired); return }
                guard acquired.jobID == job.id else { await exports.release(acquired); throw ExportFailure.sourceChanged }
                lease = acquired
                let started = try await records.begin(exportID: job.id, edit: job.edit,
                    destination: destination, confirmingUnknown: confirmingUnknown)
                attempt = started; setReceipt(started)
                if destination == .photos {
                    var permission = await photos.authorization()
                    if permission == .notDetermined { permission = await photos.requestAddOnly() }
                    guard permission == .allowed else {
                        photosDenied = true
                        await finish(id: started.id, state: .failed,
                            message: "Photos access is off. Allow adding videos in Settings, then try again. Files and Share are still available.")
                        return
                    }
                    photosDenied = false
                    do {
                        let identifier = try await photos.saveVideo(at: acquired.url)
                        await finish(id: started.id, state: .completed, message: "Saved to Photos.", reference: identifier)
                    } catch {
                        await finish(id: started.id, state: error is ExportPhotoFailure ? .unknown : .failed,
                            message: "Photos could not confirm this save. \(error.localizedDescription)")
                    }
                } else {
                    presentation = DeliveryPresentation(id: started.id, destination: destination, url: acquired.url)
                }
            } catch {
                events?.emit(.export(stage: .init(rawValue: destination.rawValue) ?? .share, outcome: .failed, edit: job.edit), operationID: request)
                notice = error.localizedDescription
                needsRecheck = error is ExportFailure || error is PrototypeError
                await release()
                isBusy = false; worker = nil
            }
        }
    }

    func completePresentation(id: UUID, completed: Bool, reference: String? = nil, error: String? = nil) {
        guard let attempt, attempt.id == id, !finishing else { return }
        let destination = attempt.destination
        let state: DeliveryAttempt.State = error != nil ? .failed : completed ? .completed : .cancelled
        let message: String
        if let error { message = "\(destination.title) could not finish. \(error)" }
        else if completed { message = destination == .files ? "Saved to Files." : "Share completed. The receiving app controls any upload." }
        else { message = destination == .files ? "Save to Files cancelled." : "Share cancelled." }
        finishing = true
        Task { await finish(id: id, state: state, message: message, reference: reference) }
    }

    private func finish(id: UUID, state: DeliveryAttempt.State, message: String, reference: String? = nil) async {
        guard var attempt, attempt.id == id else { return }
        finishing = true
        do {
            if let saved = try await records.finish(id: id, state: state, message: message, reference: reference) {
                setReceipt(saved)
                recordResult(saved, outcome: state == .completed ? .completed : state == .cancelled ? .cancelled : state == .failed ? .failed : .unknown)
            }
        } catch {
            attempt.state = .unknown
            attempt.message = "The result could not be recorded. Check \(attempt.destination.title) before trying again. \(error.localizedDescription)"
            setReceipt(attempt)
            recordResult(attempt, outcome: .unknown)
        }
        presentation = nil
        self.attempt = nil
        await release()
        isBusy = false; finishing = false; worker = nil
    }

    private func setReceipt(_ receipt: DeliveryAttempt) {
        receipts.removeAll { $0.destination == receipt.destination }; receipts.append(receipt)
    }
    private func recordResult(_ receipt: DeliveryAttempt, outcome: LocalEventPayload.ExportOutcome) {
        guard let job else { return }
        events?.emit(.export(stage: .init(rawValue: receipt.destination.rawValue) ?? .share, outcome: outcome, edit: job.edit), operationID: receipt.id)
    }
    private func release() async { if let lease { self.lease = nil; await exports.release(lease) } }
}
