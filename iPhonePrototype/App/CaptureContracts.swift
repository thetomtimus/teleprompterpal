import AVFoundation
import Foundation

struct CaptureReadiness: Equatable, Sendable {
    let sessionID: UUID
    let cameraName: String
    let microphoneName: String
    var warning: String?
}

enum CaptureStopReason: String, CaseIterable, Sendable {
    case sessionInterrupted, cameraError, mediaServicesReset, audioInterrupted, routeChanged
    case lowStorage, thermal, pressure

    var message: String {
        switch self {
        case .sessionInterrupted: "The camera was interrupted."
        case .cameraError: "The camera stopped unexpectedly."
        case .mediaServicesReset: "Camera and audio services restarted."
        case .audioInterrupted: "Another app or call interrupted the microphone."
        case .routeChanged: "The microphone connection changed."
        case .lowStorage: "Free space is running low."
        case .thermal: "The iPhone needs to cool down."
        case .pressure: "The camera needs a break."
        }
    }
}

enum CapturePermission: Sendable { case authorized, denied, restricted, undecided }

struct CapturePermissions: Sendable {
    var camera: CapturePermission
    var microphone: CapturePermission

    var denialMessage: String? {
        if camera != .authorized { return "Allow camera access in Settings, or use Rehearsal." }
        if microphone != .authorized { return "Allow microphone access in Settings, or use Rehearsal." }
        return nil
    }
}

enum CaptureAuthorization {
    @concurrent static func request() async -> CapturePermissions {
        #if targetEnvironment(simulator)
        return CapturePermissions(camera: .authorized, microphone: .authorized)
        #else
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        let camera = permission(AVCaptureDevice.authorizationStatus(for: .video))
        if camera == .authorized, AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        return CapturePermissions(camera: camera, microphone: permission(AVCaptureDevice.authorizationStatus(for: .audio)))
        #endif
    }

    private static func permission(_ status: AVAuthorizationStatus) -> CapturePermission {
        switch status {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .undecided
        @unknown default: .denied
        }
    }
}

/// The actor returns from record only after accepting the operation; a thrown error
/// means no recording was accepted. Every stop targets that same operation ID.
protocol CaptureControlling: Sendable {
    var preview: PreviewSource { get }
    var events: AsyncStream<CaptureEvent> { get }
    func configure(side: CameraSide, generation: UUID) async throws
    func startPreview() async throws -> CaptureReadiness
    func record(id: UUID, to url: URL, orientation: CaptureOrientation) async throws
    func stop(id: UUID?) async
    func suspend(generation: UUID?) async
    func stopPreview(generation: UUID?) async
    func snapshot() async -> CaptureSnapshot
    @available(iOS 27, *) func position(for orientation: CaptureOrientation) async -> CapturePosition?
    func shutdown() async
    func preparePlayback(id: UUID) async throws
    func finishPlayback(id: UUID) async
}

/// Synchronous actions execute on CaptureService's serial executor. Tests can
/// observe audio ownership without changing the process-wide audio session.
struct CaptureAudioActions: Sendable {
    var camera: @Sendable () throws -> Void
    var playback: @Sendable () throws -> Void
    var deactivate: @Sendable () throws -> Void

    static let live = CaptureAudioActions(camera: {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playAndRecord, mode: .videoRecording, options: [])
        try audio.setActive(true)
    }, playback: {
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .moviePlayback, options: [])
        try audio.setActive(true)
    }, deactivate: {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    })
}
