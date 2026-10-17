import AVFoundation
import Foundation

public struct MediaSummary: Codable, Equatable, Sendable {
    public let duration: Double
    public let width: Int
    public let height: Int
    public let nominalFrameRate: Double
    public var videoCodec: String?
    public var audioCodec: String?
    public var fileBytes: Int64?

    public var size: CGSize { CGSize(width: width, height: height) }
}

public actor MediaService {
    private var exporting = false

    public init() {}

    public func inspect(_ url: URL) async throws -> MediaSummary {
        let asset = AVURLAsset(url: url)
        guard try await asset.load(.isPlayable) else { throw PrototypeError.invalidMedia }
        let duration = try await asset.load(.duration).seconds
        let videos = try await asset.loadTracks(withMediaType: .video)
        let audios = try await asset.loadTracks(withMediaType: .audio)
        guard duration.isFinite, duration > 0, let track = videos.first, !audios.isEmpty else {
            throw PrototypeError.invalidMedia
        }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let bounds = CGRect(origin: .zero, size: size).applying(transform).standardized
        let rate = try await track.load(.nominalFrameRate)
        let videoFormat = try await track.load(.formatDescriptions).first
        let audioFormat = try await audios[0].load(.formatDescriptions).first
        let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        return MediaSummary(
            duration: duration, width: Int(bounds.width.rounded()),
            height: Int(bounds.height.rounded()), nominalFrameRate: Double(rate),
            videoCodec: codec(videoFormat), audioCodec: codec(audioFormat), fileBytes: bytes)
    }

    private func codec(_ description: CMFormatDescription?) -> String? {
        guard let description else { return nil }
        let value = CMFormatDescriptionGetMediaSubType(description)
        return String(bytes: (0..<4).map { UInt8((value >> ((3 - $0) * 8)) & 255) }, encoding: .ascii)
    }

    /// Returns the same composition used for exporting. AVFoundation objects remain in caller isolation.
    public func composition(source: URL, recipe: EditRecipe) async throws -> AVVideoComposition {
        let asset = AVURLAsset(url: source)
        return try await makeComposition(asset: asset, recipe: recipe)
    }

    public func export(
        source: URL, recipe: EditRecipe, destination: URL,
        progress: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> MediaSummary {
        guard !exporting else { throw PrototypeError.busy }
        exporting = true
        defer { exporting = false }
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        try recipe.validate(duration: duration)
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw PrototypeError.busy }
        let capacity =
            try destination.deletingLastPathComponent().resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey
            ])
            .volumeAvailableCapacityForImportantUsage ?? 0
        let sourceSize =
            (try FileManager.default.attributesOfItem(atPath: source.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard capacity > sourceSize + 128 * 1024 * 1024 else { throw PrototypeError.insufficientSpace }
        // The caller's UUID destination makes this path unique and recoverable
        // after process death. Never take ownership of an existing staging file.
        let partial = destination.deletingPathExtension().appendingPathExtension("encoding.mp4")
        guard !FileManager.default.fileExists(atPath: partial.path) else { throw PrototypeError.busy }
        defer { try? FileManager.default.removeItem(at: partial) }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality),
            session.supportedFileTypes.contains(.mp4)
        else { throw PrototypeError.exportUnavailable }
        session.videoComposition = try await makeComposition(asset: asset, recipe: recipe)
        session.timeRange = CMTimeRange(start: recipe.start.cmTime, end: recipe.end.cmTime)
        session.shouldOptimizeForNetworkUse = true
        let monitor = Task {
            // Explicit self access keeps this task on the same actor as the export session.
            guard self.exporting else { return }
            for await state in session.states(updateInterval: 0.2) {
                if Task.isCancelled { break }
                if case .exporting(let value) = state { await progress(value.fractionCompleted) }
            }
        }
        defer { monitor.cancel() }
        try await session.export(to: partial, as: .mp4)
        try Task.checkCancellation()
        let result = try await inspect(partial)
        try FileManager.default.moveItem(at: partial, to: destination)
        await progress(1)
        return result
    }

    public func validateExport(_ url: URL, edit: SavedTakeEdit) async throws -> MediaSummary {
        try Task.checkCancellation()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 64) ?? Data()
        guard header.count >= 16, String(decoding: header[4..<8], as: UTF8.self) == "ftyp",
              ["mp41", "mp42", "isom", "iso2"].contains(String(decoding: header[8..<12], as: UTF8.self)) else {
            throw ExportFailure.invalidOutput
        }
        let result = try await inspect(url)
        let geometry = try CropSelection(sourceSize: CGSize(width: edit.source.width, height: edit.source.height), crop: edit.recipe.crop).geometry
        let expected = edit.recipe.end.seconds - edit.recipe.start.seconds
        let frame = 1.0 / 30 + 0.002
        // Core Media identifies AAC as 'aac '; 'mp4a' is the container sample entry.
        guard result.videoCodec == "avc1", result.audioCodec == "aac ", (result.fileBytes ?? 0) > 0,
              result.size == geometry.renderSize, abs(result.duration - expected) <= frame,
              result.nominalFrameRate > 0, result.nominalFrameRate <= 30.1 else { throw ExportFailure.invalidOutput }
        let asset = AVURLAsset(url: url)
        guard let video = try await asset.loadTracks(withMediaType: .video).first,
              let audio = try await asset.loadTracks(withMediaType: .audio).first else { throw ExportFailure.invalidOutput }
        let audioRange = try await audio.load(.timeRange)
        guard audioRange.start.seconds <= frame,
              audioRange.end.seconds >= expected - frame else { throw ExportFailure.invalidOutput }
        let descriptions = try await video.load(.formatDescriptions)
        let extensions = descriptions.first.flatMap { CMFormatDescriptionGetExtensions($0) as? [String: Any] } ?? [:]
        let transfer = extensions[kCMFormatDescriptionExtension_TransferFunction as String] as? String
        guard transfer != AVVideoTransferFunction_SMPTE_ST_2084_PQ,
              transfer != AVVideoTransferFunction_ITU_R_2100_HLG else { throw ExportFailure.invalidOutput }
        // Decode the first and last promised video frames before publishing.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        _ = try await generator.image(at: .zero)
        _ = try await generator.image(at: CMTime(seconds: max(0, expected - 1.0 / 30), preferredTimescale: 600))
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM])
        reader.add(output)
        guard reader.startReading(), output.copyNextSampleBuffer() != nil else { throw ExportFailure.invalidOutput }
        reader.cancelReading()
        try Task.checkCancellation()
        return result
    }

    private func makeComposition(asset: AVAsset, recipe: EditRecipe) async throws -> AVVideoComposition {
        let duration = try await asset.load(.duration)
        try recipe.validate(duration: duration.seconds)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw PrototypeError.invalidMedia
        }
        let geometry = try CropGeometry(
            naturalSize: await track.load(.naturalSize),
            preferredTransform: await track.load(.preferredTransform), crop: recipe.crop)
        let descriptions = try await track.load(.formatDescriptions)
        let color = descriptions.first.flatMap { CMFormatDescriptionGetExtensions($0) as? [String: Any] } ?? [:]
        let primaries = color[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String
        let transfer = color[kCMFormatDescriptionExtension_TransferFunction as String] as? String
        let matrix = color[kCMFormatDescriptionExtension_YCbCrMatrix as String] as? String
        if #available(iOS 26, macOS 26, *) {
            var layer = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
            layer.setTransform(geometry.transform, at: .zero)
            let instruction = AVVideoCompositionInstruction(
                configuration: .init(
                    layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layer)],
                    timeRange: CMTimeRange(start: .zero, duration: duration)
                ))
            var configuration = try await AVVideoComposition.Configuration(for: asset)
            configuration.frameDuration = CMTime(value: 1, timescale: 30)
            configuration.instructions = [instruction]
            configuration.renderSize = geometry.renderSize
            return AVVideoComposition(configuration: configuration)
        } else {
            return legacyComposition(
                track: track, duration: duration, geometry: geometry,
                primaries: primaries, transfer: transfer, matrix: matrix)
        }
    }

    // Required for the iOS 18–25 / macOS 15 compatibility path. Current OS uses immutable configurations.
    @available(iOS, introduced: 18, deprecated: 26)
    @available(macOS, introduced: 15, deprecated: 26)
    private func legacyComposition(
        track: AVAssetTrack, duration: CMTime, geometry: CropGeometry,
        primaries: String?, transfer: String?, matrix: String?
    ) -> AVVideoComposition {
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(geometry.transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layer]
        let result = AVMutableVideoComposition()
        result.colorPrimaries = primaries
        result.colorTransferFunction = transfer
        result.colorYCbCrMatrix = matrix
        result.frameDuration = CMTime(value: 1, timescale: 30)
        result.renderSize = geometry.renderSize
        result.instructions = [instruction]
        return result
    }
}

extension MediaTime {
    var cmTime: CMTime { CMTime(value: value, timescale: timescale) }
}
