import SwiftUI
import UIKit

enum AppSupportLinks {
    static let privacyPolicy = URL(string: "https://teleprompterpal.com/privacy/")!
    static let support = URL(string: "https://teleprompterpal.com/support/")!
}

@MainActor struct AppSettingsView: View {
    let library: LibraryModel
    let subscriptions: SubscriptionStore
    var replayOnboarding: () -> Void = {}
    @State private var readerSettings = false

    var body: some View {
        Form {
            Section("Preferences") {
                Button { readerSettings = true } label: { Label("Reader Settings", systemImage: "textformat.size") }
                    .accessibilityIdentifier("defaultReaderSettings")
                NavigationLink {
                    SubscriptionSettingsView(store: subscriptions, localTest: SubscriptionEnvironment.isLocalTest)
                } label: {
                    Label(subscriptions.isConfigured ? "Subscription" : "Beta Information",
                        systemImage: subscriptions.isConfigured ? "creditcard" : "info.circle")
                }
            }
            Section("Help") {
                Button("Replay Introduction", systemImage: "play.rectangle") { replayOnboarding() }
                    .accessibilityIdentifier("replayOnboarding")
                NavigationLink { GettingStartedView() } label: { Label("Getting Started", systemImage: "book") }
                    .accessibilityIdentifier("gettingStarted")
                Link(destination: AppSupportLinks.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                .accessibilityIdentifier("privacyPolicyLink")
                .accessibilityHint("Opens the privacy policy in your browser.")
                Link(destination: AppSupportLinks.support) {
                    Label("Contact Support", systemImage: "questionmark.circle")
                }
                .accessibilityIdentifier("contactSupportLink")
                .accessibilityHint("Opens help and contact details in your browser.")
                Button("Open iPhone Settings", systemImage: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Section {
                Text("teleprompterpal.com").font(.headline)
                LabeledContent("Version", value: version)
                Text("Scripts, original recordings and reading preferences are saved on this iPhone. Export a copy to Photos or Files when you want to keep it elsewhere.")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
            } header: { Text("About") }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $readerSettings) { ReaderSettingsView(model: library) }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }
}

enum GettingStarted {
    static let sampleTitle = "My first take"
    static let sampleText = """
        Take a breath and look toward the lens.

        This is a sample script. Read it at your own pace, or replace it with your own words.

        Tap Play to start the text. Drag the text to pause and find your place. Adjust the pace and font until reading feels comfortable.

        In Camera mode, tap Record when you are ready. After recording, find your take in Videos. Trim the beginning and end, choose your crop, then export a copy to Photos or Files, or share it.

        Your original recording stays in the library.
        """
}

struct GettingStartedView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                guideSection("Prepare your script", paragraphs: [
                    "Create a script and type or paste your words. Import a plain text file from the Library menu. Changes save automatically; check the save status before leaving."
                ])
                guideSection("Rehearse and record", paragraphs: [
                    "Rehearse in Script actions opens the reader at your saved place. Play starts the text; dragging pauses it. Reader Settings changes the text, pace and prompt panel.",
                    "Record in the library lets you choose a script and open Camera directly. The editor’s red Record button opens Camera for that script. Camera and microphone access are requested when you enter Camera, so you can rehearse without them.",
                    "Tap Record in the studio to start the countdown. Stop ends the take. Keep the app visible while recording. There is no recording time limit. Recording stops if storage runs low or the camera is interrupted. Orientation stays fixed during each take."
                ])
                guideSection("Choose, edit and keep a take", paragraphs: [
                    "Videos groups takes by script. Tap a thumbnail to play the original, then Edit Video to trim or crop. Done saves your edits; your original stays intact. Touch and hold a take for more actions.",
                    "Export MP4 prepares a copy. Save to Photos asks only for permission to add videos. Save to Files and Share open iOS pickers. Keep the app visible until export finishes."
                ])
                guideSection("If something interrupts you", paragraphs: [
                    "Return to the app and check the saved result before retrying. Incomplete recordings remain visible in Videos. Interrupted exports can be retried. An unknown save or share result means you should check the destination before making another copy."
                ])
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }.background(PhoneTheme.canvas)
        .accessibilityIdentifier("gettingStartedGuide")
        .navigationTitle("Getting Started").navigationBarTitleDisplayMode(.inline)
    }

    private func guideSection(_ title: String, paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph).font(.body).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
