import XCTest

final class ProcessAppLocatorTests: XCTestCase {
    func testHelperResolvesToOutermostApp() {
        XCTAssertEqual(
            ProcessAppLocator.outermostBundlePath(
                of: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
            ),
            "/Applications/Google Chrome.app")
    }

    func testAppExecutableResolvesToItsBundle() {
        XCTAssertEqual(
            ProcessAppLocator.outermostBundlePath(
                of: "/Users/me/Applications/Example.app/Contents/MacOS/Example"),
            "/Users/me/Applications/Example.app")
    }

    func testCommandLineToolHasNoBundle() {
        XCTAssertNil(ProcessAppLocator.outermostBundlePath(of: "/usr/bin/ssh"))
        XCTAssertNil(ProcessAppLocator.outermostBundlePath(of: "/opt/homebrew/bin/curl"))
    }

    func testBundleMustHoldTheExecutable() {
        XCTAssertNil(ProcessAppLocator.outermostBundlePath(of: "/Applications/Example.app"))
        XCTAssertNil(ProcessAppLocator.outermostBundlePath(of: "/tmp/.app/x"))
        XCTAssertNil(ProcessAppLocator.outermostBundlePath(of: "relative/Example.app/x"))
        XCTAssertNil(ProcessAppLocator.outermostBundlePath(of: "/a/../Example.app/x"))
    }

    func testDisplayNameDropsTheExtension() {
        XCTAssertEqual(ProcessAppLocator.displayName("Google Chrome.app"), "Google Chrome")
        XCTAssertEqual(ProcessAppLocator.displayName("Safari"), "Safari")
    }

    func testCacheEvictsTheLeastRecentlyUsed() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.set("a", 1)
        cache.set("b", 2)
        XCTAssertEqual(cache.get("a"), 1)
        cache.set("c", 3)
        XCTAssertNil(cache.get("b"))
        XCTAssertEqual(cache.get("a"), 1)
        XCTAssertEqual(cache.get("c"), 3)
        XCTAssertEqual(cache.count, 2)
    }
}
