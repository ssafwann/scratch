import ScratchData
import SwiftUI

struct TaskRow: View {
    static let subtaskIndent: CGFloat = 24

    let task: NoteTask
    @ObservedObject var note: NoteTasks
    let palette: NotePalette
    let isFocused: Bool

    @State private var isHovered = false
    @Environment(TaskDrag.self) private var drag

    private var markdown: AttributedString {
        var text = (try? AttributedString(
            markdown: task.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(task.text)
        text.foregroundColor = task.isCompleted ? palette.ink.opacity(0.55) : palette.ink
        for run in Array(text.runs) {
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) { text[run.range].font = .system(size: 13, design: .monospaced) }
                if intent.contains(.strikethrough) { text[run.range].strikethroughStyle = .single }
            }
            if run.link != nil {
                text[run.range].foregroundColor = palette.accent
                text[run.range].underlineStyle = .single
            }
        }
        return text
    }

    var body: some View {
        let rendered = markdown
        HStack(alignment: .top, spacing: 0) {
            checkbox(label: String(rendered.characters))
                .padding(.trailing, 10)
            if isFocused, note.editingTaskID == task.id {
                TaskTextField(placeholder: "Task text", text: $note.editedText, palette: palette,
                              autofocus: true, cancel: { note.cancelEditing() }) {
                    note.finishEditing()
                }
            } else {
                Text(rendered)
                    .font(.system(size: 14))
                    .strikethrough(task.isCompleted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { note.beginEditing(task) }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 6, coordinateSpace: .named(TaskDrag.coordinateSpace))
                            .onChanged { value in
                                guard isFocused else { return }
                                drag.update(task: task, at: value.location, note: note)
                            }
                            .onEnded { value in
                                drag.finish(at: value.location, note: note)
                            }
                    )
                    .accessibilityActions {
                        if isFocused {
                            Button("Edit task") { note.beginEditing(task) }
                            Button("Delete task") { note.delete(task) }
                        }
                    }
            }
            Button {
                note.delete(task)
            } label: {
                Image("delete-task")
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: 14, height: 14)
                    .frame(width: 22, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent.opacity(0.7))
            .accessibilityLabel("Delete task")
            .opacity(isFocused && isHovered && drag.taskID == nil ? 1 : 0)
            .allowsHitTesting(isFocused && isHovered && drag.taskID == nil)
            .accessibilityHidden(!isFocused || !isHovered || drag.taskID != nil)
        }
        .padding(.leading, task.indentLevel == 1 ? Self.subtaskIndent : 0)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .opacity(drag.taskID == task.id ? 0.4 : 1)
    }

    private func checkbox(label: String) -> some View {
        Button {
            note.toggle(task)
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(palette.accent, lineWidth: 1.5)
                .overlay {
                    if task.isCompleted {
                        Path { path in
                            path.move(to: CGPoint(x: 3.5, y: 7))
                            path.addLine(to: CGPoint(x: 6, y: 9.5))
                            path.addLine(to: CGPoint(x: 10.5, y: 4.5))
                        }
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: 14, height: 14)
                .frame(height: 19)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(task.isCompleted ? "Completed" : "Uncompleted")
        .accessibilityHint(task.isCompleted ? "Mark uncompleted" : "Mark completed")
    }
}
