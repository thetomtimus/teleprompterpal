import SwiftUI

enum RecordingSelection { case script(UUID), create }

@MainActor struct RecordingScriptPicker: View {
    let model: LibraryModel
    let choose: (RecordingSelection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Create a script", systemImage: "plus") { choose(.create) }
                        .accessibilityIdentifier("recordingCreateScript")
                }
                Section {
                    let scripts = model.library.matching(query)
                    if scripts.isEmpty {
                        if query.isEmpty {
                            Text("No scripts yet. Create one to prepare your first recording.")
                                .foregroundStyle(PhoneTheme.auxiliaryText)
                        } else { ContentUnavailableView.search(text: query) }
                    }
                    ForEach(scripts) { script in
                        let empty = script.document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        Button { choose(.script(script.id)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(script.document.title.isEmpty ? "Untitled Script" : script.document.title)
                                    .font(.headline).foregroundStyle(.primary)
                                Text(empty ? "Add text before recording" : String(script.document.text.prefix(160)))
                                    .font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText).lineLimit(3)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.vertical, 4)
                        }.disabled(empty).accessibilityIdentifier("recordingScript_\(script.id)")
                    }
                } header: { Text("Your scripts") }
                footer: {
                    Text("The camera opens first. Tap Record in the studio when you are ready.")
                }
            }
            .navigationTitle("Choose a Script").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search scripts")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
