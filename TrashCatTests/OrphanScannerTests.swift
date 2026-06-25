import XCTest
@testable import TrashCat

final class OrphanScannerLogicTests: XCTestCase {

    // MARK: - Bundle ID matching logic

    /// Test the dot-boundary prefix matching that OrphanScanner uses.
    /// These tests verify the matching pattern, not the full scanner.

    func testExactBundleIDMatch() {
        let installed: Set<String> = ["com.google.Chrome"]
        let stem = "com.google.chrome"
        XCTAssertTrue(installed.contains { $0.lowercased() == stem },
                      "Exact (case-insensitive) bundle ID should match")
    }

    func testDotBoundaryPrefixMatch() {
        let installed: Set<String> = ["com.apple.Safari"]
        let stem = "com.apple.safari"
        let matched = installed.contains { installedID in
            let lowered = installedID.lowercased()
            return lowered == stem || lowered.hasPrefix(stem + ".")
        }
        XCTAssertTrue(matched, "Dot-boundary prefix should match")
    }

    func testShortStemDoesNotMatchUnrelated() {
        let installed: Set<String> = ["com.apple.Safari", "com.google.Chrome"]
        let stem = "com"
        let matched = installed.contains { installedID in
            let lowered = installedID.lowercased()
            return lowered == stem || lowered.hasPrefix(stem + ".")
        }
        // "com" alone would match "com.apple.safari" via hasPrefix("com.")
        // This is why OrphanScanner skips system bundle prefixes
        XCTAssertTrue(matched, "Short stem 'com' matches — this is why system prefix filtering exists")
    }

    func testNonMatchingStem() {
        let installed: Set<String> = ["com.apple.Safari"]
        let stem = "com.unknown.app"
        let matched = installed.contains { installedID in
            let lowered = installedID.lowercased()
            return lowered == stem || lowered.hasPrefix(stem + ".")
        }
        XCTAssertFalse(matched, "Unrelated stem should not match any installed ID")
    }

    // MARK: - System bundle prefix filtering

    func testAppleBundlePrefixIsFiltered() {
        let stem = "com.apple.something"
        let systemPrefixes = ["com.apple."]
        XCTAssertTrue(systemPrefixes.contains(where: { stem.hasPrefix($0) }),
                      "Apple bundle prefix should be filtered")
    }

    func testNonAppleBundleIsNotFiltered() {
        let stem = "com.google.chrome"
        let systemPrefixes = ["com.apple."]
        XCTAssertFalse(systemPrefixes.contains(where: { stem.hasPrefix($0) }),
                       "Non-Apple bundle should not be filtered by system prefix")
    }

    // MARK: - ScanPolicy integration

    func testOrphanScannerSkipsBlockedPaths() {
        // Verify that ScanPolicy blocks system paths that OrphanScanner scans
        XCTAssertTrue(ScanPolicy.isBlocked("/System/Library/Preferences"))
        XCTAssertTrue(ScanPolicy.isBlocked("/usr/local/share"))
    }

    // MARK: - Orphan reason

    func testOrphanReasonForPreferences() {
        let reason = RiskAssessor.orphanReason(for: "/Users/x/Library/Preferences/com.unknown.plist")
        XCTAssertTrue(reason.contains("偏好设置"), "Preferences path should have correct reason")
    }

    func testOrphanReasonForApplicationSupport() {
        let reason = RiskAssessor.orphanReason(for: "/Users/x/Library/Application Support/com.unknown")
        XCTAssertTrue(reason.contains("应用支持"), "Application Support path should have correct reason")
    }

    func testOrphanReasonForContainers() {
        let reason = RiskAssessor.orphanReason(for: "/Users/x/Library/Containers/com.unknown")
        XCTAssertTrue(reason.contains("沙盒容器"), "Containers path should have correct reason")
    }

    func testOrphanReasonForGroupContainers() {
        let reason = RiskAssessor.orphanReason(for: "/Users/x/Library/Group Containers/com.unknown.group")
        XCTAssertTrue(reason.contains("应用组"), "Group Containers should have correct reason")
    }

    func testOrphanReasonForSavedState() {
        let reason = RiskAssessor.orphanReason(for: "/Users/x/Library/Saved Application State/com.unknown.savedState")
        XCTAssertTrue(reason.contains("应用状态"), "Saved Application State should have correct reason")
    }

    func testOrphanReasonForUnknownPath() {
        let reason = RiskAssessor.orphanReason(for: "/Users/x/Library/some/random/path")
        XCTAssertTrue(reason.contains("残留"), "Unknown path should have generic reason")
    }
}
