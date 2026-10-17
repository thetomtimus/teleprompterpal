import Foundation

public struct TakeGroup: Identifiable, Equatable, Sendable {
    public enum ID: Hashable, Sendable { case script(UUID), unassigned }
    public let id: ID
    public let title: String
    public let takes: [PrototypeTake]

    public static func grouped(_ takes: [PrototypeTake], query: String = "") -> [TakeGroup] {
        let groups = Dictionary(grouping: takes) { take in take.script.map { ID.script($0.id) } ?? .unassigned }
        return groups.compactMap { id, items in
            let sorted = items.sorted { $0.created == $1.created ? $0.id.uuidString < $1.id.uuidString : $0.created > $1.created }
            let title = sorted.first?.script?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = id == .unassigned ? "Other recordings" : (title.isEmpty ? "Untitled script" : title)
            let matched = query.isEmpty || name.localizedCaseInsensitiveContains(query)
                ? sorted : sorted.filter { $0.script?.title.localizedCaseInsensitiveContains(query) == true }
            return matched.isEmpty ? nil : TakeGroup(id: id, title: name, takes: matched)
        }.sorted {
            let first = $0.takes.first?.created ?? .distantPast
            let second = $1.takes.first?.created ?? .distantPast
            return first == second ? $0.title < $1.title : first > second
        }
    }
}
