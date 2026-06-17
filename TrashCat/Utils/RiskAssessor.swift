import Foundation
import AppKit

/// Determines deletion risk level based on path, category, and content.
enum RiskAssessor {

    // MARK: - Running App Detection

    /// Check whether a file path is likely associated with a currently running app.
    /// Used to avoid cleaning caches that an active app may be writing to.
    static func isRunningAppPath(_ path: String) -> Bool {
        let running = Self.runningBundleIDs
        let pathLower = path.lowercased()

        return running.contains { bundleID in
            let lowered = bundleID.lowercased()
            guard pathLower.contains(lowered) else { return false }

            // Ensure a path-segment match, not a substring coincidence.
            // e.g. "com.google.Chrome" matches ".../com.google.Chrome/..."
            // but not ".../somecom.google.Chromething/..."
            if let range = pathLower.range(of: lowered) {
                let beforeOK = range.lowerBound == pathLower.startIndex
                    || pathLower[pathLower.index(before: range.lowerBound)] == "/"
                let afterOK = range.upperBound == pathLower.endIndex
                    || pathLower[range.upperBound] == "/"
                    || pathLower[range.upperBound] == "."
                return beforeOK && afterOK
            }
            return false
        }
    }

    /// Bundle IDs of currently running GUI applications (cached per assessment cycle).
    private static var runningBundleIDs: Set<String> {
        // Re-compute on each scan cycle — NSWorkspace state may change
        let apps = NSWorkspace.shared.runningApplications
        return Set(apps.compactMap { $0.bundleIdentifier })
    }

    // MARK: - High-risk paths (always danger)

    private static let dangerPaths: [String] = [
        "MobileSync/Backup",        // iOS backups — user data
        "Xcode/Archives",           // App archives — may be needed for symbolication
    ]

    // MARK: - Medium-risk paths (caution by default)

    private static let cautionPaths: [String] = [
        "Xcode/DerivedData",         // Xcode build cache — safe to delete but slows next build
        "Xcode/iOS DeviceSupport",   // Device symbols — Xcode re-downloads but takes time
        "CoreSimulator/Devices",     // Simulator images — slow to recreate
        "/private/var/folders",      // System per-user temp — mostly safe but some apps may rely on
        "/Library/Caches",           // System-level cache — need admin, some system services use
        "/Library/Updates",          // macOS update downloads — may be needed
        "workspaceStorage",          // VS Code workspace state — losing unsaved editor state
        "Application Support/Google/Chrome",    // Chrome data — cache is safe but profiles are not
        "Application Support/Microsoft Edge",   // Edge data
        "Application Support/BraveSoftware",    // Brave data
        "Application Support/Arc",              // Arc data
        "Application Support/Firefox",          // Firefox data
        "Application Support/Vivaldi",          // Vivaldi data
        "Application Support/com.operasoftware",// Opera data
    ]

    // MARK: - Known safe cache paths

    private static let safePaths: [String] = [
        "/Caches/",
        "/Cache/",
        "/Code Cache/",
        "/Service Worker/",
        "/cache2/",
        "/tmp/",
        "/private/tmp/",
        "/private/var/tmp/",
        "WebKit/",
        "/logs/",
        "/Logs/",
    ]

    // MARK: - Assessment

    static func assess(path: String, category: CleanCategory, name: String) -> RiskLevel {
        // Trash is always safe to clean — it's already trash
        if category == .trash { return .safe }

        // Orphans are always danger — user needs to verify each one
        if category == .orphan { return .danger }

        // Diagnostics are always danger — user data, not for automatic cleanup
        if category == .diagnostic { return .danger }

        // Check danger paths first
        for dp in dangerPaths {
            if path.contains(dp) { return .danger }
        }

        // Browser cache subdirectories (cache-only) are safe
        if category == .browserCache {
            for sp in safePaths {
                if path.contains(sp) {
                    return .safe
                }
            }
            return .caution
        }

        // Cache category: check if it's in a known safe or caution path
        if category == .cache || category == .temp {
            for sp in safePaths {
                if path.contains(sp) { return .safe }
            }
            for cp in cautionPaths {
                if path.contains(cp) { return .caution }
            }

            // Running app check: if this cache belongs to a running app,
            // downgrade from safe to caution to avoid potential data loss.
            if Self.isRunningAppPath(path) {
                return .caution
            }

            return .safe  // default cache = safe
        }

        // Logs are safe
        if category == .logs { return .safe }

        // Temp is safe
        if category == .temp { return .safe }

        // Running app check for browser cache
        if category == .browserCache && Self.isRunningAppPath(path) {
            return .caution
        }

        return .safe
    }

    // MARK: - Orphan risk reason

    static func orphanReason(for path: String) -> String {
        if path.contains("/Preferences/") {
            return "偏好设置文件，未匹配到已安装应用"
        }
        if path.contains("/Application Support/") {
            return "应用支持数据，未匹配到已安装应用"
        }
        if path.contains("/Containers/") {
            return "沙盒容器数据，未匹配到已安装应用"
        }
        if path.contains("/Group Containers/") {
            return "应用组共享数据，未匹配到已安装应用"
        }
        if path.contains("/Saved Application State/") {
            return "应用状态存档，未匹配到已安装应用"
        }
        return "未匹配到已安装应用的残留文件"
    }
}
