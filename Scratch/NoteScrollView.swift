import SwiftUI

private let noteScrollCoordinateSpace = "note scroll viewport"

struct NoteScrollView<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: () -> Content

    @State private var contentFrame = CGRect.zero
    @State private var isHovered = false
    @State private var isScrolling = false
    @State private var scrollUpdate = 0

    var body: some View {
        ScrollView {
            content()
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .named(noteScrollCoordinateSpace))
                } action: { frame in
                    if abs(frame.minY - contentFrame.minY) > 0.5 {
                        isScrolling = true
                        scrollUpdate += 1
                    }
                    contentFrame = frame
                }
        }
        .coordinateSpace(name: noteScrollCoordinateSpace)
        .scrollIndicators(.never)
        .onHover { isHovered = $0 }
        .task(id: scrollUpdate) {
            guard scrollUpdate > 0 else { return }
            try? await Task.sleep(for: .milliseconds(650))
            if !Task.isCancelled { isScrolling = false }
        }
        .overlay(alignment: .trailing) {
            GeometryReader { geometry in
                thumb(viewportHeight: geometry.size.height)
            }
            .frame(width: 4)
            .padding(.trailing, 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder private func thumb(viewportHeight: CGFloat) -> some View {
        let scrollRange = contentFrame.height - viewportHeight
        if scrollRange > 0.5, viewportHeight > 8 {
            let trackHeight = viewportHeight - 8
            let thumbHeight = min(trackHeight, max(16, trackHeight * viewportHeight / contentFrame.height))
            let progress = min(max(-contentFrame.minY / scrollRange, 0), 1)
            Capsule()
                .fill(accent.opacity(0.45))
                .frame(width: 4, height: thumbHeight)
                .offset(y: 4 + progress * (trackHeight - thumbHeight))
                .opacity(isHovered || isScrolling ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: isHovered || isScrolling)
        }
    }
}
