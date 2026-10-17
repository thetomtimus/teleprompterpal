import AVFoundation
import CoreGraphics
import Foundation
import Testing

@testable import PrototypeSupport

@Test("Decoded crop and trim agree with the source, including rotated MOV", arguments: [false, true])
func cropAndTrimExport(rotated: Bool) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("sample.mov")
    let output = root.appendingPathComponent("delivery.mp4")
    try await SampleMovie().make(at: source, rotated: rotated)
    let originalBytes = try Data(contentsOf: source)
    let media = MediaService()
    let original = try await media.inspect(source)
    #expect(abs(original.duration - 3) <= 1.0 / 30)
    let crop = NormalizedCrop(x: 0.15, y: 0.2, width: 0.7, height: 0.6)
    let recipe = EditRecipe(start: 0.5, end: 2.5, crop: crop)
    let result = try await media.export(source: source, recipe: recipe, destination: output)
    #expect(abs(result.duration - 2) <= 1.0 / 30)
    #expect(result.width == Int(floor(Double(original.width) * crop.width / 2) * 2))
    #expect(result.height == Int(floor(Double(original.height) * crop.height / 2) * 2))
    #expect(try Data(contentsOf: source) == originalBytes)
    let header = try Data(contentsOf: output).prefix(64)
    #expect(String(decoding: header, as: UTF8.self).contains("ftyp"))
    #expect(!String(decoding: header, as: UTF8.self).contains("qt  "))
    let originalImage = try await image(source)
    let exportedImage = try await image(output)
    for point in [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2), CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.8)] {
        let expected = try pixel(
            originalImage, x: (crop.x + crop.width * point.x) * Double(originalImage.width),
            y: (crop.y + crop.height * point.y) * Double(originalImage.height))
        let actual = try pixel(
            exportedImage, x: point.x * Double(exportedImage.width), y: point.y * Double(exportedImage.height))
        for channel in 0..<3 {
            #expect(
                abs(Int(expected[channel]) - Int(actual[channel])) < 25,
                "rotated=\(rotated) point=\(point) expected=\(expected) actual=\(actual)")
        }
    }
}

@Test("Rejected export keeps the original and publishes no partial output")
func failedExportPreservesOriginal() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("sample.mov")
    let output = root.appendingPathComponent("delivery.mp4")
    try await SampleMovie().make(at: source)
    let bytes = try Data(contentsOf: source)
    await #expect(throws: PrototypeError.invalidRecipe) {
        _ = try await MediaService().export(source: source, recipe: EditRecipe(start: 2, end: 1), destination: output)
    }
    #expect(try Data(contentsOf: source) == bytes)
    #expect(!FileManager.default.fileExists(atPath: output.path))
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.contains("partial") })
}

private func image(_ url: URL) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    return try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
}

private func pixel(_ image: CGImage, x: Double, y: Double) throws -> [UInt8] {
    let cropped = try #require(image.cropping(to: CGRect(x: floor(x), y: floor(y), width: 1, height: 1)))
    var bytes = [UInt8](repeating: 0, count: 4)
    try bytes.withUnsafeMutableBytes { buffer in
        let context = try #require(
            CGContext(
                data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return bytes
}
