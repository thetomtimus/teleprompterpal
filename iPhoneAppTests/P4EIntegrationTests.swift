import AVFoundation
import Foundation
import PrototypeSupport
import Testing
@testable import TeleprompterPhone

// Isolated files; serialize real encoder/player use in the Simulator process.
@Suite(.serialized) struct P4EIntegrationTests {
    @Test(arguments: SampleMovieOrientation.allCases, [false, true])
    func markedTrimPreservesEveryFrameAndAudioAlignment(orientation: SampleMovieOrientation, mirrored: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("p4e-timing-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("marked.mov"), media = MediaService()
        try await SampleMovie().make(at: source, orientation: orientation, mirrored: mirrored, timingMarkers: true)
        let original = try Data(contentsOf: source)
        let summary = try await media.inspect(source)
        let edit = try await TakeEditStore(root: root.appendingPathComponent("Edits")).save(takeID: UUID(),
            source: TakeEditSource(url: source, summary: summary),
            recipe: .init(start: 0.3, end: 2.7, crop: .init(x: 0.12, y: 0.08, width: 0.72, height: 0.84), cropPreset: .custom),
            expectedRevision: 0)
        let store = ExportJobStore(root: root.appendingPathComponent("Jobs"), outputs: root.appendingPathComponent("Outputs"))
        let job = try await store.prepare(id: UUID(), edit: edit)
        #expect(try await store.run(id: job.id, source: source) { _, _ in }.state == .ready)
        let output = try await store.acquireOutput(takeID: edit.takeID, source: source)
        let asset = AVURLAsset(url: source)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let transform = try await track.load(.preferredTransform)
        let crop = try CropSelection(sourceSize: summary.size, crop: edit.recipe.crop).geometry.sourceRect
        let frames = try await decodeMarkedFrames(output.url, transform: transform, crop: crop)
        #expect(frames.ids == Array(9..<81), "decoded IDs: \(frames.ids)")
        #expect(abs(output.summary.duration - 2.4) <= 1.0 / 30)
        #expect(frames.flashes.count == 2)
        let sourceAudio = try await audioOnsets(source)
        let outputAudio = try await audioOnsets(output.url)
        #expect(sourceAudio.count == 3 && outputAudio.count == 2)
        for (actual, expected) in zip(sourceAudio, [0.0, 1.0, 2.0]) { #expect(abs(actual - expected) <= 0.01) }
        for (actual, expected) in zip(outputAudio, [0.7, 1.7]) { #expect(abs(actual - expected) <= 1.0 / 30) }
        for (audio, video) in zip(outputAudio, frames.flashes) { #expect(abs(audio - video) <= 1.0 / 30) }
        print("P4E_TIMING orientation=\(orientation.rawValue) mirrored=\(mirrored) frames=\(frames.ids.count) first=\(frames.ids.first ?? -1) last=\(frames.ids.last ?? -1) duration=\(output.summary.duration) audio=\(outputAudio) video=\(frames.flashes)")
        #expect(try Data(contentsOf: source) == original)
        await store.release(output)
    }

    @Test @MainActor func scriptTakeEditDeliveryReopenAndCacheRecoveryKeepTheirAssociations() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("p4e-story-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root.appendingPathComponent("Scripts"))
        await library.initialize()
        let scriptID = try #require(library.create(title: "P4E 한국어 🎥", text: "One marked test. café مرحبا שלום"))
        let script = try #require(library.script(scriptID))
        let context = TakeScriptContext(id: scriptID, revision: script.document.revision, title: script.document.title)
        let capture = TestCapture()
        let recorder = PrototypeModel(root: root.appendingPathComponent("Capture"), capture: capture,
            requestPermissions: { .init(camera: .authorized, microphone: .authorized) }, countdownTick: {})
        await recorder.initialize(); recorder.takeContext = context; await recorder.enterCamera()
        recorder.start(); await recorder.countdownTask?.value
        let request = try #require(await capture.requests.first)
        await recorder.handle(.started(request.id)); recorder.stop()
        try await SampleMovie().make(at: request.url, orientation: .up, timingMarkers: true)
        let original = try Data(contentsOf: request.url)
        await recorder.handle(.finished(request.id, request.url, true, nil))
        let take = try #require(recorder.takes.first)
        #expect(take.script == context && take.isPlayable)
        await recorder.openTake(take)
        let session = try #require(await recorder.beginEditingTake(id: take.id))
        let editor = VideoEditorModel(session: session, title: context.title, store: recorder.edits, media: recorder.media)
        await editor.load(); editor.setStart(0.3); editor.setEnd(2.7)
        var crop = try #require(editor.cropSelection()); crop.select(.portrait); crop.position(horizontal: 0.8)
        editor.applyCrop(crop)
        let saved = try #require(await editor.exportSnapshot())
        await recorder.mp4Exports.open(edit: saved, source: request.url)
        try await p4eWait { recorder.mp4Exports.phase == .ready && !recorder.mp4Exports.isBusy }
        let readyID = try #require(recorder.mp4Exports.job?.id)
        recorder.mp4Exports.togglePlayback()
        try await p4eWait { recorder.mp4Exports.player.currentTime().seconds > 0.2 }
        recorder.mp4Exports.pausePlayback()
        let delivery = recorder.mp4Exports.delivery
        delivery.start(.files)
        try await p4eWait { delivery.presentation != nil }
        let presentation = try #require(delivery.presentation)
        #expect(!(await recorder.deleteTake(id: take.id)))
        let delivered = root.appendingPathComponent("delivered.mp4")
        try FileManager.default.copyItem(at: presentation.url, to: delivered)
        delivery.completePresentation(id: presentation.id, completed: true, reference: delivered.lastPathComponent)
        try await p4eWait { !delivery.isBusy }
        #expect(delivery.receipt(.files)?.state == .completed)
        let output = try #require(recorder.mp4Exports.outputURL)
        #expect(try Data(contentsOf: delivered) == Data(contentsOf: output))
        // An unchanged editor save must retain the revision, cache and receipt.
        let same = try #require(await editor.exportSnapshot())
        #expect(same == saved)
        await recorder.mp4Exports.leave()
        editor.close(); recorder.endEditingTake(session); recorder.stopPlayback(takeID: take.id)
        await recorder.playbackReleaseTask?.value
        await library.flush()
        let reopened = PrototypeModel(root: root.appendingPathComponent("Capture"), capture: TestCapture())
        await reopened.initialize()
        #expect(reopened.takes.count == 1 && reopened.takes.first?.script == context)
        await reopened.openTake(try #require(reopened.takes.first))
        let nextSession = try #require(await reopened.beginEditingTake(id: take.id))
        let next = VideoEditorModel(session: nextSession, title: context.title, store: reopened.edits, media: reopened.media)
        await next.load(); #expect(next.draft == saved.recipe)
        await reopened.mp4Exports.open(edit: try #require(await next.exportSnapshot()), source: request.url)
        #expect(reopened.mp4Exports.job?.id == readyID && reopened.mp4Exports.delivery.receipt(.files)?.state == .completed)
        await reopened.mp4Exports.leave()
        try FileManager.default.removeItem(at: output)
        await reopened.mp4Exports.open(edit: saved, source: request.url)
        #expect(reopened.mp4Exports.phase == .interrupted && !reopened.mp4Exports.isBusy)
        reopened.mp4Exports.retry()
        try await p4eWait { reopened.mp4Exports.phase == .ready && !reopened.mp4Exports.isBusy }
        #expect(reopened.mp4Exports.job?.id != readyID)
        #expect(reopened.mp4Exports.delivery.receipt(.files)?.state == .completed)
        await reopened.mp4Exports.leave()
        var custom = try #require(next.cropSelection()); custom.select(.custom); custom.size(width: 0.7, height: 0.8)
        next.applyCrop(custom)
        let changed = try #require(await next.exportSnapshot())
        #expect(changed.revision == saved.revision + 1)
        await reopened.mp4Exports.open(edit: changed, source: request.url)
        try await p4eWait { reopened.mp4Exports.phase == .ready && !reopened.mp4Exports.isBusy }
        #expect(reopened.mp4Exports.delivery.receipt(.files) == nil)
        #expect(try Data(contentsOf: request.url) == original)
        #expect(try await reopened.store.load().count == 1)
        await reopened.mp4Exports.leave(); next.close(); reopened.endEditingTake(nextSession)
        reopened.stopPlayback(takeID: take.id); await reopened.playbackReleaseTask?.value
        let restoredLibrary = LibraryModel(root: root.appendingPathComponent("Scripts"))
        await restoredLibrary.initialize()
        #expect(restoredLibrary.script(scriptID)?.document == script.document)
        print("P4E_STORY script/take/edit/export/copy/reopen/cache-recovery/new-revision passed; original unchanged")
    }
}

private enum P4EFailure: Error { case timeout, decode }
@MainActor private func p4eWait(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(15))
    while !condition() {
        guard ContinuousClock.now < deadline else { throw P4EFailure.timeout }
        try await Task.sleep(for: .milliseconds(20))
    }
}

private func decodeMarkedFrames(_ url: URL, transform: CGAffineTransform, crop: CGRect) async throws -> (ids: [Int], flashes: [Double]) {
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(output); #expect(reader.startReading())
    var ids: [Int] = [], flashes: [Double] = [], wasBright = false
    while let sample = output.copyNextSampleBuffer() {
        let image = try #require(CMSampleBufferGetImageBuffer(sample))
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        let base = try #require(CVPixelBufferGetBaseAddress(image)), stride = CVPixelBufferGetBytesPerRow(image)
        func white(_ point: CGPoint) throws -> Bool {
            let upright = point.applying(transform)
            let x = Int((upright.x - crop.minX).rounded(.down)), y = Int((upright.y - crop.minY).rounded(.down))
            #expect(x >= 0 && x < CVPixelBufferGetWidth(image) && y >= 0 && y < CVPixelBufferGetHeight(image))
            guard x >= 0, x < CVPixelBufferGetWidth(image), y >= 0, y < CVPixelBufferGetHeight(image) else { throw P4EFailure.decode }
            let pixel = base.advanced(by: y * stride + x * 4).assumingMemoryBound(to: UInt8.self)
            return min(pixel[0], pixel[1], pixel[2]) > 180
        }
        var frame = 0
        for bit in 0..<7 where try white(CGPoint(x: 116 + bit * 12, y: 150)) { frame |= 1 << bit }
        ids.append(frame)
        let bright = try white(CGPoint(x: 160, y: 120))
        if bright && !wasBright { flashes.append(CMSampleBufferGetPresentationTimeStamp(sample).seconds) }
        wasBright = bright
    }
    #expect(reader.status == .completed)
    return (ids, flashes)
}

private func audioOnsets(_ url: URL) async throws -> [Double] {
    let asset = AVURLAsset(url: url)
    let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false,
        AVNumberOfChannelsKey: 1, AVSampleRateKey: 48_000])
    reader.add(output); #expect(reader.startReading())
    var active: [Int] = []
    while let sample = output.copyNextSampleBuffer() {
        let block = try #require(CMSampleBufferGetDataBuffer(sample))
        var values = [Float](repeating: 0, count: CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size)
        let status = values.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!) }
        #expect(status == kCMBlockBufferNoErr)
        let start = CMSampleBufferGetPresentationTimeStamp(sample).seconds
        for index in values.indices where abs(values[index]) > 0.06 {
            let bin = Int(((start + Double(index) / 48_000) * 1000).rounded(.down))
            if active.last != bin { active.append(bin) }
        }
    }
    #expect(reader.status == .completed)
    var onsets: [Double] = [], previous: Int?
    for bin in active {
        if previous == nil || bin - previous! > 40 { onsets.append(Double(bin) / 1000) }
        previous = bin
    }
    return onsets
}
