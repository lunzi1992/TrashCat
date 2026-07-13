import XCTest
@testable import TrashCat

final class ScanPolicyTests: XCTestCase {

    // MARK: - Blocklist

    func testSystemIsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/System/Library/SomeFile"))
        XCTAssertTrue(ScanPolicy.isBlocked("/System/Applications"))
    }

    func testBinIsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/bin/bash"))
        XCTAssertTrue(ScanPolicy.isBlocked("/bin/sh"))
    }

    func testSbinIsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/sbin/mount"))
    }

    func testUsrIsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/usr/lib/libSystem.dylib"))
        XCTAssertTrue(ScanPolicy.isBlocked("/usr/local/bin/brew"))
    }

    func testPrivateVarDBIsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/private/var/db/SomeDB"))
        XCTAssertTrue(ScanPolicy.isBlocked("/private/var/db/ConfigurationProfiles"))
    }

    func testKeychainsIsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/Library/Keychains/login.keychain-db"))
        XCTAssertTrue(ScanPolicy.isBlocked("/Users/test/Library/Keychains/some.keychain"))
    }

    // MARK: - Allowed paths

    func testUserCachesNotBlocked() {
        XCTAssertFalse(ScanPolicy.isBlocked("/Users/test/Library/Caches/com.apple.Safari"))
    }

    func testTmpNotBlocked() {
        XCTAssertFalse(ScanPolicy.isBlocked("/tmp/some-file"))
        XCTAssertFalse(ScanPolicy.isBlocked("/private/tmp/some-file"))
    }

    func testUserLibraryNotBlocked() {
        XCTAssertFalse(ScanPolicy.isBlocked("/Users/test/Library/Logs/app.log"))
        XCTAssertFalse(ScanPolicy.isBlocked("/Users/test/Library/Application Support/App"))
    }

    func testLibraryCachesNotBlocked() {
        // /Library/Caches is NOT blocked (it's in cautionPaths, which is a different thing)
        XCTAssertFalse(ScanPolicy.isBlocked("/Library/Caches/com.apple.service"))
    }

    // MARK: - File age

    func testEmptyMinAgeAlwaysPasses() {
        let result = ScanPolicy.meetsAgeRequirement(
            url: URL(fileURLWithPath: "/tmp/fake-file.txt"),
            minAgeDays: nil
        )
        XCTAssertTrue(result, "nil minAgeDays should always pass")
    }

    func testZeroMinAgeAlwaysPasses() {
        let result = ScanPolicy.meetsAgeRequirement(
            url: URL(fileURLWithPath: "/tmp/fake-file.txt"),
            minAgeDays: 0
        )
        XCTAssertTrue(result, "minAgeDays=0 should always pass")
    }

    func testNegativeMinAgeAlwaysPasses() {
        let result = ScanPolicy.meetsAgeRequirement(
            url: URL(fileURLWithPath: "/tmp/fake-file.txt"),
            minAgeDays: -1
        )
        XCTAssertTrue(result, "negative minAgeDays should always pass")
    }

    func testNonExistentFileFailsAgeCheck() {
        let url = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-xyz-123")
        let result = ScanPolicy.meetsAgeRequirement(url: url, minAgeDays: 7)
        XCTAssertFalse(result, "Non-existent files should fail age check for safety")
    }

    // MARK: - Default policy values

    func testDefaultTempMinAgeIsReasonable() {
        // Should be at least 1 day and at most 365 days
        XCTAssertGreaterThanOrEqual(ScanPolicy.tempMinAgeDays, 1)
        XCTAssertLessThanOrEqual(ScanPolicy.tempMinAgeDays, 365)
    }

    func testBlockedPathsIsNotEmpty() {
        XCTAssertFalse(ScanPolicy.blockedPaths.isEmpty, "Blocklist should not be empty")
    }

    func testBlockedPathsCoverSystemPaths() {
        let paths = Set(ScanPolicy.blockedPaths)
        XCTAssertTrue(paths.contains("/System"))
        XCTAssertTrue(paths.contains("/bin"))
        XCTAssertTrue(paths.contains("/sbin"))
        XCTAssertTrue(paths.contains("/usr"))
        XCTAssertTrue(paths.contains("/private/var/db"))
    }

    // MARK: - Cleanability

    func testDiagnosticItemsAreNotCleanable() {
        let item = CleanItem(
            path: "/Users/test/Library/Mail",
            name: "邮件下载与附件",
            size: 1024,
            category: .diagnostic,
            ruleId: "mail-downloads"
        )

        XCTAssertFalse(item.isCleanable)
    }

    func testManualOnlyRuleItemsAreNotCleanable() {
        let item = CleanItem(
            path: "/Users/test/Library/Developer/Xcode/Archives/App.xcarchive",
            name: "App.xcarchive",
            size: 1024,
            category: .cache,
            ruleId: "xcode-archives"
        )

        XCTAssertFalse(item.isCleanable)
    }

    func testTrashItemRuleIsCleanable() {
        let item = CleanItem(
            path: "/Users/test/Library/Caches/example.cache",
            name: "example.cache",
            size: 1024,
            category: .cache,
            ruleId: "user-cache"
        )

        XCTAssertTrue(item.isCleanable)
    }

    func testLargeUserDataRulesAreDiagnosticOnly() {
        let diagnosticRuleIds = [
            "ios-backup",
            "xcode-archives",
            "docker-data",
            "wechat-data",
            "qq-data",
            "telegram-data",
            "virtual-machines",
            "old-dmg-files",
            "stale-downloads",
            "large-user-files",
        ]

        for ruleId in diagnosticRuleIds {
            let rule = RuleRegistry.all.first { $0.id == ruleId }
            XCTAssertNotNil(rule, "Missing rule: \(ruleId)")
            XCTAssertEqual(rule?.category, .diagnostic)
            XCTAssertEqual(rule?.deleteStrategy, .manualOnly)
            XCTAssertFalse(rule?.defaultSelected ?? true)
            XCTAssertTrue(rule?.paths.isEmpty ?? false, "\(ruleId) should be handled by SpaceDiagnosticScanner")
        }
    }

    func testDiagnosticItemsBuildSeparateTier() {
        let cache = CleanItem(
            path: "/Users/test/Library/Caches/example.cache",
            name: "example.cache",
            size: 1024,
            category: .cache,
            ruleId: "user-cache"
        )
        let diagnostic = CleanItem(
            path: "/Users/test/Library/Application Support/MobileSync/Backup/abc",
            name: "iOS 设备备份：abc",
            size: 1024,
            category: .diagnostic,
            ruleId: "ios-backup"
        )
        let summary = ScanSummary(
            results: [
                ScanResult(category: .cache, items: [cache], ruleId: "user-cache"),
                ScanResult(category: .diagnostic, items: [diagnostic]),
            ],
            scanDuration: 0
        )

        let groups = summary.buildTierGroups()

        XCTAssertTrue(groups.contains { $0.id == RiskLevel.safe.rawValue })
        XCTAssertTrue(groups.contains { $0.id == "diagnostic" })
        XCTAssertEqual(groups.first { $0.id == "diagnostic" }?.rules.first?.ruleId, "ios-backup")
    }
}
