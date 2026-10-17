import PrototypeSupport
import SwiftUI
import UIKit

@MainActor struct MP4DeliveryControls: View {
    let delivery: MP4DeliveryController
    let recheck: () -> Void
    @State private var uncertain: DeliveryDestination?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save or Share").font(.headline)
            if delivery.loading { ProgressView("Checking previous deliveries…") }
            ForEach(DeliveryDestination.allCases) { destination in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if delivery.requiresConfirmation(destination) { uncertain = destination }
                        else { delivery.start(destination) }
                    } label: {
                        Label(title(destination), systemImage: symbol(destination))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.bordered).controlSize(.large)
                        .disabled(delivery.isBusy || delivery.loading || delivery.blocked || destination == .photos && delivery.photosSaved)
                        .accessibilityIdentifier("deliverMP4_" + destination.rawValue)
                    if let receipt = delivery.receipt(destination) {
                        Text(receipt.message).font(.callout)
                            .foregroundStyle(receipt.state == .completed ? Color.primary : PhoneTheme.auxiliaryText)
                            .accessibilityIdentifier("deliveryResult_" + destination.rawValue)
                        if destination == .photos, receipt.state == .completed {
                            Button("Save Another Copy to Photos") { uncertain = .photos }
                                .frame(minHeight: 44).disabled(delivery.isBusy)
                                .accessibilityIdentifier("saveAnotherPhotosCopy")
                        }
                    }
                }
            }
            if let notice = delivery.notice {
                Text(notice).font(.callout).accessibilityIdentifier("deliveryNotice")
                if delivery.needsRecheck {
                    Button("Recheck MP4", action: recheck).frame(minHeight: 44).accessibilityIdentifier("recheckDeliveryMP4")
                }
            }
            if delivery.photosDenied {
                Button("Open Photos Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }.frame(minHeight: 44).accessibilityIdentifier("openPhotosSettings")
            }
        }
        .confirmationDialog("Try this delivery again?", item: $uncertain, titleVisibility: .visible) { destination in
            Button(delivery.receipt(destination)?.state == .completed ? "Save Another Copy" : "Try \(destination.title) Again") {
                delivery.start(destination, confirmingUnknown: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { destination in
            if delivery.receipt(destination)?.state == .completed {
                Text("This edit was already saved to Photos. Continuing saves another copy.")
            } else {
                Text("The previous \(destination.title) attempt may have finished. Check the destination first to avoid saving another copy.")
            }
        }
    }

    private func title(_ destination: DeliveryDestination) -> String {
        if destination == .photos, delivery.photosSaved { return "Saved to Photos" }
        return switch destination { case .photos: "Save to Photos"; case .files: "Save to Files"; case .share: "Share" }
    }
    private func symbol(_ destination: DeliveryDestination) -> String {
        switch destination { case .photos: delivery.photosSaved ? "checkmark" : "photo"; case .files: "folder"; case .share: "square.and.arrow.up" }
    }
}
