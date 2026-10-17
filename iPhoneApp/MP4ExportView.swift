import PrototypeSupport
import SwiftUI

@MainActor struct MP4ExportView: View {
    let controller: MP4ExportController
    let back: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirmingCancel = false

    var body: some View {
        let delivery = controller.delivery
        GeometryReader { geometry in
            if controller.phase == .ready, geometry.size.width > geometry.size.height, !typeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 18) {
                    preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                    ScrollView { details.padding(.vertical, 12) }.frame(width: max(300, geometry.size.width * 0.43))
                }.padding(.horizontal, 18)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if controller.phase == .ready { preview.frame(height: min(350, geometry.size.height * 0.46)) }
                        details
                    }.padding(18)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Export MP4").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    if controller.isBusy { confirmingCancel = true } else { back() }
                }.disabled(delivery.isBusy).accessibilityIdentifier("backFromMP4")
            }
        }
        .confirmationDialog("Cancel this export?", isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Cancel Export and Return", role: .destructive) { controller.cancel(); back() }
            Button("Keep Exporting", role: .cancel) {}
        } message: { Text("Your original recording and saved edit will be kept.") }
        .background(MP4DeliveryPresenter(request: delivery.presentation, delivery: delivery).frame(width: 0, height: 0))
        .onChange(of: delivery.isBusy) { if delivery.isBusy { controller.pausePlayback() } }
    }

    private var preview: some View {
        CroppedVideoPlayer(player: controller.player, sourceSize: controller.job?.summary?.size ?? .zero,
                           viewportID: "exportVideoViewport")
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold()).accessibilityIdentifier("mp4ExportStatus")
            if controller.isBusy {
                MP4ProgressView(progress: controller.progress, cancelling: controller.phase == .cancelling)
                Text("Keep this app open while exporting. Leaving the app stops the export so you can retry later.")
                    .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
                Button("Cancel Export", role: .destructive) { controller.cancel() }
                    .buttonStyle(.bordered).frame(minHeight: 44)
                    .disabled(controller.phase == .cancelling).accessibilityIdentifier("cancelMP4Export")
            } else if controller.phase == .ready, let summary = controller.job?.summary {
                Button(controller.playing ? "Pause MP4" : "Play MP4", systemImage: controller.playing ? "pause.fill" : "play.fill") {
                    controller.togglePlayback()
                }.buttonStyle(.borderedProminent).tint(PhoneTheme.violet).controlSize(.large).disabled(controller.delivery.isBusy)
                    .accessibilityIdentifier("playExportedMP4")
                Text("\(summary.width) × \(summary.height) · \(EditorTime.label(summary.duration)) · H.264 / AAC")
                    .font(.body).monospacedDigit().accessibilityIdentifier("mp4ExportDetails")
                Text("MP4 ready in this app’s temporary storage. Your original recording and saved edit are kept.")
                    .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
                MP4DeliveryControls(delivery: controller.delivery) { Task { await controller.recheckOutput() } }
            } else {
                if let message = controller.message { Text(message).font(.body).accessibilityIdentifier("mp4ExportMessage") }
                Button("Retry Export") { controller.retry() }
                    .buttonStyle(.borderedProminent).tint(PhoneTheme.violet).controlSize(.large).accessibilityIdentifier("retryMP4Export")
            }
            if let job = controller.job {
                Text("\(EditorTime.label(job.edit.recipe.end.seconds - job.edit.recipe.start.seconds)) selected. Your saved trim and crop are used.")
                    .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
            }
        }
    }

    private var title: String {
        switch controller.phase {
        case .idle, .preparing: "Preparing MP4"
        case .exporting: "Exporting MP4"
        case .cancelling: "Stopping export…"
        case .ready: "MP4 ready"
        case .cancelled: "Export cancelled"
        case .interrupted: "Export interrupted"
        case .failed: "Export could not finish"
        }
    }
}

@MainActor private struct MP4ProgressView: View {
    let progress: MP4ExportProgress
    let cancelling: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress.fraction).accessibilityLabel("MP4 export progress")
                .accessibilityIdentifier("mp4ExportProgress")
            Text(cancelling ? "Waiting for export to stop safely…" : progress.checking ? "Checking the MP4…"
                : "\(Int(progress.fraction * 100))%")
                .font(.headline).monospacedDigit().accessibilityIdentifier("mp4ExportPercent")
        }
    }
}
