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
    private let note: NoteTasks
    private var footerHeight = NotePresentation.footerHeight
    private var topExtension: CGFloat = 0
    private var bottomExtension: CGFloat = 0
    private var screenOffset: CGFloat = 0
    private var isUpdatingFrame = false

    init(note: NoteTasks, defaults: UserDefaults = .standard) {
        self.note = note
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
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let hostingView = NSHostingView(rootView: NoteView(
            presentation: presentation,
            note: note,
            togglePin: { [weak self] in self?.togglePin() },
            close: { [weak panel] in panel?.close() },
            resizeFooter: { [weak self] height in
                Task { @MainActor in self?.resizeFooter(to: height) }
            }
        ))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.contentMinSize = Self.minimumSize
        panel.minSize = Self.minimumSize
        restoreFrame(of: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func windowDidBecomeKey(_ notification: Notification) {
        setFocused(true)
    }

    func windowDidResignKey(_ notification: Notification) {
        note.finishRenaming()
        note.finishEditing()
        setFocused(false)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isUpdatingFrame else { return }
        screenOffset = 0
        saveFrame()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame()
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        clampedWindowSize(frameSize)
    }

    func windowDidResize(_ notification: Notification) {
        guard !isUpdatingFrame, let window else { return }
        let frame = window.frame
        let size = clampedWindowSize(frame.size)
        if frame.size != size {
            // Window managers can set a frame without going through live resize.
            let correctedFrame = NSRect(x: frame.minX, y: frame.maxY - size.height,
                                        width: size.width, height: size.height)
            window.setFrame(correctedFrame, display: true)
        }
        if !window.inLiveResize { saveFrame() }
    }

    func windowWillClose(_ notification: Notification) {
        note.finishRenaming()
        note.finishEditing()
        saveFrame()
    }

    func selectList(at index: Int) {
        note.selectList(at: index)
    }

    private func togglePin() {
        presentation.isPinned.toggle()
        window?.level = presentation.isPinned ? .floating : .normal
        defaults.set(presentation.isPinned, forKey: Self.pinnedKey)
    }

    private func saveFrame() {
        guard !isUpdatingFrame, let window else { return }
        defaults.set(NSStringFromRect(noteFrame(in: window.frame)), forKey: Self.frameKey)
    }

    private func setFocused(_ focused: Bool) {
        guard presentation.isFocused != focused else { return }
        setExtensions(top: focused ? NotePresentation.toolbarHeight : 0, bottom: focused ? footerHeight : 0)
        presentation.isFocused = focused
    }

    private func resizeFooter(to height: CGFloat) {
        guard presentation.isFocused, height > 0, height != footerHeight else { return }
        footerHeight = height
        setExtensions(top: topExtension, bottom: height)
    }

    private func setExtensions(top: CGFloat, bottom: CGFloat) {
        guard let window else { return }
        let noteFrame = noteFrame(in: window.frame)
        var target = noteFrame
        target.origin.y -= bottom
        target.size.height += top + bottom
        let unadjustedY = target.minY
        if top > 0, let bounds = window.screen?.visibleFrame {
            // Keep the controls on screen when the note is parked near an edge.
            target.origin.y = min(max(target.minY, bounds.minY), bounds.maxY - target.height)
        }

        isUpdatingFrame = true
        defer { isUpdatingFrame = false }
        topExtension = top
        bottomExtension = bottom
        let minimum = clampedWindowSize(.zero)
        window.minSize = minimum
        window.contentMinSize = minimum
        window.setFrame(target, display: true)
        screenOffset = window.frame.minY - unadjustedY
    }

    private func noteFrame(in frame: NSRect) -> NSRect {
        NSRect(x: frame.minX, y: frame.minY + bottomExtension - screenOffset,
               width: frame.width, height: frame.height - topExtension - bottomExtension)
    }

    private func clampedWindowSize(_ size: NSSize) -> NSSize {
        NSSize(width: max(size.width, Self.minimumSize.width),
               height: max(size.height, Self.minimumSize.height + topExtension + bottomExtension))
    }

    private func restoreFrame(of panel: NSPanel) {
        guard let saved = defaults.string(forKey: Self.frameKey) else {
            panel.center()
            return
        }

        let frame = NSRectFromString(saved)
        guard !frame.isEmpty,
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
        let size = Self.clampedSize(NSSize(width: min(frame.width, bounds.width),
                                          height: min(frame.height, bounds.height)))
        let x = max(bounds.minX, min(frame.minX, bounds.maxX - size.width))
        let y = max(bounds.minY, min(frame.maxY - size.height, bounds.maxY - size.height))
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: false)
    }

    private static func clampedSize(_ size: NSSize) -> NSSize {
        NSSize(width: max(size.width, minimumSize.width), height: max(size.height, minimumSize.height))
    }
}
