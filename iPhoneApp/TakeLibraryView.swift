import PrototypeSupport
import SwiftUI
import UIKit

@MainActor struct TakeLibraryView: View {
    let recorder: PrototypeModel
    @State private var query = ""
    @State private var deleting: PrototypeTake?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let groups = TakeGroup.grouped(recorder.takes, query: query)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let message = recorder.libraryMessage {
                    Section {
                        Text(message).font(.callout).accessibilityIdentifier("takeLibraryError")
                        Button("Retry Library") { Task { await recorder.refreshTakeLibrary() } }
                            .font(.headline).tint(.primary).disabled(recorder.busy)
                    }
                }
                if !recorder.initialized, recorder.libraryMessage == nil {
                    ProgressView("Checking recordings…").accessibilityIdentifier("checkingTakes")
                } else if recorder.initialized {
                    if let notice = recorder.libraryNotice { Text(notice).font(.callout) }
                    if recorder.openingTake { ProgressView("Opening recording…") }
                    if recorder.takes.isEmpty {
                        ContentUnavailableView("No recordings yet", systemImage: "video",
                            description: Text("Tap Record to choose a script, or open a script to rehearse first.").foregroundStyle(PhoneTheme.auxiliaryText))
                            .accessibilityIdentifier("emptyTakeLibrary")
                    } else if groups.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.title).font(.headline).accessibilityAddTraits(.isHeader)
                            if typeSize.isAccessibilitySize {
                                ForEach(group.takes) { take in takeEntry(take, groupTitle: group.title, compact: false) }
                            } else {
                                let playable = group.takes.filter(\.isPlayable)
                                if !playable.isEmpty {
                                    ScrollView(.horizontal) {
                                        LazyHStack(alignment: .top, spacing: 12) {
                                            ForEach(playable) { take in
                                                takeEntry(take, groupTitle: group.title, compact: true).frame(width: 148)
                                            }
                                        }
                                    }.contentMargins(.bottom, 4).scrollIndicators(.visible)
                                }
                                // Recovery problems stay in the vertical reading order,
                                // never concealed beyond the end of a thumbnail strip.
                                ForEach(group.takes.filter { !$0.isPlayable }) { take in
                                    takeEntry(take, groupTitle: group.title, compact: false)
                                }
                            }
                        }
                    }
                }
            }.padding(16)
        }
        .background(PhoneTheme.canvas)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search recordings")
        .refreshable { await recorder.refreshTakeLibrary() }
        .toolbar {
            Button("Refresh Recordings", systemImage: "arrow.clockwise") {
                Task { await recorder.refreshTakeLibrary() }
            }.disabled(recorder.busy).accessibilityIdentifier("refreshTakes")
        }
        .confirmationDialog(deleting.map(TakePresentation.deletionTitle) ?? "Delete original recording?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible, presenting: deleting) { take in
            Button(TakePresentation.deletionAction(take), role: .destructive) { Task { _ = await recorder.deleteTake(id: take.id) } }
            Button("Cancel", role: .cancel) {}
        } message: { take in
            Text(TakePresentation.deletionMessage(take))
        }
    }

    private func takeEntry(_ take: PrototypeTake, groupTitle: String, compact: Bool) -> some View {
        row(take, groupTitle: groupTitle, compact: compact)
            .contextMenu {
                Button(TakePresentation.deletionAction(take), systemImage: "trash", role: .destructive) {
                    deleting = take
                }
                .disabled(recorder.busy)
            }
            .accessibilityAction(named: TakePresentation.deletionAction(take)) { if !recorder.busy { deleting = take } }
    }

    @ViewBuilder private func row(_ take: PrototypeTake, groupTitle: String, compact: Bool) -> some View {
        if take.isPlayable {
            Button { Task { await recorder.openTake(take) } } label: {
                Group {
                    if compact { TakeCard(take: take, recorder: recorder) }
                    else { TakeRow(take: take, groupTitle: groupTitle, recorder: recorder) }
                }
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(recorder.busy).accessibilityIdentifier("video_\(take.id)")
        } else {
            TakeRow(take: take, groupTitle: groupTitle, recorder: recorder)
                .accessibilityElement(children: .combine).accessibilityIdentifier("video_\(take.id)")
        }
    }
}

private struct TakeCard: View {
    let take: PrototypeTake
    let recorder: PrototypeModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TakeThumbnail(take: take, recorder: recorder)
                .frame(height: 148)
                .overlay(alignment: .bottomTrailing) {
                    Text(TakePresentation.duration(take)).font(.caption.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 4)
                        .background(.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 5)).padding(6)
                }
            Text(take.created.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .font(.subheadline.weight(.medium)).foregroundStyle(.primary)
            Text(TakePresentation.status(take)).font(.caption).foregroundStyle(PhoneTheme.auxiliaryText)
            Text(TakePresentation.storage(take)).font(.caption).foregroundStyle(PhoneTheme.auxiliaryText)
            if let note = take.note { Text(note).font(.caption).foregroundStyle(PhoneTheme.auxiliaryText).lineLimit(2) }
        }.accessibilityElement(children: .combine)
    }
}

private struct TakeRow: View {
    let take: PrototypeTake
    let groupTitle: String
    let recorder: PrototypeModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            TakeThumbnail(take: take, recorder: recorder)
                .frame(width: typeSize.isAccessibilitySize ? 160 : 96, height: typeSize.isAccessibilitySize ? 120 : 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(take.created.formatted(.dateTime.month(.abbreviated).day().hour().minute())).font(.headline)
                if let title = take.script?.title, title != groupTitle { Text(title).font(.subheadline) }
                Text(TakePresentation.details(take)).font(.subheadline).foregroundStyle(PhoneTheme.auxiliaryText)
                Text(TakePresentation.status(take)).font(.caption)
                    .foregroundStyle(take.isPlayable ? PhoneTheme.auxiliaryText : .primary)
                if let note = take.note { Text(note).font(.caption).foregroundStyle(PhoneTheme.auxiliaryText).lineLimit(2) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if take.isPlayable { Image(systemName: "chevron.right").font(.caption).foregroundStyle(PhoneTheme.auxiliaryText).accessibilityHidden(true) }
        }.padding(.vertical, 6)
    }
}

private struct TakeThumbnail: View {
    let take: PrototypeTake
    let recorder: PrototypeModel
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            if take.isPlayable, let image { Color.black; Image(uiImage: image).resizable().scaledToFit() }
            else {
                Color(uiColor: .tertiarySystemFill)
                Image(systemName: take.isPlayable ? "video" : "exclamationmark.triangle")
                    .foregroundStyle(PhoneTheme.auxiliaryText)
            }
        }.clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
            .task(id: take) {
                image = nil
                guard take.isPlayable else { return }
                do {
                    let data = try await recorder.thumbnailData(for: take)
                    try Task.checkCancellation()
                    image = UIImage(data: data)
                } catch { image = nil }
            }
    }
}

enum TakePresentation {
    static func duration(_ take: PrototypeTake) -> String {
        guard let seconds = take.summary?.duration, seconds.isFinite, seconds >= 0, seconds < 1_000_000 else { return "Unavailable" }
        let value = Int(seconds.rounded())
        return String(format: "%d:%02d", value / 60, value % 60)
    }
    static func storage(_ take: PrototypeTake) -> String {
        guard let bytes = take.summary?.fileBytes ?? take.retainedBytes, bytes >= 0 else { return "Size unavailable" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    static func details(_ take: PrototypeTake) -> String {
        take.isPlayable ? "\(duration(take)) · \(storage(take))" : storage(take)
    }
    static func status(_ take: PrototypeTake) -> String {
        switch take.state {
        case .ready: take.isRecovered ? "Recovered recording" : "Original recording"
        case .pending: "Waiting for recovery"
        case .incomplete: "Incomplete original retained"
        case .missing: "Original file missing"
        case .deleting: "Deletion pending. Retry to finish."
        }
    }
    static func deletionAction(_ take: PrototypeTake) -> String {
        take.state == .missing ? "Remove Details" : (take.state == .deleting ? "Retry Deletion" : "Delete Original")
    }
    static func deletionTitle(_ take: PrototypeTake) -> String {
        take.state == .missing ? "Remove recording details?" : "Delete original recording?"
    }
    static func deletionMessage(_ take: PrototypeTake) -> String {
        take.state == .missing
            ? "The original file is already missing. This removes its saved details. Your script stays in the library."
            : "This removes this original recording from your iPhone. Your script stays in the library."
    }
}
