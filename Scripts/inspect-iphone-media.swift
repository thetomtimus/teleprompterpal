import AVFoundation
import Foundation

/// Local-only P1 inspection. Requires a macOS 26+ host; no media is sent to a service.
@main struct IPhoneMediaInspector {
    struct Report: Codable {
        var duration: Double
        var width: Int
        var height: Int
        var videoCodec: String
        var frames: Int
        var measuredFPS: Double
        var maximumFrameGapSeconds: Double
        var videoFirstPTS: Double
        var videoLastPTS: Double
        var audioFirstPTS: Double
        var audioLastEndPTS: Double
        var audioRMS: Double
        var audioPeak: Double
        var loudestAudioTimes: [Double]
        var startAudioPeakTimes: [Double]
        var endAudioPeakTimes: [Double]
        var fileBytes: Int64
    }

    static func main() async throws {
        guard #available(macOS 26, *) else { throw InspectError.requiresNewHost }
        guard CommandLine.arguments.count == 2 else { throw InspectError.usage }
        let report = try await inspect(URL(fileURLWithPath: CommandLine.arguments[1]))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    }

    @available(macOS 26, *)
    static func inspect(_ url: URL) async throws -> Report {
        let asset = AVURLAsset(url: url)
        guard let video = try await asset.loadTracks(withMediaType: .video).first,
            let audio = try await asset.loadTracks(withMediaType: .audio).first
        else { throw InspectError.invalidMedia }
        let duration = try await asset.load(.duration).seconds
        let size = try await video.load(.naturalSize)
        let transform = try await video.load(.preferredTransform)
        let rect = CGRect(origin: .zero, size: size).applying(transform).standardized
        let descriptions = try await video.load(.formatDescriptions)
        let codec = descriptions.first.map { CMFormatDescriptionGetMediaSubType($0) } ?? 0
        let codecName =
            String(bytes: (0..<4).map { UInt8((codec >> ((3 - $0) * 8)) & 255) }, encoding: .ascii) ?? "unknown"
        let videoReader = try AVAssetReader(asset: asset)
        let videoOutput = AVAssetReaderTrackOutput(track: video, outputSettings: nil)
        let videoProvider = videoReader.outputProvider(for: videoOutput)
        try videoReader.start()
        var times: [Double] = []
        while let sample = try await videoProvider.next() {
            // Output providers also deliver zero-sample control/marker buffers.
            guard sample.withUnsafeSampleBuffer({ CMSampleBufferGetNumSamples($0) }) > 0 else { continue }
            times.append(sample.presentationTimeStamp.seconds)
        }
        guard videoReader.status == .completed, times.count > 1, times.allSatisfy(\.isFinite) else {
            throw InspectError.invalidMedia
        }
        times.sort()  // Compressed H.264 samples may arrive in decode order when B frames are present.
        let first = times[0]
        let last = times[times.count - 1]
        guard last > first else { throw InspectError.invalidMedia }
        let gaps = zip(times.dropFirst(), times).map(-)
        let audioReader = try AVAssetReader(asset: asset)
        let audioOutput = AVAssetReaderTrackOutput(
            track: audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true, AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 1,
            ])
        let audioProvider = audioReader.outputProvider(for: audioOutput)
        try audioReader.start()
        var audioFirst: Double?
        var audioLast = 0.0
        var squareSum = 0.0
        var peak = 0.0
        var sampleCount = 0
        var peaks: [(Double, Double)] = []
        while let sample = try await audioProvider.next() {
            guard sample.withUnsafeSampleBuffer({ CMSampleBufferGetNumSamples($0) }) > 0 else { continue }
            let time = sample.presentationTimeStamp.seconds
            if audioFirst == nil { audioFirst = time }
            audioLast = time + sample.duration.seconds
            let localPeak = try sample.withUnsafeSampleBuffer { buffer -> (Double, Int) in
                guard let block = CMSampleBufferGetDataBuffer(buffer) else { throw InspectError.invalidMedia }
                let count = CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size
                var values = [Float](repeating: 0, count: count)
                let status = values.withUnsafeMutableBytes {
                    CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count * 4, destination: $0.baseAddress!)
                }
                guard status == kCMBlockBufferNoErr else { throw InspectError.invalidMedia }
                var result = 0.0
                var peakIndex = 0
                for (index, value) in values.enumerated() where value.isFinite {
                    let value = Double(value)
                    squareSum += value * value
                    sampleCount += 1
                    if abs(value) > result {
                        result = abs(value)
                        peakIndex = index
                    }
                }
                return (result, peakIndex)
            }
            peak = max(peak, localPeak.0)
            // Mono 48 kHz output: locate an impulse within its buffer instead of rounding to buffer PTS.
            peaks.append((time + Double(localPeak.1) / 48_000, localPeak.0))
        }
        guard audioReader.status == .completed, let audioFirst, sampleCount > 0 else { throw InspectError.invalidMedia }
        let loudTimes = peakTimes(peaks, limit: 12)
        let startTimes = peakTimes(peaks.filter { $0.0 < 15 }, limit: 4)
        let endTimes = peakTimes(peaks.filter { $0.0 > duration - 15 }, limit: 4)
        let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        return Report(
            duration: duration, width: Int(rect.width.rounded()), height: Int(rect.height.rounded()),
            videoCodec: codecName, frames: times.count, measuredFPS: Double(times.count - 1) / (last - first),
            maximumFrameGapSeconds: gaps.max() ?? 0, videoFirstPTS: first, videoLastPTS: last,
            audioFirstPTS: audioFirst, audioLastEndPTS: audioLast, audioRMS: sqrt(squareSum / Double(sampleCount)),
            audioPeak: peak, loudestAudioTimes: loudTimes, startAudioPeakTimes: startTimes,
            endAudioPeakTimes: endTimes, fileBytes: bytes)
    }

    static func peakTimes(_ candidates: [(Double, Double)], limit: Int) -> [Double] {
        let peak = candidates.map(\.1).max() ?? 0
        var result: [Double] = []
        for entry in candidates.sorted(by: { $0.1 > $1.1 }) where entry.1 > peak * 0.25 {
            if result.allSatisfy({ abs($0 - entry.0) > 0.3 }) { result.append(entry.0) }
            if result.count == limit { break }
        }
        return result.sorted()
    }

    enum InspectError: Error { case requiresNewHost, usage, invalidMedia }
}
