import Cocoa
import FlutterMacOS
import window

@main
class AppDelegate: FlutterAppDelegate {
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if NativeLoadVerification.requested { NativeLoadVerification.fail("interrupted") }
        WindowPlugin.instance?.handleShouldTerminate()
        return .terminateCancel
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
      return !NativeLoadVerification.requested
    }
    
    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if NativeLoadVerification.requested { return false }
        WindowPlugin.instance?.handleReopen()
        return false
    }
}
