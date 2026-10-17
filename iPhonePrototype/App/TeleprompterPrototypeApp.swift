import AVKit
import PromptingCore
import PrototypeSupport
import SwiftUI

struct PrototypeView: View {
    @State private var model: PrototypeModel
    let title: String
    let allowsScriptEditing: Bool
    let checkpoint: @MainActor (ReadingAnchor) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editingScript = false
    @State private var promptHeight = 210.0
    @State private var promptY = 12.0
    @State private var dragOrigin = 12.0
    @Environment(\.scenePhase) private var scenePhase

    init(
        model: PrototypeModel = PrototypeModel(), title: String = "Prompt Prototype",
        allowsScriptEditing: Bool = true, checkpoint: @escaping @MainActor (ReadingAnchor) -> Void = { _ in }
    ) {
        _model = State(initialValue: model)
        self.title = title
        self.allowsScriptEditing = allowsScriptEditing
        self.checkpoint = checkpoint
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    modeControls
                    if let status = model.probeStatus {
                        Text(status).font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("physicalProbeStatus")
                    }
                    preview
                        .frame(height: 400)
                    readerControls
                    recordingControls
                    if let message = model.message {
                        Text(message).font(.callout).foregroundStyle(.secondary)
                            .accessibilityIdentifier("statusMessage")
                    }
                    takes
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allowsScriptEditing {
                    Button("Script", systemImage: "square.and.pencil") { editingScript = true }
                        .disabled(model.busy).accessibilityIdentifier("editScript")
                } else {
                    Button("Done") {
                        model.interrupt()
                        dismiss()
                    }.accessibilityIdentifier("closeReader")
                }
            }
            .sheet(isPresented: $editingScript) {
                NavigationStack {
                    VStack(alignment: .leading) {
                        Text("Script edits reset when this prototype closes.")
                            .font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $model.script)
                    }
                    .padding().navigationTitle("Test script")
                    .toolbar { Button("Done") { editingScript = false } }
                }
            }
            .sheet(item: $model.selected, onDismiss: { model.player?.pause() }) { _ in TakeEditor(model: model) }
            .task {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                await model.initialize()
                await model.runPhysicalProbeIfRequested()
            }
            .onChange(of: scenePhase) {
                // System permission dialogs can temporarily deactivate the scene during setup.
                if scenePhase == .background || (scenePhase == .inactive && !model.cameraPreparing) {
                    model.interrupt()
                }
                updateIdleTimer()
            }
            .onChange(of: model.playing) { updateIdleTimer() }
            .onChange(of: model.phase) { updateIdleTimer() }
            .onChange(of: model.probeRunning) { updateIdleTimer() }
            .onChange(of: model.exporting) { updateIdleTimer() }
            .onDisappear {
                model.interrupt()
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private var modeControls: some View {
        HStack {
            Button("Rehearsal", systemImage: "text.alignleft") { Task { await model.rehearsal() } }
                .buttonStyle(.bordered).disabled(model.busy)
            Button("Camera", systemImage: "camera") { Task { await model.enterCamera() } }
                .buttonStyle(.borderedProminent).disabled(model.busy || model.cameraPreparing)
            Spacer()
            Menu {
                ForEach(CameraSide.allCases, id: \.self) { side in
                    Button(side.rawValue.capitalized) {
                        model.side = side
                        if model.cameraMode { Task { await model.enterCamera() } }
                    }
                }
                Divider()
                ForEach(CaptureOrientation.allCases, id: \.self) { value in
                    Button(value.rawValue) { model.orientation = value }
                }
            } label: {
                Image(systemName: "camera.rotate").frame(width: 44, height: 44)
            }
            .disabled(model.busy || model.cameraPreparing).accessibilityLabel("Camera and orientation")
        }
    }

    private var preview: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 22).fill(.black)
                if model.cameraMode && model.cameraReady {
                    CameraPreview(source: model.capture.preview, side: model.side, orientation: model.orientation)
                        .aspectRatio(model.orientation.aspect, contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                } else {
                    VStack {
                        Spacer()
                        Text(model.cameraMode ? "Camera preview needs a physical iPhone" : "Rehearse at your own pace")
                            .font(.callout).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                        Text("1080p · 30 fps · SDR").font(.caption).foregroundStyle(.white.opacity(0.5))
                    }.padding(.bottom, 28)
                }
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "line.3.horizontal")
                        Text("Drag to move prompt").font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.8)).frame(maxWidth: .infinity).frame(height: 30)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture().onChanged { value in
                            promptY = min(
                                max(0, dragOrigin + value.translation.height),
                                max(0, geometry.size.height - promptHeight - 46))
                        }.onEnded { _ in dragOrigin = promptY })
                    PromptReader(
                        text: model.script, fontSize: model.fontSize, speed: model.speed,
                        playing: model.playing, restart: model.restart, probe: model.readerProbe,
                        initialAnchor: model.initialAnchor, checkpoint: checkpoint
                    ) { model.playing = false }
                    .frame(height: promptHeight)
                    HStack {
                        Button {
                            promptHeight = max(100, promptHeight - 24)
                        } label: {
                            Image(systemName: "minus")
                        }
                        Text("Prompt size").font(.caption)
                        Button {
                            promptHeight = min(280, promptHeight + 24)
                            promptY = min(promptY, 354 - promptHeight)
                            dragOrigin = promptY
                        } label: {
                            Image(systemName: "plus")
                        }
                    }.buttonStyle(.bordered).tint(.white).padding(.top, 4)
                }
                .padding(.horizontal, 12).offset(y: promptY)
                if model.phase == .countdown {
                    Text("\(model.countdown)").font(.system(size: 72, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black.opacity(0.6))
                }
            }
        }
    }

    private var readerControls: some View {
        VStack(spacing: 12) {
            HStack {
                Button(
                    model.playing ? "Pause text" : "Play text", systemImage: model.playing ? "pause.fill" : "play.fill"
                ) {
                    model.playing.toggle()
                }.buttonStyle(.bordered).accessibilityIdentifier("togglePrompt")
                Button("Restart", systemImage: "backward.end.fill") {
                    model.playing = false
                    model.restart += 1
                }
                .buttonStyle(.bordered)
            }
            HStack {
                Text("Pace \(Int(model.speed))").frame(width: 76, alignment: .leading)
                Slider(value: Binding(get: { model.speed }, set: { model.speed = $0 }), in: 10...240, step: 1)
                    .accessibilityLabel("Prompt pace")
            }
            HStack {
                Text("Font \(Int(model.fontSize))").frame(width: 76, alignment: .leading)
                Slider(value: Binding(get: { model.fontSize }, set: { model.fontSize = $0 }), in: 20...72, step: 1)
                    .accessibilityLabel("Prompt font")
            }
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 8) {
            if model.phase == .countdown || model.phase == .starting || model.phase == .recording {
                Button(model.phase == .countdown ? "Cancel countdown" : "Stop recording", systemImage: "stop.fill") {
                    model.stop()
                }
                .buttonStyle(.borderedProminent).tint(.red).accessibilityIdentifier("stopRecording")
            } else {
                Button("Record take", systemImage: "record.circle") { model.start() }
                    .buttonStyle(.borderedProminent).tint(.red).disabled(!model.canRecord)
                    .accessibilityIdentifier("recordTake")
            }
            if let started = model.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Recording \(Int(context.date.timeIntervalSince(started))) s · 10 min maximum")
                        .font(.caption.monospacedDigit()).foregroundStyle(.red)
                        .accessibilityIdentifier("recordingTimer")
                }
            } else {
                Text(
                    model.phase == .idle
                        ? "3-second countdown · prompt stays out of the video" : model.phase.rawValue.capitalized
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var takes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Test takes").font(.headline)
                Spacer()
                Button("Sample Take", systemImage: "film") { Task { await model.makeSample() } }
                    .disabled(!model.initialized || model.busy).accessibilityIdentifier("sampleTake")
            }
            if model.takes.isEmpty {
                Text("Record on your iPhone, or generate a sample to test export.").font(.callout).foregroundStyle(
                    .secondary)
            }
            ForEach(model.takes) { take in
                Button {
                    Task { await model.select(take) }
                } label: {
                    HStack {
                        Image(systemName: take.state == .ready ? "play.rectangle" : "exclamationmark.triangle")
                        VStack(alignment: .leading) {
                            Text(take.created, style: .time)
                            Text(take.note ?? "\(Int(take.summary?.duration ?? 0)) s · original MOV")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let summary = take.summary { Text("\(summary.width)×\(summary.height)").font(.caption) }
                    }.padding(12).background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(model.busy || take.state != .ready)
                    .accessibilityIdentifier("take_\(take.id.uuidString)")
            }
        }
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled =
            scenePhase == .active && (model.playing || model.busy || model.probeRunning)
    }
}

struct TakeEditor: View {
    @Bindable var model: PrototypeModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let player = model.player { VideoPlayer(player: player).frame(height: 280) }
                    Text("Original preserved · crop preview matches export").font(.caption).foregroundStyle(.secondary)
                    if let summary = model.selected?.summary {
                        VStack(alignment: .leading) {
                            Text("Start \(model.editStart, specifier: "%.1f") s")
                            Slider(value: $model.editStart, in: 0...max(0.1, model.editEnd - 0.1), step: 0.1)
                                .accessibilityIdentifier("trimStart")
                            Text("End \(model.editEnd, specifier: "%.1f") s")
                            Slider(
                                value: $model.editEnd,
                                in: min(summary.duration, model.editStart + 0.1)...summary.duration, step: 0.1
                            )
                            .accessibilityIdentifier("trimEnd")
                        }.disabled(model.exporting)
                    }
                    Picker("Crop", selection: $model.cropRatio) {
                        ForEach(["Original", "9:16", "16:9", "1:1", "4:5"], id: \.self) { Text($0) }
                    }.pickerStyle(.segmented).disabled(model.exporting).accessibilityIdentifier("cropPicker")
                    if model.exporting {
                        ProgressView(value: model.progress)
                        Button("Cancel export") { model.cancelExport() }
                    } else {
                        Button("Export MP4", systemImage: "square.and.arrow.up") { model.export() }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("exportMP4")
                    }
                    if let url = model.exportedURL {
                        ShareLink("Save or share MP4", item: url).buttonStyle(.bordered)
                            .accessibilityIdentifier("shareMP4")
                    }
                    if let message = model.message {
                        Text(message).font(.callout).accessibilityIdentifier("exportStatus")
                    }
                }.padding(18)
            }
            .navigationTitle("Review take").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() }.disabled(model.exporting) }
            .interactiveDismissDisabled(model.exporting)
            .onChange(of: model.editStart) { model.updatePreview() }
            .onChange(of: model.editEnd) { model.updatePreview() }
            .onChange(of: model.cropRatio) { model.updatePreview() }
        }
    }
}
