import ScratchData
import SwiftUI

@MainActor
final class NoteTasks: ObservableObject {
    @Published private(set) var lists: [TaskList]
    @Published private(set) var activeIndex = 0
    @Published private(set) var tasks: [NoteTask]
    @Published private(set) var isRenaming = false
    @Published var renamedTitle = ""
    @Published private(set) var editingTaskID: Int64?
    @Published var editedText = ""
    @Published private(set) var errorMessage: String?

    private let store: TaskStore
    var list: TaskList { lists[activeIndex] }

    init(store: TaskStore) throws {
        self.store = store
        let lists = try store.lists()
        guard let list = lists.first else { throw TaskStoreError.listNotFound }
        self.lists = lists
        tasks = try store.tasks(in: list.id)
    }

    func selectList(at index: Int) {
        guard lists.indices.contains(index), index != activeIndex,
              finishRenaming(), finishEditing() else { return }
        do {
            let selectedTasks = try store.tasks(in: lists[index].id)
            activeIndex = index
            tasks = selectedTasks
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginRenaming() {
        guard !isRenaming, finishEditing() else { return }
        renamedTitle = list.name
        isRenaming = true
    }

    @discardableResult
    func finishRenaming() -> Bool {
        guard isRenaming else { return true }
        let name = renamedTitle.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != list.name {
            do {
                try store.renameList(list.id, to: name)
                lists = try store.lists()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        }
        cancelRenaming()
        return true
    }

    func cancelRenaming() {
        isRenaming = false
        renamedTitle = ""
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
        guard editingTaskID != task.id, finishRenaming(), finishEditing() else { return }
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
