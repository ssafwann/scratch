import AppKit
import ScratchData

@main
@MainActor
enum ScratchApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var note: NoteWindowController?
    private var taskStore: TaskStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        NSApp.activate()
        do {
            taskStore = try TaskStore.openDefault()
        } catch {
            NSApp.presentError(error)
            NSApp.terminate(nil)
            return
        }
        let note = NoteWindowController()
        self.note = note
        note.showWindow(nil)
        note.window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Scratch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        let close = fileMenu.addItem(withTitle: "Close", action: #selector(closeNote), keyEquivalent: "w")
        close.target = self
        fileItem.submenu = fileMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func closeNote() {
        note?.window?.close()
    }
}
