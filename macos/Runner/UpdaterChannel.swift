import Cocoa
import FlutterMacOS

/// In-app update: the app downloads (lib/common/request.dart) and the steps that
/// touch the installed app run here, each verifying the signed manifest again.
final class UpdaterChannel {
    // TODO(release): pin the release Ed25519 public key (base64 of 32 bytes), the same value as
    // macUpdatePublicKey in lib/common/constant.dart. Empty keeps the in-app updater off.
    static let pinnedPublicKey = ""

    private static var instance: UpdaterChannel?
    private let channel: FlutterMethodChannel
    private let queue = DispatchQueue(label: "flash.updater", qos: .userInitiated)

    static func register(messenger: FlutterBinaryMessenger) {
        instance = UpdaterChannel(messenger: messenger)
    }

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.follow.clash/mac_updater", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(nil)
                return
            }
            let arguments = call.arguments as? [String: Any] ?? [:]
            self.queue.async {
                let answer = self.handle(call.method, arguments)
                DispatchQueue.main.async { result(answer ?? FlutterMethodNotImplemented) }
            }
        }
    }

    private var target: String? {
        Bundle.main.bundlePath == FCUpdateInstalledBundle() ? FCUpdateInstalledBundle() : nil
    }

    private func handle(_ method: String, _ arguments: [String: Any]) -> Any? {
        switch method {
        case "prepare":
            guard let manifest = (arguments["manifest"] as? FlutterStandardTypedData)?.data,
                  let archive = arguments["archive"] as? String
            else { return ["code": "failed", "detail": "arguments"] }
            return prepare(manifest: manifest, archive: archive)
        case "install":
            guard let staged = arguments["staged"] as? String else { return ["code": "failed", "detail": "arguments"] }
            guard let target else { return ["code": "notInApplications", "detail": Bundle.main.bundlePath] }
            return FCUpdateInstall(staged, target, FCUpdateDefaultPolicy())
        case "relaunch":
            guard let target else { return ["code": "notInApplications"] }
            return ["code": FCUpdateScheduleRelaunch(getpid(), target) ? "ok" : "failed"]
        case "reveal":
            guard let archive = arguments["archive"] as? String, let version = arguments["version"] as? String
            else { return ["code": "failed", "detail": "arguments"] }
            return reveal(archive: archive, version: version)
        case "cleanup":
            if let target { FCUpdateCleanup(target) }
            return ["code": "ok"]
        default:
            return nil
        }
    }

    private func prepare(manifest: Data, archive: String) -> [AnyHashable: Any] {
        guard let payload = UpdateManifestSignature.open(manifest, publicKey: Self.pinnedPublicKey) else {
            return ["code": "rejected", "detail": "manifest signature"]
        }
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "amd64"
        #endif
        let name = (archive as NSString).lastPathComponent
        guard let assets = payload["assets"] as? [[String: Any]],
              let asset = assets.first(where: { $0["arch"] as? String == arch && $0["name"] as? String == name }),
              let sha256 = asset["sha256"] as? String, let size = asset["size"] as? NSNumber,
              let version = payload["version"] as? String, let build = payload["build"] as? NSNumber,
              let helperBuild = payload["helperBuild"] as? NSNumber
        else { return ["code": "rejected", "detail": "manifest content"] }
        let expected: [String: Any] = [
            "sha256": sha256, "size": size, "version": version, "build": build, "helperBuild": helperBuild,
        ]
        guard let target else { return ["code": "notInApplications", "detail": Bundle.main.bundlePath] }
        return FCUpdatePrepare(archive, expected, target, FCUpdateDefaultPolicy())
    }

    /// Shown for a manual install; files the app downloaded itself carry no quarantine.
    private func reveal(archive: String, version: String) -> [String: Any] {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let app = downloads.flatMap { FCUpdateUnpackForManualInstall(archive, version, $0.path) }
        let shown = URL(fileURLWithPath: app ?? archive)
        DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting([shown]) }
        return ["code": "ok", "detail": shown.path]
    }
}
