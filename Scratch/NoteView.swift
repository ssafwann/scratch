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
    let togglePin: () -> Void
    let close: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let tasks = [
        SampleTask(text: "Review this week’s priorities"),
        SampleTask(text: "Pick up a notebook"),
        SampleTask(text: "Send meeting notes", completed: true)
    ]

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
                    ForEach(tasks) { task in
                        SampleTaskRow(task: task, palette: palette)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
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
            Text("Untitled")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .layoutPriority(1)
            Text(tasks.count, format: .number)
                .font(.system(size: 11))
                .foregroundStyle(palette.accent.opacity(0.75))
                .accessibilityLabel("\(tasks.count) tasks")
            Spacer()
            if presentation.isFocused {
                panelButton("pin", label: presentation.isPinned ? "Unpin Note" : "Pin Note", action: togglePin)
                    .opacity(presentation.isPinned ? 1 : 0.6)
                panelButton("x", label: "Close", action: close)
            } else {
                let remaining = tasks.filter { !$0.completed }.count
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

private struct SampleTask: Identifiable {
    let text: String
    var completed = false

    var id: String { text }
}

private struct SampleTaskRow: View {
    let task: SampleTask
    let palette: NotePalette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(palette.accent, lineWidth: 1.5)
                .overlay {
                    if task.completed {
                        Path { path in
                            path.move(to: CGPoint(x: 3.5, y: 7))
                            path.addLine(to: CGPoint(x: 6, y: 9.5))
                            path.addLine(to: CGPoint(x: 10.5, y: 4.5))
                        }
                        .stroke(palette.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(width: 14, height: 14)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(task.text)
                .font(.system(size: 14))
                .strikethrough(task.completed)
                .foregroundStyle(task.completed ? palette.ink.opacity(0.55) : palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.text)
        .accessibilityValue(task.completed ? "Completed" : "Uncompleted")
    }
}

private struct NotePalette {
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
