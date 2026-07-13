import XCTest
@testable import TrashCat

final class CleanItemTests: XCTestCase {

    // MARK: - isCleanable

    func testCacheItemIsCleanable() {
        let item = CleanItem(path: "/tmp/test", name: "test", size: 100, category: .cache)
        XCTAssertTrue(item.isCleanable, "Cache items without ruleId should be cleanable")
    }

    func testDiagnosticItemIsNotCleanable() {
        let item = CleanItem(path: "/test", name: "diag", size: 100, category: .diagnostic)
        XCTAssertFalse(item.isCleanable, "Diagnostic items should not be cleanable")
    }

    func testManualOnlyRuleItemIsNotCleanable() {
        let item = CleanItem(path: "/test", name: "backup", size: 100,
                             category: .cache, ruleId: "ios-backup")
        XCTAssertFalse(item.isCleanable, "Items with manualOnly rule should not be cleanable")
    }

    func testTrashItemRuleIsCleanable() {
        let item = CleanItem(path: "/test", name: "trash", size: 100,
                             category: .trash, ruleId: "trash")
        XCTAssertTrue(item.isCleanable, "Trash items should be cleanable")
    }

    // MARK: - Risk level

    func testTrashRiskIsSafe() {
        let item = CleanItem(path: "/Users/x/.Trash/file", name: "file", size: 10, category: .trash)
        XCTAssertEqual(item.riskLevel, .safe)
    }

    func testOrphanRiskIsDanger() {
        let item = CleanItem(path: "/Users/x/Library/Preferences/com.unknown.plist",
                             name: "com.unknown.plist", size: 10, category: .orphan)
        XCTAssertEqual(item.riskLevel, .danger)
    }

    func testIOSBackupPathRiskIsDanger() {
        let item = CleanItem(path: "/Users/x/Library/Application Support/MobileSync/Backup/abc",
                             name: "abc", size: 1000, category: .cache)
        XCTAssertEqual(item.riskLevel, .danger)
    }

    func testXcodeArchivesPathRiskIsDanger() {
        let item = CleanItem(path: "/Users/x/Library/Developer/Xcode/Archives/2026-06-25/App.xcarchive",
                             name: "App.xcarchive", size: 5000, category: .cache)
        XCTAssertEqual(item.riskLevel, .danger)
    }

    // MARK: - defaultSelected

    func testSafeItemIsDefaultSelected() {
        let item = CleanItem(path: "/tmp/old", name: "old", size: 10, category: .temp)
        XCTAssertTrue(item.defaultSelected, "Safe items should be default selected")
    }

    func testDangerItemIsNotDefaultSelected() {
        let item = CleanItem(path: "/Users/x/.Trash/whatever", name: "x", size: 10, category: .orphan)
        XCTAssertFalse(item.defaultSelected, "Danger items should not be default selected")
    }

    func testRuleRiskCannotBeDowngradedByPathAssessment() {
        let item = CleanItem(
            path: "/Users/x/.gradle/caches/modules/files.bin",
            name: "files.bin",
            size: 10,
            category: .cache,
            ruleId: "gradle-cache"
        )
        XCTAssertEqual(item.riskLevel, .caution)
        XCTAssertFalse(item.defaultSelected)
    }

    func testScanSummaryDeduplicatesResolvedPaths() {
        let first = CleanItem(path: "/tmp/example", name: "example", size: 10, category: .temp)
        let second = CleanItem(path: "/private/tmp/example", name: "example", size: 10, category: .temp)
        let summary = ScanSummary(
            results: [
                ScanResult(category: .temp, items: [first]),
                ScanResult(category: .temp, items: [second]),
            ],
            scanDuration: 0
        )
        XCTAssertEqual(summary.totalFileCount, 1)
        XCTAssertEqual(summary.totalSize, 10)
    }

    // MARK: - RiskLevel ordering

    func testRiskLevelOrdering() {
        XCTAssertLessThan(RiskLevel.safe, .caution)
        XCTAssertLessThan(RiskLevel.caution, .danger)
        XCTAssertLessThan(RiskLevel.safe, .danger)
    }

    func testRiskLevelComparableConsistency() {
        // All cases should be comparable without crashing
        let levels = RiskLevel.allCases
        for a in levels {
            for b in levels {
                _ = a < b
                _ = a == b
            }
        }
    }

    // MARK: - CleanRule equality

    func testCleanRuleEqualityById() {
        let rule1 = RuleRegistry.all.first!
        let rule2 = RuleRegistry.all.first!
        XCTAssertEqual(rule1, rule2, "Same rule instances with same ID should be equal")
    }

    func testCleanRuleInequalityById() {
        let rules = RuleRegistry.all
        guard rules.count >= 2 else { return }
        XCTAssertNotEqual(rules[0], rules[1], "Different rule IDs should not be equal")
    }

    // MARK: - ScanResult

    func testScanResultTotalSize() {
        let items = [
            CleanItem(path: "/a", name: "a", size: 100, category: .cache),
            CleanItem(path: "/b", name: "b", size: 200, category: .cache),
            CleanItem(path: "/c", name: "c", size: 300, category: .cache),
        ]
        let result = ScanResult(category: .cache, items: items)
        XCTAssertEqual(result.totalSize, 600)
        XCTAssertEqual(result.fileCount, 3)
    }

    func testEmptyScanResult() {
        let result = ScanResult(category: .logs, items: [])
        XCTAssertEqual(result.totalSize, 0)
        XCTAssertEqual(result.fileCount, 0)
    }

    // MARK: - ScanSummary

    func testScanSummaryAggregation() {
        let r1 = ScanResult(category: .cache, items: [
            CleanItem(path: "/a", name: "a", size: 100, category: .cache)
        ])
        let r2 = ScanResult(category: .logs, items: [
            CleanItem(path: "/b", name: "b", size: 200, category: .logs),
            CleanItem(path: "/c", name: "c", size: 300, category: .logs),
        ])
        let summary = ScanSummary(results: [r1, r2], scanDuration: 1.5)
        XCTAssertEqual(summary.totalSize, 600)
        XCTAssertEqual(summary.totalFileCount, 3)
        XCTAssertFalse(summary.isEmpty)
    }

    func testEmptyScanSummary() {
        let summary = ScanSummary(results: [
            ScanResult(category: .cache, items: []),
            ScanResult(category: .logs, items: []),
        ], scanDuration: 0.5)
        XCTAssertTrue(summary.isEmpty)
    }

    // MARK: - CleanResult

    func testCleanResultSuccess() {
        let result = CleanResult(freedSize: 1000, freedFileCount: 5, duration: 1.0, errors: [])
        XCTAssertTrue(result.isSuccess)
    }

    func testCleanResultFailure() {
        let result = CleanResult(freedSize: 500, freedFileCount: 3, duration: 1.0,
                                 errors: ["some error"])
        XCTAssertFalse(result.isSuccess)
    }

    func testCleanResultWithBreakdown() {
        let result = CleanResult(
            freedSize: 1000, freedFileCount: 5, duration: 1.0, errors: [],
            categoryBreakdown: [(.cache, 700, 3), (.logs, 300, 2)]
        )
        XCTAssertEqual(result.categoryBreakdown.count, 2)
        XCTAssertEqual(result.categoryBreakdown[0].1, 700)
    }

    // MARK: - Tier group building

    func testTierGroupsSeparateTrash() {
        let trashItem = CleanItem(path: "/Users/x/.Trash/old", name: "old", size: 50, category: .trash)
        let cacheItem = CleanItem(path: "/Users/x/Library/Caches/test", name: "test", size: 100, category: .cache)

        let summary = ScanSummary(results: [
            ScanResult(category: .trash, items: [trashItem]),
            ScanResult(category: .cache, items: [cacheItem]),
        ], scanDuration: 0.1)

        let tiers = summary.buildTierGroups()
        XCTAssertGreaterThan(tiers.count, 0, "Should produce at least one tier")

        // Trash should be in its own tier
        let trashTier = tiers.first { $0.id == "trash" }
        XCTAssertNotNil(trashTier, "Trash should have its own tier")
    }

    func testTierGroupsRespectRiskOrder() {
        let safeItem = CleanItem(path: "/tmp/old", name: "old", size: 10, category: .temp)
        let dangerItem = CleanItem(path: "/Users/x/Library/Application Support/MobileSync/Backup/x",
                                   name: "x", size: 1000, category: .cache)

        let summary = ScanSummary(results: [
            ScanResult(category: .temp, items: [safeItem]),
            ScanResult(category: .cache, items: [dangerItem]),
        ], scanDuration: 0.1)

        let tiers = summary.buildTierGroups()
        // Safe tier should come before danger tier
        if tiers.count >= 2 {
            XCTAssertLessThan(tiers[0].riskLevel, tiers[1].riskLevel,
                              "Tiers should be ordered safe → caution → danger")
        }
    }
}
