import ScratchData
import SwiftUI

struct TaskDropPosition {
    let listID: Int64
    var parentID: Int64?
    var beforeTaskID: Int64?
}

@MainActor
@Observable
final class TaskDrag {
    nonisolated static let coordinateSpace = "task drag"

    struct Indicator: Equatable {
        let groupID: Int64
        let y: CGFloat
        var indent: CGFloat = 0
    }

    private(set) var taskID: Int64?
    private(set) var indicator: Indicator?
    private(set) var targetListID: Int64?

    @ObservationIgnored var groupFrames: [Int64: CGRect] = [:]
    @ObservationIgnored var rowFrames: [Int64: CGRect] = [:]
    @ObservationIgnored var tabFrames: [Int64: CGRect] = [:]
    @ObservationIgnored var viewport = CGRect.zero

    func update(task: NoteTask, at point: CGPoint, note: NoteTasks) {
        if taskID == nil {
            guard note.finishRenaming(), note.finishEditing() else { return }
            taskID = task.id
        }
        guard taskID == task.id else { return }
        let drop = destination(for: task, at: point, note: note)
        indicator = drop?.line
        let listID = drop?.position.listID
        targetListID = listID == note.list.id ? nil : listID
    }

    func finish(at point: CGPoint, note: NoteTasks) {
        defer { cancel() }
        guard let id = taskID, let task = note.tasks.first(where: { $0.id == id }),
              let target = destination(for: task, at: point, note: note)
        else { return }
        note.moveTask(id, to: target.position)
    }

    func cancel() {
        taskID = nil
        indicator = nil
        targetListID = nil
    }

    func removeStaleFrames(keeping ids: Set<Int64>) {
        groupFrames = groupFrames.filter { ids.contains($0.key) }
        rowFrames = rowFrames.filter { ids.contains($0.key) }
    }

    private func destination(
        for task: NoteTask, at point: CGPoint, note: NoteTasks
    ) -> (position: TaskDropPosition, line: Indicator?)? {
        if let tab = note.lists.first(where: { tabFrames[$0.id]?.contains(point) == true }) {
            guard tab.id != note.list.id else { return nil }
            return (TaskDropPosition(listID: tab.id), nil)
        }
        guard viewport.contains(point) else { return nil }

        let groups = note.visibleGroups
        let index = groups.firstIndex { (groupFrames[$0.id]?.maxY ?? -.infinity) > point.y }
            ?? groups.indices.last
        guard let index,
              let frame = groupFrames[groups[index].id], groups[index].id != task.id
        else { return nil }
        let group = groups[index]
        if task.indentLevel == 0 {
            let next = groups.dropFirst(index + 1).first { $0.id != task.id }
            let before = point.y < frame.midY
            return (
                TaskDropPosition(listID: note.list.id, beforeTaskID: before ? group.id : next?.id),
                Indicator(groupID: group.id, y: before ? 0 : frame.height)
            )
        }

        let children = group.children.filter { $0.id != task.id }
        let next = children.first { child in
            rowFrames[child.id].map { point.y < $0.midY } ?? false
        }
        let y = next.flatMap { rowFrames[$0.id]?.minY }
            ?? group.children.last.flatMap { rowFrames[$0.id]?.maxY }
            ?? rowFrames[group.id]?.maxY
            ?? frame.maxY
        return (
            TaskDropPosition(listID: note.list.id, parentID: group.id, beforeTaskID: next?.id),
            Indicator(groupID: group.id, y: y - frame.minY, indent: TaskRow.subtaskIndent)
        )
    }
}
