import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import PrototypeSupport

@Test(arguments: [CGSize(width: 1920, height: 1080), CGSize(width: 1080, height: 1920), CGSize(width: 321, height: 241)])
func cropPresetsStayInsideTheSourceWithoutUpscaling(_ size: CGSize) throws {
    var selection = try CropSelection(sourceSize: size)
    for preset in CropPreset.allCases {
        selection.select(preset)
        let geometry = selection.geometry
        #expect(selection.crop.isValid)
        #expect(geometry.renderSize.width <= size.width && geometry.renderSize.height <= size.height)
        #expect(Int(geometry.renderSize.width) % 2 == 0 && Int(geometry.renderSize.height) % 2 == 0)
        if let ratio = preset.ratio {
            #expect(abs(geometry.renderSize.width - geometry.renderSize.height * ratio) < 4)
            selection.position(horizontal: 1, vertical: 0)
            #expect(selection.preset == preset && selection.crop.isValid)
        }
    }
}

@Test func customCropClampsMovesAndAllCornersAndRejectsNonfiniteInput() throws {
    var selection = try CropSelection(sourceSize: CGSize(width: 320, height: 240))
    selection.select(.custom); selection.size(width: 0.6, height: 0.5)
    let origin = selection.crop
    selection.move(from: origin, by: CGSize(width: 100, height: -100))
    #expect(selection.crop.x == 0.4 && selection.crop.y == 0)
    #expect(selection.crop.width == origin.width && selection.crop.height == origin.height)
    let before = selection
    selection.move(from: selection.crop, by: CGSize(width: CGFloat.nan, height: 1))
    #expect(selection == before)
    for corner in CropCorner.allCases {
        for delta in [-100.0, -0.1, 0.1, 100] {
            selection.resize(corner, from: selection.crop, by: CGSize(width: delta, height: -delta))
            #expect(selection.crop.isValid)
            #expect(selection.geometry.renderSize.width >= 2 && selection.geometry.renderSize.height >= 2)
        }
    }
    selection.size(width: .infinity, height: .nan)
    #expect(selection.crop.isValid)
    selection.select(.original)
    #expect(selection.crop == NormalizedCrop())
}

@Test func previewViewportMapsEveryPointToTheExportsIntegralSourceRectangle() throws {
    let size = CGSize(width: 321, height: 241)
    var selected = try CropSelection(sourceSize: size)
    for preset in CropPreset.allCases {
        selected.select(preset)
        if preset == .custom { selected.size(width: 0.67, height: 0.73); selected.position(horizontal: 0.8, vertical: 0.2) }
        let geometry = selected.geometry
        for available in [CGSize(width: 366, height: 330), CGSize(width: 350, height: 180)] {
            let layout = try CropPreviewLayout(sourceSize: size, crop: selected.crop, available: available)
            let scale = layout.sourceFrame.width / size.width
            #expect(abs(layout.viewport.width / layout.viewport.height
                - geometry.renderSize.width / geometry.renderSize.height) < 0.000_001)
            for point in [CGPoint(x: 0.17, y: 0.23), CGPoint(x: 0.81, y: 0.77)] {
                let sourceX = (point.x * layout.viewport.width - layout.sourceFrame.minX) / scale
                let sourceY = (point.y * layout.viewport.height - layout.sourceFrame.minY) / scale
                #expect(abs(sourceX - (geometry.sourceRect.minX + point.x * geometry.sourceRect.width)) < 0.000_001)
                #expect(abs(sourceY - (geometry.sourceRect.minY + point.y * geometry.sourceRect.height)) < 0.000_001)
            }
        }
    }
}

@Test func oldRecipesDecodeAndCustomModeSurvivesRoundTrip() throws {
    let old = Data(#"{"schemaVersion":1,"start":{"value":0,"timescale":600},"end":{"value":1800,"timescale":600},"crop":{"x":0,"y":0,"width":1,"height":1}}"#.utf8)
    #expect(try JSONDecoder().decode(EditRecipe.self, from: old).cropPreset == nil)
    let recipe = EditRecipe(start: 0.5, end: 2.5, crop: .init(x: 0.2, y: 0.1, width: 0.6, height: 0.7), cropPreset: .custom)
    #expect(try JSONDecoder().decode(EditRecipe.self, from: JSONEncoder().encode(recipe)) == recipe)
}

/// A single bounded export lane avoids exhausting the hardware encoder pool.
@Test func decodedPresetAndCustomExportsMatchEveryPreferredRotationAndMirror() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("crop-matrix-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    let media = MediaService()
    for mirrored in [false, true] {
        for orientation in SampleMovieOrientation.allCases {
            let source = root.appendingPathComponent("source-\(orientation.rawValue)-\(mirrored).mov")
            try await SampleMovie().make(at: source, orientation: orientation, mirrored: mirrored)
            let bytes = try Data(contentsOf: source), summary = try await media.inspect(source)
            let track = try #require(try await AVURLAsset(url: source).loadTracks(withMediaType: .video).first)
            let actualTransform = try await track.load(.preferredTransform)
            #expect((actualTransform.a * actualTransform.d - actualTransform.b * actualTransform.c < 0) == mirrored)
            var expectedTransform = orientation.transform
            if mirrored {
                let width = CGRect(x: 0, y: 0, width: 320, height: 240).applying(expectedTransform).standardized.width
                expectedTransform = expectedTransform.concatenating(.init(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0))
            }
            #expect(actualTransform == expectedTransform)
            let original = try await cropImage(source, at: 1)
            var selected = try CropSelection(sourceSize: summary.size)
            for preset in CropPreset.allCases {
                selected.select(preset)
                if preset == .custom {
                    selected.size(width: 0.67, height: 0.71)
                    selected.position(horizontal: 0.82, vertical: 0.19)
                }
                let output = root.appendingPathComponent(UUID().uuidString + ".mp4")
                let recipe = EditRecipe(start: 0.6, end: 1.8, crop: selected.crop, cropPreset: selected.preset)
                let summary = try await media.export(source: source, recipe: recipe, destination: output)
                #expect(summary.size == selected.geometry.renderSize)
                #expect(abs(summary.duration - 1.2) <= 1.0 / 30)
                let decoded = try await cropImage(output, at: 0.4)
                let rect = selected.geometry.sourceRect
                for point in [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.2),
                              CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.8, y: 0.8)] {
                    let expected = try cropPixel(original, x: rect.minX + rect.width * point.x, y: rect.minY + rect.height * point.y)
                    let actual = try cropPixel(decoded, x: CGFloat(decoded.width) * point.x, y: CGFloat(decoded.height) * point.y)
                    for channel in 0..<3 {
                        #expect(abs(expected[channel] - actual[channel]) < 30,
                            "orientation=\(orientation) mirror=\(mirrored) preset=\(preset) expected=\(expected) actual=\(actual)")
                    }
                }
                try FileManager.default.removeItem(at: output)
            }
            #expect(try Data(contentsOf: source) == bytes)
        }
    }
}

private func cropImage(_ url: URL, at seconds: Double) async throws -> CGImage {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero; generator.requestedTimeToleranceAfter = .zero
    return try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
}

private func cropPixel(_ image: CGImage, x: CGFloat, y: CGFloat) throws -> [Int] {
    let pixel = try #require(image.cropping(to: CGRect(x: floor(x), y: floor(y), width: 1, height: 1)))
    var bytes = [UInt8](repeating: 0, count: 4)
    try bytes.withUnsafeMutableBytes { buffer in
        let context = try #require(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return bytes.map(Int.init)
}
