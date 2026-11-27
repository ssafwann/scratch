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

    @State private var newTask = ""

    private var palette: NotePalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        VStack(spacing: 0) {
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
            Text(note.list.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .layoutPriority(1)
            Text(note.tasks.count, format: .number)
                .font(.system(size: 11))
                .foregroundStyle(palette.accent.opacity(0.75))
                .accessibilityLabel("\(note.tasks.count) tasks")
            Spacer()
            if presentation.isFocused {
                panelButton("pin", label: presentation.isPinned ? "Unpin Note" : "Pin Note", action: togglePin)
                    .opacity(presentation.isPinned ? 1 : 0.6)
                panelButton("x", label: "Close", action: close)
            } else {
                let remaining = note.tasks.filter { !$0.isCompleted }.count
                Text(remaining, format: .number)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(palette.accent)
                    .frame(minWidth: 26, minHeight: 18)
                    .background(palette.accent.opacity(0.18), in: Capsule())
                    .accessibilityLabel("\(remaining) uncompleted tasks")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(palette.accent.opacity(0.22))
                .frame(height: 0.5)
            TaskTextField(placeholder: "Add task…", text: $newTask, palette: palette) {
                guard note.finishEditing(), note.add(newTask) else { return }
                newTask = ""
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

struct NotePalette {
    let paper: Color
    let ink: Color
    let accent: Color

    static let light = NotePalette(paper: rgb(0xEEEDFE), ink: rgb(0x26215C), accent: rgb(0x3C3489))
    static let dark = NotePalette(paper: rgb(0x26215C), ink: rgb(0xEEEDFE), accent: rgb(0xCECBF6))

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }
}
