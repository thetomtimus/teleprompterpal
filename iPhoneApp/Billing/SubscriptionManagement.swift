import Observation
import StoreKit
import SwiftUI

/// Capture this view's actual window scene, and surface errors the SwiftUI sheet helper hides.
@MainActor @Observable final class SubscriptionManagement {
    private(set) var presenting = false
    private(set) var message: String?
    @ObservationIgnored weak var scene: UIWindowScene?

    func open() async {
        guard !presenting else { return }
        guard let scene else {
            message = "Apple’s subscription settings could not open. Return to this screen and try again."
            return
        }
        presenting = true; message = nil
        defer { presenting = false }
        do { try await AppStore.showManageSubscriptions(in: scene) }
        catch StoreKitError.userCancelled { }
        catch { message = "Apple’s subscription settings could not open. Check your connection and try again." }
    }
}

@MainActor struct SubscriptionSceneCapture: UIViewRepresentable {
    let management: SubscriptionManagement
    func makeUIView(context: Context) -> SceneView {
        let view = SceneView()
        view.management = management
        view.isUserInteractionEnabled = false
        return view
    }
    func updateUIView(_ view: SceneView, context: Context) { view.management = management }
    final class SceneView: UIView {
        weak var management: SubscriptionManagement?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            management?.scene = window?.windowScene
        }
    }
}
