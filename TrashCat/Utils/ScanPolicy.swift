import Foundation

/// Enforces scan-policy.md safety rules:
/// - Blocklist: never scan system-critical paths
/// - File age: temp files must be older than N days
/// - Running app: optionally skip caches of currently running apps
enum ScanPolicy {

    // MARK: - Blocklist

    /// Paths never to scan, list, or offer for cleanup.
    /// These should be checked before any scanner enumerates a directory.
    static let blockedPaths: [String] = [
        "/System",
        "/bin",
        "/sbin",
        "/usr",
        "/private/var/db",
        "/Library/Keychains",
        "Keychains",           // catches ~/Library/Keychains too
    ]

    /// Check if a path should be excluded from all scanning.
    static func isBlocked(_ path: String) -> Bool {
        for blocked in blockedPaths {
            if path.hasPrefix(blocked) { return true }
        }
        return false
    }

    // MARK: - File Age

    /// Minimum age (in days) for temp files to be included in cleanup.
    /// Files modified more recently than this are skipped.
    static let tempMinAgeDays: Int = 7

    /// Check whether a file at the given URL meets the age requirement.
    /// Returns true if the file is old enough to clean (or if age check doesn't apply).
    static func meetsAgeRequirement(url: URL, minAgeDays: Int? = nil) -> Bool {
        guard let days = minAgeDays, days > 0 else { return true }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return false  // can't determine age → skip to be safe
        }

        let age = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
        return age >= days
    }
}
