import SwiftUI

struct BetaInformationView: View {
    var body: some View {
        Form {
            Section("Beta access") {
                Text("teleprompterpal.com").font(.headline)
                Label("Purchases disabled", systemImage: "checkmark.circle")
                    .accessibilityIdentifier("betaPurchasesDisabled")
                Text("Recording, editing, exporting and saving are available without a subscription in this beta.")
                LabeledContent("Recording time limit", value: "None")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Recording time limit")
                    .accessibilityValue("None")
                    .accessibilityIdentifier("betaRecordingPolicy")
                Text("Keep the app visible while recording. Low storage, camera interruptions or device conditions can end a take.")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
            }
            Section("Your library") {
                Text("Your scripts, original recordings and edits are saved on this iPhone. No account is required.")
                Text("Export a copy to Photos or Files to keep it outside the app. Deleting the app removes its local library.")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
                NavigationLink("Privacy", destination: BetaPrivacyView())
                    .accessibilityIdentifier("betaPrivacy")
            }
            Section("Feedback") {
                Text("If you installed this beta through TestFlight, use Send Beta Feedback in TestFlight to report a problem.")
                Text("Include what you were doing and what you expected. Attach scripts or videos only if you want to share them.")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
            }
        }
        .navigationTitle("Beta Information").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("betaInformation")
    }
}

private struct BetaPrivacyView: View {
    var body: some View {
        Form {
            Section("Scripts and videos") {
                Text("Scripts, original takes, reading preferences and saved edits stay in the app’s local storage. Camera and microphone access are used for recording. Rehearsal works without them.")
                Text("Save to Photos asks for permission to add a video. Files and Share deliver a copy only when you choose a destination. Those apps and providers control their copies.")
            }
            Section("Local diagnostics") {
                Text("The app keeps a limited event journal on this iPhone to help diagnose recording, export and purchase flows. It excludes script text, video and audio content.")
                Text("The app has no analytics upload service and does not send your library or local event journal to an app-operated server.")
            }
            Section("Apple services") {
                Text("Purchases are disabled in this beta. Apple handles TestFlight installation, feedback and crash diagnostics under its own privacy terms.")
            }
            Section("Full policy") {
                Link("Privacy Policy", destination: AppSupportLinks.privacyPolicy)
                    .accessibilityIdentifier("betaFullPrivacyPolicyLink")
                    .accessibilityHint("Opens the privacy policy in your browser.")
            }
        }
        .navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("betaPrivacyInformation")
    }
}
