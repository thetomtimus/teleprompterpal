import Foundation

public struct ReadingAnchor: Codable, Equatable, Sendable {
    public static let maximumContextUTF16Length = 64

    public var utf16Offset: Int
    public var contextBefore: String
    public var contextAfter: String
    public var viewportFraction: Double

    public init(
        utf16Offset: Int = 0,
        contextBefore: String = "",
        contextAfter: String = "",
        viewportFraction: Double = 0.5,
        document: String? = nil
    ) {
        self.utf16Offset = Self.clampedOffset(utf16Offset, document: document)
        self.contextBefore = Self.contextSuffix(contextBefore)
        self.contextAfter = Self.contextPrefix(contextAfter)
        self.viewportFraction = Self.clampedViewportFraction(viewportFraction)
    }

    public func clamped(to document: String) -> ReadingAnchor {
        ReadingAnchor(
            utf16Offset: utf16Offset,
            contextBefore: contextBefore,
            contextAfter: contextAfter,
            viewportFraction: viewportFraction,
            document: document
        )
    }

    public static func capture(offset: Int, in document: String, viewportFraction: Double = 0) -> ReadingAnchor {
        let units = Array(document.utf16)
        var index = min(max(offset, 0), units.count)
        if index > 0, index < units.count, isLowSurrogate(units[index]), isHighSurrogate(units[index - 1]) {
            index -= 1
        }
        var start = max(0, index - maximumContextUTF16Length)
        if start < index, isLowSurrogate(units[start]) { start += 1 }
        var end = min(units.count, index + maximumContextUTF16Length)
        if end > index, isHighSurrogate(units[end - 1]) { end -= 1 }
        return .init(
            utf16Offset: index,
            contextBefore: String(decoding: units[start..<index], as: UTF16.self),
            contextAfter: String(decoding: units[index..<end], as: UTF16.self),
            viewportFraction: viewportFraction, document: document)
    }

    private enum CodingKeys: String, CodingKey {
        case utf16Offset
        case contextBefore
        case contextAfter
        case viewportFraction
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            utf16Offset: try container.decode(Int.self, forKey: .utf16Offset),
            contextBefore: try container.decode(String.self, forKey: .contextBefore),
            contextAfter: try container.decode(String.self, forKey: .contextAfter),
            viewportFraction: try container.decode(Double.self, forKey: .viewportFraction)
        )
    }

    private static func clampedOffset(_ offset: Int, document: String?) -> Int {
        let nonnegative = max(0, offset)
        guard let document else { return nonnegative }
        return min(nonnegative, document.utf16.count)
    }

    private static func clampedViewportFraction(_ fraction: Double) -> Double {
        guard fraction.isFinite else { return 0.5 }
        return min(max(fraction, 0), 1)
    }

    private static func contextPrefix(_ context: String) -> String {
        let units = Array(context.utf16)
        guard units.count > maximumContextUTF16Length else { return context }
        var end = maximumContextUTF16Length
        if end > 0, isHighSurrogate(units[end - 1]) {
            end -= 1
        }
        return String(decoding: units[..<end], as: UTF16.self)
    }

    private static func contextSuffix(_ context: String) -> String {
        let units = Array(context.utf16)
        guard units.count > maximumContextUTF16Length else { return context }
        var start = units.count - maximumContextUTF16Length
        if start < units.count, isLowSurrogate(units[start]) {
            start += 1
        }
        return String(decoding: units[start...], as: UTF16.self)
    }

    private static func isHighSurrogate(_ unit: UInt16) -> Bool {
        (0xD800...0xDBFF).contains(unit)
    }

    private static func isLowSurrogate(_ unit: UInt16) -> Bool {
        (0xDC00...0xDFFF).contains(unit)
    }
}
