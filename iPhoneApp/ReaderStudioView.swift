import PhoneLibrary
import PromptingCore
import SwiftUI
import UIKit

/// Coordinates are normalized within the offered stage, excluding the two explicit handles.
struct PromptPanelGeometry {
    let height: Double
    let travel: Double
    let y: Double
    init(availableHeight: Double, preferences: ReaderPreferences) {
        let available = max(0, availableHeight)
        height = min(available, max(min(164, available), available * preferences.panelHeight))
        travel = max(0, available - height)
        y = travel * preferences.panelPosition
    }
}

@MainActor struct ReaderStudioView: View {
    let model: PrototypeModel
    @Binding var preferences: ReaderPreferences
    let title: String
    var startInCamera = false
    var returnToSection: (PhoneSection) -> Void = { _ in }
    let checkpoint: @MainActor (ReadingAnchor) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var settings = false
    @State private var closing = false
    @State private var returnSection: PhoneSection?
    @State private var anchorHandoff = ReaderAnchorHandoff()

    var body: some View {
        NavigationStack {
            Group {
            if model.cameraMode {
                CameraStudioView(model: model, preferences: $preferences, handoff: anchorHandoff, checkpoint: checkpoint, close: requestClose)
            } else {
            GeometryReader { geometry in
                let wide = geometry.size.width > geometry.size.height
                let layout = wide ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 12))
                layout {
                    ReaderStage(model: model, preferences: $preferences, handoff: anchorHandoff, checkpoint: checkpoint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    controls
                        .frame(width: wide ? min(300, geometry.size.width * 0.38) : nil)
                        .frame(maxHeight: wide ? .infinity : min(310, geometry.size.height * 0.43))
                }.padding(12)
            }
            }
            }
            .background(PhoneTheme.canvas)
            .toolbarVisibility(model.cameraMode ? .hidden : .visible, for: .navigationBar)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(closing ? "Finishing…" : "Done") {
                        requestClose(nil)
                    }.disabled(closing).accessibilityIdentifier("closeReader")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reader Settings", systemImage: "slider.horizontal.3") { settings = true }
                        .accessibilityIdentifier("readerSettings")
                }
            }
            .sheet(isPresented: $settings) { StudioSettings(preferences: $preferences) }
            #if DEBUG && !targetEnvironment(simulator)
            .safeAreaInset(edge: .top) {
                if model.probeRunning, let status = model.probeStatus {
                    Text(status).font(.callout.bold()).frame(maxWidth: .infinity, minHeight: 70)
                        .padding(.horizontal, 12).background(.regularMaterial)
                        .accessibilityIdentifier("physicalProbeStatus")
                }
            }
            #endif
            .task {
                await model.initialize()
                if startInCamera, !model.cameraMode { await model.enterCamera() }
                updateIdleTimer()
            }
            .onChange(of: model.playing) { updateIdleTimer() }
            .onChange(of: model.probeRunning) { updateIdleTimer() }
            .onChange(of: model.phase) {
                updateIdleTimer()
                if closing, model.phase == .idle { finishClosing() }
            }
            .onChange(of: scenePhase) {
                if scenePhase == .background { model.interrupt() }
                updateIdleTimer()
            }
            .onDisappear {
                model.interrupt()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .preferredColorScheme(.dark).tint(.white)
    }

    private func requestClose(_ section: PhoneSection?) {
        guard !closing else { return }
        returnSection = section
        closing = true
        model.interrupt(reason: "Recording ended when the reader closed.")
        if model.phase == .idle { finishClosing() }
    }

    private func finishClosing() {
        if let returnSection { returnToSection(returnSection) }
        dismiss()
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active
            && (model.playing || model.probeRunning || [.countdown, .starting, .recording].contains(model.phase))
    }

    private var controls: some View {
        @Bindable var model = model
        return ScrollView {
            VStack(spacing: 12) {
                Picker("Reader mode", selection: Binding(
                    get: { model.cameraMode },
                    set: { camera in
                        Task { if camera { await model.enterCamera() } else { await model.rehearsal() } }
                    }
                )) {
                    Text("Rehearsal").tag(false)
                    Text("Camera").tag(true)
                }.pickerStyle(.segmented).disabled(model.busy || model.cameraPreparing)
                    .accessibilityIdentifier("readerMode")
                let transportLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
                transportLayout {
                    Button(model.playing ? "Pause text" : "Play text",
                           systemImage: model.playing ? "pause.fill" : "play.fill") {
                        model.playing.toggle()
                    }.buttonStyle(.borderedProminent).tint(PhoneTheme.violet).font(.headline)
                        .disabled([.countdown, .starting, .stopping, .validating].contains(model.phase))
                        .accessibilityIdentifier("togglePrompt")
                    Button("Restart", systemImage: "backward.end.fill") {
                        model.playing = false
                        model.restart += 1
                    }.buttonStyle(.bordered).font(.headline).tint(.primary)
                        .accessibilityIdentifier("restartPrompt")
                }.controlSize(.large)
                if model.cameraMode {
                    let cameraLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
                    cameraLayout {
                        Menu("Camera", systemImage: "camera.rotate") {
                            Picker("Lens", selection: $model.side) {
                                Text("Front").tag(CameraSide.front)
                                Text("Rear").tag(CameraSide.rear)
                            }
                            Picker("Orientation", selection: $model.orientation) {
                                Text("Portrait").tag(CaptureOrientation.portrait)
                                Text("Landscape Left").tag(CaptureOrientation.landscapeLeft)
                                Text("Landscape Right").tag(CaptureOrientation.landscapeRight)
                            }
                        }.disabled(model.busy || model.cameraPreparing).font(.headline).tint(.primary).frame(minHeight: 44)
                        captureButton
                    }
                    .onChange(of: model.side) { Task { await model.enterCamera() } }
                }
                paceAndFont
                if model.cameraMode {
                    if let info = model.cameraInfo {
                        Text("\(info.cameraName) · 1080p · 30 fps · SDR")
                            .font(.caption).foregroundStyle(PhoneTheme.auxiliaryText)
                        Text("Microphone: \(info.microphoneName)")
                            .font(.caption).foregroundStyle(PhoneTheme.auxiliaryText)
                            .accessibilityIdentifier("microphoneRoute")
                        if let warning = info.warning {
                            Text(warning).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("No time limit · about 2 GB free to start").font(.caption)
                        .foregroundStyle(PhoneTheme.auxiliaryText)
                    if !model.busy {
                        Text("Orientation locks for each take. Front preview is mirrored; saved video is unmirrored.")
                            .font(.caption).foregroundStyle(PhoneTheme.auxiliaryText)
                    }
                }
                if let message = model.message {
                    Text(message).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("statusMessage")
                    if model.cameraMode, !model.cameraReady, !model.busy {
                        let recoveryLayout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
                        recoveryLayout {
                            Button("Retry Camera") { Task { await model.enterCamera() } }
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }.buttonStyle(.bordered).font(.headline).tint(.primary).controlSize(.large)
                    }
                }
            }.frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden)
    }

    private var paceAndFont: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Pace").font(.subheadline)
                Slider(value: $preferences.speed, in: 10...240, step: 1).accessibilityLabel("Prompt pace")
                            .accessibilityValue("\(Int(preferences.speed)) points per second")
                Text("\(Int(preferences.speed))").font(.subheadline).monospacedDigit().frame(minWidth: 32)
            }
            HStack {
                Text("Font").font(.subheadline)
                Slider(value: $preferences.fontSize, in: 20...72, step: 1).accessibilityLabel("Prompt font")
                            .accessibilityValue("\(Int(preferences.fontSize)) points")
                Text("\(Int(preferences.fontSize))").font(.subheadline).monospacedDigit().frame(minWidth: 32)
            }
        }
    }

    @ViewBuilder private var captureButton: some View {
        switch model.phase {
        case .countdown, .starting, .recording:
            Button(model.phase == .countdown ? "Cancel" : "Stop recording", systemImage: "stop.fill") {
                model.stop()
            }.buttonStyle(.borderedProminent).font(.headline).tint(.red).controlSize(.large)
                .accessibilityIdentifier("stopRecording")
        case .stopping, .validating:
            ProgressView("Saving take…")
        case .idle:
            if model.cameraPreparing { ProgressView("Opening camera…") }
            else {
                Button("Record", systemImage: "record.circle") { model.start() }
                    .buttonStyle(.borderedProminent).font(.headline).controlSize(.large)
                    .disabled(!model.canRecord).accessibilityIdentifier("recordTake")
            }
        }
    }
}

@MainActor private struct ReaderStage: View {
    let model: PrototypeModel
    @Binding var preferences: ReaderPreferences
    let handoff: ReaderAnchorHandoff
    let checkpoint: @MainActor (ReadingAnchor) -> Void
    @State private var moveOrigin: Double?
    @State private var heightOrigin: Double?

    var body: some View {
        GeometryReader { geometry in
            let available = max(0, geometry.size.height - 88)
            let panel = PromptPanelGeometry(availableHeight: available, preferences: preferences)
            ZStack(alignment: .top) {
                Color.black
                if model.cameraMode && model.cameraReady {
                    CameraPreview(source: model.capture.preview, side: model.captureSide,
                        orientation: model.captureOrientation, probe: model.readerProbe)
                        .aspectRatio(model.captureOrientation.aspect, contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                VStack(spacing: 0) {
                    handle("Move prompt", symbol: "line.3.horizontal")
                        .accessibilityValue("\(Int(preferences.panelPosition * 100)) percent down")
                        .gesture(DragGesture().onChanged { value in
                            let origin = moveOrigin ?? panel.y
                            moveOrigin = origin
                            preferences.panelPosition = panel.travel > 0
                                ? min(max((origin + value.translation.height) / panel.travel, 0), 1) : 0
                        }.onEnded { _ in moveOrigin = nil })
                        .accessibilityAdjustableAction { direction in
                            preferences.panelPosition = min(max(preferences.panelPosition + (direction == .increment ? 0.1 : -0.1), 0), 1)
                        }
                    PromptReader(text: model.script, fontSize: preferences.fontSize, speed: preferences.speed,
                                 playing: model.playing, restart: model.restart, probe: model.readerProbe,
                                 initialAnchor: model.initialAnchor, checkpoint: checkpoint,
                                 alignment: preferences.alignment.native, lightAppearance: preferences.appearance == .light,
                                 backgroundOpacity: preferences.backgroundOpacity, handoff: handoff) { model.playing = false }
                        .overlay(alignment: .top) {
                            if preferences.readingBand {
                                Rectangle().fill(Color.accentColor.opacity(preferences.appearance == .dark ? 0.28 : 0.13))
                                    .frame(height: preferences.fontSize * 1.35).padding(.top, 12)
                                    .allowsHitTesting(false).accessibilityHidden(true)
                            }
                        }
                        .frame(height: panel.height)
                    handle("Resize prompt", symbol: "arrow.up.and.down")
                        .accessibilityValue("\(Int(preferences.panelHeight * 100)) percent height")
                        .gesture(DragGesture().onChanged { value in
                            let origin = heightOrigin ?? panel.height
                            heightOrigin = origin
                            preferences.panelHeight = available > 0
                                ? min(max((origin + value.translation.height) / available, 0.30), 0.85) : 0.55
                        }.onEnded { _ in heightOrigin = nil })
                        .accessibilityAdjustableAction { direction in
                            preferences.panelHeight = min(max(preferences.panelHeight + (direction == .increment ? 0.05 : -0.05), 0.30), 0.85)
                        }
                }.padding(.horizontal, 8).offset(y: panel.y)
                if model.phase == .countdown {
                    Text("\(model.countdown)").font(.system(size: 72, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black.opacity(0.75))
                }
            }.overlay(alignment: .bottomLeading) {
                captureStatus.padding(12)
            }.clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder private var captureStatus: some View {
        switch model.phase {
        case .idle, .countdown: EmptyView()
        case .starting:
            Text("Starting recording…").font(.headline).padding(10)
                .foregroundStyle(.white).background(.black.opacity(0.9))
                .accessibilityIdentifier("captureState")
        case .recording:
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let elapsed = max(0, Int(timeline.date.timeIntervalSince(model.startedAt ?? timeline.date)))
                Label(String(format: "Recording %d:%02d", elapsed / 60, elapsed % 60), systemImage: "record.circle")
                    .font(.headline).monospacedDigit().padding(10)
                    .foregroundStyle(.white).background(.black.opacity(0.9))
            }.accessibilityIdentifier("captureState")
        case .stopping, .validating:
            Text("Finishing recording…").font(.headline).padding(10)
                .foregroundStyle(.white).background(.black.opacity(0.9))
                .accessibilityIdentifier("captureState")
        }
    }

    private func handle(_ title: String, symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
            Text(title).font(.caption)
            Spacer()
        }.foregroundStyle(.white).padding(.horizontal, 14).frame(height: 44)
            .background(.black.opacity(0.9)).contentShape(Rectangle())
            .accessibilityElement(children: .ignore).accessibilityLabel(title)
            .accessibilityIdentifier(title == "Move prompt" ? "movePrompt" : "resizePrompt")
    }
}

extension ReaderPreferences.Alignment {
    var title: String {
        switch self { case .natural: "Automatic"; case .left: "Left"; case .center: "Center"; case .right: "Right" }
    }
    var native: NSTextAlignment {
        switch self { case .natural: .natural; case .left: .left; case .center: .center; case .right: .right }
    }
}

@MainActor private struct StudioSettings: View {
    @Binding var preferences: ReaderPreferences
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Menu {
                        Picker("Alignment", selection: $preferences.alignment) {
                            ForEach(ReaderPreferences.Alignment.allCases, id: \.self) { alignment in
                                Text(alignment.title).tag(alignment)
                            }
                        }
                    } label: {
                        LabeledContent {
                            HStack {
                                Text(preferences.alignment.title)
                                Image(systemName: "chevron.up.chevron.down").font(.caption)
                            }.foregroundStyle(PhoneTheme.auxiliaryText)
                        } label: { Text("Alignment").foregroundStyle(.primary) }
                    }
                    Toggle("Reading band", isOn: $preferences.readingBand)
                } header: { Text("Reading").foregroundStyle(PhoneTheme.auxiliaryText) }
                Section {
                    Picker("Background", selection: $preferences.appearance) {
                        Text("Dark").tag(ReaderPreferences.Appearance.dark)
                        Text("Light").tag(ReaderPreferences.Appearance.light)
                    }.pickerStyle(.segmented)
                    LabeledContent("Opacity") {
                        Text(preferences.backgroundOpacity.formatted(.percent.precision(.fractionLength(0))))
                            .foregroundStyle(PhoneTheme.auxiliaryText)
                    }
                    Slider(value: $preferences.backgroundOpacity, in: 0.65...1, step: 0.05)
                        .accessibilityLabel("Prompt background opacity")
                        .accessibilityValue(preferences.backgroundOpacity.formatted(.percent.precision(.fractionLength(0))))
                } header: { Text("Prompt appearance").foregroundStyle(PhoneTheme.auxiliaryText) }
                Section {
                    Button("Reset near the lens") {
                        preferences.panelPosition = 0
                        preferences.panelHeight = 0.55
                    }
                } header: { Text("Position").foregroundStyle(PhoneTheme.auxiliaryText) }
            }.navigationTitle("Reader Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
