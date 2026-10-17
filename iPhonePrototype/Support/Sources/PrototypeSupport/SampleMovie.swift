import AVFoundation
import CoreVideo
import Foundation

public enum SampleMovieOrientation: Int, CaseIterable, Sendable {
    case up, right, down, left
    public var transform: CGAffineTransform {
        switch self {
        case .up: .identity
        case .right: .init(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)
        case .down: .init(a: -1, b: 0, c: 0, d: -1, tx: 320, ty: 240)
        case .left: .init(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 320)
        }
    }
}

/// Synthetic validation fixture only. Production capture uses AVCaptureMovieFileOutput.
public actor SampleMovie {
    private static let queue = SampleMovieQueue()
    public init() {}

    public func make(at destination: URL, rotated: Bool = false) async throws {
        try await make(at: destination, orientation: rotated ? .right : .up)
    }

    public func make(at destination: URL, orientation: SampleMovieOrientation, mirrored: Bool = false,
                     timingMarkers: Bool = false) async throws {
        var transform = orientation.transform
        if mirrored {
            let width = CGRect(x: 0, y: 0, width: 320, height: 240).applying(transform).standardized.width
            transform = transform.concatenating(.init(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0))
        }
        let accepted = transform
        try await Self.queue.perform { try await self.writeMovie(at: destination, transform: accepted, timingMarkers: timingMarkers) }
    }

    private func writeMovie(at destination: URL, transform: CGAffineTransform, timingMarkers: Bool) async throws {
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let video = folder.appendingPathComponent(UUID().uuidString + ".silent.mov")
        let wave = folder.appendingPathComponent(UUID().uuidString + ".wav")
        let encoded = folder.appendingPathComponent(UUID().uuidString + ".encoded.mov")
        defer {
            try? FileManager.default.removeItem(at: video)
            try? FileManager.default.removeItem(at: wave)
            try? FileManager.default.removeItem(at: encoded)
        }
        try await makeVideo(at: video, transform: .identity, timingMarkers: timingMarkers)
        try makeWave().write(to: wave)
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let audioAsset = AVURLAsset(url: wave)
        guard let videoSource = try await videoAsset.loadTracks(withMediaType: .video).first,
            let audioSource = try await audioAsset.loadTracks(withMediaType: .audio).first,
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let audioTrack = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        else {
            throw PrototypeError.invalidMedia
        }
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 3, preferredTimescale: 600))
        try videoTrack.insertTimeRange(range, of: videoSource, at: .zero)
        videoTrack.preferredTransform = try await videoSource.load(.preferredTransform)
        try audioTrack.insertTimeRange(range, of: audioSource, at: .zero)
        try await exporter.export(to: encoded, as: .mov)

        // HighestQuality can bake preferred transforms into pixels. Attach the
        // requested rotation/reflection only after the H.264/AAC encode so tests
        // exercise real track metadata, as a camera file does.
        let encodedAsset = AVURLAsset(url: encoded)
        let transformed = AVMutableComposition()
        guard let encodedVideo = try await encodedAsset.loadTracks(withMediaType: .video).first,
            let encodedAudio = try await encodedAsset.loadTracks(withMediaType: .audio).first,
            let finalVideo = transformed.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let finalAudio = transformed.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
            let passthrough = AVAssetExportSession(asset: transformed, presetName: AVAssetExportPresetPassthrough)
        else { throw PrototypeError.invalidMedia }
        try finalVideo.insertTimeRange(range, of: encodedVideo, at: .zero)
        finalVideo.preferredTransform = transform
        try finalAudio.insertTimeRange(range, of: encodedAudio, at: .zero)
        try await passthrough.export(to: destination, as: .mov)
    }

    private func makeVideo(at url: URL, transform: CGAffineTransform, timingMarkers: Bool) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240,
                // Match the SDR camera baseline; untagged SD fixtures permit different matrix inference.
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
                ],
            ])
        input.transform = transform
        if #available(iOS 26, macOS 26, *) {
            let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: nil)
            guard writer.startWriting() else { throw writer.error ?? PrototypeError.invalidMedia }
            writer.startSession(atSourceTime: .zero)
            for frame in 0..<90 {
                try Task.checkCancellation()
                try await receiver.append(
                    CVReadOnlyPixelBuffer(unsafeBuffer: makeFrame(frame, timingMarkers: timingMarkers)),
                    with: CMTime(value: Int64(frame), timescale: 30))
            }
            receiver.finish()
            await writer.finishWriting()
        } else {
            try await legacyWrite(writer: writer, input: input, timingMarkers: timingMarkers)
        }
        guard writer.status == .completed else { throw writer.error ?? PrototypeError.invalidMedia }
    }

    @available(iOS, introduced: 18, deprecated: 26)
    @available(macOS, introduced: 15, deprecated: 26)
    private func legacyWrite(writer: AVAssetWriter, input: AVAssetWriterInput, timingMarkers: Bool) async throws {
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? PrototypeError.invalidMedia }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<90 {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw writer.error ?? PrototypeError.invalidMedia }
                try await Task.sleep(for: .milliseconds(5))
            }
            guard adaptor.append(try makeFrame(frame, timingMarkers: timingMarkers), withPresentationTime: CMTime(value: Int64(frame), timescale: 30))
            else {
                throw writer.error ?? PrototypeError.invalidMedia
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
    }

    private nonisolated func makeFrame(_ frame: Int, timingMarkers: Bool) throws -> sending CVPixelBuffer {
        var value: CVPixelBuffer?
        guard
            CVPixelBufferCreate(
                kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32BGRA,
                nil, &value) == kCVReturnSuccess, let buffer = value
        else { throw PrototypeError.invalidMedia }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw PrototypeError.invalidMedia }
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        for y in 0..<240 {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
            for x in 0..<320 {
                let color: (UInt8, UInt8, UInt8)
                switch (x < 160, y < 120) {
                case (true, true): color = (235, 30, 30)
                case (false, true): color = (30, 220, 30)
                case (true, false): color = (30, 30, 235)
                case (false, false): color = (235, 220, 30)
                }
                let white = y > 225 && x < (frame + 1) * 320 / 90
                row[x * 4] = white ? 255 : color.2
                row[x * 4 + 1] = white ? 255 : color.1
                row[x * 4 + 2] = white ? 255 : color.0
                row[x * 4 + 3] = 255
            }
        }
        if timingMarkers {
            // A three-frame flash coincides with each 100 ms audio pulse. Seven
            // robust binary blocks identify every frame after decoding/cropping.
            func fill(_ rect: CGRect, white: Bool) {
                for y in Int(rect.minY)..<Int(rect.maxY) {
                    let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
                    for x in Int(rect.minX)..<Int(rect.maxX) {
                        for channel in 0..<3 { row[x * 4 + channel] = white ? 255 : 0 }
                    }
                }
            }
            fill(CGRect(x: 148, y: 108, width: 24, height: 24), white: frame % 30 < 3)
            for bit in 0..<7 {
                fill(CGRect(x: 112 + bit * 12, y: 144, width: 10, height: 12), white: frame & (1 << bit) != 0)
            }
            // Human-readable corner and frame labels use a tiny bitmap alphabet
            // so the fixture needs no platform font or rendering dependency.
            let glyphs: [Character: [Int]] = [
                "T": [7,2,2,2,2], "L": [4,4,4,4,7], "R": [6,5,6,5,5],
                "B": [6,5,6,5,6], "F": [7,4,6,4,4],
                "0": [7,5,5,5,7], "1": [2,6,2,2,7], "2": [7,1,7,4,7],
                "3": [7,1,7,1,7], "4": [5,5,7,1,1], "5": [7,4,7,1,7],
                "6": [7,4,7,5,7], "7": [7,1,1,1,1], "8": [7,5,7,5,7], "9": [7,5,7,1,7],
            ]
            func label(_ text: String, x: Int, y: Int) {
                fill(CGRect(x: x - 2, y: y - 2, width: text.count * 8 + 2, height: 14), white: false)
                for (index, letter) in text.enumerated() {
                    for (row, bits) in (glyphs[letter] ?? []).enumerated() {
                        for column in 0..<3 where bits & (1 << (2 - column)) != 0 {
                            fill(CGRect(x: x + index * 8 + column * 2, y: y + row * 2, width: 2, height: 2), white: true)
                        }
                    }
                }
            }
            label("TL", x: 8, y: 8); label("TR", x: 292, y: 8)
            label("BL", x: 8, y: 210); label("BR", x: 292, y: 210)
            label(String(format: "F%02d", frame), x: 148, y: 164)
        }
        return buffer
    }

    private func makeWave() -> Data {
        let sampleCount = 48_000 * 3
        var result = Data()
        func word(_ value: UInt32, bytes: Int) {
            for shift in 0..<bytes { result.append(UInt8((value >> (shift * 8)) & 255)) }
        }
        result.append(contentsOf: "RIFF".utf8)
        word(UInt32(36 + sampleCount * 2), bytes: 4)
        result.append(contentsOf: "WAVEfmt ".utf8)
        word(16, bytes: 4)
        word(1, bytes: 2)
        word(1, bytes: 2)
        word(48_000, bytes: 4)
        word(96_000, bytes: 4)
        word(2, bytes: 2)
        word(16, bytes: 2)
        result.append(contentsOf: "data".utf8)
        word(UInt32(sampleCount * 2), bytes: 4)
        for index in 0..<sampleCount {
            let phase = index % 48_000
            let value = phase < 4_800 ? Int16(sin(Double(index) * 2 * .pi * 880 / 48_000) * 8_000) : 0
            word(UInt32(UInt16(bitPattern: value)), bytes: 2)
        }
        return result
    }
}

/// Synthetic fixtures share the process's finite hardware encoder resources.
/// Serialize their complete writer lifetimes, including across SampleMovie actors.
private actor SampleMovieQueue {
    private var tail: Task<Void, Error>?
    private var tailID: UUID?

    func perform(_ action: @escaping @Sendable () async throws -> Void) async throws {
        let previous = tail, id = UUID()
        let task = Task {
            _ = try? await previous?.value
            try Task.checkCancellation()
            try await action()
        }
        tail = task; tailID = id
        defer { if tailID == id { tail = nil; tailID = nil } }
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: { task.cancel() }
    }
}
