import Foundation

/// An Apple system process known by the feature it works for, or, when
/// [shared], a service many apps go through that no one app owns.
struct SystemService: Equatable {
    let id: String
    let shared: Bool
    /// Bundles or icon files on this Mac to take the icon from, in order.
    let iconPaths: [String]
}

/// Apple system executables by path. Only paths seen on a Mac and whose
/// owner is beyond doubt are listed; a name alone never matches.
enum ProcessSourceCatalog {
    private static let settingsPanes = "/System/Library/ExtensionKit/Extensions"
    private static let systemSettings = "/System/Applications/System Settings.app"

    private static func app(_ name: String) -> String {
        "/System/Applications/\(name).app"
    }

    private static func pane(_ name: String) -> String {
        "\(settingsPanes)/\(name).appex"
    }

    private static func service(
        _ id: String, icons: [String], _ executables: [String]
    ) -> (SystemService, [String]) {
        (SystemService(id: id, shared: false, iconPaths: icons), executables)
    }

    private static func shared(_ id: String, _ executables: [String]) -> (SystemService, [String]) {
        (SystemService(id: id, shared: true, iconPaths: []), executables)
    }

    private static let frameworks = "/System/Library/Frameworks"
    private static let privateFrameworks = "/System/Library/PrivateFrameworks"
    private static let commerceKit = "\(privateFrameworks)/CommerceKit.framework/Resources"

    static let entries: [(SystemService, [String])] = [
        service("appStore", icons: [app("App Store")], [
            "\(commerceKit)/storedownloadd",
            "\(commerceKit)/storeaccountd",
            "\(commerceKit)/storeassetd",
            "\(commerceKit)/storelegacy",
            "\(commerceKit)/commerce",
            "\(commerceKit)/storeuid.app/Contents/MacOS/storeuid",
            "\(privateFrameworks)/AppStoreDaemon.framework/Support/appstoreagent",
            "\(privateFrameworks)/AppStoreDaemon.framework/Support/appstored",
            "\(privateFrameworks)/AppStoreComponents.framework/Support/appstorecomponentsd",
        ]),
        service("softwareUpdate", icons: [pane("SoftwareUpdateSettingsExtension"), systemSettings], [
            "/System/Library/CoreServices/Software Update.app/Contents/Resources/softwareupdated",
            "\(privateFrameworks)/MobileSoftwareUpdate.framework/Support/softwareupdated",
            "\(privateFrameworks)/SoftwareUpdate.framework/Resources/SoftwareUpdateNotificationManager.app/Contents/MacOS/SoftwareUpdateNotificationManager",
        ]),
        service("pushNotifications", icons: [pane("NotificationsSettings"), systemSettings], [
            "\(privateFrameworks)/ApplePushService.framework/apsd",
        ]),
        service("iCloud", icons: ["\(privateFrameworks)/AOSUI.framework/Resources/iCloud.icns", pane("AppleIDSettings")], [
            "\(privateFrameworks)/CloudKitDaemon.framework/Support/cloudd",
            "\(privateFrameworks)/iCloudDriveCore.framework/Versions/A/Support/bird",
            "\(privateFrameworks)/SyncedDefaults.framework/Support/syncdefaultsd",
        ]),
        service("photos", icons: [app("Photos")], [
            "\(privateFrameworks)/CloudPhotoLibrary.framework/Versions/A/Support/cloudphotod",
            "\(privateFrameworks)/PhotoAnalysis.framework/Versions/A/Support/photoanalysisd",
        ]),
        service("messages", icons: [app("Messages")], [
            "\(privateFrameworks)/IMCore.framework/imagent.app/Contents/MacOS/imagent",
            "\(privateFrameworks)/IDS.framework/identityservicesd.app/Contents/MacOS/identityservicesd",
            "\(privateFrameworks)/IMTransferServices.framework/IMTransferAgent.app/Contents/MacOS/IMTransferAgent",
        ]),
        service("maps", icons: [app("Maps")], [
            "\(privateFrameworks)/GeoServices.framework/XPCServices/com.apple.geod.xpc/Contents/MacOS/com.apple.geod",
            "/System/Library/CoreServices/mapspushd",
            "\(privateFrameworks)/MapsSync.framework/mapssyncd",
        ]),
        service("weather", icons: [app("Weather")], [
            "\(privateFrameworks)/WeatherDaemon.framework/weatherd",
        ]),
        service("siri", icons: ["/System/Library/CoreServices/Siri.app", pane("SiriPreferenceExtension")], [
            "\(privateFrameworks)/AssistantServices.framework/Versions/A/Support/assistantd",
            "/usr/libexec/siriknowledged",
        ]),
        service("spotlight", icons: ["/System/Library/CoreServices/Spotlight.app", pane("SpotlightPreferenceExtension")], [
            "\(privateFrameworks)/CoreParsec.framework/parsecd",
            "/System/Library/CoreServices/Spotlight.app/Contents/MacOS/Spotlight",
        ]),
        service("appleAccount", icons: [pane("AppleIDSettings"), systemSettings], [
            "\(privateFrameworks)/AuthKit.framework/Versions/A/Support/akd",
            "/usr/libexec/appleaccountd",
        ]),
        service("findMy", icons: [app("FindMy"), app("Find My")], [
            "/usr/libexec/searchpartyd",
            "/usr/libexec/findmydeviced",
            "/usr/libexec/findmylocateagent",
            "\(privateFrameworks)/FindMyMac.framework/Resources/FindMyMacd",
        ]),
        service("dateTime", icons: [pane("DateAndTime Extension"), systemSettings], [
            "/usr/libexec/timed",
            "/usr/sbin/sntpd",
        ]),
        service("mail", icons: [app("Mail")], [
            "\(privateFrameworks)/EmailDaemon.framework/Versions/A/maild",
        ]),
        service("safari", icons: ["/Applications/Safari.app"], [
            "/System/Cryptexes/App/usr/libexec/SafariBookmarksSyncAgent",
            "/System/Cryptexes/App/usr/libexec/SafariNotificationAgent",
            "/System/Cryptexes/App/usr/libexec/com.apple.Safari.History",
            "\(privateFrameworks)/SafariSafeBrowsing.framework/com.apple.Safari.SafeBrowsing.Service",
        ]),
        service("news", icons: [app("News")], [
            "\(privateFrameworks)/NewsDaemon.framework/newsd",
        ]),
        service("home", icons: [app("Home")], [
            "\(privateFrameworks)/HomeKitDaemon.framework/Support/homed",
        ]),
        service("gameCenter", icons: [pane("GameCenterMacOSSettingsExtension"), app("Games")], [
            "/usr/libexec/gamed",
        ]),
        service("screenTime", icons: [pane("ScreenTimePreferencesExtension"), systemSettings], [
            "\(privateFrameworks)/ScreenTimeCore.framework/Versions/A/ScreenTimeAgent",
        ]),
        service("tips", icons: [app("Tips")], [
            "/usr/libexec/tipsd",
        ]),
        service("books", icons: [app("Books")], [
            "\(privateFrameworks)/BookLibraryCore.framework/Support/bookassetd",
        ]),
        service("reminders", icons: [app("Reminders")], [
            "/usr/libexec/remindd",
        ]),
        service("contacts", icons: [app("Contacts")], [
            "\(frameworks)/AddressBook.framework/Versions/A/Helpers/AddressBookSourceSync.app/Contents/MacOS/AddressBookSourceSync",
        ]),
        service("analytics", icons: [pane("SecurityPrivacyExtension"), systemSettings], [
            "/System/Library/CoreServices/SubmitDiagInfo",
            "\(privateFrameworks)/CoreAnalytics.framework/Support/analyticsd",
        ]),
        shared("backgroundDownloads", ["/usr/libexec/nsurlsessiond"]),
        shared("nameResolution", ["/usr/sbin/mDNSResponder", "/usr/sbin/mDNSResponderHelper"]),
        shared("certificateChecks", ["/usr/libexec/trustd", "/usr/sbin/ocspd"]),
        shared("webContent", [
            "\(frameworks)/WebKit.framework/XPCServices/com.apple.WebKit.Networking.xpc/Contents/MacOS/com.apple.WebKit.Networking",
        ]),
        shared("networkProxy", ["/usr/libexec/networkserviceproxy"]),
        shared("systemAssets", ["/usr/libexec/mobileassetd"]),
        shared("location", ["/usr/libexec/locationd"]),
        shared("continuity", ["/usr/libexec/sharingd", "/usr/libexec/rapportd"]),
        shared("captivePortal", ["/usr/libexec/captiveagent"]),
        shared("appSecurity", ["/usr/libexec/syspolicyd"]),
    ]

    private static let byPath: [String: SystemService] = {
        var map: [String: SystemService] = [:]
        for (service, executables) in entries {
            for executable in executables {
                if let key = normalize(executable) {
                    precondition(map[key] == nil, "\(executable) is listed twice")
                    map[key] = service
                }
            }
        }
        return map
    }()

    static func service(forExecutable path: String) -> SystemService? {
        normalize(path).flatMap { byPath[$0] }
    }

    /// One spelling per executable: the cryptex mounts and a framework's
    /// `Versions/<v>` links reach the same file by several paths.
    static func normalize(_ path: String) -> String? {
        guard path.hasPrefix("/") else {
            return nil
        }
        var parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if parts.contains("..") || parts.contains(".") || parts.isEmpty {
            return nil
        }
        let preboot = ["System", "Volumes", "Preboot", "Cryptexes"]
        if parts.count > 5, Array(parts.prefix(4)) == preboot {
            parts = ["System", "Cryptexes"] + parts.dropFirst(4)
        }
        if parts.count > 3, parts[0] == "System", parts[1] == "Cryptexes", parts[2] == "OS" {
            parts = Array(parts.dropFirst(3))
        }
        var index = 0
        while index + 2 < parts.count {
            if parts[index].hasSuffix(".framework"), parts[index + 1] == "Versions" {
                parts.removeSubrange(index + 1...index + 2)
            }
            index += 1
        }
        return "/" + parts.joined(separator: "/")
    }
}

/// A launchd job that names, through `AssociatedBundleIdentifiers`, the
/// apps it works for.
struct LaunchdJob: Equatable {
    let label: String
    let program: String
    let bundleIds: [String]

    init(label: String, program: String, bundleIds: [String]) {
        self.label = label
        self.program = program
        self.bundleIds = bundleIds
    }

    init?(plist: [String: Any]) {
        let program =
            (plist["Program"] as? String)
            ?? (plist["ProgramArguments"] as? [Any])?.first as? String
        guard let program, program.hasPrefix("/") else {
            return nil
        }
        let ids: [String]
        switch plist["AssociatedBundleIdentifiers"] {
        case let id as String:
            ids = [id]
        case let list as [Any]:
            ids = list.compactMap { $0 as? String }
        default:
            ids = []
        }
        let bundleIds = ids.filter { !$0.isEmpty }
        if bundleIds.isEmpty {
            return nil
        }
        self.init(label: plist["Label"] as? String ?? "", program: program, bundleIds: bundleIds)
    }
}

/// Third-party launchd jobs by program path, read again only once a
/// directory changed and [minInterval] passed since the last look.
final class LaunchdIndex {
    static let defaultDirectories = [
        "/Library/LaunchDaemons",
        "/Library/LaunchAgents",
        NSHomeDirectory() + "/Library/LaunchAgents",
    ]

    let directories: [String]
    let minInterval: TimeInterval
    private let now: () -> Date
    private var checkedAt: Date?
    private var stamps: [String: Date] = [:]
    private var jobs: [String: LaunchdJob] = [:]
    private(set) var generation = 0

    init(
        directories: [String] = LaunchdIndex.defaultDirectories,
        minInterval: TimeInterval = 30,
        now: @escaping () -> Date = Date.init
    ) {
        self.directories = directories
        self.minInterval = minInterval
        self.now = now
    }

    func job(forExecutable path: String) -> LaunchdJob? {
        refreshIfNeeded()
        return ProcessSourceCatalog.normalize(path).flatMap { jobs[$0] }
    }

    func refreshIfNeeded() {
        let time = now()
        if let checkedAt, time.timeIntervalSince(checkedAt) < minInterval {
            return
        }
        checkedAt = time
        let current = Dictionary(
            uniqueKeysWithValues: directories.map { ($0, Self.modified($0) ?? .distantPast) })
        if current == stamps && generation > 0 {
            return
        }
        stamps = current
        jobs = Self.index(directories.flatMap(Self.read))
        generation += 1
    }

    /// The first job by label wins when two run the same program.
    static func index(_ jobs: [LaunchdJob]) -> [String: LaunchdJob] {
        var map: [String: LaunchdJob] = [:]
        for job in jobs.sorted(by: { $0.label < $1.label }) {
            if let key = ProcessSourceCatalog.normalize(job.program), map[key] == nil {
                map[key] = job
            }
        }
        return map
    }

    private static func modified(_ directory: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: directory))?[.modificationDate] as? Date
    }

    private static func read(_ directory: String) -> [LaunchdJob] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return []
        }
        return names.filter { $0.hasSuffix(".plist") }.compactMap { name in
            let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url),
                let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: Any]
            else {
                return nil
            }
            return LaunchdJob(plist: plist)
        }
    }
}
