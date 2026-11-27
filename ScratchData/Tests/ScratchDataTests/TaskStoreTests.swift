import Foundation
import ScratchData
import Testing

struct TaskStoreTests {
    @Test func seedsSixListsAndPersistsChangesAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("test.sqlite").path

        let first = try TaskStore(path: path)
        let lists = try first.lists()
        #expect(lists.map(\.id) == [1, 2, 3, 4, 5, 6])
        #expect(lists.allSatisfy { $0.name == "Untitled" })
        try first.renameList(2, to: "Work")
        let task = try first.addTask("Draft", to: 2)
        try first.editTask(task.id, text: "**Draft**\nNext line")

        let reopened = try TaskStore(path: path)
        #expect(try reopened.lists().map(\.name) == ["Untitled", "Work", "Untitled", "Untitled", "Untitled", "Untitled"])
        #expect(try reopened.tasks(in: 2).map(\.text) == ["**Draft**\nNext line"])
        #expect(try reopened.tasks(in: 1).isEmpty)
    }

    @Test func addsTasksAndKeepsTheParentGroupContiguous() throws {
        let store = try TaskStore()
        let parent = try store.addTask("Parent", to: 1)
        let next = try store.addTask("Next", to: 1)
        let first = try store.addTask("First child", to: 1, parentID: parent.id)
        let second = try store.addTask("Second child", to: 1, parentID: parent.id)

        let tasks = try store.tasks(in: 1)
        #expect(tasks.map(\.id) == [parent.id, first.id, second.id, next.id])
        #expect(tasks.map(\.position) == [0, 1, 2, 3])
        #expect(tasks.map(\.indentLevel) == [0, 1, 1, 0])
        #expect(tasks.allSatisfy { !$0.isCompleted })
        #expect(throws: TaskStoreError.emptyText) { try store.addTask(" \n ", to: 1) }
        #expect(throws: TaskStoreError.listNotFound) { try store.addTask("Missing list", to: 7) }
    }

    @Test func completingAParentCompletesSubtasksAndReopeningAChildReopensItsParent() throws {
        let store = try TaskStore()
        let parent = try store.addTask("Parent", to: 1)
        let first = try store.addTask("First", to: 1, parentID: parent.id)
        try store.addTask("Second", to: 1, parentID: parent.id)
        try store.addTask("Unrelated", to: 1)

        try store.toggleTask(parent.id)
        #expect(try store.tasks(in: 1).map(\.isCompleted) == [true, true, true, false])
        try store.toggleTask(first.id)
        #expect(try store.tasks(in: 1).map(\.isCompleted) == [false, false, true, false])
        try store.toggleTask(parent.id)
        try store.toggleTask(parent.id)
        #expect(try store.tasks(in: 1).map(\.isCompleted) == [false, true, true, false])
        try store.toggleTask(parent.id)
        try store.addTask("New child", to: 1, parentID: parent.id)
        #expect(try store.tasks(in: 1).map(\.isCompleted) == [false, true, true, false, false])
    }

    @Test func reordersAndMovesTheWholeParentGroupBetweenLists() throws {
        let store = try TaskStore()
        let first = try store.addTask("First", to: 1)
        let parent = try store.addTask("Parent", to: 1)
        let child = try store.addTask("Child", to: 1, parentID: parent.id)
        let last = try store.addTask("Last", to: 1)
        let destination = try store.addTask("Destination", to: 2)

        try store.moveTask(parent.id, to: 1, beforeTaskID: first.id)
        let reordered = try store.tasks(in: 1)
        #expect(reordered.map(\.id) == [parent.id, child.id, first.id, last.id])
        #expect(reordered.map(\.position) == [0, 1, 2, 3])

        try store.moveTask(parent.id, to: 2)
        let remaining = try store.tasks(in: 1)
        #expect(remaining.map(\.id) == [first.id, last.id])
        #expect(remaining.map(\.position) == [0, 1])
        let moved = try store.tasks(in: 2)
        #expect(moved.map(\.id) == [destination.id, parent.id, child.id])
        #expect(moved.map(\.indentLevel) == [0, 0, 1])
        #expect(moved.allSatisfy { $0.listID == 2 })
    }

    @Test func nestsMovesAndPromotesSubtasksWithOneLevelOfIndentation() throws {
        let store = try TaskStore()
        let left = try store.addTask("Left", to: 1)
        let right = try store.addTask("Right", to: 1)
        let child = try store.addTask("Child", to: 1)
        let sibling = try store.addTask("Sibling", to: 1, parentID: right.id)
        try store.toggleTask(right.id)

        try store.moveTask(child.id, to: 1, parentID: left.id)
        #expect(try store.tasks(in: 1).map(\.id) == [left.id, child.id, right.id, sibling.id])
        try store.moveTask(child.id, to: 1, parentID: right.id, beforeTaskID: sibling.id)
        let nested = try store.tasks(in: 1)
        #expect(nested.map(\.id) == [left.id, right.id, child.id, sibling.id])
        #expect(nested.map(\.indentLevel) == [0, 0, 1, 1])
        #expect(nested.map(\.isCompleted) == [false, false, false, true])

        #expect(throws: TaskStoreError.invalidDestination) { try store.moveTask(left.id, to: 1, parentID: child.id) }
        #expect(throws: TaskStoreError.invalidDestination) { try store.moveTask(right.id, to: 1, parentID: left.id) }
        #expect(throws: TaskStoreError.invalidDestination) {
            try store.moveTask(child.id, to: 1, parentID: left.id, beforeTaskID: sibling.id)
        }
        #expect(try store.tasks(in: 1) == nested)

        try store.moveTask(child.id, to: 2)
        let promoted = try #require(store.tasks(in: 2).first)
        #expect(promoted.id == child.id)
        #expect(promoted.indentLevel == 0)
    }

    @Test func deletesParentAndItsChildren() throws {
        let store = try TaskStore()
        let parent = try store.addTask("Parent", to: 1)
        try store.addTask("Child", to: 1, parentID: parent.id)
        let survivor = try store.addTask("Survivor", to: 1)

        try store.deleteTask(parent.id)
        let remaining = try store.tasks(in: 1)
        #expect(remaining.map(\.id) == [survivor.id])
        #expect(remaining.map(\.position) == [0])
        #expect(throws: TaskStoreError.taskNotFound) { try store.deleteTask(parent.id) }
    }

    @Test func clearsCompletedTasksWithoutRemovingOpenParentsOrOtherLists() throws {
        let store = try TaskStore()
        let completed = try store.addTask("Completed parent", to: 1)
        try store.addTask("Child", to: 1, parentID: completed.id)
        let open = try store.addTask("Open parent", to: 1)
        let completedChild = try store.addTask("Completed child", to: 1, parentID: open.id)
        let openChild = try store.addTask("Open child", to: 1, parentID: open.id)
        let other = try store.addTask("Other list", to: 2)

        for id in [completed.id, completedChild.id, other.id] {
            try store.toggleTask(id)
        }
        try store.clearCompleted(in: 1)
        let remaining = try store.tasks(in: 1)
        #expect(remaining.map(\.id) == [open.id, openChild.id])
        #expect(remaining.map(\.position) == [0, 1])
        #expect(remaining.map(\.indentLevel) == [0, 1])
        #expect(try store.tasks(in: 2).map(\.id) == [other.id])
    }
}
