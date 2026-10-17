import PrototypeSupport
import SwiftUI
import UIKit

/// A persistent host owns the native controller and delegate through completion.
/// Presenting directly avoids SwiftUI tearing down a picker's weak delegate
/// before its post-dismissal export callback arrives.
struct MP4DeliveryPresenter: UIViewControllerRepresentable {
    let request: DeliveryPresentation?
    let delivery: MP4DeliveryController

    func makeUIViewController(context: Context) -> Host { Host(delivery: delivery) }
    func updateUIViewController(_ host: Host, context: Context) { host.update(request) }

    @MainActor final class Host: UIViewController {
        private let delivery: MP4DeliveryController
        private var pending: DeliveryPresentation?
        private var shownID: UUID?
        private var native: UIViewController?
        private var coordinator: NativeDelegate?

        init(delivery: MP4DeliveryController) { self.delivery = delivery; super.init(nibName: nil, bundle: nil) }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override func viewDidLoad() { super.viewDidLoad(); view.backgroundColor = .clear }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); showPending() }

        func update(_ request: DeliveryPresentation?) {
            pending = request
            if request == nil {
                if let native { native.dismiss(animated: true) { [weak self] in self?.showPending() } }
                native = nil; coordinator = nil; shownID = nil
            } else { showPending() }
        }

        private func showPending() {
            var presenter = parent ?? self
            while let ancestor = presenter.parent { presenter = ancestor }
            while let visible = presenter.presentedViewController { presenter = visible }
            guard let pending, pending.id != shownID, isViewLoaded, view.window != nil,
                  !presenter.isBeingDismissed else { return }
            shownID = pending.id
            let coordinator = NativeDelegate(id: pending.id, delivery: delivery)
            self.coordinator = coordinator
            let controller: UIViewController
            if pending.destination == .files {
                let picker = UIDocumentPickerViewController(forExporting: [pending.url], asCopy: true)
                picker.delegate = coordinator; picker.shouldShowFileExtensions = true
                picker.modalPresentationStyle = .pageSheet
                picker.sheetPresentationController?.prefersGrabberVisible = true
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                picker.directoryURL = documents
                controller = picker
            } else {
                let activity = UIActivityViewController(activityItems: [pending.url], applicationActivities: nil)
                activity.excludedActivityTypes = [.saveToCameraRoll]
                let id = pending.id, delivery = delivery
                activity.completionWithItemsHandler = { type, completed, _, error in
                    let reference = type?.rawValue, message = error?.localizedDescription
                    Task { @MainActor in delivery.completePresentation(id: id, completed: completed, reference: reference, error: message) }
                }
                let anchor = view.window ?? view!
                activity.popoverPresentationController?.sourceView = anchor
                activity.popoverPresentationController?.sourceRect = CGRect(x: anchor.bounds.midX, y: anchor.bounds.midY, width: 1, height: 1)
                controller = activity
            }
            native = controller
            presenter.present(controller, animated: true)
            controller.presentationController?.delegate = coordinator
        }
    }

    @MainActor final class NativeDelegate: NSObject, UIDocumentPickerDelegate, UIPopoverPresentationControllerDelegate {
        let id: UUID
        let delivery: MP4DeliveryController
        init(id: UUID, delivery: MP4DeliveryController) { self.id = id; self.delivery = delivery }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            delivery.completePresentation(id: id, completed: !urls.isEmpty, reference: urls.first?.lastPathComponent)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            delivery.completePresentation(id: id, completed: false)
        }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            delivery.completePresentation(id: id, completed: false)
        }
        func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
            delivery.completePresentation(id: id, completed: false)
        }
    }
}
