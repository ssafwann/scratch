import SwiftUI

@MainActor
final class NotePresentation: ObservableObject {
    static let toolbarHeight: CGFloat = 38
    static let toolbarRestHeight: CGFloat = 8
    static let headerHeight: CGFloat = 34
    static let footerHeight: CGFloat = 44

    struct WindowLayout: Equatable {
        var top: CGFloat = 0
        var bottom: CGFloat = 0
        var isCompact = false
    }

    @Published var windowLayout = WindowLayout()
    @Published var showsEdges = false
    @Published var showsTasks = true
    @Published var isCollapsed = false

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
    let toggleCollapse: () -> Void
    let resizeFooter: (CGFloat) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var drafts: [Int64: String] = [:]

    private var palette: NotePalette {
        NotePalette.forList(at: note.activeIndex, colorScheme: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = presentation.windowLayout
            let topSpace = layout.isCompact ? 0 : layout.top + NotePresentation.toolbarRestHeight
            let hiddenTop = presentation.showsEdges ? 0 : presentation.showsTasks ? layout.top : topSpace
            let hiddenBottom = presentation.showsTasks
                ? (presentation.showsEdges ? 0 : layout.bottom)
                : max(0, geometry.size.height - topSpace - NotePresentation.headerHeight)

            // The window reserves these slots before the reveal. Only the mask and the
            // controls animate, so the title and the scroll view keep their coordinates.
            VStack(spacing: 0) {
                toolbarSlot(height: topSpace)
                header
                taskList
                footerSlot(height: layout.bottom)
            }
            .background(palette.paper)
            .mask {
                RoundedRectangle(cornerRadius: 12)
                    .padding(.top, hiddenTop)
                    .padding(.bottom, hiddenBottom)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(palette.accent.opacity(0.22), lineWidth: 0.5)
                    .padding(.top, hiddenTop)
                    .padding(.bottom, hiddenBottom)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private var taskList: some View {
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
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.accent.opacity(0.22))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
                .opacity(presentation.showsTasks ? 1 : 0)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(!presentation.isCollapsed)
        .accessibilityHidden(presentation.isCollapsed)
    }

    private func toolbarSlot(height: CGFloat) -> some View {
        let visibleHeight = presentation.showsEdges ? height : NotePresentation.toolbarRestHeight
        return Color.clear
            .frame(height: height)
            .overlay(alignment: .bottom) {
                toolbar
                    .frame(height: visibleHeight)
                    .clipped()
                    .opacity(presentation.showsEdges ? 1 : 0)
                    .allowsHitTesting(controlsInteractive)
                    .accessibilityHidden(!controlsInteractive)
            }
            .clipped()
    }

    private func footerSlot(height: CGFloat) -> some View {
        Color.clear
            .frame(height: height)
            .overlay(alignment: .top) {
                footer
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { resizeFooter($0) }
                    .frame(height: presentation.showsEdges ? height : 0, alignment: .top)
                    .clipped()
                    .opacity(presentation.showsEdges ? 1 : 0)
                    .allowsHitTesting(controlsInteractive)
                    .accessibilityHidden(!controlsInteractive)
            }
    }

    private var controlsInteractive: Bool {
        presentation.isFocused && presentation.showsEdges && !presentation.isCollapsed
    }

    private var header: some View {
        Group {
            if presentation.isCollapsed {
                Button(action: toggleCollapse) {
                    HStack(spacing: 6) {
                        Text(note.list.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        remainingPill
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Expand \(note.list.name)")
            } else {
                HStack(spacing: 6) {
                    ListTabs(note: note, palette: palette, isFocused: presentation.isFocused)
                    if !presentation.isFocused {
                        Spacer(minLength: 6)
                        remainingPill
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: NotePresentation.headerHeight)
    }

    private var remainingPill: some View {
        let remaining = note.tasks.filter { !$0.isCompleted }.count
        return Text(remaining, format: .number)
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(palette.accent)
            .frame(minWidth: 26, minHeight: 18)
            .background(palette.accent.opacity(0.18), in: Capsule())
            .fixedSize()
            .accessibilityLabel("\(remaining) uncompleted tasks")
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Spacer()
            panelButton("chevron-up", label: "Collapse Note", action: toggleCollapse)
            panelButton("pin", label: presentation.isPinned ? "Unpin Note" : "Pin Note", action: togglePin)
                .opacity(presentation.isPinned ? 1 : 0.6)
            panelButton("x", label: "Close", action: close)
        }
        .padding(.horizontal, 14)
    }

    private var footer: some View {
        let listID = note.list.id
        let draft = Binding(get: { drafts[listID, default: ""] }, set: { drafts[listID] = $0 })
        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(palette.accent.opacity(0.22))
                .frame(height: 1)
            TaskTextField(placeholder: "Add task…", text: draft, palette: palette, isEnabled: controlsInteractive) {
                guard note.finishRenaming(), note.finishEditing(), note.add(draft.wrappedValue) else { return }
                drafts.removeValue(forKey: listID)
            }
            .padding(.vertical, 12)
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
