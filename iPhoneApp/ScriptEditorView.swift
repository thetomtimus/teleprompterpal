import SwiftUI
import UIKit

@MainActor struct ScriptEditorView: View {
    let model: LibraryModel
    let id: UUID
    let read: (UUID) -> Void
    let record: (UUID) -> Void
    @State private var settings = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if let record = model.script(id) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? 6 : 12) {
                    TextField(
                        "Script title",
                        text: Binding(
                            get: { model.script(id)?.document.title ?? "" },
                            set: { model.edit(id, title: $0, text: model.script(id)?.document.text ?? "") })
                    )
                    .font(verticalSizeClass == .compact ? .title2.bold() : .title.bold()).accessibilityIdentifier("scriptTitle")
                    if typeSize.isAccessibilitySize {
                        DisclosureGroup("Script details") {
                            Text(record.document.updatedAt.formatted(date: .long, time: .shortened))
                                .fixedSize(horizontal: false, vertical: true)
                        }.font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
                    } else {
                        Text(record.document.updatedAt.formatted(date: .long, time: .shortened))
                            .font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
                    }
                    LibrarySaveStatus(model: model)
                }.padding(.horizontal, 18).padding(.vertical, verticalSizeClass == .compact ? 8 : 18)
                NativeScriptEditor(text: record.document.text) { text in
                    model.edit(id, title: model.script(id)?.document.title ?? "", text: text)
                }.accessibilityIdentifier("scriptText")
            }
            .background(PhoneTheme.canvas)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                Menu("Script actions", systemImage: "ellipsis.circle") {
                    Button("Rehearse", systemImage: "play") { read(id) }.accessibilityIdentifier("openReader")
                    Button("Duplicate", systemImage: "doc.on.doc") { _ = model.duplicate(id) }
                    Button("Reader Settings", systemImage: "textformat.size") { settings = true }
                }.accessibilityIdentifier("scriptActions")
                }.referenceChrome()
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Move to Recently Deleted", systemImage: "trash") {
                        model.setDeleted(id, deleted: true); dismiss()
                    }.accessibilityIdentifier("deleteScript")
                }.referenceChrome()
            }
            .safeAreaInset(edge: .bottom) {
                RecordCircle(title: "Record", identifier: "recordFromEditor",
                    enabled: !record.document.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { self.record(id) }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(PhoneTheme.canvas.ignoresSafeArea(edges: .bottom))
            }
            .task { model.select(id) }
            .onDisappear { Task { await model.flush() } }
            .sheet(isPresented: $settings) { ReaderSettingsView(model: model) }
        } else {
            ContentUnavailableView("Script unavailable", systemImage: "doc")
        }
    }
}

@MainActor struct ReaderSettingsView: View {
    let model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    LabeledContent("Font size", value: "\(Int(model.library.preferences.fontSize)) pt")
                    Slider(
                        value: Binding(
                            get: { model.library.preferences.fontSize },
                            set: {
                                model.setPreferences(font: $0, speed: model.library.preferences.speed)
                            }), in: 20...72, step: 1
                    ).accessibilityLabel("Font size")
                        .accessibilityValue("\(Int(model.library.preferences.fontSize)) points")
                }
                Section("Scrolling") {
                    LabeledContent("Pace", value: "\(Int(model.library.preferences.speed)) pt/s")
                    Slider(
                        value: Binding(
                            get: { model.library.preferences.speed },
                            set: {
                                model.setPreferences(font: model.library.preferences.fontSize, speed: $0)
                            }), in: 10...240, step: 1
                    ).accessibilityLabel("Reader pace")
                        .accessibilityValue("\(Int(model.library.preferences.speed)) points per second")
                }
            }.navigationTitle("Reader Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}

@MainActor private struct NativeScriptEditor: UIViewRepresentable {
    let text: String
    let changed: @MainActor (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(changed: changed) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = .preferredFont(forTextStyle: .title3)
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 4, left: 14, bottom: 24, right: 14)
        view.backgroundColor = .clear
        view.textColor = .label
        view.keyboardDismissMode = .interactive
        view.accessibilityLabel = "Script text"
        view.accessibilityIdentifier = "scriptText"
        view.delegate = context.coordinator
        view.text = text
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        // UIKit owns marked text and selection during IME composition.
        if view.markedTextRange == nil, view.text != text {
            let selection = view.selectedRange
            view.text = text
            view.selectedRange = NSRange(location: min(selection.location, text.utf16.count), length: 0)
        }
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        let changed: @MainActor (String) -> Void
        init(changed: @escaping @MainActor (String) -> Void) { self.changed = changed }
        func textViewDidChange(_ view: UITextView) {
            if view.markedTextRange == nil { changed(view.text) }
        }
        func textViewDidEndEditing(_ view: UITextView) { changed(view.text) }
    }
}
