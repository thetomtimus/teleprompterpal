import Foundation

public enum ReadingPositionAdjustmentReason: Equatable, Sendable {
    case editTouchesAnchor
    case invalidEdit
    case contextNotFound
    case ambiguousContext
}

public struct ReadingPositionMapping: Equatable, Sendable {
    public let anchor: ReadingAnchor
    public let requiresPause: Bool
    public let reason: ReadingPositionAdjustmentReason?

    public init(
        anchor: ReadingAnchor,
        requiresPause: Bool,
        reason: ReadingPositionAdjustmentReason?
    ) {
        self.anchor = anchor
        self.requiresPause = requiresPause
        self.reason = reason
    }
}

public enum ReadingPositionMapper {
    public static func map(
        anchor: ReadingAnchor,
        editedRangeUTF16: NSRange,
        replacement: String,
        preEditDocument: String,
        postEditDocument: String
    ) -> ReadingPositionMapping {
        let normalizedAnchor = normalizedOffsetBackward(
            anchor.utf16Offset,
            in: preEditDocument
        )
        guard
            let edit = validatedEdit(
                range: editedRangeUTF16,
                replacement: replacement,
                preEditDocument: preEditDocument,
                postEditDocument: postEditDocument
            )
        else {
            return invalidMapping(
                anchor: anchor,
                normalizedPreEditOffset: normalizedAnchor,
                postEditDocument: postEditDocument
            )
        }

        let mappedOffset: Int
        let requiresPause: Bool

        if edit.length == 0, edit.location < normalizedAnchor {
            guard let shifted = adding(normalizedAnchor, edit.replacementLength) else {
                return invalidMapping(
                    anchor: anchor,
                    normalizedPreEditOffset: normalizedAnchor,
                    postEditDocument: postEditDocument
                )
            }
            mappedOffset = shifted
            requiresPause = false
        } else if edit.length == 0, edit.location == normalizedAnchor {
            mappedOffset = edit.location
            requiresPause = true
        } else if edit.length > 0, edit.upperBound <= normalizedAnchor {
            guard let shifted = adding(normalizedAnchor, edit.lengthDelta) else {
                return invalidMapping(
                    anchor: anchor,
                    normalizedPreEditOffset: normalizedAnchor,
                    postEditDocument: postEditDocument
                )
            }
            mappedOffset = shifted
            requiresPause = false
        } else if edit.location > normalizedAnchor {
            mappedOffset = normalizedAnchor
            requiresPause = false
        } else {
            mappedOffset = edit.location
            requiresPause = true
        }

        return mapping(
            offset: mappedOffset,
            viewportFraction: anchor.viewportFraction,
            document: postEditDocument,
            requiresPause: requiresPause,
            reason: requiresPause ? .editTouchesAnchor : nil
        )
    }

    public static func recover(
        anchor: ReadingAnchor,
        in document: String
    ) -> ReadingPositionMapping {
        let documentUnits = Array(document.utf16)
        let beforeContextUnits = boundedContextSuffix(anchor.contextBefore)
        let afterContextUnits = boundedContextPrefix(anchor.contextAfter)
        let fallbackOffset = normalizedOffsetBackward(anchor.utf16Offset, in: documentUnits)
        var bestCandidates: [ContextCandidate] = []

        for boundary in scalarBoundaries(in: documentUnits) {
            let candidate = contextCandidate(
                at: boundary,
                beforeContextUnits: beforeContextUnits,
                afterContextUnits: afterContextUnits,
                documentUnits: documentUnits
            )
            guard candidate.matchedSides > 0 else { continue }

            guard let currentBest = bestCandidates.first else {
                bestCandidates = [candidate]
                continue
            }
            if candidate.isSemanticallyBetter(than: currentBest) {
                bestCandidates = [candidate]
            } else if candidate.hasEqualSemanticScore(to: currentBest) {
                bestCandidates.append(candidate)
            }
        }

        guard !bestCandidates.isEmpty else {
            return mapping(
                offset: fallbackOffset,
                viewportFraction: anchor.viewportFraction,
                documentUnits: documentUnits,
                requiresPause: true,
                reason: .contextNotFound
            )
        }

        let minimumDistance = bestCandidates.map { distance($0.offset, fallbackOffset) }.min()
        guard let minimumDistance else {
            return mapping(
                offset: fallbackOffset,
                viewportFraction: anchor.viewportFraction,
                documentUnits: documentUnits,
                requiresPause: true,
                reason: .contextNotFound
            )
        }
        let nearest = bestCandidates.filter {
            distance($0.offset, fallbackOffset) == minimumDistance
        }
        guard nearest.count == 1, let winner = nearest.first else {
            return mapping(
                offset: fallbackOffset,
                viewportFraction: anchor.viewportFraction,
                documentUnits: documentUnits,
                requiresPause: true,
                reason: .ambiguousContext
            )
        }

        return mapping(
            offset: winner.offset,
            viewportFraction: anchor.viewportFraction,
            documentUnits: documentUnits,
            requiresPause: false,
            reason: nil
        )
    }

    public static func restoredOffset(
        anchorY: Double,
        clipHeight: Double,
        viewportFraction: Double,
        maximumOffset: Double
    ) -> Double {
        let acceptedMaximum =
            maximumOffset.isFinite && maximumOffset >= 0
            ? maximumOffset
            : 0
        let acceptedAnchorY = anchorY.isFinite ? anchorY : 0
        let acceptedClipHeight = clipHeight.isFinite && clipHeight >= 0 ? clipHeight : 0
        let acceptedFraction =
            viewportFraction.isFinite
            ? min(max(viewportFraction, 0), 1)
            : 0.5
        let proposedOffset = acceptedAnchorY - acceptedClipHeight * acceptedFraction
        guard proposedOffset.isFinite else {
            return proposedOffset.sign == .minus ? 0 : acceptedMaximum
        }
        return min(max(proposedOffset, 0), acceptedMaximum)
    }

    private static func validatedEdit(
        range: NSRange,
        replacement: String,
        preEditDocument: String,
        postEditDocument: String
    ) -> ValidatedEdit? {
        guard range.location >= 0, range.length >= 0 else { return nil }
        let (upperBound, rangeOverflow) = range.location.addingReportingOverflow(range.length)
        guard !rangeOverflow else { return nil }

        let preEditUnits = Array(preEditDocument.utf16)
        let postEditUnits = Array(postEditDocument.utf16)
        let replacementUnits = Array(replacement.utf16)
        guard upperBound <= preEditUnits.count else { return nil }
        guard isScalarBoundary(range.location, in: preEditUnits) else { return nil }
        guard isScalarBoundary(upperBound, in: preEditUnits) else { return nil }

        let (lengthDelta, deltaOverflow) = replacementUnits.count
            .subtractingReportingOverflow(range.length)
        guard !deltaOverflow else { return nil }
        let (expectedPostLength, lengthOverflow) = preEditUnits.count
            .addingReportingOverflow(lengthDelta)
        guard !lengthOverflow, expectedPostLength == postEditUnits.count else { return nil }

        var expectedPostUnits: [UInt16] = []
        expectedPostUnits.reserveCapacity(expectedPostLength)
        expectedPostUnits.append(contentsOf: preEditUnits[..<range.location])
        expectedPostUnits.append(contentsOf: replacementUnits)
        expectedPostUnits.append(contentsOf: preEditUnits[upperBound...])
        guard expectedPostUnits == postEditUnits else { return nil }

        return ValidatedEdit(
            location: range.location,
            length: range.length,
            upperBound: upperBound,
            replacementLength: replacementUnits.count,
            lengthDelta: lengthDelta
        )
    }

    private static func invalidMapping(
        anchor: ReadingAnchor,
        normalizedPreEditOffset: Int,
        postEditDocument: String
    ) -> ReadingPositionMapping {
        let postEditUnits = Array(postEditDocument.utf16)
        return mapping(
            offset: normalizedOffsetBackward(normalizedPreEditOffset, in: postEditUnits),
            viewportFraction: anchor.viewportFraction,
            documentUnits: postEditUnits,
            requiresPause: true,
            reason: .invalidEdit
        )
    }

    private static func mapping(
        offset: Int,
        viewportFraction: Double,
        document: String,
        requiresPause: Bool,
        reason: ReadingPositionAdjustmentReason?
    ) -> ReadingPositionMapping {
        mapping(
            offset: offset,
            viewportFraction: viewportFraction,
            documentUnits: Array(document.utf16),
            requiresPause: requiresPause,
            reason: reason
        )
    }

    private static func mapping(
        offset: Int,
        viewportFraction: Double,
        documentUnits: [UInt16],
        requiresPause: Bool,
        reason: ReadingPositionAdjustmentReason?
    ) -> ReadingPositionMapping {
        let scalarOffset = normalizedOffsetBackward(offset, in: documentUnits)
        let contexts = contexts(around: scalarOffset, in: documentUnits)
        return ReadingPositionMapping(
            anchor: ReadingAnchor(
                utf16Offset: scalarOffset,
                contextBefore: contexts.before,
                contextAfter: contexts.after,
                viewportFraction: viewportFraction
            ),
            requiresPause: requiresPause,
            reason: reason
        )
    }

    private static func contexts(
        around offset: Int,
        in units: [UInt16]
    ) -> (before: String, after: String) {
        let limit = ReadingAnchor.maximumContextUTF16Length

        var beforeStart = max(0, offset - limit)
        if beforeStart < offset, isLowSurrogate(units[beforeStart]) {
            beforeStart += 1
        }
        var afterEnd = min(units.count, offset + limit)
        if afterEnd > offset, isHighSurrogate(units[afterEnd - 1]) {
            afterEnd -= 1
        }

        return (
            String(decoding: units[beforeStart..<offset], as: UTF16.self),
            String(decoding: units[offset..<afterEnd], as: UTF16.self)
        )
    }

    private static func contextCandidate(
        at boundary: Int,
        beforeContextUnits: [UInt16],
        afterContextUnits: [UInt16],
        documentUnits: [UInt16]
    ) -> ContextCandidate {
        let beforeMatch = matchingSuffixUTF16Length(
            beforeContextUnits,
            in: documentUnits,
            endingAt: boundary
        )
        let afterMatch = matchingPrefixUTF16Length(
            afterContextUnits,
            in: documentUnits,
            startingAt: boundary
        )
        let beforeLength = beforeContextUnits.count
        let afterLength = afterContextUnits.count
        let beforeMatched = beforeMatch > 0
        let afterMatched = afterMatch > 0

        return ContextCandidate(
            offset: boundary,
            isExactTwoSided: beforeLength > 0
                && afterLength > 0
                && beforeMatch == beforeLength
                && afterMatch == afterLength,
            matchedSides: (beforeMatched ? 1 : 0) + (afterMatched ? 1 : 0),
            totalMatchedUTF16Length: beforeMatch + afterMatch
        )
    }

    private static func boundedContextSuffix(_ context: String) -> [UInt16] {
        let units = Array(context.utf16)
        let limit = ReadingAnchor.maximumContextUTF16Length
        guard units.count > limit else { return units }

        var start = units.count - limit
        if isLowSurrogate(units[start]) {
            start += 1
        }
        return Array(units[start...])
    }

    private static func boundedContextPrefix(_ context: String) -> [UInt16] {
        let units = Array(context.utf16)
        let limit = ReadingAnchor.maximumContextUTF16Length
        guard units.count > limit else { return units }

        var end = limit
        if isHighSurrogate(units[end - 1]) {
            end -= 1
        }
        return Array(units[..<end])
    }

    private static func matchingSuffixUTF16Length(
        _ expected: [UInt16],
        in document: [UInt16],
        endingAt boundary: Int
    ) -> Int {
        var expectedEnd = expected.count
        var documentEnd = boundary
        var matchedLength = 0

        while expectedEnd > 0, documentEnd > 0 {
            let expectedStart = previousScalarStart(before: expectedEnd, in: expected)
            let documentStart = previousScalarStart(before: documentEnd, in: document)
            guard expectedEnd - expectedStart == documentEnd - documentStart else { break }
            guard
                expected[expectedStart..<expectedEnd]
                    .elementsEqual(document[documentStart..<documentEnd])
            else { break }

            matchedLength += expectedEnd - expectedStart
            expectedEnd = expectedStart
            documentEnd = documentStart
        }
        return matchedLength
    }

    private static func matchingPrefixUTF16Length(
        _ expected: [UInt16],
        in document: [UInt16],
        startingAt boundary: Int
    ) -> Int {
        var expectedStart = 0
        var documentStart = boundary
        var matchedLength = 0

        while expectedStart < expected.count, documentStart < document.count {
            let expectedEnd = nextScalarEnd(after: expectedStart, in: expected)
            let documentEnd = nextScalarEnd(after: documentStart, in: document)
            guard expectedEnd - expectedStart == documentEnd - documentStart else { break }
            guard
                expected[expectedStart..<expectedEnd]
                    .elementsEqual(document[documentStart..<documentEnd])
            else { break }

            matchedLength += expectedEnd - expectedStart
            expectedStart = expectedEnd
            documentStart = documentEnd
        }
        return matchedLength
    }

    private static func scalarBoundaries(in units: [UInt16]) -> [Int] {
        return (0...units.count).filter { isScalarBoundary($0, in: units) }
    }

    private static func normalizedOffsetBackward(_ offset: Int, in document: String) -> Int {
        normalizedOffsetBackward(offset, in: Array(document.utf16))
    }

    private static func normalizedOffsetBackward(_ offset: Int, in units: [UInt16]) -> Int {
        var result = min(max(offset, 0), units.count)
        if result < units.count, isLowSurrogate(units[result]) {
            result -= 1
        }
        return result
    }

    private static func previousScalarStart(before end: Int, in units: [UInt16]) -> Int {
        let lastUnit = end - 1
        if isLowSurrogate(units[lastUnit]), lastUnit > 0,
            isHighSurrogate(units[lastUnit - 1])
        {
            return lastUnit - 1
        }
        return lastUnit
    }

    private static func nextScalarEnd(after start: Int, in units: [UInt16]) -> Int {
        if isHighSurrogate(units[start]), start + 1 < units.count,
            isLowSurrogate(units[start + 1])
        {
            return start + 2
        }
        return start + 1
    }

    private static func isScalarBoundary(_ offset: Int, in units: [UInt16]) -> Bool {
        guard (0...units.count).contains(offset) else { return false }
        return offset == units.count || !isLowSurrogate(units[offset])
    }

    private static func isHighSurrogate(_ unit: UInt16) -> Bool {
        (0xD800...0xDBFF).contains(unit)
    }

    private static func isLowSurrogate(_ unit: UInt16) -> Bool {
        (0xDC00...0xDFFF).contains(unit)
    }

    private static func adding(_ left: Int, _ right: Int) -> Int? {
        let (result, overflow) = left.addingReportingOverflow(right)
        return overflow ? nil : result
    }

    private static func distance(_ left: Int, _ right: Int) -> Int {
        left >= right ? left - right : right - left
    }
}

private struct ValidatedEdit {
    let location: Int
    let length: Int
    let upperBound: Int
    let replacementLength: Int
    let lengthDelta: Int
}

private struct ContextCandidate {
    let offset: Int
    let isExactTwoSided: Bool
    let matchedSides: Int
    let totalMatchedUTF16Length: Int

    func isSemanticallyBetter(than other: ContextCandidate) -> Bool {
        if isExactTwoSided != other.isExactTwoSided {
            return isExactTwoSided
        }
        if matchedSides != other.matchedSides {
            return matchedSides > other.matchedSides
        }
        return totalMatchedUTF16Length > other.totalMatchedUTF16Length
    }

    func hasEqualSemanticScore(to other: ContextCandidate) -> Bool {
        isExactTwoSided == other.isExactTwoSided
            && matchedSides == other.matchedSides
            && totalMatchedUTF16Length == other.totalMatchedUTF16Length
    }
}
