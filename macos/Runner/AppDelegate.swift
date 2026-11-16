import Cocoa
import FlutterMacOS

@main
struct FlashApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

class AppDelegate: FlutterAppDelegate {
    private var flutterWindow: MainFlutterWindow?
    private var pendingLinks: [String] = []
    private var linksTaken = false

    override func applicationWillFinishLaunching(_ notification: Notification) {
        if !NativeLoadVerification.requested {
            NSAppleEventManager.shared().setEventHandler(
                self,
                andSelector: #selector(handleGetURL(_:withReplyEvent:)),
                forEventClass: AEEventClass(kInternetEventClass),
                andEventID: AEEventID(kAEGetURL)
            )
        }
        let window = MainFlutterWindow(
            contentRect: NSRect(x: 335, y: 390, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.allowsToolTipsWhenApplicationIsInactive = false
        window.autorecalculatesKeyViewLoop = false
        window.contentView?.wantsLayer = true
        flutterWindow = window
        mainFlutterWindow = window
        if !NativeLoadVerification.requested {
            NSApp.setActivationPolicy(.regular)
            configureMenus()
        }
        window.configureFlutter()
        super.applicationWillFinishLaunching(notification)
        if !NativeLoadVerification.requested {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func handleGetURL(
        _ event: NSAppleEventDescriptor,
        withReplyEvent _: NSAppleEventDescriptor
    ) {
        guard let link = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }
        if linksTaken {
            NotificationCenter.default.post(name: .flClashApplicationOpenLink, object: link)
        } else {
            pendingLinks.append(link)
        }
    }

    @objc func takePendingLinks() -> [String] {
        linksTaken = true
        defer { pendingLinks = [] }
        return pendingLinks
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if NativeLoadVerification.requested { NativeLoadVerification.fail("interrupted") }
        NotificationCenter.default.post(name: .flClashApplicationShouldTerminate, object: nil)
        return .terminateCancel
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return !NativeLoadVerification.requested
    }

    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if NativeLoadVerification.requested { return false }
        NotificationCenter.default.post(name: .flClashApplicationReopen, object: nil)
        return false
    }

    private func configureMenus() {
        let main = NSMenu(title: "Main Menu")
        NSApp.mainMenu = main
        let application = submenu("APP_NAME", in: main)
        applicationMenu = application
        item(application, "About APP_NAME", "orderFrontStandardAboutPanel:", "", modifiers: [])
        application.addItem(.separator())
        item(application, "Preferences…", nil, ",")
        application.addItem(.separator())
        let services = submenu("Services", in: application)
        NSApp.servicesMenu = services
        application.addItem(.separator())
        item(application, "Hide APP_NAME", "hide:", "h")
        item(application, "Hide Others", "hideOtherApplications:", "h", modifiers: [.option, .command])
        item(application, "Show All", "unhideAllApplications:", "", modifiers: [])
        application.addItem(.separator())
        item(application, "Quit APP_NAME", "terminate:", "q")
        let edit = submenu("Edit", in: main)
        item(edit, "Undo", "undo:", "z")
        item(edit, "Redo", "redo:", "Z")
        edit.addItem(.separator())
        item(edit, "Cut", "cut:", "x")
        item(edit, "Copy", "copy:", "c")
        item(edit, "Paste", "paste:", "v")
        item(edit, "Paste and Match Style", "pasteAsPlainText:", "V", modifiers: [.option, .command])
        item(edit, "Delete", "delete:", "", modifiers: [])
        item(edit, "Select All", "selectAll:", "a")
        edit.addItem(.separator())
        let find = submenu("Find", in: edit)
        item(find, "Find…", "performFindPanelAction:", "f", tag: 1)
        item(find, "Find and Replace…", "performFindPanelAction:", "f", modifiers: [.option, .command], tag: 12)
        item(find, "Find Next", "performFindPanelAction:", "g", tag: 2)
        item(find, "Find Previous", "performFindPanelAction:", "G", tag: 3)
        item(find, "Use Selection for Find", "performFindPanelAction:", "e", tag: 7)
        item(find, "Jump to Selection", "centerSelectionInVisibleArea:", "j")
        let spelling = submenu("Spelling and Grammar", in: edit)
        item(spelling, "Show Spelling and Grammar", "showGuessPanel:", ":")
        item(spelling, "Check Document Now", "checkSpelling:", ";")
        spelling.addItem(.separator())
        item(spelling, "Check Spelling While Typing", "toggleContinuousSpellChecking:", "", modifiers: [])
        item(spelling, "Check Grammar With Spelling", "toggleGrammarChecking:", "", modifiers: [])
        item(spelling, "Correct Spelling Automatically", "toggleAutomaticSpellingCorrection:", "", modifiers: [])
        let substitutions = submenu("Substitutions", in: edit)
        item(substitutions, "Show Substitutions", "orderFrontSubstitutionsPanel:", "", modifiers: [])
        substitutions.addItem(.separator())
        item(substitutions, "Smart Copy/Paste", "toggleSmartInsertDelete:", "", modifiers: [])
        item(substitutions, "Smart Quotes", "toggleAutomaticQuoteSubstitution:", "", modifiers: [])
        item(substitutions, "Smart Dashes", "toggleAutomaticDashSubstitution:", "", modifiers: [])
        item(substitutions, "Smart Links", "toggleAutomaticLinkDetection:", "", modifiers: [])
        item(substitutions, "Data Detectors", "toggleAutomaticDataDetection:", "", modifiers: [])
        item(substitutions, "Text Replacement", "toggleAutomaticTextReplacement:", "", modifiers: [])
        let transformations = submenu("Transformations", in: edit)
        item(transformations, "Make Upper Case", "uppercaseWord:", "", modifiers: [])
        item(transformations, "Make Lower Case", "lowercaseWord:", "", modifiers: [])
        item(transformations, "Capitalize", "capitalizeWord:", "", modifiers: [])
        let speech = submenu("Speech", in: edit)
        item(speech, "Start Speaking", "startSpeaking:", "", modifiers: [])
        item(speech, "Stop Speaking", "stopSpeaking:", "", modifiers: [])
        let view = submenu("View", in: main)
        item(view, "Enter Full Screen", "toggleFullScreen:", "f", modifiers: [.control, .command])
        let windows = submenu("Window", in: main)
        NSApp.windowsMenu = windows
        item(windows, "Minimize", "performMiniaturize:", "m")
        item(windows, "Zoom", "performZoom:", "", modifiers: [])
        windows.addItem(.separator())
        item(windows, "Bring All to Front", "arrangeInFront:", "", modifiers: [])
        let help = submenu("Help", in: main)
        NSApp.helpMenu = help
    }

    private func submenu(_ title: String, in parent: NSMenu) -> NSMenu {
        let menu = NSMenu(title: title)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        parent.addItem(item)
        return menu
    }

    private func item(
        _ menu: NSMenu, _ title: String, _ action: String?, _ key: String,
        modifiers: NSEvent.ModifierFlags = .command, tag: Int = 0
    ) {
        let item = NSMenuItem(
            title: title, action: action.map(NSSelectorFromString), keyEquivalent: key
        )
        item.keyEquivalentModifierMask = modifiers
        item.tag = tag
        menu.addItem(item)
    }
}

// rust_api's window module observes these; the names are fixed there.
extension Notification.Name {
    static let flClashApplicationShouldTerminate = Notification.Name("FlClashApplicationShouldTerminate")
    static let flClashApplicationReopen = Notification.Name("FlClashApplicationReopen")
    static let flClashApplicationOpenLink = Notification.Name("FlClashApplicationOpenLink")
}
