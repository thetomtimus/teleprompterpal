import AVKit
import PrototypeSupport
import SwiftUI

@MainActor struct VideoEditorView: View {
    let model: VideoEditorModel
    let finish: () -> Void
    var exporter: MP4ExportController? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var cropping: CropSelection?
    @State private var showingExport = false
    @State private var preparingExport = false

    var body: some View {
        Group {
            if showingExport, let exporter {
                MP4ExportView(controller: exporter) {
                    Task { await exporter.leave(); showingExport = false }
                }
            } else if let selection = cropping {
                CropEditorView(player: model.player, selection: selection, canApply: model.canSave,
                    cancel: { cropping = nil }) { selected in
                    model.applyCrop(selected); cropping = nil
                }
            } else {
                editorContent
            }
        }
        .task { await model.load(); await model.loadTimeline() }
        .onChange(of: scenePhase) { if scenePhase != .active { model.pause() } }
        .onDisappear { model.close(); if showingExport { exporter?.dismiss() } }
    }

    private var editorContent: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > geometry.size.height && !typeSize.isAccessibilitySize
            if wide {
                HStack(alignment: .top, spacing: 18) {
                    preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                    ScrollView { controls.padding(.vertical, 12) }
                        .frame(width: max(300, geometry.size.width * 0.43))
                }.padding(.horizontal, 18)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        preview.frame(height: max(180, min(330, geometry.size.height * 0.42)))
                        controls
                    }.padding(18)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Edit Video").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: finish).disabled(model.saving || preparingExport).accessibilityIdentifier("cancelVideoEdit")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(model.saving ? "Saving…" : "Done") {
                    Task { if await model.save() { finish() } }
                }.disabled(!model.canSave || preparingExport).accessibilityIdentifier("saveVideoEdit")
            }
        }
    }

    private var preview: some View {
        ZStack {
            Color.black
            CroppedVideoPlayer(player: model.player, sourceSize: model.sourceSize, crop: model.draft.crop)
            if model.loading { ProgressView("Opening preview…").tint(.white).foregroundStyle(.white) }
        }.clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain).accessibilityIdentifier("editorPreview")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trim selection").font(.headline)
                    Text("\(EditorTime.label(model.selectionDuration)) selected")
                        .font(.subheadline).monospacedDigit().foregroundStyle(PhoneTheme.auxiliaryText)
                        .accessibilityIdentifier("selectedTrimDuration")
                }
                Spacer(minLength: 12)
                Button { Task { await model.reset() } } label: { Text("Reset").frame(minHeight: 44) }
                    .disabled(!model.ready || model.loading || model.saving || model.writeBlocked)
                    .accessibilityIdentifier("resetVideoEdit")
            }
            if let message = model.message {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle").font(.callout)
                        .accessibilityIdentifier("videoEditMessage")
                    if model.writeBlocked {
                        Button("Retry Opening Edits") { Task { await model.load() } }
                            .frame(minHeight: 44).disabled(model.loading || model.saving)
                    }
                }
            }
            if model.ready {
                if let exporter {
                    Button(model.hasChanges ? "Save Edit & Export MP4" : "Export MP4", systemImage: "film") {
                        guard !preparingExport else { return }
                        preparingExport = true; model.pause()
                        Task {
                            defer { preparingExport = false }
                            if let edit = await model.exportSnapshot() {
                                showingExport = true
                                await exporter.open(edit: edit, source: model.session.source)
                            }
                        }
                    }.buttonStyle(.borderedProminent).tint(PhoneTheme.violet).controlSize(.large)
                        .disabled(!model.canSave || preparingExport || exporter.isBusy).accessibilityIdentifier("exportMP4")
                    Text("Export saves this edit and keeps the original recording.")
                        .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
                }
                Button {
                    model.pause(); cropping = model.cropSelection()
                } label: {
                    HStack {
                        Label("Crop", systemImage: "crop")
                        Spacer()
                        if let selection = model.cropSelection() {
                            Text("\(selection.preset.title) · \(Int(selection.geometry.renderSize.width)) × \(Int(selection.geometry.renderSize.height))")
                                .monospacedDigit().font(.subheadline)
                        }
                    }.frame(minHeight: 44)
                }.accessibilityIdentifier("editCrop").disabled(model.writeBlocked)
                TrimTimeline(thumbnails: model.thumbnails, duration: model.duration, start: model.start,
                    end: model.end, step: model.frameStep, transport: model.transport,
                    loadingImages: model.thumbnails.isEmpty && model.thumbnailMessage == nil,
                    setStart: model.setStart, setEnd: model.setEnd)
                if let message = model.thumbnailMessage {
                    Text(message).font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
                }
                EditorTransportControls(transport: model.transport, start: model.start, end: model.end,
                    toggle: model.togglePlayback, scrub: model.scrub)
                timeControl("Start", value: model.start, prefix: "trimStart", earlier: {
                    model.setStart(model.start - model.frameStep)
                }, later: { model.setStart(model.start + model.frameStep) })
                timeControl("End", value: model.end, prefix: "trimEnd", earlier: {
                    model.setEnd(model.end - model.frameStep)
                }, later: { model.setEnd(model.end + model.frameStep) })
                Text("Drag the handles to trim. Done saves your edits and keeps the original recording.")
                    .font(.callout).foregroundStyle(PhoneTheme.auxiliaryText)
            }
        }.disabled(model.loading || model.saving || preparingExport)
    }

    private func timeControl(_ title: String, value: Double, prefix: String,
                             earlier: @escaping () -> Void, later: @escaping () -> Void) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            HStack {
                Text(title).font(.body)
                Spacer(minLength: 4)
                Text(EditorTime.label(value)).monospacedDigit().font(.body)
                    .accessibilityIdentifier(prefix + "Value")
            }
            HStack(spacing: 12) {
                Button(action: earlier) { Image(systemName: "backward.frame").frame(minWidth: 44, minHeight: 44) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Move \(title.lowercased()) earlier by one frame")
                    .accessibilityIdentifier(prefix + "Earlier")
                Button(action: later) { Image(systemName: "forward.frame").frame(minWidth: 44, minHeight: 44) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Move \(title.lowercased()) later by one frame")
                    .accessibilityIdentifier(prefix + "Later")
            }
        }
    }
}

@MainActor private struct EditorTransportControls: View {
    let transport: EditorTransport
    let start: Double
    let end: Double
    let toggle: () -> Void
    let scrub: (Double) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 8) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            layout {
                Text(EditorTime.label(transport.position)).monospacedDigit().font(.subheadline)
                    .accessibilityIdentifier("editorPlayheadTime")
                if !typeSize.isAccessibilitySize { Spacer() }
                Button(action: toggle) {
                    Label(transport.isPlaying ? "Pause selection" : "Play selection",
                          systemImage: transport.isPlaying ? "pause.fill" : "play.fill")
                        .frame(minHeight: 44)
                }.font(.headline).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playTrimSelection")
            }
            Slider(value: Binding(get: { min(max(start, transport.position), end) }, set: { scrub($0) }), in: start...max(start, end))
                .accessibilityLabel("Playhead within selection").accessibilityIdentifier("editorPlayhead")
                .frame(minHeight: 44)
        }
    }
}

