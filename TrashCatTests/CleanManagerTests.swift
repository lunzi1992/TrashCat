import XCTest
@testable import TrashCat

final class CleanManagerTests: XCTestCase {

    // MARK: - Clean result structure

    func testCleanResultWithNoItems() async {
        let manager = CleanManager()
        let result = await manager.clean(items: [])
        XCTAssertEqual(result.freedSize, 0)
        XCTAssertEqual(result.freedFileCount, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.isSuccess)
    }

    func testCleanResultCategoryBreakdownEmpty() {
        let result = CleanResult(freedSize: 0, freedFileCount: 0, duration: 0, errors: [])
        XCTAssertTrue(result.categoryBreakdown.isEmpty)
    }

    // MARK: - isCleanable guard

    func testDiagnosticItemsAreSkipped() async {
        let manager = CleanManager()
        let item = CleanItem(
            path: "/nonexistent/path",
            name: "diag",
            size: 100,
            category: .diagnostic
        )
        let result = await manager.clean(items: [item])
        XCTAssertEqual(result.freedFileCount, 0, "Diagnostic items should be skipped")
        XCTAssertEqual(result.freedSize, 0)
        XCTAssertFalse(result.errors.isEmpty, "Should have error for skipped item")
    }

    func testManualOnlyRuleItemsAreSkipped() async {
        let manager = CleanManager()
        let item = CleanItem(
            path: "/nonexistent/backup",
            name: "backup",
            size: 1000,
            category: .cache,
            ruleId: "ios-backup"  // manualOnly rule
        )
        let result = await manager.clean(items: [item])
        XCTAssertEqual(result.freedFileCount, 0, "Manual-only items should be skipped")
    }

    // MARK: - Nonexistent files

    func testNonexistentFileProducesError() async {
        let manager = CleanManager()
        let item = CleanItem(
            path: "/definitely/does/not/exist/file.txt",
            name: "file.txt",
            size: 100,
            category: .cache
        )
        let result = await manager.clean(items: [item])
        XCTAssertEqual(result.freedFileCount, 0)
        XCTAssertFalse(result.errors.isEmpty, "Nonexistent file should produce an error")
        XCTAssertFalse(result.isSuccess)
    }

    // MARK: - Result aggregation

    func testMultipleErrorsAllCollected() async {
        let manager = CleanManager()
        let items = [
            CleanItem(path: "/nope/1", name: "1", size: 10, category: .cache),
            CleanItem(path: "/nope/2", name: "2", size: 20, category: .cache),
            CleanItem(path: "/nope/3", name: "3", size: 30, category: .cache),
        ]
        let result = await manager.clean(items: items)
        XCTAssertEqual(result.errors.count, 3, "All errors should be collected")
    }

    // MARK: - Permanent delete (not used in MVP but tested for safety)

    func testPermanentDeleteSkipsDiagnostic() async {
        let manager = CleanManager()
        let item = CleanItem(
            path: "/nonexistent",
            name: "diag",
            size: 100,
            category: .diagnostic
        )
        let result = await manager.permanentDelete(items: [item])
        XCTAssertEqual(result.freedFileCount, 0, "Diagnostic items should be skipped even in permanent delete")
    }
}
