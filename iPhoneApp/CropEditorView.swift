import AVFoundation
import PrototypeSupport
import SwiftUI

@MainActor struct CropEditorView: View {
    let player: AVPlayer
    let cancel: () -> Void
    let apply: (CropSelection) -> Void
    let canApply: Bool
    @State private var selection: CropSelection
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var presetWidth = 88.0

    init(player: AVPlayer, selection: CropSelection, canApply: Bool, cancel: @escaping () -> Void,
         apply: @escaping (CropSelection) -> Void) {
        self.player = player; self.cancel = cancel; self.apply = apply; self.canApply = canApply
        // One crop task owns its draft; Cancel never mutates the parent recipe.
        _selection = State(initialValue: selection)
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height && !typeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 18) {
                    canvas.frame(maxWidth: .infinity, maxHeight: .infinity)
                    ScrollView { controls.padding(.vertical, 12) }
                        .frame(width: max(300, geometry.size.width * 0.43))
                }.padding(.horizontal, 18)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        canvas.frame(height: max(220, min(380, geometry.size.height * 0.46)))
                        controls
                    }.padding(18)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Crop Video").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel).accessibilityIdentifier("cancelCrop")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { apply(selection) }.disabled(!canApply).accessibilityIdentifier("applyCrop")
            }
        }
    }

    private var canvas: some View {
        CropCanvas(player: player, selection: $selection)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !canApply { Text("Return to the editor to reopen this recording.").font(.callout) }
            Text("Aspect ratio").font(.headline)
            LazyVGrid(columns: [.init(.adaptive(minimum: presetWidth), spacing: 8)], spacing: 8) {
                ForEach(CropPreset.allCases) { preset in
                    Button { selection.select(preset) } label: {
                        Text(preset.title).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).font(.body)
                    .fontWeight(selection.preset == preset ? .semibold : .regular)
                    .background(selection.preset == preset ? PhoneTheme.violet.opacity(0.25) : .clear,
                                in: Capsule())
                    .accessibilityAddTraits(selection.preset == preset ? .isSelected : [])
                    .accessibilityIdentifier("cropPreset_" + preset.rawValue)
                }
            }
            Text("\(Int(selection.geometry.renderSize.width)) × \(Int(selection.geometry.renderSize.height)) pixels")
                .font(.headline).monospacedDigit().accessibilityIdentifier("cropDimensions")
            Text("Original: \(Int(selection.sourceSize.width)) × \(Int(selection.sourceSize.height)). Cropping keeps only the selected area.")
                .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
            cropSlider("Horizontal position", value: Binding(get: { selection.horizontalPosition },
                set: { selection.position(horizontal: $0) }), range: 0...1, identifier: "cropHorizontal",
                disabled: selection.crop.width >= 1)
            cropSlider("Vertical position", value: Binding(get: { selection.verticalPosition },
                set: { selection.position(vertical: $0) }), range: 0...1, identifier: "cropVertical",
                disabled: selection.crop.height >= 1)
            if selection.preset == .custom {
                cropSlider("Width", value: Binding(get: { selection.crop.width }, set: { selection.size(width: $0) }),
                    range: (2 / selection.sourceSize.width)...1, identifier: "cropWidth")
                cropSlider("Height", value: Binding(get: { selection.crop.height }, set: { selection.size(height: $0) }),
                    range: (2 / selection.sourceSize.height)...1, identifier: "cropHeight")
            }
            Text("Drag the frame to move it. In Custom, drag a corner or adjust width and height.")
                .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
        }
    }

    private func cropSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                            identifier: String, disabled: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body)
            Slider(value: value, in: range)
                .frame(minHeight: 44).disabled(disabled)
                .accessibilityLabel(title)
                .accessibilityValue(value.wrappedValue.formatted(.percent.precision(.fractionLength(0))))
                .accessibilityIdentifier(identifier)
        }
    }
}

@MainActor private struct CropCanvas: View {
    let player: AVPlayer
    @Binding var selection: CropSelection

    var body: some View {
        GeometryReader { geometry in
            let available = CGSize(width: max(1, geometry.size.width - 44), height: max(1, geometry.size.height - 44))
            if let layout = try? CropPreviewLayout(sourceSize: selection.sourceSize, crop: .init(), available: available) {
                let scale = layout.sourceFrame.width / selection.sourceSize.width
                let pixels = selection.geometry.sourceRect
                let sourceRect = layout.viewport.offsetBy(dx: 22, dy: 22)
                let rect = CGRect(x: sourceRect.minX + pixels.minX * scale,
                                  y: sourceRect.minY + pixels.minY * scale,
                                  width: pixels.width * scale, height: pixels.height * scale)
                ZStack(alignment: .topLeading) {
                    CroppedVideoPlayer(player: player, sourceSize: selection.sourceSize, viewportID: "cropSourceViewport")
                        .padding(22)
                    Path { path in path.addRect(sourceRect); path.addRect(rect) }
                        .fill(.black.opacity(0.55), style: FillStyle(eoFill: true)).allowsHitTesting(false)
                    CropMoveFrame(selection: $selection, sourcePoints: CGSize(
                        width: selection.sourceSize.width * scale, height: selection.sourceSize.height * scale))
                        .frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
                    if selection.preset == .custom {
                        ForEach(CropCorner.allCases) { corner in
                            CropCornerHandle(corner: corner, selection: $selection, sourcePoints: CGSize(
                                width: selection.sourceSize.width * scale, height: selection.sourceSize.height * scale))
                                .position(x: corner == .topLeft || corner == .bottomLeft ? rect.minX : rect.maxX,
                                          y: corner == .topLeft || corner == .topRight ? rect.minY : rect.maxY)
                        }
                    }
                }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("cropCanvas")
    }
}

@MainActor private struct CropMoveFrame: View {
    @Binding var selection: CropSelection
    let sourcePoints: CGSize
    @GestureState private var origin: NormalizedCrop?

    var body: some View {
        ZStack {
            Rectangle().strokeBorder(.black.opacity(0.8), lineWidth: 4)
            Rectangle().strokeBorder(.white, lineWidth: 2)
            CropGrid().stroke(.black.opacity(0.7), lineWidth: 3)
            CropGrid().stroke(.white.opacity(0.95), lineWidth: 1)
        }.contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($origin) { _, state, _ in if state == nil { state = selection.crop } }
                .onChanged { value in
                    selection.move(from: origin ?? selection.crop, by: CGSize(
                        width: value.translation.width / sourcePoints.width,
                        height: value.translation.height / sourcePoints.height))
                })
            .accessibilityElement(children: .ignore).accessibilityLabel("Crop position")
            .accessibilityValue("Horizontal \(Int(selection.horizontalPosition * 100)) percent, vertical \(Int(selection.verticalPosition * 100)) percent")
            .accessibilityHint("Adjust horizontally, or use the position sliders for both directions.")
            .accessibilityAdjustableAction { direction in
                selection.position(horizontal: selection.horizontalPosition + (direction == .increment ? 0.02 : -0.02))
            }.accessibilityIdentifier("cropMoveFrame")
    }

}

private struct CropGrid: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            for fraction in [1.0 / 3, 2.0 / 3] {
                path.move(to: CGPoint(x: rect.width * fraction, y: 0))
                path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
                path.move(to: CGPoint(x: 0, y: rect.height * fraction))
                path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
            }
        }
    }
}

@MainActor private struct CropCornerHandle: View {
    let corner: CropCorner
    @Binding var selection: CropSelection
    let sourcePoints: CGSize
    @GestureState private var origin: NormalizedCrop?
    private var left: Bool { corner == .topLeft || corner == .bottomLeft }
    private var top: Bool { corner == .topLeft || corner == .topRight }

    var body: some View {
        Image(systemName: left == top ? "arrow.up.left.and.arrow.down.right" : "arrow.up.right.and.arrow.down.left")
            .font(.body.weight(.semibold)).foregroundStyle(.white)
            .frame(width: 44, height: 44).background(PhoneTheme.violet, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($origin) { _, state, _ in if state == nil { state = selection.crop } }
                .onChanged { value in
                    selection.resize(corner, from: origin ?? selection.crop, by: CGSize(
                        width: value.translation.width / sourcePoints.width,
                        height: value.translation.height / sourcePoints.height))
                })
            .accessibilityElement(children: .ignore).accessibilityLabel("\(left ? "Left" : "Right") \(top ? "top" : "bottom") crop corner")
            .accessibilityValue("Width \(Int(selection.crop.width * 100)) percent, height \(Int(selection.crop.height * 100)) percent")
            .accessibilityHint("Swipe up to enlarge the crop, or down to shrink it.")
            .accessibilityAdjustableAction { direction in
                let delta = direction == .increment ? 0.02 : -0.02
                selection.resize(corner, from: selection.crop, by: CGSize(
                    width: left ? -delta : delta, height: top ? -delta : delta))
            }.accessibilityIdentifier("cropCorner_" + corner.rawValue)
    }
}
