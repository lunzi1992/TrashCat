import XCTest
@testable import TrashCat

final class ScanPolicyAdvancedTests: XCTestCase {

    // MARK: - Edge cases for isBlocked

    func testRootSystemBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/System"))
    }

    func testHomeLibraryNotBlocked() {
        XCTAssertFalse(ScanPolicy.isBlocked("/Users/test/Library/Caches"))
    }

    func testTmpNotBlocked() {
        XCTAssertFalse(ScanPolicy.isBlocked("/tmp/test"))
    }

    func testUserKeychainsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/Users/test/Library/Keychains"))
    }

    func testEmptyPathNotBlocked() {
        XCTAssertFalse(ScanPolicy.isBlocked(""))
    }

    // MARK: - Temp file age

    func testTempMinAgeDaysIs7() {
        XCTAssertEqual(ScanPolicy.tempMinAgeDays, 7,
                       "Temp files should require 7 days minimum age per scan-policy.md")
    }

    // MARK: - Blocklist completeness (per scan-policy.md §3)

    func testAllCriticalPathsBlocked() {
        let criticalPaths = [
            "/System",
            "/bin",
            "/sbin",
            "/usr",
            "/private/var/db",
        ]
        for path in criticalPaths {
            XCTAssertTrue(ScanPolicy.isBlocked(path),
                          "Path '\(path)' must be blocked per scan-policy.md §3")
        }
    }

    func testKeychainsBlocked() {
        XCTAssertTrue(ScanPolicy.isBlocked("/Library/Keychains"))
        XCTAssertTrue(ScanPolicy.isBlocked("/Users/x/Library/Keychains"))
    }
}

// MARK: - RiskAssessor additional tests

final class RiskAssessorAdvancedTests: XCTestCase {

    // MARK: - Safe cache paths

    func testCachesPathIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/x/Library/Caches/com.someapp/cache.bin",
            category: .cache, name: "cache.bin"
        )
        XCTAssertEqual(result, .safe)
    }

    func testTmpPathIsSafe() {
        let result = RiskAssessor.assess(
            path: "/tmp/old-file.tmp",
            category: .temp, name: "old-file.tmp"
        )
        XCTAssertEqual(result, .safe)
    }

    func testLogPathIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/x/Library/Logs/app.log",
            category: .logs, name: "app.log"
        )
        XCTAssertEqual(result, .safe)
    }

    // MARK: - Browser cache

    func testBrowserCacheSubdirIsSafe() {
        let result = RiskAssessor.assess(
            path: "/Users/x/Library/Caches/Google/Chrome/Default/Cache/f_000001",
            category: .browserCache, name: "f_000001"
        )
        XCTAssertEqual(result, .safe)
    }

    func testBrowserCacheNonCacheSubdirIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/x/Library/Application Support/Google/Chrome/Default/Login Data",
            category: .browserCache, name: "Login Data"
        )
        XCTAssertEqual(result, .caution)
    }

    // MARK: - Caution paths

    func testXcodeDerivedDataIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/x/Library/Developer/Xcode/DerivedData/MyApp-abc123",
            category: .cache, name: "MyApp-abc123"
        )
        XCTAssertEqual(result, .caution)
    }

    func testCoreSimulatorIsCaution() {
        let result = RiskAssessor.assess(
            path: "/Users/x/Library/Developer/CoreSimulator/Devices/abc-123",
            category: .cache, name: "abc-123"
        )
        XCTAssertEqual(result, .caution)
    }

    // MARK: - Default selected

    func testSafeIsDefaultSelected() {
        XCTAssertTrue(RiskLevel.safe.defaultSelected)
    }

    func testCautionIsNotDefaultSelected() {
        XCTAssertFalse(RiskLevel.caution.defaultSelected)
    }

    func testDangerIsNotDefaultSelected() {
        XCTAssertFalse(RiskLevel.danger.defaultSelected)
    }

    // MARK: - Display names

    func testDisplayNames() {
        XCTAssertEqual(RiskLevel.safe.displayName, "推荐清理")
        XCTAssertEqual(RiskLevel.caution.displayName, "需要确认")
        XCTAssertEqual(RiskLevel.danger.displayName, "谨慎处理")
    }

    // MARK: - Explanations exist

    func testAllRiskLevelsHaveExplanations() {
        for level in RiskLevel.allCases {
            XCTAssertFalse(level.explanation.isEmpty,
                           "RiskLevel \(level) should have non-empty explanation")
        }
    }

    // MARK: - Icons exist

    func testAllRiskLevelsHaveIcons() {
        for level in RiskLevel.allCases {
            XCTAssertFalse(level.iconName.isEmpty,
                           "RiskLevel \(level) should have non-empty iconName")
        }
    }
}
