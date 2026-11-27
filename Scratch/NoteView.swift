import SwiftUI

@MainActor
final class NotePresentation: ObservableObject {
    @Published var isFocused = false
    @Published var isPinned: Bool

    init(isPinned: Bool) {
        self.isPinned = isPinned
    }
}

struct NoteView: View {
    @ObservedObject var presentation: NotePresentation
    @ObservedObject var note: NoteTasks
    let togglePin: () -> Void
    let close: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var drafts: [Int64: String] = [:]

    private var palette: NotePalette {
        NotePalette.forList(at: note.activeIndex, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            if presentation.isFocused {
                toolbar
            }
            header
            Rectangle()
                .fill(palette.accent.opacity(0.22))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(note.tasks) { task in
                        TaskRow(task: task, note: note, palette: palette, isFocused: presentation.isFocused)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .id(note.list.id)
            if presentation.isFocused {
                footer
            }
        }
        .background(palette.paper)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(palette.accent.opacity(0.22), lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        HStack(spacing: 6) {
            ListTabs(note: note, palette: palette, isFocused: presentation.isFocused)
            if !presentation.isFocused {
                Spacer(minLength: 6)
                let remaining = note.tasks.filter { !$0.isCompleted }.count
                Text(remaining, format: .number)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: 26, minHeight: 18)
                    .background(palette.accent.opacity(0.18), in: Capsule())
                    .fixedSize()
                    .accessibilityLabel("\(remaining) uncompleted tasks")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Spacer()
            panelButton("pin", label: presentation.isPinned ? "Unpin Note" : "Pin Note", action: togglePin)
                .opacity(presentation.isPinned ? 1 : 0.6)
            panelButton("x", label: "Close", action: close)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private var footer: some View {
        let listID = note.list.id
        let draft = Binding(get: { drafts[listID, default: ""] }, set: { drafts[listID] = $0 })
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(palette.accent.opacity(0.22))
                .frame(height: 0.5)
            TaskTextField(placeholder: "Add task…", text: draft, palette: palette) {
                guard note.finishRenaming(), note.finishEditing(), note.add(draft.wrappedValue) else { return }
                drafts.removeValue(forKey: listID)
            }
            .padding(.vertical, 10)
            if let error = note.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(palette.ink)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 14)
    }

    private func panelButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .frame(width: 16, height: 16)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.accent)
        .accessibilityLabel(label)
        .help(label)
    }
}
