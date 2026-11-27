import SwiftUI

struct ListTabs: View {
    @ObservedObject var note: NoteTasks
    let palette: NotePalette
    let isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredIndex: Int?

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
        return Button {
            note.selectList(at: index)
        } label: {
            Circle()
                .fill(NotePalette.forList(at: index, colorScheme: colorScheme).accent)
                .opacity(selected || hovered ? 1 : 0.55)
                .frame(width: selected || hovered ? 8 : 6, height: selected || hovered ? 8 : 6)
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
    }
}
