import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Extracts local decoded camera frames for P1 framing/sync inspection. No upload or telemetry.
@main struct IPhoneFrameExtractor {
    static func main() async throws {
        guard CommandLine.arguments.count >= 4 else { throw FrameError.usage }
        let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 960, height: 960)
        for value in CommandLine.arguments.dropFirst(3) {
            guard let seconds = Double(value), seconds.isFinite, seconds >= 0 else { throw FrameError.usage }
            let result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            let path = directory.appendingPathComponent(String(format: "frame-%09.3f.png", seconds))
            guard
                let destination = CGImageDestinationCreateWithURL(
                    path as CFURL, UTType.png.identifier as CFString, 1, nil)
            else { throw FrameError.writeFailed }
            CGImageDestinationAddImage(destination, result.image, nil)
            guard CGImageDestinationFinalize(destination) else { throw FrameError.writeFailed }
            print("\(path.path): actual PTS \(result.actualTime.seconds)")
        }
    }

    enum FrameError: Error { case usage, writeFailed }
}
