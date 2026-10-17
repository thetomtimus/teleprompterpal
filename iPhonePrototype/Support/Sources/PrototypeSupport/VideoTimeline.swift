import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct TimelineFrame: Identifiable, Sendable {
    public let id: Int
    public let seconds: Double
    public let data: Data
}

public actor VideoTimeline {
    public init() {}

    /// A bounded, downsampled strip. Trim/scrub changes never regenerate it.
    public func frames(source: URL, count: Int = 8) async throws -> [TimelineFrame] {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw PrototypeError.invalidMedia }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let accepted = min(12, max(2, count))
        var result: [TimelineFrame] = []
        for index in 0..<accepted {
            try Task.checkCancellation()
            let seconds = duration * (Double(index) + 0.5) / Double(accepted)
            let frame = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            let buffer = NSMutableData()
            guard let encoder = CGImageDestinationCreateWithData(buffer, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw PrototypeError.invalidMedia
            }
            CGImageDestinationAddImage(encoder, frame.image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
            guard CGImageDestinationFinalize(encoder), buffer.length <= 128 * 1024 else {
                throw PrototypeError.invalidMedia
            }
            result.append(.init(id: index, seconds: frame.actualTime.seconds, data: buffer as Data))
        }
        return result
    }
}
