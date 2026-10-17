import AVFoundation
import Dispatch
import Foundation
import PrototypeSupport
import UIKit

enum CameraSide: String, CaseIterable, Sendable { case front, rear }
enum CaptureOrientation: String, CaseIterable, Sendable {
    case portrait, landscapeLeft, landscapeRight
    var aspect: CGFloat { self == .portrait ? 9.0 / 16 : 16.0 / 9 }

    func angle(using coordinator: AVCaptureDevice.RotationCoordinator) -> CGFloat {
        if #available(iOS 27, *) {
            // Native sensor orientation differs between cameras; a universal 90° is incorrect.
            switch self {
            case .portrait: return coordinator.videoRotationAngleRelative(toDeviceOrientation: .portrait)
            case .landscapeLeft: return coordinator.videoRotationAngleRelative(toDeviceOrientation: .landscapeLeft)
            case .landscapeRight: return coordinator.videoRotationAngleRelative(toDeviceOrientation: .landscapeRight)
            }
        }
        // Before the static-angle API, freeze the gravity-correct angle at capture start.
        // The operator must hold the phone in the desired orientation before starting a take.
        return coordinator.videoRotationAngleForHorizonLevelCapture
    }
}

enum CaptureEvent: Sendable {
    case started(UUID)
    case finished(UUID, URL, Bool, String?)
    case interrupted(UUID, UUID?, CaptureStopReason)
    case status(CaptureReadiness)
}

enum CaptureRecordingPolicy {
    /// AVFoundation's invalid duration and zero byte ceiling impose no app time/size cap.
    /// Keep real disk headroom checks so a long take can still finalize safely.
    static func configure(_ output: AVCaptureMovieFileOutput) {
        output.maxRecordedDuration = .invalid
        output.maxRecordedFileSize = 0
        output.minFreeDiskSpaceLimit = CaptureStoragePolicy.outputReserve
        output.movieFragmentInterval = CMTime(seconds: 5, preferredTimescale: 600)
    }
}

/// Narrow AVFoundation bridge. Session mutation belongs exclusively to CaptureService's
/// serial executor. MainActor only attaches it to a layer and configures that layer's
/// preview connection. No view receives the session or device/output references.
final class PreviewSource: @unchecked Sendable {
    fileprivate let session = AVCaptureSession()

    @MainActor func attach(to view: PreviewView, side: CameraSide) {
        let layer = view.previewLayer
        if layer.session !== session { layer.session = session }
        if layer.videoGravity != .resizeAspect { layer.videoGravity = .resizeAspect }
        view.configureRotation(side: side)
        if let connection = layer.connection {
            if connection.isVideoMirroringSupported {
                if connection.automaticallyAdjustsVideoMirroring {
                    connection.automaticallyAdjustsVideoMirroring = false
                }
                let mirrored = side == .front
                if connection.isVideoMirrored != mirrored { connection.isVideoMirrored = mirrored }
            }
        }
    }
}

actor CaptureService: CaptureControlling {
    nonisolated let preview = PreviewSource()
    nonisolated let events: AsyncStream<CaptureEvent>
    private let continuation: AsyncStream<CaptureEvent>.Continuation
    private let queue = DispatchSerialQueue(label: "com.secondwind.teleprompter.capture", qos: .userInitiated)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }
    private var session: AVCaptureSession { preview.session }
    private let output = AVCaptureMovieFileOutput()
    private var configured = false
    private var activeID: UUID?
    private var stopRequested = false
    private var suspended = false
    private var delegate: MovieDelegate?
    private var observers: [NSObjectProtocol] = []
    private var activeDevice: AVCaptureDevice?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var rotationGeneration = UUID()
    private var horizonAngle: CGFloat?
    private var recordingAngle: CGFloat?
    private var sessionID = UUID()
    private var microphoneRoute: [String] = []
    private var pressureObservation: NSKeyValueObservation?
    private var healthWarning: String?
    private var playbackID: UUID?
    private let audioActions: CaptureAudioActions

    init(audio: CaptureAudioActions = .live) {
        audioActions = audio
        let pair = AsyncStream<CaptureEvent>.makeStream()
        events = pair.stream
        continuation = pair.continuation
    }

    func configure(side: CameraSide, generation: UUID) throws {
        guard activeID == nil else { throw CaptureFailure.busy }
        playbackID = nil
        configured = false
        suspended = true
        sessionID = generation
        #if targetEnvironment(simulator)
        throw CaptureFailure.simulator
        #else
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        else { throw CaptureFailure.permission }
        guard ProcessInfo.processInfo.thermalState != .critical else { throw CaptureFailure.overheated }
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video,
                position: side == .front ? .front : .back),
            let mic = AVCaptureDevice.default(for: .audio)
        else { throw CaptureFailure.noCamera }
        guard
            let format = device.formats.first(where: {
                let dims = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                return dims.width == 1920 && dims.height == 1080
                    && $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
            })
        else { throw CaptureFailure.format }
        let videoInput = try AVCaptureDeviceInput(device: device)
        let audioInput = try AVCaptureDeviceInput(device: mic)
        try audioActions.camera()
        session.automaticallyConfiguresApplicationAudioSession = false
        session.beginConfiguration()
        // This synchronous transaction never suspends or overlaps start/stop.
        defer { session.commitConfiguration() }
        for input in session.inputs { session.removeInput(input) }
        session.sessionPreset = .inputPriority
        guard session.canAddInput(videoInput), session.canAddInput(audioInput) else { throw CaptureFailure.noCamera }
        session.addInput(videoInput)
        session.addInput(audioInput)
        if !session.outputs.contains(output) {
            guard session.canAddOutput(output) else { throw CaptureFailure.noCamera }
            session.addOutput(output)
        }
        try device.lockForConfiguration()
        device.activeFormat = format
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        device.automaticallyAdjustsVideoHDREnabled = false
        if format.isVideoHDRSupported { device.isVideoHDREnabled = false }
        device.unlockForConfiguration()
        activeDevice = device
        guard ![.critical, .shutdown].contains(device.systemPressureState.level) else {
            throw CaptureFailure.pressure
        }
        rotationObservation?.invalidate()
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        rotationCoordinator = coordinator
        let rotationID = UUID()
        rotationGeneration = rotationID
        horizonAngle = coordinator.videoRotationAngleForHorizonLevelCapture
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]
        ) {
            [weak self] coordinator, change in
            let angle = change.newValue ?? coordinator.videoRotationAngleForHorizonLevelCapture
            Task { @concurrent in await self?.receivedHorizonAngle(angle, generation: rotationID) }
        }
        guard output.availableVideoCodecTypes.contains(.h264), let connection = output.connection(with: .video) else {
            throw CaptureFailure.format
        }
        output.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
        CaptureRecordingPolicy.configure(output)
        configured = true
        microphoneRoute = currentMicrophoneRoute()
        healthWarning = ProcessInfo.processInfo.thermalState == .serious ? "The iPhone is warm. Watch for a camera interruption." : nil
        installObservers()
        #endif
    }

    func startPreview() throws -> CaptureReadiness {
        guard configured, activeID == nil else { throw CaptureFailure.noCamera }
        suspended = false
        if !session.isRunning { session.startRunning() }
        guard session.isRunning else { throw CaptureFailure.noCamera }
        guard !AVAudioSession.sharedInstance().currentRoute.inputs.isEmpty else {
            stopPreview()
            throw CaptureFailure.microphone
        }
        microphoneRoute = currentMicrophoneRoute()
        return readiness()
    }

    func record(id: UUID, to url: URL, orientation: CaptureOrientation) throws {
        try Task.checkCancellation()
        guard configured, !suspended, session.isRunning, activeID == nil else { throw CaptureFailure.busy }
        guard let connection = output.connection(with: .video), let rotationCoordinator else {
            throw CaptureFailure.format
        }
        let angle = orientation.angle(using: rotationCoordinator)
        guard connection.isVideoRotationAngleSupported(angle)
        else { throw CaptureFailure.format }
        connection.videoRotationAngle = angle
        recordingAngle = angle
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        activeID = id
        stopRequested = false
        let delegate = MovieDelegate(id: id) { [weak self] event in
            Task { await self?.receive(event) }
        }
        self.delegate = delegate
        output.startRecording(to: url, recordingDelegate: delegate)
    }

    func stop(id: UUID? = nil) {
        if let id, activeID != id { return }
        stopRequested = true
        if output.isRecording { output.stopRecording() }
    }

    func suspend(generation: UUID? = nil) {
        if let generation, generation != sessionID { return }
        suspended = true
        stop()
        if activeID == nil { stopPreview() }
    }

    func stopPreview(generation: UUID? = nil) {
        if let generation, generation != sessionID { return }
        guard activeID == nil else { return }
        suspended = true
        if session.isRunning { session.stopRunning() }
        // A delayed camera teardown may arrive after original playback acquired
        // the same audio session. Only its scoped playback lease may release it.
        if playbackID == nil { try? audioActions.deactivate() }
    }

    // Concrete and protocol-based calls use the same async actor operations.
    func preparePlayback(id: UUID) async throws {
        guard activeID == nil else { throw CaptureFailure.busy }
        stopPreview()
        try audioActions.playback()
        playbackID = id
    }

    func finishPlayback(id: UUID) async {
        releasePlayback(id: id)
    }

    private func releasePlayback(id: UUID) {
        guard playbackID == id else { return }
        playbackID = nil
        try? audioActions.deactivate()
    }

    private func receive(_ event: CaptureEvent) {
        switch event {
        case .started(let id):
            guard activeID == id else { return }
            continuation.yield(event)
            if stopRequested { output.stopRecording() }
        case .finished(let id, _, _, _):
            guard activeID == id else { return }
            activeID = nil
            delegate = nil
            continuation.yield(event)
            if suspended { stopPreview() }
        case .interrupted(let generation, _, _):
            guard generation == sessionID, configured else { return }
            configured = false
            suspended = true
            stop()
            continuation.yield(event)
            if activeID == nil { stopPreview() }
        case .status(let info):
            guard info.sessionID == sessionID, configured else { return }
            continuation.yield(event)
        }
    }

    func shutdown() {
        suspend()
        // Keep finalization callbacks alive until the original file is closed.
        guard activeID == nil else { return }
        if let playbackID { releasePlayback(id: playbackID) }
        for token in observers { NotificationCenter.default.removeObserver(token) }
        observers.removeAll()
        rotationObservation?.invalidate()
        pressureObservation?.invalidate()
        continuation.finish()
    }

    func snapshot() -> CaptureSnapshot {
        let dimensions = activeDevice.map { CMVideoFormatDescriptionGetDimensions($0.activeFormat.formatDescription) }
        let duration = activeDevice?.activeVideoMinFrameDuration.seconds ?? 0
        return CaptureSnapshot(
            elapsed: 0, thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            pressure: activeDevice?.systemPressureState.level.rawValue ?? "unavailable",
            width: Int(dimensions?.width ?? 0), height: Int(dimensions?.height ?? 0),
            requestedFPS: duration > 0 ? 1 / duration : 0,
            hdrEnabled: activeDevice?.isVideoHDREnabled ?? false,
            audioInputs: AVAudioSession.sharedInstance().currentRoute.inputs.map { $0.portType.rawValue },
            recordingRotationAngle: recordingAngle.map(Double.init),
            horizonCaptureRotationAngle: horizonAngle.map(Double.init),
            sessionRunning: session.isRunning, outputRecording: output.isRecording, stopRequested: stopRequested
        )
    }

    @available(iOS 27, *)
    func position(for orientation: CaptureOrientation) -> CapturePosition? {
        guard let rotationCoordinator else { return nil }
        let actual = Double(horizonAngle ?? rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        let expected = Double(orientation.angle(using: rotationCoordinator))
        let delta = abs(actual - expected).truncatingRemainder(dividingBy: 360)
        return CapturePosition(actual: actual, expected: expected, matches: min(delta, 360 - delta) < 20)
    }

    private func receivedHorizonAngle(_ angle: CGFloat, generation: UUID) {
        guard generation == rotationGeneration else { return }
        horizonAngle = angle
    }

    private func installObservers() {
        for token in observers { NotificationCenter.default.removeObserver(token) }
        observers.removeAll()
        pressureObservation?.invalidate()
        let generation = sessionID
        for name in [
            AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification,
            AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
        ] {
            let isSessionNotification = name == AVCaptureSession.wasInterruptedNotification || name == AVCaptureSession.runtimeErrorNotification
            let token = NotificationCenter.default.addObserver(forName: name, object: isSessionNotification ? session : nil, queue: nil) {
                [weak self] notification in
                if notification.name == AVAudioSession.interruptionNotification,
                    (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                        != AVAudioSession.InterruptionType.began.rawValue
                {
                    return
                }
                if notification.name == AVAudioSession.routeChangeNotification {
                    // Category changes generated by our own setup do not invalidate a new preview.
                    if (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                        == AVAudioSession.RouteChangeReason.categoryChange.rawValue { return }
                    Task { @concurrent in await self?.microphoneChanged(generation: generation) }
                    return
                }
                let reason: CaptureStopReason
                if notification.name == AVAudioSession.interruptionNotification { reason = .audioInterrupted }
                else if notification.name == AVCaptureSession.runtimeErrorNotification {
                    let code = (notification.userInfo?[AVCaptureSessionErrorKey] as? NSError)?.code
                    reason = code == AVError.mediaServicesWereReset.rawValue ? .mediaServicesReset : .cameraError
                } else { reason = .sessionInterrupted }
                Task { @concurrent in await self?.interrupted(reason, generation: generation) }
            }
            observers.append(token)
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @concurrent in await self?.healthChanged(generation: generation) }
        })
        pressureObservation = activeDevice?.observe(\.systemPressureState, options: [.new]) { [weak self] _, _ in
            Task { @concurrent in await self?.healthChanged(generation: generation) }
        }
    }

    private func currentMicrophoneRoute() -> [String] {
        AVAudioSession.sharedInstance().currentRoute.inputs.map { $0.uid + ":" + $0.portType.rawValue }
    }

    private func readiness() -> CaptureReadiness {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs.map(\.portName)
        return CaptureReadiness(sessionID: sessionID, cameraName: activeDevice?.localizedName ?? "Camera",
                                microphoneName: inputs.isEmpty ? "Unavailable" : inputs.joined(separator: ", "),
                                warning: healthWarning)
    }

    private func microphoneChanged(generation: UUID) {
        guard generation == sessionID, configured, !suspended else { return }
        let route = currentMicrophoneRoute()
        guard route != microphoneRoute else { return }
        microphoneRoute = route
        interrupted(.routeChanged, generation: generation)
    }

    private func healthChanged(generation: UUID) {
        guard generation == sessionID, configured else { return }
        if ProcessInfo.processInfo.thermalState == .critical { interrupted(.thermal, generation: generation); return }
        let pressure = activeDevice?.systemPressureState.level
        if pressure == .critical || pressure == .shutdown { interrupted(.pressure, generation: generation); return }
        healthWarning = ProcessInfo.processInfo.thermalState == .serious || pressure == .serious
            ? "The iPhone is warm or the camera is under load. Watch for an interruption." : nil
        continuation.yield(.status(readiness()))
    }

    private func interrupted(_ reason: CaptureStopReason, generation: UUID) {
        receive(.interrupted(generation, activeID, reason))
    }
}

struct CapturePosition: Sendable {
    let actual: Double
    let expected: Double
    let matches: Bool
}

private final class MovieDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, Sendable {
    let id: UUID
    let emit: @Sendable (CaptureEvent) -> Void
    init(id: UUID, emit: @escaping @Sendable (CaptureEvent) -> Void) {
        self.id = id
        self.emit = emit
    }

    func fileOutput(
        _ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]
    ) {
        emit(.started(id))
    }
    func fileOutput(
        _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection], error: Error?
    ) {
        let succeeded =
            error == nil || (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        let note: String?
        switch (error as NSError?)?.code {
        case AVError.diskFull.rawValue: note = "Recording ended because free space ran low."
        default: note = error?.localizedDescription
        }
        emit(.finished(id, outputFileURL, succeeded, note))
    }
}

enum CaptureFailure: Error, LocalizedError {
    case simulator, permission, noCamera, format, busy, microphone, overheated, pressure, storage, storageUnknown
    var errorDescription: String? {
        switch self {
        case .simulator: "Camera is unavailable in Simulator. Rehearse here, or record on your iPhone."
        case .permission: "Allow camera and microphone access in Settings, or use rehearsal."
        case .noCamera: "The camera is unavailable. Try entering Camera again."
        case .format: "This camera cannot record 1080p at 30 fps in SDR. Try the other camera."
        case .busy: "Wait for the current take to finish."
        case .microphone: "No microphone is connected. Reconnect it and enter Camera again, or use Rehearsal."
        case .overheated: "Let the iPhone cool down, then enter Camera again."
        case .pressure: "Let the camera recover, then enter Camera again."
        case .storage: "Free about 2 GB to start recording. Rehearsal is available."
        case .storageUnknown: "Free space could not be checked. Try Camera again, or use Rehearsal."
        }
    }
}
