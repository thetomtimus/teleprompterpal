import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

public actor TakeThumbnailStore {
    public let root: URL
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var tail: Task<Data, Error>?
    private var tailKey: String?
    private let maximumBytes = 32 * 1024 * 1024
    private let maximumFiles = 256

    public init(root: URL) { self.root = root }

    /// One decode at a time, at most 16 queued visible-row requests, and a bounded
    /// regenerable disk cache. The original is read only; no full movie enters UI state.
    public func data(for take: PrototypeTake, source: URL) async throws -> Data {
        guard take.isPlayable else { throw PrototypeError.invalidMedia }
        let signature = try fingerprint(source)
        let key = take.id.uuidString + "-thumb-v1-" + signature
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent(key + ".jpg")
        if let values = try? FileManager.default.attributesOfItem(atPath: destination.path),
           values[.type] as? FileAttributeType == .typeRegular,
           let bytes = values[.size] as? NSNumber, bytes.intValue <= 512 * 1024,
           let data = try? Data(contentsOf: destination),
           let decoded = CGImageSourceCreateWithData(data as CFData, nil),
           CGImageSourceGetCount(decoded) == 1, CGImageSourceCreateImageAtIndex(decoded, 0, nil) != nil {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: destination.path)
            return data
        }
        if let existing = inFlight[key] { return try await existing.value }
        guard inFlight.count < 16 else { throw PrototypeError.busy }
        let preceding = tail
        let task = Task { @concurrent in
            _ = try? await preceding?.value
            return try await self.generate(take: take, source: source, signature: signature, destination: destination)
        }
        inFlight[key] = task
        tail = task
        tailKey = key
        defer {
            inFlight[key] = nil
            if tailKey == key { tail = nil; tailKey = nil }
        }
        return try await task.value
    }

    public func remove(id: UUID) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            where url.lastPathComponent.hasPrefix(id.uuidString + "-thumb-v1-") && url.pathExtension == "jpg" {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func generate(take: PrototypeTake, source: URL, signature: String, destination: URL) async throws -> Data {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: source))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)
        let time = min(0.5, (take.summary?.duration ?? 0) / 2)
        let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
        guard try fingerprint(source) == signature else { throw PrototypeError.invalidMedia }
        let buffer = NSMutableData()
        guard let encoder = CGImageDestinationCreateWithData(buffer, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PrototypeError.invalidMedia
        }
        CGImageDestinationAddImage(encoder, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(encoder), buffer.length <= 512 * 1024 else { throw PrototypeError.invalidMedia }
        let data = buffer as Data
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        try evict()
        return data
    }

    private func fingerprint(_ source: URL) throws -> String {
        let values = try FileManager.default.attributesOfItem(atPath: source.path)
        guard values[.type] as? FileAttributeType == .typeRegular,
              let size = values[.size] as? NSNumber, let modified = values[.modificationDate] as? Date else {
            throw PrototypeError.invalidMedia
        }
        return "\(size.int64Value)-\(Int64(modified.timeIntervalSinceReferenceDate * 1_000_000))"
    }

    private func evict() throws {
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter {
                guard $0.pathExtension == "jpg", let id = UUID(uuidString: String($0.lastPathComponent.prefix(36))) else { return false }
                return $0.lastPathComponent.hasPrefix(id.uuidString + "-thumb-v1-")
            }
            .compactMap { url -> (URL, Int, Date)? in
                guard let values = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let bytes = values[.size] as? NSNumber, let modified = values[.modificationDate] as? Date else { return nil }
                return (url, bytes.intValue, modified)
            }.sorted { $0.2 < $1.2 }
        var bytes = files.reduce(0) { $0 + $1.1 }
        var count = files.count
        for file in files where bytes > maximumBytes || count > maximumFiles {
            try FileManager.default.removeItem(at: file.0)
            bytes -= file.1; count -= 1
        }
    }
}
