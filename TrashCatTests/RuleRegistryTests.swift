import XCTest
@testable import TrashCat

final class RuleRegistryTests: XCTestCase {

    // MARK: - Registry integrity

    func testAllRulesHaveUniqueIds() {
        let ids = RuleRegistry.all.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "Rule IDs must be unique")
    }

    func testByIdMatchesAll() {
        for rule in RuleRegistry.all {
            XCTAssertEqual(RuleRegistry.byId[rule.id], rule, "byId lookup must match")
        }
    }

    func testAllRulesHaveNonEmptyTitle() {
        for rule in RuleRegistry.all {
            XCTAssertFalse(rule.title.isEmpty, "Rule '\(rule.id)' has empty title")
        }
    }

    func testAllRulesHaveNonEmptyDescription() {
        for rule in RuleRegistry.all {
            XCTAssertFalse(rule.description.isEmpty, "Rule '\(rule.id)' has empty description")
        }
    }

    func testAllRulesHaveImpactSummary() {
        for rule in RuleRegistry.all {
            XCTAssertFalse(rule.impactSummary.isEmpty, "Rule '\(rule.id)' has empty impactSummary")
        }
    }

    // MARK: - Risk consistency

    func testSafeRulesAreDefaultSelected() {
        for rule in RuleRegistry.all {
            if rule.riskLevel == .safe {
                XCTAssertTrue(rule.defaultSelected, "Safe rule '\(rule.id)' should be defaultSelected")
            }
        }
    }

    func testDangerRulesAreNotDefaultSelected() {
        for rule in RuleRegistry.all {
            if rule.riskLevel == .danger {
                XCTAssertFalse(rule.defaultSelected, "Danger rule '\(rule.id)' should NOT be defaultSelected")
            }
        }
    }

    func testCautionRulesAreNotDefaultSelected() {
        for rule in RuleRegistry.all {
            if rule.riskLevel == .caution {
                XCTAssertFalse(rule.defaultSelected, "Caution rule '\(rule.id)' should NOT be defaultSelected")
            }
        }
    }

    // MARK: - Manual-only rules

    func testManualOnlyRulesAreDanger() {
        for rule in RuleRegistry.all {
            if rule.deleteStrategy == .manualOnly {
                XCTAssertEqual(rule.riskLevel, .danger,
                               "Manual-only rule '\(rule.id)' must be danger level")
            }
        }
    }

    // MARK: - Path resolution

    func testResolveHomePath() {
        let resolved = RuleRegistry.resolve(path: "~/Library/Caches")
        XCTAssertTrue(resolved.contains("/Library/Caches"), "Home path should expand ~")
        XCTAssertFalse(resolved.contains("~"), "No ~ should remain after resolve")
    }

    func testResolveAbsolutePath() {
        let resolved = RuleRegistry.resolve(path: "/tmp/test")
        XCTAssertEqual(resolved, "/tmp/test", "Absolute paths pass through")
    }

    // MARK: - Critical rules exist

    func testUserCacheRuleExists() {
        XCTAssertNotNil(RuleRegistry.byId["user-cache"], "user-cache rule must exist")
    }

    func testIOSBackupRuleExists() {
        XCTAssertNotNil(RuleRegistry.byId["ios-backup"], "ios-backup rule must exist")
    }

    func testOrphanRuleExists() {
        XCTAssertNotNil(RuleRegistry.byId["orphan-files"], "orphan-files rule must exist")
    }

    func testTrashRuleExists() {
        XCTAssertNotNil(RuleRegistry.byId["trash"], "trash rule must exist")
    }

    // MARK: - iOS backup is danger + manualOnly

    func testIOSBackupIsDangerAndManualOnly() {
        let rule = RuleRegistry.byId["ios-backup"]
        XCTAssertEqual(rule?.riskLevel, .danger)
        XCTAssertEqual(rule?.deleteStrategy, .manualOnly)
    }

    func testXcodeArchivesIsDangerAndManualOnly() {
        let rule = RuleRegistry.byId["xcode-archives"]
        XCTAssertEqual(rule?.riskLevel, .danger)
        XCTAssertEqual(rule?.deleteStrategy, .manualOnly)
    }
}
