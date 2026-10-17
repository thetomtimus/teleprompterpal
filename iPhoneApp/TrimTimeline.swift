import SwiftUI

@MainActor struct TrimTimeline: View {
    let thumbnails: [EditorThumbnail]
    let duration: Double
    let start: Double
    let end: Double
    let step: Double
    let transport: EditorTransport
    let loadingImages: Bool
    let setStart: (Double) -> Void
    let setEnd: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let width = max(1, geometry.size.width - 44)
                let left = width * start / max(duration, 0.001)
                let right = width * end / max(duration, 0.001)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        if thumbnails.isEmpty {
                            Rectangle().fill(Color(uiColor: .secondarySystemFill))
                                .overlay { if loadingImages { ProgressView().controlSize(.small) } }
                        } else {
                            ForEach(thumbnails) { thumbnail in
                                Image(uiImage: thumbnail.image).resizable().scaledToFill()
                                    .frame(width: width / Double(thumbnails.count), height: 60).clipped()
                            }
                        }
                    }.frame(width: width, height: 60).clipped().offset(x: 22, y: 14)
                        .accessibilityHidden(true)
                    Rectangle().fill(.black.opacity(0.65)).frame(width: left, height: 60).offset(x: 22, y: 14)
                        .allowsHitTesting(false)
                    Rectangle().fill(.black.opacity(0.65)).frame(width: max(0, width - right), height: 60)
                        .offset(x: 22 + right, y: 14).allowsHitTesting(false)
                    Rectangle().strokeBorder(.tint, lineWidth: 3)
                        .frame(width: max(2, right - left), height: 64).offset(x: 22 + left, y: 12)
                        .allowsHitTesting(false)
                    TimelinePlayhead(transport: transport, duration: duration, width: width)
                        .offset(x: 22, y: 14).allowsHitTesting(false).accessibilityHidden(true)
                    TrimHandle(title: "Trim start", identifier: "trimStartHandle", value: start,
                        step: step, pointsPerSecond: width / max(duration, 0.001), change: setStart)
                        .position(x: 22 + left, y: 44)
                    TrimHandle(title: "Trim end", identifier: "trimEndHandle", value: end,
                        step: step, pointsPerSecond: width / max(duration, 0.001), change: setEnd)
                        .position(x: 22 + right, y: 44)
                }
            }.frame(height: 88)
            HStack {
                Text(EditorTime.label(0))
                Spacer()
                Text(EditorTime.label(duration))
            }.font(.caption).monospacedDigit().foregroundStyle(PhoneTheme.auxiliaryText)
                .padding(.horizontal, 16).accessibilityHidden(true)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("trimTimeline")
    }
}

@MainActor private struct TrimHandle: View {
    let title: String
    let identifier: String
    let value: Double
    let step: Double
    let pointsPerSecond: Double
    let change: (Double) -> Void
    @State private var origin: Double?

    var body: some View {
        RoundedRectangle(cornerRadius: 4).fill(.tint).frame(width: 12, height: 72)
            .overlay { Capsule().fill(Color(uiColor: .systemBackground)).frame(width: 2, height: 24) }
            .frame(width: 44, height: 88).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { gesture in
                if origin == nil { origin = value }
                change((origin ?? value) + gesture.translation.width / pointsPerSecond)
            }.onEnded { _ in origin = nil })
            .accessibilityElement(children: .ignore).accessibilityLabel(title)
            .accessibilityValue(EditorTime.label(value)).accessibilityIdentifier(identifier)
            .accessibilityAdjustableAction { direction in
                change(value + (direction == .increment ? step : -step))
            }
    }
}

@MainActor private struct TimelinePlayhead: View {
    let transport: EditorTransport
    let duration: Double
    let width: Double
    var body: some View {
        Rectangle().fill(.white).frame(width: 2, height: 60)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 1, y: 1)
            .offset(x: width * min(1, max(0, transport.position / max(duration, 0.001))) - 1)
    }
}
