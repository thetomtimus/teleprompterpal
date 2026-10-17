import CoreGraphics
import Foundation

public enum CropPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case original, portrait, landscape, square, fourByFive, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .original: "Original"
        case .portrait: "9:16"
        case .landscape: "16:9"
        case .square: "1:1"
        case .fourByFive: "4:5"
        case .custom: "Custom"
        }
    }
    public var ratio: Double? {
        switch self {
        case .portrait: 9.0 / 16
        case .landscape: 16.0 / 9
        case .square: 1
        case .fourByFive: 4.0 / 5
        case .original, .custom: nil
        }
    }
}

public enum CropCorner: String, CaseIterable, Identifiable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight
    public var id: String { rawValue }
}

/// Crop coordinates use the upright, preferred-transform-normalized source.
public struct CropSelection: Equatable, Sendable {
    public let sourceSize: CGSize
    public private(set) var crop: NormalizedCrop
    public private(set) var preset: CropPreset

    public init(sourceSize: CGSize, crop: NormalizedCrop = .init(), preset: CropPreset? = nil) throws {
        guard sourceSize.width >= 2, sourceSize.height >= 2 else { throw PrototypeError.invalidRecipe }
        _ = try CropGeometry(naturalSize: sourceSize, preferredTransform: .identity, crop: crop)
        self.sourceSize = sourceSize; self.crop = crop
        self.preset = preset ?? (crop == .init() ? .original : .custom)
    }

    public var geometry: CropGeometry {
        // Every mutator maintains the same finite, >=2-pixel rectangle invariant.
        try! CropGeometry(naturalSize: sourceSize, preferredTransform: .identity, crop: crop)
    }
    public var horizontalPosition: Double { crop.width < 1 ? crop.x / (1 - crop.width) : 0.5 }
    public var verticalPosition: Double { crop.height < 1 ? crop.y / (1 - crop.height) : 0.5 }

    public mutating func select(_ value: CropPreset) {
        let candidate = value == .original ? NormalizedCrop()
            : value.ratio.map { NormalizedCrop.centered(ratio: $0, in: sourceSize) } ?? crop
        guard accepts(candidate) else { return }
        preset = value; crop = candidate
    }

    public mutating func move(from origin: NormalizedCrop, by translation: CGSize) {
        guard translation.width.isFinite, translation.height.isFinite else { return }
        var candidate = crop
        candidate.x = min(max(0, origin.x + translation.width), 1 - crop.width)
        candidate.y = min(max(0, origin.y + translation.height), 1 - crop.height)
        if accepts(candidate) { crop = candidate }
    }

    public mutating func position(horizontal: Double? = nil, vertical: Double? = nil) {
        var candidate = crop
        if let horizontal, horizontal.isFinite { candidate.x = min(1, max(0, horizontal)) * (1 - crop.width) }
        if let vertical, vertical.isFinite { candidate.y = min(1, max(0, vertical)) * (1 - crop.height) }
        if accepts(candidate) { crop = candidate }
    }

    public mutating func resize(_ corner: CropCorner, from origin: NormalizedCrop, by translation: CGSize) {
        guard preset == .custom, translation.width.isFinite, translation.height.isFinite else { return }
        let minimumWidth = 2 / sourceSize.width, minimumHeight = 2 / sourceSize.height
        var left = origin.x, top = origin.y, right = origin.x + origin.width, bottom = origin.y + origin.height
        switch corner {
        case .topLeft, .bottomLeft: left = min(max(0, left + translation.width), right - minimumWidth)
        case .topRight, .bottomRight: right = max(min(1, right + translation.width), left + minimumWidth)
        }
        switch corner {
        case .topLeft, .topRight: top = min(max(0, top + translation.height), bottom - minimumHeight)
        case .bottomLeft, .bottomRight: bottom = max(min(1, bottom + translation.height), top + minimumHeight)
        }
        let candidate = NormalizedCrop(x: left, y: top, width: right - left, height: bottom - top)
        if accepts(candidate) { crop = candidate }
    }

    public mutating func size(width: Double? = nil, height: Double? = nil) {
        guard preset == .custom else { return }
        var candidate = crop
        let center = CGPoint(x: crop.x + crop.width / 2, y: crop.y + crop.height / 2)
        if let width, width.isFinite { candidate.width = min(1, max(2 / sourceSize.width, width)) }
        if let height, height.isFinite { candidate.height = min(1, max(2 / sourceSize.height, height)) }
        candidate.x = min(max(0, center.x - candidate.width / 2), 1 - candidate.width)
        candidate.y = min(max(0, center.y - candidate.height / 2), 1 - candidate.height)
        if accepts(candidate) { crop = candidate }
    }

    private func accepts(_ candidate: NormalizedCrop) -> Bool {
        (try? CropGeometry(naturalSize: sourceSize, preferredTransform: .identity, crop: candidate)) != nil
    }
}

/// The visible viewport and the full source layer share the export's integral
/// pixel rectangle. Native AVPlayer decoding applies the preferred transform.
public struct CropPreviewLayout: Sendable {
    public let viewport: CGRect
    public let sourceFrame: CGRect

    public init(sourceSize: CGSize, crop: NormalizedCrop, available: CGSize) throws {
        let geometry = try CropGeometry(naturalSize: sourceSize, preferredTransform: .identity, crop: crop)
        guard available.width.isFinite, available.height.isFinite, available.width > 0, available.height > 0 else {
            throw PrototypeError.invalidRecipe
        }
        let rect = geometry.sourceRect
        let scale = min(available.width / rect.width, available.height / rect.height)
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        viewport = CGRect(x: (available.width - size.width) / 2, y: (available.height - size.height) / 2,
                          width: size.width, height: size.height)
        sourceFrame = CGRect(x: -rect.minX * scale, y: -rect.minY * scale,
                             width: sourceSize.width * scale, height: sourceSize.height * scale)
    }
}
