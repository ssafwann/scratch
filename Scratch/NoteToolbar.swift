import AppKit
import SwiftUI

struct NoteToolbar: View {
    @ObservedObject var note: NoteTasks
    let palette: NotePalette
    let isDark: Bool
    let isPinned: Bool
    let toggleAppearance: () -> Void
    let toggleCollapse: () -> Void
    let togglePin: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            button(isDark ? "moon" : "sun", label: isDark ? "Switch to light mode" : "Switch to dark mode",
                   action: toggleAppearance)
            completedMenu
            if note.hasCompletedTasks {
                button("wand-sparkles", label: "Clear completed tasks", action: note.clearCompleted)
            }
            Spacer()
            button("chevron-up", label: "Collapse Note", action: toggleCollapse)
            button("pin", label: isPinned ? "Unpin Note" : "Pin Note", action: togglePin)
                .opacity(isPinned ? 1 : 0.6)
            button("x", label: "Close", action: close)
        }
        .padding(.horizontal, 14)
        .environment(\.colorScheme, isDark ? .dark : .light)
    }

    private var completedMenu: some View {
        Menu {
            Toggle("Hide completed", isOn: completedBinding(.hide))
            Toggle("Move completed to bottom", isOn: completedBinding(.moveToBottom))
        } label: {
            Image(nsImage: filterIcon)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 26, height: 26)
        .accessibilityLabel("Completed tasks")
        .help("Completed tasks")
    }

    private var filterIcon: NSImage {
        let tint = NSColor(palette.accent)
        return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            guard let source = NSImage(named: "list-filter") else { return false }
            source.draw(in: rect)
            tint.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    private func completedBinding(_ option: NoteTasks.CompletedOption) -> Binding<Bool> {
        Binding(
            get: { note.completedOption(option) },
            set: { note.setCompletedOption(option, enabled: $0) }
        )
    }

    private func button(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { icon(name) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .help(label)
    }

    private func icon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(palette.accent)
            .frame(width: 16, height: 16)
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
    }
}
