import Foundation
import GRDB

public enum TaskStoreError: Error, Equatable {
    case emptyText
    case listNotFound
    case taskNotFound
    case invalidDestination
}

/// Tasks are stored in display order. Each parent is immediately followed by its subtasks.
public final class TaskStore: Sendable {
    private let database: DatabaseQueue

    public init(path: String = ":memory:") throws {
        database = try DatabaseQueue(path: path)
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createListsAndTasks") { db in
            try db.execute(sql: """
                CREATE TABLE lists (
                    id INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 6),
                    name TEXT NOT NULL
                );

                INSERT INTO lists (id, name) VALUES
                    (1, 'Untitled'), (2, 'Untitled'), (3, 'Untitled'),
                    (4, 'Untitled'), (5, 'Untitled'), (6, 'Untitled');

                CREATE TABLE tasks (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    listID INTEGER NOT NULL REFERENCES lists(id),
                    text TEXT NOT NULL,
                    isCompleted BOOLEAN NOT NULL DEFAULT 0 CHECK (isCompleted IN (0, 1)),
                    position INTEGER NOT NULL CHECK (position >= 0),
                    indentLevel INTEGER NOT NULL DEFAULT 0 CHECK (indentLevel IN (0, 1))
                );

                CREATE INDEX taskOrder ON tasks (listID, position);
                """)
        }
        try migrator.migrate(database)
    }

    public static func openDefault() throws -> TaskStore {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = support.appendingPathComponent("Scratch", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try TaskStore(path: directory.appendingPathComponent("Scratch.sqlite").path)
    }

    public func lists() throws -> [TaskList] {
        try database.read { db in
            try TaskList.fetchAll(db, sql: "SELECT id, name FROM lists ORDER BY id")
        }
    }

    public func tasks(in listID: Int64) throws -> [NoteTask] {
        try database.read { db in try Self.tasks(in: listID, db: db) }
    }

    public func renameList(_ listID: Int64, to name: String) throws {
        let name = try Self.validatedText(name)
        try database.write { db in
            try db.execute(sql: "UPDATE lists SET name = ? WHERE id = ?", arguments: [name, listID])
            guard db.changesCount > 0 else { throw TaskStoreError.listNotFound }
        }
    }

    @discardableResult
    public func addTask(_ text: String, to listID: Int64, parentID: Int64? = nil) throws -> NoteTask {
        let text = try Self.validatedText(text)
        return try database.write { db in
            let tasks = try Self.tasks(in: listID, db: db)
            let position = try Self.insertionIndex(in: tasks, parentID: parentID, beforeTaskID: nil)
            // Shift the existing rows before inserting so the new position is available.
            try db.execute(
                sql: "UPDATE tasks SET position = position + 1 WHERE listID = ? AND position >= ?",
                arguments: [listID, position]
            )
            try db.execute(
                sql: "INSERT INTO tasks (listID, text, position, indentLevel) VALUES (?, ?, ?, ?)",
                arguments: [listID, text, position, parentID == nil ? 0 : 1]
            )
            let task = try Self.task(db.lastInsertedRowID, db: db)
            try Self.reopenParent(parentID, in: tasks, db: db)
            return task
        }
    }

    public func editTask(_ id: Int64, text: String) throws {
        let text = try Self.validatedText(text)
        try database.write { db in
            try db.execute(sql: "UPDATE tasks SET text = ? WHERE id = ?", arguments: [text, id])
            guard db.changesCount > 0 else { throw TaskStoreError.taskNotFound }
        }
    }

    public func toggleTask(_ id: Int64) throws {
        try database.write { db in
            let task = try Self.task(id, db: db)
            let tasks = try Self.tasks(in: task.listID, db: db)
            let index = task.position
            let completed = !task.isCompleted
            let affected = completed ? Self.group(in: tasks, at: index) : index..<(index + 1)
            for index in affected {
                try Self.setCompletion(completed, of: tasks[index].id, db: db)
            }
            if !completed, task.indentLevel == 1 {
                let parentID = tasks[..<index].last { $0.indentLevel == 0 }?.id
                try Self.reopenParent(parentID, in: tasks, db: db)
            }
        }
    }

    public func deleteTask(_ id: Int64) throws {
        try database.write { db in
            let task = try Self.task(id, db: db)
            var tasks = try Self.tasks(in: task.listID, db: db)
            let range = Self.group(in: tasks, at: task.position)
            try Self.delete(tasks[range].map(\.id), db: db)
            tasks.removeSubrange(range)
            try Self.saveOrder(tasks, listID: task.listID, db: db)
        }
    }

    public func clearCompleted(in listID: Int64) throws {
        try database.write { db in
            let tasks = try Self.tasks(in: listID, db: db)
            var removed: [Int64] = []
            var remaining: [NoteTask] = []
            var parentCompleted = false
            for task in tasks {
                if task.indentLevel == 0 { parentCompleted = task.isCompleted }
                if task.isCompleted || parentCompleted {
                    removed.append(task.id)
                } else {
                    remaining.append(task)
                }
            }
            guard !removed.isEmpty else { return }
            try Self.delete(removed, db: db)
            try Self.saveOrder(remaining, listID: listID, db: db)
        }
    }

    /// A nil parent places the task at the top level. A nil anchor appends it among its siblings.
    public func moveTask(
        _ id: Int64, to listID: Int64, parentID: Int64? = nil, beforeTaskID: Int64? = nil
    ) throws {
        try database.write { db in
            let task = try Self.task(id, db: db)
            var source = try Self.tasks(in: task.listID, db: db)
            let range = Self.group(in: source, at: task.position)
            var moved = Array(source[range])
            guard parentID == nil || moved.count == 1 else { throw TaskStoreError.invalidDestination }
            source.removeSubrange(range)

            let sameList = task.listID == listID
            var destination = sameList ? source : try Self.tasks(in: listID, db: db)
            let index = try Self.insertionIndex(in: destination, parentID: parentID, beforeTaskID: beforeTaskID)
            moved[0].indentLevel = parentID == nil ? 0 : 1
            if !task.isCompleted {
                try Self.reopenParent(parentID, in: destination, db: db)
            }
            destination.insert(contentsOf: moved, at: index)
            try Self.saveOrder(destination, listID: listID, db: db)
            if !sameList {
                try Self.saveOrder(source, listID: task.listID, db: db)
            }
        }
    }

    private static func validatedText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskStoreError.emptyText }
        return trimmed
    }

    private static func tasks(in listID: Int64, db: Database) throws -> [NoteTask] {
        guard try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM lists WHERE id = ?)", arguments: [listID])
                == true else { throw TaskStoreError.listNotFound }
        return try NoteTask.fetchAll(db, sql: "SELECT * FROM tasks WHERE listID = ? ORDER BY position",
                                     arguments: [listID])
    }

    private static func task(_ id: Int64, db: Database) throws -> NoteTask {
        guard let task = try NoteTask.fetchOne(db, key: id) else { throw TaskStoreError.taskNotFound }
        return task
    }

    private static func group(in tasks: [NoteTask], at index: Int) -> Range<Int> {
        let next = index + 1
        guard tasks[index].indentLevel == 0 else { return index..<next }
        let end = tasks[next...].firstIndex { $0.indentLevel == 0 } ?? tasks.endIndex
        return index..<end
    }

    private static func insertionIndex(
        in tasks: [NoteTask], parentID: Int64?, beforeTaskID: Int64?
    ) throws -> Int {
        let candidates: Range<Int>
        let depth: Int
        if let parentID {
            guard let index = tasks.firstIndex(where: { $0.id == parentID && $0.indentLevel == 0 })
            else { throw TaskStoreError.invalidDestination }
            candidates = (index + 1)..<group(in: tasks, at: index).upperBound
            depth = 1
        } else {
            candidates = tasks.indices
            depth = 0
        }
        guard let beforeTaskID else { return candidates.upperBound }
        guard let index = candidates.first(where: {
            tasks[$0].id == beforeTaskID && tasks[$0].indentLevel == depth
        }) else { throw TaskStoreError.invalidDestination }
        return index
    }

    private static func reopenParent(_ parentID: Int64?, in tasks: [NoteTask], db: Database) throws {
        guard let parentID, tasks.contains(where: { $0.id == parentID && $0.isCompleted }) else { return }
        try setCompletion(false, of: parentID, db: db)
    }

    private static func setCompletion(_ completed: Bool, of id: Int64, db: Database) throws {
        try db.execute(sql: "UPDATE tasks SET isCompleted = ? WHERE id = ?", arguments: [completed, id])
    }

    private static func delete(_ ids: [Int64], db: Database) throws {
        for id in ids {
            try db.execute(sql: "DELETE FROM tasks WHERE id = ?", arguments: [id])
        }
    }

    private static func saveOrder(_ tasks: [NoteTask], listID: Int64, db: Database) throws {
        for (position, task) in tasks.enumerated() {
            // A task can change indentation without changing its list or position.
            try db.execute(sql: "UPDATE tasks SET listID = ?, position = ?, indentLevel = ? WHERE id = ?",
                           arguments: [listID, position, task.indentLevel, task.id])
        }
    }
}
