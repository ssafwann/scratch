import AppKit
import SwiftUI

struct TaskTextField: View {
    let placeholder: String
    @Binding var text: String
    let palette: NotePalette
    var autofocus = false
    var cancel: (() -> Void)?
    let submit: () -> Void

    var body: some View {
        Editor(text: $text, palette: palette, label: placeholder, autofocus: autofocus,
               cancel: cancel, submit: submit)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.accent.opacity(0.65))
                        .padding(.top, 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct Editor: NSViewRepresentable {
    @Binding var text: String
    let palette: NotePalette
    let label: String
    let autofocus: Bool
    let cancel: (() -> Void)?
    let submit: () -> Void

    private static let font = NSFont.systemFont(ofSize: 14)

    func makeNSView(context: Context) -> NSScrollView {
        let editor = TaskEditor()
        editor.isRichText = false
        editor.importsGraphics = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.font = Self.font
        editor.drawsBackground = false
        editor.textContainerInset = .zero
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.widthTracksTextView = true
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.setAccessibilityLabel(label)
        editor.delegate = context.coordinator
        editor.autofocus = autofocus

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? TaskEditor else { return }
        context.coordinator.text = $text
        editor.submit = submit
        editor.cancel = cancel
        editor.textColor = NSColor(palette.ink)
        editor.insertionPointColor = NSColor(palette.accent)
        if editor.string != text {
            editor.string = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        // A trailing newline adds an empty line. Include it in the measurement.
        let measuredText = text.hasSuffix("\n") ? text + " " : text
        let bounds = (measuredText as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: Self.font]
        )
        return CGSize(width: width, height: min(max(ceil(bounds.height) + 2, 19), 78))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            text.wrappedValue = editor.string
        }
    }
}

private final class TaskEditor: NSTextView {
    var autofocus = false
    var submit: (() -> Void)?
    var cancel: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard autofocus, window != nil else { return }
        Task { @MainActor [weak self] in
            guard let self, window?.isKeyWindow == true else { return }
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if !hasMarkedText(), let key = event.charactersIgnoringModifiers, key == "\r" || key == "\u{3}" {
            if event.modifierFlags.contains(.shift) {
                insertText("\n", replacementRange: selectedRange())
            } else {
                submit?()
            }
            return
        }
        if !hasMarkedText(), event.charactersIgnoringModifiers == "\u{1b}", let cancel {
            cancel()
            return
        }
        super.keyDown(with: event)
    }
}
