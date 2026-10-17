import AVFoundation
import Observation
import PrototypeSupport
import UIKit

@MainActor @Observable final class MP4ExportProgress {
    var fraction = 0.0
    var checking = false
}

/// App ownership outlives a dismissed editor until cancellation has drained.
@MainActor @Observable final class MP4ExportController {
    enum Phase { case idle, preparing, exporting, cancelling, ready, cancelled, interrupted, failed }
    private(set) var phase: Phase = .idle
    private(set) var job: ExportJob?
    private(set) var message: String?
    private(set) var outputURL: URL?
    private(set) var playing = false
    let progress = MP4ExportProgress()
    let player = AVPlayer()
    let store: ExportJobStore
    let delivery: MP4DeliveryController
    @ObservationIgnored private let events: LocalEventRecorder?
    private var operation: UUID?
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var lease: ExportOutputLease?
    @ObservationIgnored private var snapshot: SavedTakeEdit?
    @ObservationIgnored private var source: URL?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var background: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var foreground = true
    @ObservationIgnored private var requestedStop: Phase?

    var isBusy: Bool { operation != nil || phase == .preparing }

    init(store: ExportJobStore, photos: (any PhotoLibrarySaving)? = nil, events: LocalEventRecorder? = nil) {
        self.store = store
        self.events = events
        delivery = MP4DeliveryController(exports: store,
            records: DeliveryStore(root: store.root.deletingLastPathComponent().appendingPathComponent("Deliveries")),
            photos: photos ?? SystemPhotoLibrarySaver.configured(root: store.root.deletingLastPathComponent()), events: events)
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.interrupt() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
            object: nil, queue: .main) { [weak self] notification in
            guard let item = notification.object as? AVPlayerItem else { return }
            let identity = ObjectIdentifier(item)
            MainActor.assumeIsolated {
                guard let self, let current = self.player.currentItem, ObjectIdentifier(current) == identity else { return }
                self.playing = false; self.player.seek(to: .zero)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.foreground = true } })
    }

    func open(edit: SavedTakeEdit, source: URL) async {
        guard !isBusy else { return }
        let request = UUID(); generation = request
        phase = .preparing; message = nil; job = nil
        snapshot = edit; self.source = source
        await releaseOutput()
        do {
            let saved = try await store.load(takeID: edit.takeID)
            guard generation == request else { return }
            if let saved, saved.edit == edit {
                await show(saved, source: source, request: request)
            } else { phase = .idle; start() }
        } catch {
            guard generation == request else { return }
            phase = .failed; message = error.localizedDescription
            recordResult(id: request, outcome: .failed)
        }
    }

    func retry() { guard !isBusy else { return }; start() }

    private func start() {
        guard operation == nil, let snapshot, let source else { return }
        guard foreground else { phase = .interrupted; message = "Return to the app, then retry the export."; return }
        let id = UUID(); operation = id; generation = id
        requestedStop = nil
        phase = .preparing; message = nil; job = nil
        progress.fraction = 0; progress.checking = false
        worker = Task { [self] in
            await releaseOutput()
            do {
                let prepared = try await store.prepare(id: id, edit: snapshot)
                guard operation == id else { return }
                job = prepared
                let result: ExportJob
                if prepared.state == .ready { result = prepared }
                else {
                    if phase != .cancelling { phase = .exporting }
                    result = try await store.run(id: prepared.id, source: source) { [weak self] value, checking in
                        await self?.receive(value, checking: checking, operation: id)
                    }
                }
                guard operation == id else { return }
                await show(result, source: source, request: id)
            } catch {
                guard operation == id else { return }
                if let requestedStop {
                    phase = requestedStop
                    message = requestedStop == .interrupted
                        ? "Export was interrupted. Retry when you’re ready; your original and saved edit are kept."
                        : "Export cancelled. Your original and saved edit are kept."
                } else {
                    phase = .failed; message = "Export could not finish. \(error.localizedDescription)"
                }
                recordResult(id: job?.id ?? id,
                    outcome: requestedStop == .interrupted ? .interrupted : requestedStop == .cancelled ? .cancelled : .failed)
            }
            if operation == id { operation = nil; worker = nil; endBackground() }
        }
    }

    private func receive(_ value: Double, checking: Bool, operation id: UUID) {
        guard operation == id, phase == .exporting, value.isFinite else { return }
        progress.fraction = max(progress.fraction, min(0.99, max(0, value)))
        progress.checking = checking
    }

    private func show(_ result: ExportJob, source: URL, request: UUID) async {
        guard generation == request else { return }
        job = result; message = result.message
        switch result.state {
        case .ready:
            do {
                let acquired = try await store.acquireOutput(takeID: result.takeID, source: source)
                guard generation == request else { await store.release(acquired); return }
                lease = acquired; outputURL = acquired.url
                job?.summary = acquired.summary
                player.replaceCurrentItem(with: AVPlayerItem(url: acquired.url))
                await delivery.open(job: result, source: source)
                guard generation == request else { return }
                progress.fraction = 1; phase = .ready
                recordResult(id: result.id, outcome: .ready)
            } catch {
                guard generation == request else { return }
                phase = .failed; message = error.localizedDescription
                job = (try? await store.invalidateOutput(takeID: result.takeID, message: error.localizedDescription)) ?? result
                recordResult(id: result.id, outcome: .failed)
            }
        case .cancelled: phase = .cancelled; recordResult(id: result.id, outcome: .cancelled)
        case .interrupted: phase = .interrupted; recordResult(id: result.id, outcome: .interrupted)
        case .failed: phase = .failed; recordResult(id: result.id, outcome: .failed)
        case .exporting, .cancelling: phase = .interrupted; recordResult(id: result.id, outcome: .interrupted)
        }
    }

    func cancel(interrupted: Bool = false) {
        if operation == nil, phase == .preparing {
            recordResult(id: generation, outcome: interrupted ? .interrupted : .cancelled)
            generation = UUID(); phase = interrupted ? .interrupted : .cancelled
            message = "Export stopped. Your original and saved edit are kept."; return
        }
        guard let id = operation, phase != .cancelling else { return }
        requestedStop = interrupted ? .interrupted : .cancelled
        phase = .cancelling
        Task { @concurrent [weak self, store] in
            // Persist the user's intent before asking AVFoundation to unwind.
            try? await store.requestStop(id: id, interrupted: interrupted)
            await self?.cancelWorker(id)
        }
    }

    private func recordResult(id: UUID, outcome: LocalEventPayload.ExportOutcome) {
        guard let snapshot else { return }
        events?.emit(.export(stage: .file, outcome: outcome, edit: snapshot), operationID: id)
    }

    private func cancelWorker(_ id: UUID) {
        guard operation == id else { return }
        worker?.cancel()
    }

    func interrupt() {
        foreground = false
        player.pause(); playing = false
        guard operation != nil else {
            if phase == .preparing { generation = UUID(); phase = .interrupted; message = "Export was interrupted. Retry when you’re ready." }
            return
        }
        if background == .invalid {
            background = UIApplication.shared.beginBackgroundTask(withName: "Stop MP4 export") { [weak self] in
                Task { @MainActor [weak self] in
                    self?.worker?.cancel(); self?.endBackground()
                }
            }
        }
        cancel(interrupted: true)
    }

    func leave() async {
        cancel()
        await worker?.value
        generation = UUID()
        await releaseOutput()
        if operation == nil, phase == .preparing { phase = .idle }
    }

    func dismiss() {
        let request = generation, pending = worker
        cancel()
        player.pause(); playing = false
        if operation == nil { generation = UUID(); phase = .idle }
        Task { @concurrent [weak self] in
            await pending?.value
            await self?.finishDismiss(request)
        }
    }

    private func finishDismiss(_ request: UUID) async {
        guard generation == request || operation == nil && phase == .idle else { return }
        await releaseOutput()
    }

    func togglePlayback() {
        guard phase == .ready, outputURL != nil else { return }
        if playing { player.pause(); playing = false }
        else { player.play(); playing = true }
    }

    func pausePlayback() { player.pause(); playing = false }

    func recheckOutput() async {
        guard !isBusy, !delivery.isBusy, let snapshot, let source else { return }
        await open(edit: snapshot, source: source)
    }

    private func releaseOutput() async {
        player.pause(); playing = false; player.replaceCurrentItem(with: nil); outputURL = nil
        if let lease { self.lease = nil; await store.release(lease) }
    }

    private func endBackground() {
        if background != .invalid { UIApplication.shared.endBackgroundTask(background); background = .invalid }
    }

    isolated deinit {
        worker?.cancel(); player.pause()
        observers.forEach(NotificationCenter.default.removeObserver)
        if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
    }
}
