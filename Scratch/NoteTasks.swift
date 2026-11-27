import ScratchData
import SwiftUI

@MainActor
final class NoteTasks: ObservableObject {
    enum CompletedOption: Int {
        case hide = 1
        case moveToBottom = 2
    }

    private static let completedOptionsKey = "completedTaskOptions"

    @Published private(set) var lists: [TaskList]
    @Published private(set) var activeIndex = 0
    @Published private(set) var tasks: [NoteTask]
    @Published private(set) var isRenaming = false
    @Published var renamedTitle = ""
    @Published private(set) var editingTaskID: Int64?
    @Published var editedText = ""
    @Published private(set) var errorMessage: String?
    @Published private var completedOptions: [String: Int]

    private let store: TaskStore
    private let defaults: UserDefaults
    var list: TaskList { lists[activeIndex] }
    var hasCompletedTasks: Bool { tasks.contains(where: \.isCompleted) }

    init(store: TaskStore, defaults: UserDefaults = .standard) throws {
        self.store = store
        self.defaults = defaults
        completedOptions = defaults.dictionary(forKey: Self.completedOptionsKey) as? [String: Int] ?? [:]
        let lists = try store.lists()
        guard let list = lists.first else { throw TaskStoreError.listNotFound }
        self.lists = lists
        tasks = try store.tasks(in: list.id)
    }

    func completedOption(_ option: CompletedOption) -> Bool {
        (completedOptions[String(list.id), default: 0] & option.rawValue) != 0
    }

    func setCompletedOption(_ option: CompletedOption, enabled: Bool) {
        guard finishEditing(), finishRenaming() else { return }
        let key = String(list.id)
        let value = completedOptions[key, default: 0]
        completedOptions[key] = enabled ? value | option.rawValue : value & ~option.rawValue
        defaults.set(completedOptions, forKey: Self.completedOptionsKey)
    }

    var visibleTasks: [NoteTask] {
        let hide = completedOption(.hide)
        let moveToBottom = completedOption(.moveToBottom)
        guard hide || moveToBottom else { return tasks }

        // Apply the same stable partition to whole parent groups and to their children.
        func arranged<T>(_ items: [T], isCompleted: (T) -> Bool) -> [T] {
            let open = items.filter { !isCompleted($0) }
            return hide ? open : open + items.filter(isCompleted)
        }

        var groups: [[NoteTask]] = []
        for task in tasks {
            if task.indentLevel == 0 || groups.isEmpty {
                groups.append([task])
            } else {
                groups[groups.count - 1].append(task)
            }
        }
        return arranged(groups) { $0.first?.isCompleted == true }.flatMap { group -> [NoteTask] in
            guard let parent = group.first else { return [] }
            return [parent] + arranged(Array(group.dropFirst()), isCompleted: \.isCompleted)
        }
    }

    func clearCompleted() {
        guard finishEditing(), finishRenaming() else { return }
        update { try store.clearCompleted(in: list.id) }
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
