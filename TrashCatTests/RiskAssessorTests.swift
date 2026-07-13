import XCTest
@testable import TrashCat

final class RiskAssessorTests: XCTestCase {

    // MARK: - Category-level defaults

    func testTrashIsAlwaysSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/.Trash/some-file.txt",
            category: .trash,
            name: "some-file.txt"
        )
        XCTAssertEqual(result, .safe, "Trash items should always be safe")
    }

    func testOrphanIsAlwaysDanger() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Preferences/com.unknown.plist",
            category: .orphan,
            name: "com.unknown.plist"
        )
        XCTAssertEqual(result, .danger, "Orphan items should always be danger")
    }

    func testDiagnosticIsAlwaysDanger() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Mail",
            category: .diagnostic,
            name: "邮件下载与附件"
        )
        XCTAssertEqual(result, .danger, "Diagnostic items should always be danger")
    }

    // MARK: - Danger paths

    func testIOSBackupIsDanger() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Application Support/MobileSync/Backup/abc123",
            category: .cache,
            name: "abc123"
        )
        XCTAssertEqual(result, .danger, "iOS backups should be danger")
    }

    func testXcodeArchivesIsDanger() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Developer/Xcode/Archives/MyApp.xcarchive",
            category: .cache,
            name: "MyApp.xcarchive"
        )
        XCTAssertEqual(result, .danger, "Xcode archives should be danger")
    }

    // MARK: - Caution paths

    func testXcodeDerivedDataIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Developer/Xcode/DerivedData/MyApp-abc",
            category: .cache,
            name: "MyApp-abc"
        )
        XCTAssertEqual(result, .caution)
    }

    func testXcodeDeviceSupportIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Developer/Xcode/iOS DeviceSupport/16.0",
            category: .cache,
            name: "16.0"
        )
        XCTAssertEqual(result, .caution)
    }

    func testCoreSimulatorIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Developer/CoreSimulator/Devices/abc-123",
            category: .cache,
            name: "abc-123"
        )
        XCTAssertEqual(result, .caution)
    }

    func testSystemLibraryCachesIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Library/Caches/com.apple.SomeService",
            category: .cache,
            name: "SomeService"
        )
        XCTAssertEqual(result, .caution)
    }

    func testSystemUpdatesIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Library/Updates/ProductMetadata.plist",
            category: .cache,
            name: "ProductMetadata.plist"
        )
        XCTAssertEqual(result, .caution)
    }

    // MARK: - Safe paths (cache)

    func testUserCacheIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Caches/com.apple.Safari/Cache.db",
            category: .cache,
            name: "Cache.db"
        )
        // Default cache falls through to .safe since it contains /Caches/
        XCTAssertEqual(result, .safe)
    }

    func testWebKitIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/WebKit/com.apple.Safari/WebsiteData/abc.sqlite",
            category: .cache,
            name: "abc.sqlite"
        )
        XCTAssertEqual(result, .safe)
    }

    func testTempCategoryIsSafe() {
        let result = RiskAssessor.assess(
            path: "/tmp/some-temp-file.log",
            category: .temp,
            name: "some-temp-file.log"
        )
        // /tmp is in safePaths
        XCTAssertEqual(result, .safe)
    }

    func testLogsCategoryIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Logs/SomeApp/app.log",
            category: .logs,
            name: "app.log"
        )
        XCTAssertEqual(result, .safe)
    }

    // MARK: - Browser cache

    func testBrowserCacheSubdirIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Application Support/Google/Chrome/Default/Cache/abc123",
            category: .browserCache,
            name: "abc123",
            runningBundleIDs: []
        )
        XCTAssertEqual(result, .safe)
    }

    func testBrowserCacheNonSafePathIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Application Support/Google/Chrome/Default/Preferences",
            category: .browserCache,
            name: "Preferences",
            runningBundleIDs: []
        )
        // Preferences doesn't match any safePath → falls to caution
        XCTAssertEqual(result, .caution)
    }

    func testBrowserCodeCacheIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Application Support/Google/Chrome/Default/Code Cache/js_123",
            category: .browserCache,
            name: "js_123",
            runningBundleIDs: []
        )
        XCTAssertEqual(result, .safe)
    }

    func testServiceWorkerCacheIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/test/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage/data",
            category: .browserCache,
            name: "data",
            runningBundleIDs: []
        )
        XCTAssertEqual(result, .safe)
    }

    // MARK: - Running app detection

    func testRunningAppDetection() {
        // Test that the method exists and returns a boolean.
        // Actual result depends on what's running at test time.
        let path1 = "/Users/test/Library/Caches/com.apple.Safari/Cache.db"
        let result1 = RiskAssessor.isRunningAppPath(path1)

        let path2 = "/tmp/nothing-here-xyz.abc"
        let result2 = RiskAssessor.isRunningAppPath(path2)

        // Both should be valid boolean results with no crash
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        // An obviously fake path should return false
        XCTAssertFalse(result2, "Non-existent path should not match any running app")
    }

    // MARK: - Orphan reason

    func testOrphanReasonForPreferences() {
        let reason = RiskAssessor.orphanReason(
            for: "/Users/test/Library/Preferences/com.example.app.plist"
        )
        XCTAssertTrue(reason.contains("偏好设置文件"))
    }

    func testOrphanReasonForContainers() {
        let reason = RiskAssessor.orphanReason(
            for: "/Users/test/Library/Containers/com.example.app"
        )
        XCTAssertTrue(reason.contains("沙盒容器数据"))
    }

    func testOrphanReasonForApplicationSupport() {
        let reason = RiskAssessor.orphanReason(
            for: "/Users/test/Library/Application Support/com.example.app"
        )
        XCTAssertTrue(reason.contains("应用支持数据"))
    }

    func testOrphanReasonFallback() {
        let reason = RiskAssessor.orphanReason(
            for: "/Users/test/Library/Caches/some.cache"
        )
        XCTAssertTrue(reason.contains("未匹配到已安装应用的残留文件"))
    }
}
