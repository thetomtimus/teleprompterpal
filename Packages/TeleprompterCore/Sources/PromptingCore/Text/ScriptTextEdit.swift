import Foundation

public struct UTF16TextRange: Equatable, Hashable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public enum ScriptTextEditError: Error, Equatable, Sendable {
    case arithmeticOverflow
    case invalidRevision
    case invalidRange
    case inconsistentLength
    case replacementMismatch
}

public struct ScriptTextEdit: Equatable, Sendable {
    public let range: UTF16TextRange
    public let replacement: String
    public let changeInLength: Int
    public let baseUTF16Length: Int
    public let resultUTF16Length: Int
    public let baseRevision: UInt64
    public let revision: UInt64

    public init(
        range: UTF16TextRange, replacement: String, changeInLength: Int, baseUTF16Length: Int,
        resultUTF16Length: Int, baseRevision: UInt64, revision: UInt64
    ) {
        self.range = range
        self.replacement = replacement
        self.changeInLength = changeInLength
        self.baseUTF16Length = baseUTF16Length
        self.resultUTF16Length = resultUTF16Length
        self.baseRevision = baseRevision
        self.revision = revision
    }

    public static func replacing(
        in baseText: String,
        range: UTF16TextRange,
        with replacement: String,
        baseRevision: UInt64
    ) throws -> ScriptTextEdit {
        guard baseRevision != UInt64.max else { throw ScriptTextEditError.arithmeticOverflow }
        try validate(range: range, in: baseText)
        let replacementLength = replacement.utf16.count
        let (changeInLength, deltaOverflow) = replacementLength.subtractingReportingOverflow(
            range.length
        )
        guard !deltaOverflow else { throw ScriptTextEditError.arithmeticOverflow }
        let (resultLength, resultOverflow) = baseText.utf16.count.addingReportingOverflow(
            changeInLength
        )
        guard !resultOverflow, resultLength >= 0 else {
            throw ScriptTextEditError.arithmeticOverflow
        }
        return ScriptTextEdit(
            range: range,
            replacement: replacement,
            changeInLength: changeInLength,
            baseUTF16Length: baseText.utf16.count,
            resultUTF16Length: resultLength,
            baseRevision: baseRevision,
            revision: baseRevision + 1
        )
    }

    /// Minimal replacement between committed native-editor values, preserving scalar boundaries.
    public static func difference(from old: String, to new: String, baseRevision: UInt64) throws -> ScriptTextEdit {
        let before = Array(old.utf16)
        let after = Array(new.utf16)
        var prefix = 0
        while prefix < min(before.count, after.count), before[prefix] == after[prefix] { prefix += 1 }
        while prefix > 0, !isUnicodeScalarBoundary(prefix, in: old) || !isUnicodeScalarBoundary(prefix, in: new) {
            prefix -= 1
        }
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix,
            before[before.count - suffix - 1] == after[after.count - suffix - 1]
        { suffix += 1 }
        while suffix > 0,
            !isUnicodeScalarBoundary(before.count - suffix, in: old)
                || !isUnicodeScalarBoundary(after.count - suffix, in: new)
        { suffix -= 1 }
        let replacement = String(decoding: after[prefix..<(after.count - suffix)], as: UTF16.self)
        return try replacing(
            in: old, range: .init(location: prefix, length: before.count - prefix - suffix),
            with: replacement, baseRevision: baseRevision)
    }

    public func applying(to baseText: String, revision currentRevision: UInt64) throws -> String {
        guard baseRevision == currentRevision,
            revision == baseRevision.addingReportingOverflow(1).partialValue,
            !baseRevision.addingReportingOverflow(1).overflow
        else { throw ScriptTextEditError.invalidRevision }
        guard baseText.utf16.count == baseUTF16Length else {
            throw ScriptTextEditError.inconsistentLength
        }
        try Self.validate(range: range, in: baseText)
        let (expectedDelta, deltaOverflow) = replacement.utf16.count.subtractingReportingOverflow(
            range.length
        )
        guard !deltaOverflow, expectedDelta == changeInLength else {
            throw ScriptTextEditError.replacementMismatch
        }
        let (expectedLength, lengthOverflow) = baseUTF16Length.addingReportingOverflow(
            changeInLength
        )
        guard !lengthOverflow, expectedLength == resultUTF16Length else {
            throw ScriptTextEditError.inconsistentLength
        }
        let result = NSMutableString(string: baseText)
        result.replaceCharacters(
            in: NSRange(location: range.location, length: range.length),
            with: replacement
        )
        let resultString = result as String
        guard resultString.utf16.count == resultUTF16Length else {
            throw ScriptTextEditError.inconsistentLength
        }
        return resultString
    }

    private static func validate(range: UTF16TextRange, in text: String) throws {
        guard range.location >= 0, range.length >= 0 else {
            throw ScriptTextEditError.invalidRange
        }
        let (end, overflow) = range.location.addingReportingOverflow(range.length)
        guard !overflow, end <= text.utf16.count,
            isUnicodeScalarBoundary(range.location, in: text),
            isUnicodeScalarBoundary(end, in: text)
        else {
            throw ScriptTextEditError.invalidRange
        }
    }

    private static func isUnicodeScalarBoundary(_ offset: Int, in text: String) -> Bool {
        let utf16 = text.utf16
        guard offset >= 0, offset <= utf16.count else { return false }
        guard offset > 0, offset < utf16.count else { return true }
        let previousIndex = utf16.index(utf16.startIndex, offsetBy: offset - 1)
        let currentIndex = utf16.index(utf16.startIndex, offsetBy: offset)
        let previous = utf16[previousIndex]
        let current = utf16[currentIndex]
        let previousIsHighSurrogate = previous >= 0xD800 && previous <= 0xDBFF
        let currentIsLowSurrogate = current >= 0xDC00 && current <= 0xDFFF
        return !(previousIsHighSurrogate && currentIsLowSurrogate)
    }
}
