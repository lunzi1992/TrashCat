import Foundation

/// Derives human-readable app names and file types from file paths.
enum FileCategorizer {

    // MARK: - App Name

    /// Map bundle-identifier-like path components to friendly app names
    private static let bundleNameMap: [String: String] = [
        "com.google.Chrome": "Chrome",
        "com.google.chrome": "Chrome",
        "Google": "Chrome",
        "com.microsoft.edgemac": "Edge",
        "Microsoft Edge": "Edge",
        "com.brave.Browser": "Brave",
        "BraveSoftware": "Brave",
        "company.thebrowser.Browser": "Arc",
        "Arc": "Arc",
        "com.vivaldi.Vivaldi": "Vivaldi",
        "Vivaldi": "Vivaldi",
        "com.operasoftware.Opera": "Opera",
        "org.mozilla.firefox": "Firefox",
        "Firefox": "Firefox",
        "com.apple.Safari": "Safari",
        "com.apple.WebKit": "Safari (WebKit)",
        "com.apple.QuickLook": "QuickLook",
        "com.apple.dt.Xcode": "Xcode",
        "com.apple.dt": "Xcode",
        "MobileSync": "iOS 备份",
        "com.spotify.client": "Spotify",
        "com.tencent.xinWeChat": "微信",
        "com.tencent.meeting": "腾讯会议",
        "com.tencent.QQMusicMac": "QQ音乐",
        "com.tencent.imamac": "ima",
        "com.netease.163music": "网易云音乐",
        "com.kingsoft.wpsoffice.mac": "WPS",
        "com.openai.chat": "ChatGPT",
        "com.openai.codex": "Codex",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "com.exafunction.windsurf": "Windsurf",
        "md.obsidian": "Obsidian",
        "notion.id": "Notion",
        "com.electron.lark": "飞书",
        "com.apple.mail": "邮件",
        "com.apple.Music": "音乐",
        "com.apple.TV": "Apple TV",
        "com.apple.Photos": "照片",
        "com.apple.iChat": "信息",
        "com.parallels.desktop": "Parallels",
        "com.docker.docker": "Docker",
        "Docker": "Docker",
        "com.apple.CoreSimulator": "iOS 模拟器",
        "CoreSimulator": "iOS 模拟器",
        "DeveloperDiskImages": "Xcode",
        "DerivedData": "Xcode",
        "XCPGDevices": "Xcode",
        "XCTestDevices": "Xcode",
        "DVTDownloads": "Xcode",
    ]

    /// Guess which app owns a file, based on its path.
    static func appName(for path: String, category: CleanCategory) -> String {
        let components = path.components(separatedBy: "/")

        // Check known bundle names in reverse (deepest first)
        for component in components.reversed() {
            let cleaned = component.replacingOccurrences(of: ".noindex", with: "")
            if let name = bundleNameMap[component] ?? bundleNameMap[cleaned] {
                return name
            }
            if let name = bundleNameMap[component.replacingOccurrences(of: ".noindex", with: "")] {
                return name
            }
        }

        // Try to extract app name from bundle-id-style paths
        for component in components where component.contains(".") {
            let parts = component.components(separatedBy: ".")
            if parts.count >= 3 {
                // e.g., com.google.Chrome → "Chrome"
                let last = parts.last!
                if last.count > 1 && !last.allSatisfy({ $0 == "-" || $0.isNumber }) {
                    return last.capitalized
                }
            }
        }

        // Fallback to category-level grouping
        switch category {
        case .cache:        return "系统缓存"
        case .temp:         return "系统临时文件"
        case .logs:         return "系统日志"
        case .trash:        return "废纸篓"
        case .browserCache: return "浏览器"
        case .orphan:       return "已卸载应用"
        case .diagnostic:   return "空间诊断"
        }
    }

    // MARK: - File Type

    static func fileType(for path: String, name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()

        switch ext {
        case "log":       return "日志"
        case "plist":     return "配置文件"
        case "db", "sqlite", "sqlite3", "sqlitedb":
                          return "数据库"
        case "cache":     return "缓存"
        case "tmp", "temp": return "临时文件"
        case "dat", "data": return "数据文件"
        case "json":      return "JSON"
        case "xml":       return "XML"
        case "png", "jpg", "jpeg", "gif", "webp", "heic":
                          return "图片缓存"
        case "js", "css", "html": return "Web 缓存"
        case "dylib", "framework": return "库文件"
        case "":          return noExtensionType(name: name)
        default:          return ext.uppercased() + " 文件"
        }
    }

    private static func noExtensionType(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("cache") || lower.contains("caches") { return "缓存" }
        if lower.contains("log") { return "日志" }
        if lower.contains("tmp") || lower.contains("temp") { return "临时文件" }
        if lower.contains("cookie") { return "Cookie" }
        if lower.contains("bookmark") { return "书签" }
        if lower.contains("history") { return "历史记录" }
        if lower.contains("index") { return "索引" }
        if lower.contains("session") { return "会话数据" }
        if lower.contains("pref") { return "偏好设置" }
        return "数据"
    }
}
