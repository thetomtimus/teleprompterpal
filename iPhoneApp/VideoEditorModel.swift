import AVFoundation
import Observation
import PrototypeSupport
import UIKit

@MainActor @Observable final class EditorTransport {
    var position = 0.0
    var isPlaying = false
}

@MainActor struct EditorThumbnail: Identifiable {
    let id: Int
    let image: UIImage
}

@MainActor @Observable final class VideoEditorModel: Identifiable {
    let session: TakeEditingSession
    nonisolated let id: UUID
    let title: String
    let player = AVPlayer()
    let transport = EditorTransport()
    private(set) var duration = 0.0
    private(set) var sourceSize = CGSize.zero
    private(set) var frameStep = 1.0 / 30
    private(set) var draft = EditRecipe(end: 0)
    private(set) var loading = true
    private(set) var saving = false
    private(set) var ready = false
    private(set) var writeBlocked = false
    private(set) var message: String?
    private(set) var thumbnails: [EditorThumbnail] = []
    private(set) var thumbnailMessage: String?
    @ObservationIgnored private let store: TakeEditStore
    @ObservationIgnored private let media: MediaService
    @ObservationIgnored private var sourceIdentity: TakeEditSource?
    @ObservationIgnored private var revision: UInt64 = 0
    @ObservationIgnored private var entryRecipe = EditRecipe(end: 0)
    @ObservationIgnored private var loadID = UUID()
    @ObservationIgnored private var seekID = UUID()
    @ObservationIgnored private var seekTask: Task<Void, Never>?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var itemStatusObservation: NSKeyValueObservation?
    @ObservationIgnored private var notifications: [NSObjectProtocol] = []
    @ObservationIgnored private var closed = false
    @ObservationIgnored private var playRequested = false

    init(session: TakeEditingSession, title: String, store: TakeEditStore, media: MediaService) {
        self.session = session; self.title = title; self.store = store; self.media = media
        id = session.id
    }

    var start: Double { draft.start.seconds }
    var end: Double { draft.end.seconds }
    var selectionDuration: Double { end - start }
    var hasChanges: Bool { draft != entryRecipe }
    var canSave: Bool { ready && !loading && !saving && !writeBlocked && !closed }

    func load() async {
        guard !closed, !saving else { return }
        let request = UUID(); loadID = request
        loading = true; ready = false; message = nil; writeBlocked = false
        pause()
        do {
            let summary = try await media.inspect(session.source)
            let source = try await Task { @concurrent [session] in
                try TakeEditSource(url: session.source, summary: summary)
            }.value
            guard loadID == request, !closed, !Task.isCancelled else { return }
            duration = summary.duration
            sourceSize = summary.size
            frameStep = min(duration, 1 / (summary.nominalFrameRate.isFinite && summary.nominalFrameRate > 0
                ? summary.nominalFrameRate : 30))
            sourceIdentity = source
            var recipe = EditRecipe(end: duration)
            revision = 0
            do {
                if let saved = try await store.load(takeID: session.takeID, source: source) {
                    recipe = saved.recipe; revision = saved.revision
                }
            } catch {
                writeBlocked = true
                message = error.localizedDescription
            }
            guard loadID == request, !closed, !Task.isCancelled else { return }
            _ = try CropSelection(sourceSize: sourceSize, crop: recipe.crop, preset: recipe.cropPreset)
            guard loadID == request, !closed, !Task.isCancelled else { return }
            draft = recipe; entryRecipe = recipe
            let item = AVPlayerItem(url: session.source)
            item.forwardPlaybackEndTime = recipe.end.editorTime
            player.replaceCurrentItem(with: item)
            _ = await player.seek(to: recipe.start.editorTime, toleranceBefore: .zero, toleranceAfter: .zero)
            guard loadID == request, !closed, !Task.isCancelled else { return }
            if item.status == .failed { throw item.error ?? PrototypeError.invalidMedia }
            transport.position = start
            installObservers(item: item)
            ready = true; loading = false
        } catch {
            guard loadID == request, !closed, !Task.isCancelled else { return }
            loading = false; writeBlocked = true
            message = "The preview could not open. Return to the original or retry. \(error.localizedDescription)"
        }
    }

    func loadTimeline() async {
        guard ready, !closed, thumbnails.isEmpty else { return }
        do {
            let frames = try await VideoTimeline().frames(source: session.source)
            guard !closed, !Task.isCancelled else { return }
            thumbnails = frames.compactMap { frame in
                UIImage(data: frame.data).map { EditorThumbnail(id: frame.id, image: $0) }
            }
        } catch {
            guard !closed, !Task.isCancelled else { return }
            thumbnailMessage = "Timeline images are unavailable. You can still trim using the time controls."
        }
    }

    func setStart(_ value: Double) {
        guard ready, !loading, !saving, !closed, value.isFinite else { return }
        let accepted = min(max(0, value), max(0, end - frameStep))
        draft.start = MediaTime(seconds: accepted)
        trimChanged(preview: start)
    }

    func setEnd(_ value: Double) {
        guard ready, !loading, !saving, !closed, value.isFinite else { return }
        let accepted = max(min(duration, value), min(duration, start + frameStep))
        draft.end = MediaTime(seconds: accepted)
        trimChanged(preview: max(start, end - frameStep))
    }

    func reset() async {
        guard ready, !loading, !saving, !closed, !writeBlocked else { return }
        pause()
        loading = true
        defer { loading = false }
        let request = UUID(); loadID = request
        let recipe = EditRecipe(end: duration)
        let previousItem = player.currentItem
        do {
            guard !closed, loadID == request else { return }
            // Reset all seeks, end boundaries and crop-renderer state together
            // when returning to the full original.
            seekID = UUID(); seekTask?.cancel(); seekTask = nil
            player.currentItem?.cancelPendingSeeks()
            removeObservers()
            let item = AVPlayerItem(url: session.source)
            item.forwardPlaybackEndTime = recipe.end.editorTime
            player.replaceCurrentItem(with: item)
            let accepted = await player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            guard !closed, loadID == request else { return }
            guard accepted, item.status != .failed else { throw item.error ?? PrototypeError.invalidMedia }
            draft = recipe
            transport.position = 0
            installObservers(item: item)
        } catch {
            guard !closed, loadID == request else { return }
            if player.currentItem !== previousItem {
                player.replaceCurrentItem(with: previousItem)
                if let previousItem { installObservers(item: previousItem) }
            }
            message = "Reset could not finish. Your edits are still here."
        }
    }

    private func trimChanged(preview: Double) {
        pause()
        player.currentItem?.forwardPlaybackEndTime = draft.end.editorTime
        seek(to: preview)
    }

    func scrub(to value: Double) {
        guard ready, !loading, !saving, !closed, value.isFinite else { return }
        pause(); seek(to: min(max(start, value), end))
    }

    func togglePlayback() {
        guard ready, !loading, !saving, !closed else { return }
        if playRequested { pause(); return }
        playRequested = true
        let position = transport.position >= end - frameStep / 2 || transport.position < start
            ? start : transport.position
        seek(to: position, resume: true)
    }

    func pause() {
        playRequested = false
        player.pause()
        transport.isPlaying = false
    }

    private func seek(to seconds: Double, resume: Bool = false) {
        seekID = UUID(); let request = seekID
        seekTask?.cancel()
        player.currentItem?.cancelPendingSeeks()
        transport.position = seconds
        transport.isPlaying = resume
        seekTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(35)) } catch { return }
            guard let self, !closed, seekID == request else { return }
            let accepted = await player.seek(to: MediaTime(seconds: seconds).editorTime,
                                             toleranceBefore: .zero, toleranceAfter: .zero)
            guard !closed, seekID == request, !Task.isCancelled else { return }
            seekTask = nil
            if accepted { transport.position = player.currentTime().seconds }
            if accepted, resume, playRequested { player.play() }
            else { transport.isPlaying = false }
        }
    }

    func cropSelection() -> CropSelection? {
        try? CropSelection(sourceSize: sourceSize, crop: draft.crop, preset: draft.cropPreset)
    }

    func applyCrop(_ selection: CropSelection) {
        guard ready, !loading, !saving, !closed, !writeBlocked, selection.sourceSize == sourceSize else { return }
        pause()
        draft.crop = selection.crop; draft.cropPreset = selection.preset
    }

    func save() async -> Bool {
        guard canSave, let sourceIdentity else { return false }
        saving = true; pause()
        defer { saving = false }
        let snapshot = draft
        do {
            let summary = try await media.inspect(session.source)
            let current = try await Task { @concurrent [session] in
                try TakeEditSource(url: session.source, summary: summary)
            }.value
            guard current == sourceIdentity else { throw TakeEditFailure.sourceChanged }
            let saved = try await store.save(takeID: session.takeID, source: sourceIdentity,
                                             recipe: snapshot, expectedRevision: revision)
            guard !closed else { return false }
            revision = saved.revision; entryRecipe = snapshot; message = nil
            return true
        } catch {
            guard !closed else { return false }
            message = "Edits were not saved. Your draft is still here. \(error.localizedDescription)"
            return false
        }
    }

    func exportSnapshot() async -> SavedTakeEdit? {
        guard await save(), let sourceIdentity, !closed else { return nil }
        do { return try await store.load(takeID: session.takeID, source: sourceIdentity) }
        catch { message = "The saved edit could not be prepared for export. \(error.localizedDescription)"; return nil }
    }

    private func installObservers(item: AVPlayerItem) {
        removeObservers()
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let identity = ObjectIdentifier(item)
            let detail = item.error?.localizedDescription ?? "The video could not be decoded."
            Task { @MainActor [weak self] in
                guard let self, !closed, let current = player.currentItem,
                      ObjectIdentifier(current) == identity else { return }
                pause(); ready = false; writeBlocked = true
                message = "The preview could not play. Return to the original or retry. \(detail)"
            }
        }
        // AVFoundation explicitly delivers this observer on the supplied main queue.
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.closed, self.seekTask == nil, time.seconds.isFinite else { return }
                self.transport.position = min(max(self.start, time.seconds), self.end)
                if self.playRequested, time.seconds >= self.end - 0.001 { self.finishSelection() }
            }
        }
        notifications.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.finishSelection() } })
        notifications.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.pause() } })
    }

    private func finishSelection() {
        guard !closed else { return }
        pause(); seek(to: start)
    }

    private func removeObservers() {
        itemStatusObservation?.invalidate(); itemStatusObservation = nil
        if let timeObserver { player.removeTimeObserver(timeObserver); self.timeObserver = nil }
        notifications.forEach(NotificationCenter.default.removeObserver)
        notifications.removeAll()
    }

    func close() {
        guard !closed else { return }
        closed = true; loadID = UUID(); seekID = UUID()
        seekTask?.cancel(); seekTask = nil
        pause(); removeObservers(); player.replaceCurrentItem(with: nil)
    }

    isolated deinit {
        seekTask?.cancel()
        removeObservers()
        player.pause()
    }
}

private extension MediaTime {
    var editorTime: CMTime { CMTime(value: value, timescale: timescale) }
}

enum EditorTime {
    static func label(_ seconds: Double) -> String {
        let value = seconds.isFinite ? max(0, seconds) : 0
        return String(format: "%d:%05.2f", Int(value) / 60, value.truncatingRemainder(dividingBy: 60))
    }
}
