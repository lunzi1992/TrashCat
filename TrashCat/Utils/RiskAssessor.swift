import Foundation
import AppKit

/// Determines deletion risk level based on path, category, and content.
enum RiskAssessor {

    // MARK: - Running App Detection

    /// Check whether a file path is likely associated with a currently running app.
    /// Used to avoid cleaning caches that an active app may be writing to.
    static func isRunningAppPath(_ path: String, runningBundleIDs: Set<String>? = nil) -> Bool {
        let running = runningBundleIDs ?? Self.runningBundleIDs
        let pathLower = path.lowercased()

        return running.contains { bundleID in
            let lowered = bundleID.lowercased()
            let hints = [lowered] + (runningPathHints[bundleID] ?? []).map { $0.lowercased() }

            return hints.contains { hint in
                guard let range = pathLower.range(of: hint) else { return false }
                let beforeOK = range.lowerBound == pathLower.startIndex
                    || pathLower[pathLower.index(before: range.lowerBound)] == "/"
                let afterOK = range.upperBound == pathLower.endIndex
                    || pathLower[range.upperBound] == "/"
                    || pathLower[range.upperBound] == "."
                return beforeOK && afterOK
            }
        }
    }

    /// Bundle IDs of currently running GUI applications (cached per assessment cycle).
    private static var runningBundleIDs: Set<String> {
        // Re-compute on each scan cycle — NSWorkspace state may change
        let apps = NSWorkspace.shared.runningApplications
        return Set(apps.compactMap { $0.bundleIdentifier })
    }

    private static let runningPathHints: [String: [String]] = [
        "company.thebrowser.Browser": [
            "Application Support/Arc",
            "Caches/company.thebrowser.Browser",
        ],
        "com.google.Chrome": [
            "Application Support/Google/Chrome",
            "Caches/Google/Chrome",
            "Caches/com.google.Chrome",
        ],
        "com.microsoft.edgemac": [
            "Application Support/Microsoft Edge",
            "Caches/Microsoft Edge",
            "Caches/com.microsoft.edgemac",
        ],
        "com.brave.Browser": [
            "Application Support/BraveSoftware/Brave-Browser",
            "Caches/BraveSoftware",
            "Caches/com.brave.Browser",
        ],
        "org.mozilla.firefox": [
            "Application Support/Firefox",
            "Caches/Firefox",
            "Caches/org.mozilla.firefox",
        ],
        "com.apple.Safari": [
            "Library/Safari",
            "Library/WebKit/com.apple.Safari",
            "Caches/com.apple.Safari",
        ],
    ]

    // MARK: - High-risk paths (always danger)

    private static let dangerPaths: [String] = [
        "MobileSync/Backup",        // iOS backups — user data
        "Xcode/Archives",           // App archives — may be needed for symbolication
    ]

    // MARK: - Medium-risk paths (caution by default)

    /// Absolute paths that must appear at the **start** of the scanned path.
    /// e.g. "/Library/Caches" matches "/Library/Caches/…" but NOT "~/Library/Caches/…"
    private static let cautionPathPrefixes: [String] = [
        "/Library/Caches",           // System-level cache — need admin, some system services use
        "/Library/Updates",          // macOS update downloads — may be needed
        "/private/var/folders",      // System per-user temp — mostly safe but some apps may rely on
    ]

    /// Relative path snippets that trigger caution anywhere in the path.
    private static let cautionPathSubstrings: [String] = [
        "Xcode/DerivedData",         // Xcode build cache — safe to delete but slows next build
        "Xcode/iOS DeviceSupport",   // Device symbols — Xcode re-downloads but takes time
        "CoreSimulator/Devices",     // Simulator images — slow to recreate
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

    static func assess(
        path: String,
        category: CleanCategory,
        name: String,
        runningBundleIDs: Set<String>? = nil
    ) -> RiskLevel {
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
            if Self.isRunningAppPath(path, runningBundleIDs: runningBundleIDs) {
                return .caution
            }
            for sp in safePaths {
                if path.contains(sp) {
                    return .safe
                }
            }
            return .caution
        }

        // Cache / temp category: check caution paths first, then safe paths.
        // Order matters: a path like /Library/Caches/… contains both
        // "/Library/Caches" (caution) and "/Caches/" (safe); the more
        // conservative judgement must win.
        //
        // Prefix-matched paths (absolute system paths) are checked separately
        // from substring paths so that "/Library/Caches" only matches the
        // system-level directory, not "~/Library/Caches".
        if category == .cache || category == .temp {
            for cp in cautionPathPrefixes {
                if path.hasPrefix(cp) { return .caution }
            }
            for cp in cautionPathSubstrings {
                if path.contains(cp) { return .caution }
            }
            for sp in safePaths {
                if path.contains(sp) { return .safe }
            }

            // Running app check: if this cache belongs to a running app,
            // downgrade from safe to caution to avoid potential data loss.
            if Self.isRunningAppPath(path, runningBundleIDs: runningBundleIDs) {
                return .caution
            }

            return .safe  // default cache = safe
        }

        // Logs are safe
        if category == .logs { return .safe }

        // Temp is safe
        if category == .temp { return .safe }

        // Running app check for browser cache
        if category == .browserCache && Self.isRunningAppPath(path, runningBundleIDs: runningBundleIDs) {
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
