import Foundation

// MARK: - Browser Definition

private struct BrowserDef {
    let name: String
    let applicationSupportPath: String   // relative to ~/Library/Application Support/
    let cacheSubpaths: [String]          // relative to the appSupportPath
}

// MARK: - Browser Registry

private let knownBrowsers: [String: BrowserDef] = [
    // Chromium-based
    "com.google.Chrome": BrowserDef(
        name: "Chrome",
        applicationSupportPath: "Google/Chrome",
        cacheSubpaths: defaultChromiumCachePaths()),
    "com.microsoft.edgemac": BrowserDef(
        name: "Edge",
        applicationSupportPath: "Microsoft Edge",
        cacheSubpaths: defaultChromiumCachePaths()),
    "com.brave.Browser": BrowserDef(
        name: "Brave",
        applicationSupportPath: "BraveSoftware/Brave-Browser",
        cacheSubpaths: defaultChromiumCachePaths()),
    "com.vivaldi.Vivaldi": BrowserDef(
        name: "Vivaldi",
        applicationSupportPath: "Vivaldi",
        cacheSubpaths: defaultChromiumCachePaths()),
    "com.operasoftware.Opera": BrowserDef(
        name: "Opera",
        applicationSupportPath: "com.operasoftware.Opera",
        cacheSubpaths: ["Cache"]),  // Opera uses flat structure
    "company.thebrowser.Browser": BrowserDef(
        name: "Arc",
        applicationSupportPath: "Arc",
        cacheSubpaths: arcCachePaths()),

    // Firefox (Gecko)
    "org.mozilla.firefox": BrowserDef(
        name: "Firefox",
        applicationSupportPath: "Firefox",
        cacheSubpaths: []),  // handled separately via Profiles/

    // Safari (WebKit) — cache already covered by CacheScanner, but check WebKit dirs
    "com.apple.Safari": BrowserDef(
        name: "Safari",
        applicationSupportPath: "",  // Safari uses Caches/ and WebKit/, not AppSupport
        cacheSubpaths: []),
]

// MARK: - Cache Path Helpers

private func defaultChromiumCachePaths() -> [String] {
    var paths: [String] = []
    // Default profile
    paths.append("Default/Cache")
    paths.append("Default/Code Cache")
    paths.append("Default/Service Worker/CacheStorage")
    paths.append("Default/Service Worker/ScriptCache")
    // Additional profiles
    for i in 1...5 {
        paths.append("Profile \(i)/Cache")
        paths.append("Profile \(i)/Code Cache")
        paths.append("Profile \(i)/Service Worker/CacheStorage")
    }
    return paths
}

private func arcCachePaths() -> [String] {
    var paths = defaultChromiumCachePaths()
    // Arc-specific caches
    paths.append("ArchiveItemsFaviconCache")
    paths.append("ArchiveSnapshotCache")
    paths.append("BoostsImageCache")
    paths.append("SidebarItemsFaviconCache")
    return paths
}

// MARK: - BrowserCacheScanner

final class BrowserCacheScanner: Scannable {
    let category: CleanCategory = .browserCache
    let progressLabel = "翻浏览器的老鼠窝..."

    private let fileManager = FileManager.default
    private let maxItems = 10000

    func scan() async throws -> ScanResult {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let installedBrowsers = await discoverInstalledBrowsers()
        var items: [CleanItem] = []

        for (bundleId, def) in installedBrowsers {
            let appSupportBase = "\(home)/Library/Application Support/\(def.applicationSupportPath)"

            for subpath in def.cacheSubpaths {
                let fullPath = "\(appSupportBase)/\(subpath)"
                guard fileManager.fileExists(atPath: fullPath) else { continue }

                let scannedItems = await scanRecursive(at: fullPath, browser: def.name)
                items.append(contentsOf: scannedItems)
                if items.count >= maxItems { break }
            }

            // Firefox: scan Profiles/*/cache2
            if bundleId == "org.mozilla.firefox" {
                let profilesDir = "\(appSupportBase)/Profiles"
                if let profiles = try? fileManager.contentsOfDirectory(atPath: profilesDir) {
                    for profile in profiles where profile.contains(".default") {
                        let cachePath = "\(profilesDir)/\(profile)/cache2"
                        if fileManager.fileExists(atPath: cachePath) {
                            let scanned = await scanRecursive(at: cachePath, browser: "Firefox")
                            items.append(contentsOf: scanned)
                        }
                    }
                }
            }

            if items.count >= maxItems { break }
        }

        // Safari WebKit cache (not in Application Support, not in regular Caches)
        let safariWebKit = "\(home)/Library/WebKit/com.apple.Safari"
        if fileManager.fileExists(atPath: safariWebKit) {
            let scanned = await scanRecursive(at: safariWebKit, browser: "Safari")
            items.append(contentsOf: scanned)
        }

        return ScanResult(category: .browserCache, items: items, ruleId: "browser-cache")
    }

    // MARK: - Browser Discovery

    private func discoverInstalledBrowsers() async -> [(bundleId: String, def: BrowserDef)] {
        var results: [(String, BrowserDef)] = []
        let appDirs = ["/Applications", "\(fileManager.homeDirectoryForCurrentUser.path)/Applications"]

        for appDir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: appDir),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleId = bundle.bundleIdentifier else { continue }

                if let def = knownBrowsers[bundleId] {
                    results.append((bundleId, def))
                }
            }
        }

        return results
    }

    // MARK: - Recursive Scan

    private func scanRecursive(at path: String, browser: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                print("[TrashCat] BrowserCache(\(browser)) error at \(url.path): \(error)")
                return true
            }
        ) else { return items }

        for case let url as URL in enumerator {
            guard items.count < maxItems else { break }
            guard !ScanPolicy.isBlocked(url.path) else { continue }

            // Use NSURL.getResourceValue to read from enumerator's pre-fetched cache
            let nsurl = url as NSURL
            var isDir: AnyObject?
            guard let _ = try? nsurl.getResourceValue(&isDir, forKey: .isDirectoryKey),
                  let dirNum = isDir as? NSNumber, !dirNum.boolValue else { continue }

            var fileSizeNum: AnyObject?
            guard let _ = try? nsurl.getResourceValue(&fileSizeNum, forKey: .fileSizeKey),
                  let sizeNum = fileSizeNum as? NSNumber, sizeNum.intValue > 0 else { continue }

            let relative = "[\(browser)] " + url.path.replacingOccurrences(of: path + "/", with: "")
            items.append(CleanItem(
                path: url.path,
                name: relative,
                size: Int64(sizeNum.intValue),
                category: .browserCache,
                ruleId: "browser-cache"
            ))
        }

        return items
    }
}
