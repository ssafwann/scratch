import AppKit
import ScratchData
import ServiceManagement

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
private final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var note: NoteWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        NSApp.activate()
        let tasks: NoteTasks
        do {
            tasks = try NoteTasks(store: TaskStore.openDefault())
        } catch {
            NSApp.presentError(error)
            NSApp.terminate(nil)
            return
        }
        let note = NoteWindowController(note: tasks) {
            NSApp.terminate(nil)
        }
        self.note = note
        note.showWindow(nil)
        note.window?.makeKeyAndOrderFront(nil)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let launchAtLogin = appMenu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin),
                                           keyEquivalent: "")
        launchAtLogin.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Scratch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        let close = fileMenu.addItem(withTitle: "Close", action: #selector(closeNote), keyEquivalent: "w")
        close.target = self
        fileItem.submenu = fileMenu

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let listsItem = NSMenuItem(title: "List", action: nil, keyEquivalent: "")
        mainMenu.addItem(listsItem)
        let listsMenu = NSMenu(title: "List")
        for number in 1...6 {
            let item = listsMenu.addItem(withTitle: "Switch to List \(number)", action: #selector(selectList(_:)),
                                         keyEquivalent: String(number))
            item.tag = number - 1
            item.target = self
        }
        listsItem.submenu = listsMenu
        NSApp.mainMenu = mainMenu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleLaunchAtLogin) {
            let status = SMAppService.mainApp.status
            menuItem.state = status == .enabled ? .on : status == .requiresApproval ? .mixed : .off
        }
        return true
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func selectList(_ sender: NSMenuItem) {
        note?.selectList(at: sender.tag)
    }

    @objc private func closeNote() {
        note?.window?.close()
    }
}
