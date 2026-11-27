import ScratchData
import SwiftUI

@MainActor
final class NoteTasks: ObservableObject {
    let list: TaskList

    @Published private(set) var tasks: [NoteTask]
    @Published private(set) var editingTaskID: Int64?
    @Published var editedText = ""
    @Published private(set) var errorMessage: String?

    private let store: TaskStore

    init(store: TaskStore) throws {
        self.store = store
        guard let list = try store.lists().first else { throw TaskStoreError.listNotFound }
        self.list = list
        tasks = try store.tasks(in: list.id)
    }

    func add(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return update { try store.addTask(text, to: list.id) }
    }

    func toggle(_ task: NoteTask) {
        update { try store.toggleTask(task.id) }
    }

    func delete(_ task: NoteTask) {
        if editingTaskID == task.id { cancelEditing() }
        update { try store.deleteTask(task.id) }
    }

    func beginEditing(_ task: NoteTask) {
        guard editingTaskID != task.id, finishEditing() else { return }
        editedText = task.text
        editingTaskID = task.id
    }

    @discardableResult
    func finishEditing() -> Bool {
        guard let id = editingTaskID else { return true }
        let text = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, text != tasks.first(where: { $0.id == id })?.text {
            guard update({ try store.editTask(id, text: text) }) else { return false }
        }
        cancelEditing()
        return true
    }

    func cancelEditing() {
        editingTaskID = nil
        editedText = ""
    }

    @discardableResult
    private func update(_ change: () throws -> Void) -> Bool {
        do {
            try change()
            tasks = try store.tasks(in: list.id)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
