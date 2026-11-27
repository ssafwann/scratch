import AppKit
import SwiftUI

@MainActor
final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var isAdjustingNoteFrame = false

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // These frame changes extend an already positioned note around a fixed title.
        isAdjustingNoteFrame ? frameRect : super.constrainFrameRect(frameRect, to: screen)
    }
}

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate {
    private static let frameKey = "noteFrame"
    private static let pinnedKey = "notePinned"
    private static let revealAnimation = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.18)
    private static let minimumSize = NSSize(width: 280, height: 200)

    private let defaults: UserDefaults
    private let presentation: NotePresentation
    private let note: NoteTasks
    private var footerHeight = NotePresentation.footerHeight
    private var expandedHeight: CGFloat = 382
    private var transitionID = 0
    private var isTransitioning = false

    private var isUpdatingFrame: Bool { (window as? NotePanel)?.isAdjustingNoteFrame == true }

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
            toggleCollapse: { [weak self] in self?.toggleCollapse() },
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
        presentation.isFocused = focused
        if !presentation.isCollapsed {
            transition(showsEdges: focused, showsTasks: true)
        }
    }

    private func toggleCollapse() {
        guard note.finishRenaming(), note.finishEditing() else { return }
        presentation.isCollapsed.toggle()
        transition(showsEdges: presentation.isFocused && !presentation.isCollapsed,
                   showsTasks: !presentation.isCollapsed)
    }

    private func transition(showsEdges: Bool, showsTasks: Bool) {
        transitionID += 1
        let id = transitionID
        isTransitioning = true
        let current = presentation.windowLayout
        let needsSpace = (showsEdges && current.top == 0) || (showsTasks && current.isCompact)
        if needsSpace {
            setWindowLayout(layout(showsEdges: showsEdges, showsTasks: showsTasks))
            // Let AppKit lay out the larger transparent window before animating its contents.
            DispatchQueue.main.async { [weak self] in
                self?.animate(showsEdges: showsEdges, showsTasks: showsTasks, id: id)
            }
        } else {
            animate(showsEdges: showsEdges, showsTasks: showsTasks, id: id)
        }
    }

    private func animate(showsEdges: Bool, showsTasks: Bool, id: Int) {
        guard transitionID == id else { return }
        withAnimation(Self.revealAnimation, completionCriteria: .logicallyComplete) {
            presentation.showsEdges = showsEdges
            presentation.showsTasks = showsTasks
        } completion: { [weak self] in
            guard let self, self.transitionID == id else { return }
            self.isTransitioning = false
            self.setWindowLayout(self.layout(showsEdges: showsEdges, showsTasks: showsTasks))
        }
    }

    private func layout(showsEdges: Bool, showsTasks: Bool) -> NotePresentation.WindowLayout {
        if !showsTasks { return .init(isCompact: true) }
        if !showsEdges { return .init() }
        return .init(top: NotePresentation.toolbarHeight - NotePresentation.toolbarRestHeight, bottom: footerHeight)
    }

    private func resizeFooter(to height: CGFloat) {
        guard height > 0, height != footerHeight else { return }
        footerHeight = height
        if presentation.showsEdges, !isTransitioning {
            setWindowLayout(layout(showsEdges: true, showsTasks: true))
        }
    }

    private func setWindowLayout(_ layout: NotePresentation.WindowLayout) {
        guard let panel = window as? NotePanel, presentation.windowLayout != layout else { return }
        let base = noteFrame(in: panel.frame)
        var target = base
        if layout.isCompact {
            expandedHeight = base.height
            target.size.height = NotePresentation.headerHeight
            target.origin.y = base.maxY - NotePresentation.toolbarRestHeight - target.height
        } else {
            target.size.height += layout.top + layout.bottom
            target.origin.y -= layout.bottom
        }

        panel.isAdjustingNoteFrame = true
        defer { panel.isAdjustingNoteFrame = false }
        presentation.windowLayout = layout
        let minimum = clampedWindowSize(.zero)
        panel.minSize = minimum
        panel.contentMinSize = minimum
        panel.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                               height: layout.isCompact ? NotePresentation.headerHeight : CGFloat.greatestFiniteMagnitude)
        panel.setFrame(target, display: true, animate: false)
    }

    private func noteFrame(in frame: NSRect) -> NSRect {
        let layout = presentation.windowLayout
        if layout.isCompact {
            let top = frame.maxY + NotePresentation.toolbarRestHeight
            return NSRect(x: frame.minX, y: top - expandedHeight, width: frame.width, height: expandedHeight)
        }
        return NSRect(x: frame.minX, y: frame.minY + layout.bottom,
                      width: frame.width, height: frame.height - layout.top - layout.bottom)
    }

    private func clampedWindowSize(_ size: NSSize) -> NSSize {
        let layout = presentation.windowLayout
        let minimumHeight = Self.minimumSize.height + layout.top + layout.bottom
        return NSSize(width: max(size.width, Self.minimumSize.width),
                      height: layout.isCompact ? NotePresentation.headerHeight : max(size.height, minimumHeight))
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
