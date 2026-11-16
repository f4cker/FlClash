import XCTest

final class ProcessSourceCatalogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("process-source-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testAppStoreDaemonsNameTheAppStore() {
        for path in [
            "/System/Library/PrivateFrameworks/CommerceKit.framework/Versions/A/Resources/storedownloadd",
            "/System/Library/PrivateFrameworks/AppStoreDaemon.framework/Support/appstoreagent",
        ] {
            let service = ProcessSourceCatalog.service(forExecutable: path)
            XCTAssertEqual(service?.id, "appStore", path)
            XCTAssertEqual(service?.shared, false)
            XCTAssertEqual(service?.iconPaths.first, "/System/Applications/App Store.app")
        }
    }

    func testSharedServicesNameNoApp() {
        let service = ProcessSourceCatalog.service(forExecutable: "/usr/libexec/nsurlsessiond")
        XCTAssertEqual(service?.id, "backgroundDownloads")
        XCTAssertEqual(service?.shared, true)
        XCTAssertEqual(service?.iconPaths, [])
        XCTAssertEqual(
            ProcessSourceCatalog.service(forExecutable: "/usr/sbin/mDNSResponder")?.id,
            "nameResolution")
    }

    func testPushGoesToNotifications() {
        let service = ProcessSourceCatalog.service(
            forExecutable: "/System/Library/PrivateFrameworks/ApplePushService.framework/apsd")
        XCTAssertEqual(service?.id, "pushNotifications")
        XCTAssertTrue(service?.iconPaths.first?.hasSuffix("NotificationsSettings.appex") ?? false)
    }

    func testCryptexAndVersionedPathsMatchTheirListedSpelling() {
        XCTAssertEqual(
            ProcessSourceCatalog.service(
                forExecutable: "/System/Volumes/Preboot/Cryptexes/App/usr/libexec/SafariBookmarksSyncAgent")?.id,
            "safari")
        XCTAssertEqual(
            ProcessSourceCatalog.service(
                forExecutable:
                    "/System/Volumes/Preboot/Cryptexes/OS/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.Networking.xpc/Contents/MacOS/com.apple.WebKit.Networking"
            )?.id,
            "webContent")
        XCTAssertEqual(
            ProcessSourceCatalog.service(
                forExecutable: "/System/Library/PrivateFrameworks/CloudPhotoLibrary.framework/Versions/A/Support//cloudphotod")?.id,
            "photos")
    }

    func testOnlyTheFullPathMatches() {
        XCTAssertNil(ProcessSourceCatalog.service(forExecutable: "apsd"))
        XCTAssertNil(ProcessSourceCatalog.service(forExecutable: "/tmp/apsd"))
        XCTAssertNil(ProcessSourceCatalog.service(forExecutable: "/usr/local/bin/nsurlsessiond"))
        XCTAssertNil(ProcessSourceCatalog.service(forExecutable: "/usr/libexec/../libexec/trustd"))
    }

    func testEveryEntryIsWellFormed() {
        var ids = Set<String>()
        for (service, executables) in ProcessSourceCatalog.entries {
            XCTAssertTrue(ids.insert(service.id).inserted, "\(service.id) is listed twice")
            XCTAssertFalse(executables.isEmpty, service.id)
            XCTAssertEqual(service.shared, service.iconPaths.isEmpty, service.id)
            for executable in executables {
                XCTAssertEqual(
                    ProcessSourceCatalog.service(forExecutable: executable), service, executable)
            }
        }
    }

    func testLaunchdJobReadsProgramAndAssociatedApps() {
        let job = LaunchdJob(plist: [
            "Label": "com.example.daemon",
            "ProgramArguments": ["/Library/PrivilegedHelperTools/com.example.daemon", "-d"],
            "AssociatedBundleIdentifiers": ["com.example.app"],
        ])
        XCTAssertEqual(job?.program, "/Library/PrivilegedHelperTools/com.example.daemon")
        XCTAssertEqual(job?.bundleIds, ["com.example.app"])
        XCTAssertEqual(
            LaunchdJob(plist: [
                "Program": "/usr/local/bin/x", "AssociatedBundleIdentifiers": "com.example.x",
            ])?.bundleIds,
            ["com.example.x"])
    }

    func testLaunchdJobWithoutAssociationOrAbsoluteProgramIsSkipped() {
        XCTAssertNil(LaunchdJob(plist: ["Program": "/usr/local/bin/x"]))
        XCTAssertNil(
            LaunchdJob(plist: ["Program": "x", "AssociatedBundleIdentifiers": ["com.example.x"]]))
        XCTAssertNil(
            LaunchdJob(plist: ["Program": "/x", "AssociatedBundleIdentifiers": [""]]))
    }

    func testIndexReadsPlistsAndRefreshesOnlyAfterAChange() throws {
        var now = Date(timeIntervalSince1970: 1000)
        let index = LaunchdIndex(directories: [directory.path], minInterval: 30, now: { now })
        let daemon = "/Library/PrivilegedHelperTools/com.example.daemon"
        XCTAssertNil(index.job(forExecutable: daemon))
        XCTAssertEqual(index.generation, 1)

        try write("com.example.daemon.plist", [
            "Label": "com.example.daemon",
            "ProgramArguments": [daemon],
            "AssociatedBundleIdentifiers": ["com.example.app"],
        ])
        XCTAssertNil(index.job(forExecutable: daemon))
        now += 31
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 5000)], ofItemAtPath: directory.path)
        XCTAssertEqual(index.job(forExecutable: daemon)?.bundleIds, ["com.example.app"])
        XCTAssertEqual(index.generation, 2)

        now += 31
        _ = index.job(forExecutable: daemon)
        XCTAssertEqual(index.generation, 2)
    }

    func testResolverAttributesALaunchdDaemonToItsApp() throws {
        let app = directory.appendingPathComponent("Example.app")
        try FileManager.default.createDirectory(
            at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "com.example.app", "CFBundleName": "Example"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let daemon = "/Library/PrivilegedHelperTools/com.example.daemon"
        try write("com.example.daemon.plist", [
            "Label": "com.example.daemon",
            "Program": daemon,
            "AssociatedBundleIdentifiers": ["com.example.missing", "com.example.app"],
        ])
        let resolver = ProcessSourceResolver(
            launchd: LaunchdIndex(directories: [directory.path]),
            appURL: { $0 == "com.example.app" ? app : nil })

        XCTAssertEqual(
            resolver.resolve(daemon),
            .app(
                bundleId: "com.example.app", name: "Example", bundlePath: app.path,
                launchdLabel: "com.example.daemon"))
        XCTAssertEqual(resolver.resolve("/Library/PrivilegedHelperTools/other"), .none)
    }

    func testResolverPrefersTheCatalogOverASystemHelperBundle() {
        let resolver = ProcessSourceResolver(
            launchd: LaunchdIndex(directories: [directory.path]),
            fileExists: { $0 == "/System/Applications/Messages.app" })
        let imagent = "/System/Library/PrivateFrameworks/IMCore.framework/imagent.app/Contents/MacOS/imagent"
        guard case let .service(service, iconPath) = resolver.resolve(imagent) else {
            return XCTFail("imagent is not a service")
        }
        XCTAssertEqual(service.id, "messages")
        XCTAssertEqual(iconPath, "/System/Applications/Messages.app")
    }

    func testResolverFallsBackThroughIconPaths() {
        let resolver = ProcessSourceResolver(
            launchd: LaunchdIndex(directories: [directory.path]),
            fileExists: { $0 == "/System/Applications/Find My.app" })
        XCTAssertEqual(
            resolver.resolve("/usr/libexec/searchpartyd"),
            .service(
                ProcessSourceCatalog.service(forExecutable: "/usr/libexec/searchpartyd")!,
                iconPath: "/System/Applications/Find My.app"))
    }

    private func write(_ name: String, _ plist: [String: Any]) throws {
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: directory.appendingPathComponent(name))
    }
}
