import PhoneLibrary
import PromptingCore
import SwiftUI
import UIKit

@MainActor struct CameraStudioView: View {
    let model: PrototypeModel
    @Binding var preferences: ReaderPreferences
    let handoff: ReaderAnchorHandoff
    let checkpoint: @MainActor (ReadingAnchor) -> Void
    let close: (PhoneSection?) -> Void
    @State private var tool: CameraTool?
    @State private var moveOrigin: Double?
    @State private var heightOrigin: Double?
    @ScaledMetric(relativeTo: .caption) private var toolHeight = 58
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                // Status copy can shrink the preview in portrait at accessibility sizes.
                // Use the phone's size class, not the remaining preview aspect.
                let wide = verticalSizeClass == .compact
                let available = max(0, geometry.size.height - (wide ? 76 : min(toolHeight, 140) + 80))
                let panel = PromptPanelGeometry(availableHeight: available, preferences: preferences)
                ZStack(alignment: .top) {
                    preview(size: geometry.size)
                    Group {
                        if wide {
                            HStack(alignment: .top, spacing: 16) {
                                prompt(panel: panel, available: available).frame(maxWidth: .infinity)
                                textTools.frame(width: 220)
                            }.padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 10) {
                                prompt(panel: panel, available: available)
                                textTools
                            }.padding(.horizontal, 30)
                        }
                    }.offset(y: panel.y + 8)
                    VStack {
                        Spacer(minLength: 0)
                        cameraControls.padding(.horizontal, 20).padding(.bottom, 12)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            CameraMessage(model: model)
            RecordingDock(selection: nil, enabled: !model.cameraPreparing, select: { close($0) }) {
                captureControl
            }
        }
        .background(.black)
        .sheet(item: $tool) { selected in
            CameraToolSheet(tool: selected, model: model, preferences: $preferences)
                .presentationDetents(typeSize.isAccessibilitySize || selected == .background || selected == .camera ? [.large] : [.medium, .large])
                .tint(.white)
        }
        .onChange(of: model.side) { Task { await model.enterCamera() } }
    }

    private func preview(size: CGSize) -> some View {
        ZStack {
            Color.black
            if model.cameraReady {
                CameraPreview(source: model.capture.preview, side: model.captureSide,
                    orientation: model.captureOrientation, probe: model.readerProbe)
                    .aspectRatio(model.captureOrientation.aspect, contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            }
            #if DEBUG && targetEnvironment(simulator)
            if SimulatorIntegrationFixture.accepts("--p6b-camera-preview-fixture") {
                Image("OnboardingPresenter").resizable().scaledToFill()
                    .frame(width: size.width, height: size.height).clipped().accessibilityHidden(true)
            }
            #endif
        }.frame(width: size.width, height: size.height)
    }

    private func prompt(panel: PromptPanelGeometry, available: Double) -> some View {
        VStack(spacing: 0) {
            PromptReader(text: model.script, fontSize: preferences.fontSize, speed: preferences.speed,
                playing: model.playing, restart: model.restart, probe: model.readerProbe,
                initialAnchor: model.initialAnchor, checkpoint: checkpoint,
                alignment: preferences.alignment.native, lightAppearance: preferences.appearance == .light,
                backgroundOpacity: 0, handoff: handoff) { model.playing = false }
                .frame(height: max(0, panel.height - 44))
                .overlay(alignment: .top) {
                    if preferences.readingBand {
                        Rectangle().fill(.white.opacity(0.14)).frame(height: preferences.fontSize * 1.35)
                            .padding(.top, 12).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            VStack(spacing: 3) {
                HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().frame(width: 3, height: 3) } }
                HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().frame(width: 3, height: 3) } }
            }.foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 44)
                .contentShape(Rectangle())
                .gesture(DragGesture().onChanged { value in
                    let origin = moveOrigin ?? panel.y
                    moveOrigin = origin
                    preferences.panelPosition = panel.travel > 0
                        ? min(max((origin + value.translation.height) / panel.travel, 0), 1) : 0
                }.onEnded { _ in moveOrigin = nil })
                .accessibilityLabel("Move prompt").accessibilityIdentifier("movePrompt")
                .accessibilityValue("\(Int(preferences.panelPosition * 100)) percent down")
                .accessibilityHint("Drag vertically, or swipe up and down with VoiceOver, to move the prompt.")
                .accessibilityAdjustableAction { direction in
                    preferences.panelPosition = min(max(preferences.panelPosition + (direction == .increment ? 0.1 : -0.1), 0), 1)
                }
        }
        .background((preferences.appearance == .light ? Color.white : .black).opacity(preferences.backgroundOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay {
            PromptCorners().stroke(.white.opacity(0.42), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .padding(8).allowsHitTesting(false).accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
                .gesture(DragGesture().onChanged { value in
                    let origin = heightOrigin ?? panel.height
                    heightOrigin = origin
                    preferences.panelHeight = available > 0
                        ? min(max((origin + value.translation.height) / available, 0.30), 0.85) : 0.55
                }.onEnded { _ in heightOrigin = nil })
                .accessibilityLabel("Resize prompt").accessibilityIdentifier("resizePrompt")
                .accessibilityValue("\(Int(preferences.panelHeight * 100)) percent height")
                .accessibilityAdjustableAction { direction in
                    preferences.panelHeight = min(max(preferences.panelHeight + (direction == .increment ? 0.05 : -0.05), 0.30), 0.85)
                }
        }
    }

    private var textTools: some View {
        HStack(spacing: 0) {
            toolButton("Size", symbol: "textformat.size", tool: .size, identifier: "promptSize")
            toolButton("Background", symbol: "circle.lefthalf.filled", tool: .background, identifier: "readerSettings")
            toolButton("Speed", symbol: "speedometer", tool: .speed, identifier: "promptSpeed")
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .frame(maxWidth: typeSize.isAccessibilitySize ? 320 : 230)
    }

    private func toolButton(_ title: String, symbol: String, tool: CameraTool, identifier: String) -> some View {
        Button { self.tool = tool } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol).font(.title3)
                if !typeSize.isAccessibilitySize { Text(title).font(.caption).multilineTextAlignment(.center) }
            }.frame(maxWidth: .infinity, minHeight: 50).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier(identifier)
    }

    private var cameraControls: some View {
        HStack(spacing: 18) {
            Button { tool = .camera } label: {
                Image(systemName: "video").font(.system(size: 22)).frame(width: 52, height: 48)
                    .overlay(alignment: .topTrailing) {
                        Text("FHD").font(.caption2.bold()).dynamicTypeSize(...DynamicTypeSize.xxxLarge).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(PhoneTheme.violet, in: Capsule()).offset(x: 9, y: -3)
                    }
            }.buttonStyle(.plain).accessibilityLabel("Camera settings, 1080p at 30 frames per second")
                .accessibilityIdentifier("cameraOptions")
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                CameraRecordingStatus(model: model)
                HStack(spacing: 12) {
                    Button(model.playing ? "Pause text" : "Play text", systemImage: model.playing ? "pause.fill" : "play.fill") {
                        model.playing.toggle()
                    }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("togglePrompt")
                        .disabled([.countdown, .starting, .stopping, .validating].contains(model.phase))
                    Button("Restart", systemImage: "backward.end.fill") {
                        model.playing = false; model.restart += 1
                    }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("restartPrompt")
                }.labelStyle(.iconOnly).font(.system(size: 19)).buttonStyle(.borderless).controlSize(.large)
                    .frame(minHeight: 44)
            }.padding(.horizontal, 8).background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 0)
            Button("Switch camera", systemImage: "camera.rotate") {
                model.side = model.side == .front ? .rear : .front
            }.labelStyle(.iconOnly).font(.system(size: 22)).frame(width: 52, height: 48).buttonStyle(.plain)
                .disabled(model.busy || model.cameraPreparing).accessibilityIdentifier("switchCamera")
        }
    }

    @ViewBuilder private var captureControl: some View {
        switch model.phase {
        case .recording:
            RecordCircle(title: "Stop recording", identifier: "stopRecording", stopping: true) { model.stop() }
        case .countdown:
            Button("Cancel countdown") { model.interrupt(reason: "Countdown cancelled.") }
                .font(.headline).frame(width: 66, height: 66).background(PhoneTheme.card, in: Circle())
                .accessibilityIdentifier("cancelCountdown")
        case .idle:
            RecordCircle(title: "Record", identifier: "recordTake", enabled: model.canRecord) { model.start() }
        case .starting, .stopping, .validating:
            ProgressView().frame(width: 66, height: 66).background(PhoneTheme.card, in: Circle())
                .accessibilityLabel("Finishing recording")
        }
    }
}

private struct PromptCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(23, min(rect.width, rect.height) / 4)
        for (x, y, dx, dy) in [(rect.minX,rect.minY,1.0,1.0),(rect.maxX,rect.minY,-1.0,1.0),
                               (rect.minX,rect.maxY,1.0,-1.0),(rect.maxX,rect.maxY,-1.0,-1.0)] {
            path.move(to: CGPoint(x: x, y: y + dy * length))
            path.addQuadCurve(to: CGPoint(x: x + dx * length, y: y), control: CGPoint(x: x, y: y))
        }
        return path
    }
}

private enum CameraTool: String, Identifiable { case size, background, speed, camera; var id: Self { self } }

@MainActor private struct CameraToolSheet: View {
    let tool: CameraTool
    let model: PrototypeModel
    @Binding var preferences: ReaderPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                switch tool {
                case .size:
                    Section("Text") {
                        LabeledContent("Font size", value: "\(Int(preferences.fontSize)) pt")
                        Slider(value: $preferences.fontSize, in: 20...72, step: 1).accessibilityLabel("Prompt font")
                            .accessibilityValue("\(Int(preferences.fontSize)) points")
                    }
                case .speed:
                    Section("Scrolling") {
                        LabeledContent("Pace", value: "\(Int(preferences.speed)) pt/s")
                        Slider(value: $preferences.speed, in: 10...240, step: 1).accessibilityLabel("Prompt pace")
                            .accessibilityValue("\(Int(preferences.speed)) points per second")
                        Button(model.playing ? "Pause text" : "Play text") { model.playing.toggle() }
                    }
                case .background:
                    Section("Reading") {
                        Picker("Alignment", selection: $preferences.alignment) {
                            ForEach(ReaderPreferences.Alignment.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Toggle("Reading band", isOn: $preferences.readingBand)
                    }
                    Section("Prompt appearance") {
                        Picker("Background", selection: $preferences.appearance) {
                            Text("Dark").tag(ReaderPreferences.Appearance.dark)
                            Text("Light").tag(ReaderPreferences.Appearance.light)
                        }.pickerStyle(.segmented)
                        LabeledContent("Opacity", value: preferences.backgroundOpacity.formatted(.percent.precision(.fractionLength(0))))
                        Slider(value: $preferences.backgroundOpacity, in: 0.65...1, step: 0.05)
                            .accessibilityLabel("Prompt background opacity")
                        .accessibilityValue(preferences.backgroundOpacity.formatted(.percent.precision(.fractionLength(0))))
                    }
                    Section("Position") {
                        Button("Reset near the lens") { preferences.panelPosition = 0; preferences.panelHeight = 0.55 }
                    }
                case .camera:
                    Section("Recording format") {
                        Text("1080p · 30 fps · SDR")
                        Text("No time limit · about 2 GB free to start").foregroundStyle(PhoneTheme.auxiliaryText)
                        Text("Recording stops if storage runs low or the camera is interrupted.")
                            .foregroundStyle(PhoneTheme.auxiliaryText)
                        Text("Orientation locks for each take. Front preview is mirrored; saved video is unmirrored.")
                            .foregroundStyle(PhoneTheme.auxiliaryText)
                    }
                    Section("Camera") {
                        Picker("Lens", selection: $model.side) {
                            Text("Front").tag(CameraSide.front); Text("Rear").tag(CameraSide.rear)
                        }
                        Picker("Orientation", selection: $model.orientation) {
                            Text("Portrait").tag(CaptureOrientation.portrait)
                            Text("Landscape Left").tag(CaptureOrientation.landscapeLeft)
                            Text("Landscape Right").tag(CaptureOrientation.landscapeRight)
                        }
                    }.disabled(model.busy || model.cameraPreparing)
                    if let info = model.cameraInfo {
                        Section("Audio") {
                            Text("Microphone: \(info.microphoneName)").accessibilityIdentifier("microphoneRoute")
                            if let warning = info.warning { Text(warning) }
                        }
                    }
                    Section {
                        Button("Rehearse without camera") { Task { await model.rehearsal(); dismiss() } }
                            .disabled(model.busy || model.cameraPreparing)
                    }
                }
            }
            .navigationTitle(tool == .background ? "Reader Settings" : tool.rawValue.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

@MainActor private struct CameraMessage: View {
    let model: PrototypeModel
    @State private var details = false
    var body: some View {
        VStack(spacing: 4) {
            if model.cameraPreparing { ProgressView("Opening camera…") }
            #if DEBUG && targetEnvironment(simulator)
            if SimulatorIntegrationFixture.accepts("--p6b-camera-preview-fixture") {
                Text("Illustrated preview · not live").font(.caption2)
                    .accessibilityIdentifier("simulatorPreviewLabel")
            }
            #endif
            if let message = model.message {
                HStack(spacing: 8) {
                    Text(summary(message)).font(.caption).lineLimit(2)
                        .accessibilityLabel(message).accessibilityIdentifier("statusMessage")
                    Button("Camera information", systemImage: "info.circle") { details = true }
                        .labelStyle(.iconOnly).font(.system(size: 19)).frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("cameraInformation")
                }
            }
        }.frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, model.message == nil ? 0 : 4)
            .background(PhoneTheme.canvas)
            .alert("Camera information", isPresented: $details) {
                Button("Retry Camera") { Task { await model.enterCamera() } }
                Button("Rehearse") { Task { await model.rehearsal() } }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Button("OK", role: .cancel) { }
            } message: { Text(model.message ?? "Camera settings are available from the FHD control.") }
    }
    private func summary(_ message: String) -> String {
        #if targetEnvironment(simulator)
        if message.contains("Simulator") { return "Camera unavailable in Simulator" }
        #endif
        return message
    }
}

@MainActor private struct CameraRecordingStatus: View {
    let model: PrototypeModel
    var body: some View {
        Group {
            switch model.phase {
            case .idle: EmptyView()
            case .countdown: Text("\(model.countdown)").font(.title.bold())
            case .starting: Text("Starting recording…")
            case .recording:
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let elapsed = max(0, Int(timeline.date.timeIntervalSince(model.startedAt ?? timeline.date)))
                    Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60)).monospacedDigit()
                        .accessibilityLabel(String(format: "Recording %d:%02d", elapsed / 60, elapsed % 60))
                }
            case .stopping, .validating: Text("Finishing recording…")
            }
        }.font(.caption.bold()).dynamicTypeSize(...DynamicTypeSize.xxxLarge).accessibilityIdentifier("captureState")
    }
}
