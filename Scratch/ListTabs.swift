import SwiftUI

struct ListTabs: View {
    @ObservedObject var note: NoteTasks
    let palette: NotePalette
    let isFocused: Bool

    @State private var hoveredIndex: Int?
    @Environment(TaskDrag.self) private var drag

    var body: some View {
        HStack(spacing: 6) {
            title
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .layoutPriority(1)
            if isFocused {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(note.lists.indices, id: \.self) { index in
                        tab(at: index)
                    }
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { hoveredIndex = nil }
        }
        .onChange(of: note.activeIndex) { _, _ in hoveredIndex = nil }
    }

    @ViewBuilder private var title: some View {
        if isFocused, note.isRenaming {
            TaskTextField(placeholder: "List name", text: $note.renamedTitle, palette: palette,
                          autofocus: true, singleLine: true, cancel: { note.cancelRenaming() }) {
                note.finishRenaming()
            }
        } else if isFocused {
            Button {
                hoveredIndex = nil
                note.beginRenaming()
            } label: {
                Text(hoveredIndex.map { note.lists[$0].name } ?? note.list.name)
                    .opacity(hoveredIndex == nil || hoveredIndex == note.activeIndex ? 1 : 0.65)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename \(note.list.name)")
        } else {
            Text(note.list.name)
        }
    }

    private func tab(at index: Int) -> some View {
        let selected = note.activeIndex == index
        let hovered = hoveredIndex == index
        let targeted = drag.targetListID == note.lists[index].id
        return Button {
            note.selectList(at: index)
        } label: {
            Circle()
                .fill(palette.accent)
                .opacity(targeted || selected ? 1 : hovered ? 0.85 : 0.3)
                .frame(width: 6, height: 6)
                .scaleEffect(targeted ? 1.9 : hovered ? 1.35 : 1)
                .frame(width: 14, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(note.lists[index].name), list \(index + 1)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .onHover { inside in
            if inside { hoveredIndex = index }
            else if hoveredIndex == index { hoveredIndex = nil }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(TaskDrag.coordinateSpace)) } action: {
            drag.tabFrames[note.lists[index].id] = $0
        }
    }
}
