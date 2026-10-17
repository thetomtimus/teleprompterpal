import AVKit
import PrototypeSupport
import SwiftUI

@MainActor struct TakePlaybackView: View {
    let recorder: PrototypeModel
    let take: PrototypeTake
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var deleting = false
    @State private var editor: VideoEditorModel?

    var body: some View {
        NavigationStack {
            if let editor {
                VideoEditorView(model: editor, finish: finishEditing, exporter: recorder.mp4Exports)
            } else {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let player = recorder.player {
                            OriginalVideoPlayer(player: player)
                                .frame(height: min(420, geometry.size.height * 0.62))
                        }
                        Button("Edit Video", systemImage: "slider.horizontal.3") { Task { await openEditor() } }
                            .font(.headline).buttonStyle(.borderedProminent).tint(PhoneTheme.violet).controlSize(.large)
                            .frame(minHeight: 44).disabled(recorder.busy).accessibilityIdentifier("editVideo")
                        Text(take.script?.title ?? "Other recordings").font(.title3.bold())
                        VStack(spacing: 10) {
                            metadata("Recorded", value: take.created.formatted(date: .abbreviated, time: .shortened))
                            metadata("Duration", value: TakePresentation.duration(take))
                            metadata("Storage", value: TakePresentation.storage(take))
                            if let summary = take.summary { metadata("Resolution", value: "\(summary.width) × \(summary.height)") }
                        }.font(.body)
                        Text(TakePresentation.status(take)).font(.headline)
                        if let note = take.note { Text(note).font(.callout).foregroundStyle(PhoneTheme.auxiliaryText) }
                        Text("This is the original recording. Deleting its script does not delete this video.")
                            .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
                        Button("Delete Original", systemImage: "trash", role: .destructive) { deleting = true }
                            .font(.headline).buttonStyle(.bordered).controlSize(.large)
                            .disabled(recorder.busy).accessibilityIdentifier("deleteOriginal")
                    }.padding(18)
                }
            }
            .navigationTitle("Recording").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("closeTake") }
            .confirmationDialog("Delete original recording?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete Original", role: .destructive) {
                    Task { if await recorder.deleteTake(id: take.id) { dismiss() } }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes this original recording from your iPhone. Your script stays in the library.") }
            }
        }
        .preferredColorScheme(.dark).tint(.white)
        .interactiveDismissDisabled(editor != nil)
        .onDisappear {
            if let editor { editor.close(); recorder.endEditingTake(editor.session) }
            recorder.stopPlayback(takeID: take.id)
        }
    }

    private func openEditor() async {
        guard let session = await recorder.beginEditingTake(id: take.id) else { return }
        editor = VideoEditorModel(session: session, title: take.script?.title ?? "Recording",
            store: recorder.edits, media: recorder.media)
    }

    private func finishEditing() {
        guard let editor else { return }
        editor.close()
        recorder.endEditingTake(editor.session)
        self.editor = nil
    }

    private func metadata(_ label: String, value: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(label)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
            Text(value).foregroundStyle(PhoneTheme.auxiliaryText).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}

/// Own the native controller explicitly so its transport remains accessible
/// inside the scrolling metadata sheet on every supported iOS version.
private struct OriginalVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.view.accessibilityIdentifier = "originalVideoPlayer"
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
        controller.player = nil
    }
}
