import CoreGraphics
import Foundation

public enum PrototypeError: Error, LocalizedError, Equatable, Sendable {
    case invalidRecipe
    case invalidMedia
    case exportUnavailable
    case busy
    case insufficientSpace

    public var errorDescription: String? {
        switch self {
        case .invalidRecipe: "Choose a nonempty trim and a crop inside the video."
        case .invalidMedia: "This file does not contain playable video and audio."
        case .exportUnavailable: "MP4 export is unavailable for this video."
        case .busy: "Wait for the current operation to finish."
        case .insufficientSpace: "Free more space before recording or exporting."
        }
    }
}

public struct MediaTime: Codable, Equatable, Sendable {
    public var value: Int64
    public var timescale: Int32

    public init(seconds: Double) {
        timescale = 600
        value =
            seconds.isFinite && abs(seconds) < 1_000_000
            ? Int64((seconds * 600).rounded()) : -1
    }

    public var seconds: Double { timescale > 0 ? Double(value) / Double(timescale) : .nan }
}

public struct NormalizedCrop: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 0, y: Double = 0, width: Double = 1, height: Double = 1) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite)
            && x >= 0 && y >= 0 && width > 0 && height > 0
            && x + width <= 1.000_001 && y + height <= 1.000_001
    }

    public static func centered(ratio: Double, in size: CGSize) -> Self {
        guard ratio.isFinite, ratio > 0, size.width > 0, size.height > 0 else { return .init() }
        let sourceRatio = Double(size.width / size.height)
        if sourceRatio > ratio {
            let width = ratio / sourceRatio
            return .init(x: (1 - width) / 2, width: width)
        }
        let height = sourceRatio / ratio
        return .init(y: (1 - height) / 2, height: height)
    }
}

public struct EditRecipe: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var start: MediaTime
    public var end: MediaTime
    public var crop: NormalizedCrop
    public var cropPreset: CropPreset?

    public init(start: Double = 0, end: Double, crop: NormalizedCrop = .init(), cropPreset: CropPreset? = nil) {
        self.start = MediaTime(seconds: start)
        self.end = MediaTime(seconds: end)
        self.crop = crop
        self.cropPreset = cropPreset
    }

    public func validate(duration: Double) throws {
        guard schemaVersion == 1, duration.isFinite, duration > 0,
            start.seconds.isFinite, end.seconds.isFinite,
            start.seconds >= 0, end.seconds > start.seconds,
            end.seconds <= duration + 1.0 / 600, crop.isValid
        else {
            throw PrototypeError.invalidRecipe
        }
    }
}

public struct CropGeometry: Sendable {
    public let renderSize: CGSize
    public let transform: CGAffineTransform
    public let sourceRect: CGRect

    public init(naturalSize: CGSize, preferredTransform: CGAffineTransform, crop: NormalizedCrop) throws {
        let bounds = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform).standardized
        guard crop.isValid, bounds.width.isFinite, bounds.height.isFinite,
            bounds.width >= 2, bounds.height >= 2
        else { throw PrototypeError.invalidRecipe }
        // One integral rectangle supplies both the composition and export dimensions.
        let width = floor(bounds.width * crop.width / 2) * 2
        let height = floor(bounds.height * crop.height / 2) * 2
        guard width >= 2, height >= 2 else { throw PrototypeError.invalidRecipe }
        let x = min(floor(bounds.width * crop.x), bounds.width - width)
        let y = min(floor(bounds.height * crop.y), bounds.height - height)
        sourceRect = CGRect(x: x, y: y, width: width, height: height)
        renderSize = sourceRect.size
        transform = preferredTransform.concatenating(
            CGAffineTransform(translationX: -bounds.minX - x, y: -bounds.minY - y)
        )
    }
}
