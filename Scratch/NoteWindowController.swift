import AppKit
import SwiftUI

@MainActor
final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    private static let frameKey = "noteFrame"
    private static let pinnedKey = "notePinned"
    private static let minimumSize = NSSize(width: 280, height: 200)

    private let defaults: UserDefaults
    private let presentation: NotePresentation

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let pinned = defaults.object(forKey: Self.pinnedKey) as? Bool ?? true
        presentation = NotePresentation(isPinned: pinned)

        let panel = NotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 382),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)

        panel.title = "Scratch"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.tabbingMode = .disallowed
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.level = pinned ? .floating : .normal
        panel.isMovableByWindowBackground = true
        panel.minSize = Self.minimumSize
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView: NoteView(
            presentation: presentation,
            togglePin: { [weak self] in self?.togglePin() },
            close: { [weak panel] in panel?.close() }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        restoreFrame(of: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        presentation.isFocused = true
    }

    func windowDidResignKey(_ notification: Notification) {
        presentation.isFocused = false
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        if window?.inLiveResize == false {
            saveFrame()
        }
    }

    func windowWillClose(_ notification: Notification) {
        saveFrame()
    }

    private func togglePin() {
        presentation.isPinned.toggle()
        window?.level = presentation.isPinned ? .floating : .normal
        defaults.set(presentation.isPinned, forKey: Self.pinnedKey)
    }

    private func saveFrame() {
        guard let window else { return }
        defaults.set(NSStringFromRect(window.frame), forKey: Self.frameKey)
    }

    private func restoreFrame(of panel: NSPanel) {
        guard let saved = defaults.string(forKey: Self.frameKey) else {
            panel.center()
            return
        }

        let frame = NSRectFromString(saved)
        guard frame.width >= Self.minimumSize.width, frame.height >= Self.minimumSize.height,
              let screen = NSScreen.screens.max(by: {
                  let first = $0.visibleFrame.intersection(frame)
                  let second = $1.visibleFrame.intersection(frame)
                  return first.width * first.height < second.width * second.height
              }),
              screen.visibleFrame.intersects(frame) else {
            panel.center()
            return
        }

        let bounds = screen.visibleFrame
        let width = min(frame.width, bounds.width)
        let height = min(frame.height, bounds.height)
        let x = min(max(frame.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(frame.maxY - height, bounds.minY), bounds.maxY - height)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
    }
}
