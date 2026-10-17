import Foundation

public struct ScriptDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let defaultTitle = "Lecture Teleprompter"

    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var text: String
    public var revision: UInt64
    public var updatedAt: Date

    public init(
        schemaVersion: Int = ScriptDocument.currentSchemaVersion,
        id: UUID = UUID(),
        title: String = ScriptDocument.defaultTitle,
        text: String = "",
        revision: UInt64 = 0,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.text = text
        self.revision = revision
        self.updatedAt = updatedAt
    }
}
