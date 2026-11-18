import FlutterMacOS
import UserNotifications

/// Posts a decryption script's `$notification.post` as a system notification.
/// Permission is asked the first time a script posts, not at launch.
final class ScriptNotificationChannel: NSObject, UNUserNotificationCenterDelegate {
    private static var instance: ScriptNotificationChannel?

    private let channel: FlutterMethodChannel
    private var authorization: Bool?
    private var waiting: [UNNotificationRequest] = []

    static func register(messenger: FlutterBinaryMessenger) {
        instance = ScriptNotificationChannel(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.layoute.flash/script_notification", binaryMessenger: messenger)
        super.init()
        UNUserNotificationCenter.current().delegate = self
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "post",
                let arguments = call.arguments as? [String: Any],
                let title = arguments["title"] as? String
            else {
                result(FlutterMethodNotImplemented)
                return
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = arguments["subtitle"] as? String ?? ""
            content.body = arguments["body"] as? String ?? ""
            content.threadIdentifier = "script." + (arguments["script"] as? String ?? "")
            self?.post(
                UNNotificationRequest(
                    identifier: UUID().uuidString, content: content, trigger: nil))
            result(nil)
        }
    }

    private func post(_ request: UNNotificationRequest) {
        switch authorization {
        case true:
            UNUserNotificationCenter.current().add(request)
        case false:
            return
        case nil:
            waiting.append(request)
            guard waiting.count == 1 else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
                granted, _ in
                DispatchQueue.main.async {
                    self.authorization = granted
                    let requests = self.waiting
                    self.waiting = []
                    if granted {
                        requests.forEach { UNUserNotificationCenter.current().add($0) }
                    }
                }
            }
        }
    }

    // Shown while Flash is frontmost too; the script's page is usually open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
