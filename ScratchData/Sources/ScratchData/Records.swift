import GRDB

public struct TaskList: Identifiable, Decodable, FetchableRecord, Equatable, Sendable {
    public let id: Int64
    public let name: String
}

public struct NoteTask: Identifiable, Decodable, FetchableRecord, TableRecord, Equatable, Sendable {
    public static let databaseTableName = "tasks"

    public let id: Int64
    public let listID: Int64
    public let text: String
    public let isCompleted: Bool
    public let position: Int
    public internal(set) var indentLevel: Int
}
