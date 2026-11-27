import ScratchData
import SwiftUI

struct TaskGroupView: View {
    let group: NoteTasks.TaskGroup
    @ObservedObject var note: NoteTasks
    let palette: NotePalette
    let isFocused: Bool

    @Environment(TaskDrag.self) private var drag

    var body: some View {
        VStack(spacing: 0) {
            row(group.parent)
            ForEach(group.children) { child in
                row(child)
            }
            if isFocused, note.editingTaskID == group.id {
                AddSubtaskRow(palette: palette) { text in
                    note.add(text, parentID: group.id)
                }
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(TaskDrag.coordinateSpace)) } action: {
            drag.groupFrames[group.id] = $0
        }
        .overlay(alignment: .topLeading) {
            if let indicator = drag.indicator, indicator.groupID == group.id {
                Capsule()
                    .fill(palette.accent)
                    .frame(height: 2)
                    .padding(.leading, indicator.indent)
                    .offset(y: indicator.y - 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func row(_ task: NoteTask) -> some View {
        TaskRow(task: task, note: note, palette: palette, isFocused: isFocused)
            .padding(.vertical, 5)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(TaskDrag.coordinateSpace)) } action: {
                drag.rowFrames[task.id] = $0
            }
    }
}

private struct AddSubtaskRow: View {
    let palette: NotePalette
    let add: (String) -> Bool

    @State private var isAdding = false
    @State private var text = ""

    var body: some View {
        Group {
            if isAdding {
                HStack(spacing: 10) {
                    icon
                    TaskTextField(placeholder: "Add subtask", text: $text, palette: palette,
                                  autofocus: true, cancel: close) {
                        if add(text) { close() }
                    }
                }
            } else {
                Button {
                    isAdding = true
                } label: {
                    HStack(spacing: 10) {
                        icon
                        Text("Add subtask")
                            .font(.system(size: 14))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(palette.accent.opacity(0.62))
        .padding(.leading, TaskRow.subtaskIndent)
        .padding(.trailing, 22)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: some View {
        Image("add-subtask")
            .resizable()
            .renderingMode(.template)
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }

    private func close() {
        text = ""
        isAdding = false
    }
}
