import Foundation

final class BrowserCacheScanner: Scannable {
    let category: CleanCategory = .browserCache
    let progressLabel = "翻浏览器的老鼠窝..."

    private let fileManager = FileManager.default
    private let maxItems = 10000

    /// Cache-only paths — deliberately excludes Bookmarks, Login Data, Cookies, Preferences
    private var browserCachePaths: [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var paths: [String] = []

        // Chrome
        let chromeBase = "\(home)/Library/Application Support/Google/Chrome"
        paths.append("\(chromeBase)/Default/Cache")
        paths.append("\(chromeBase)/Default/Code Cache")
        paths.append("\(chromeBase)/Default/Service Worker/CacheStorage")
        paths.append("\(chromeBase)/Default/Service Worker/ScriptCache")
        // Chrome profiles (Profile 1, Profile 2, ...)
        for i in 1...5 {
            paths.append("\(chromeBase)/Profile \(i)/Cache")
            paths.append("\(chromeBase)/Profile \(i)/Code Cache")
            paths.append("\(chromeBase)/Profile \(i)/Service Worker/CacheStorage")
        }

        // Edge
        let edgeBase = "\(home)/Library/Application Support/Microsoft Edge"
        paths.append("\(edgeBase)/Default/Cache")
        paths.append("\(edgeBase)/Default/Code Cache")
        paths.append("\(edgeBase)/Default/Service Worker/CacheStorage")

        // Firefox
        let firefoxBase = "\(home)/Library/Application Support/Firefox/Profiles"
        if let profiles = try? fileManager.contentsOfDirectory(atPath: firefoxBase) {
            for profile in profiles where profile.hasSuffix(".default-release") || profile.hasSuffix(".default") {
                paths.append("\(firefoxBase)/\(profile)/cache2")
            }
        }

        // Brave
        let braveBase = "\(home)/Library/Application Support/BraveSoftware/Brave-Browser"
        paths.append("\(braveBase)/Default/Cache")
        paths.append("\(braveBase)/Default/Code Cache")

        // Opera
        let operaBase = "\(home)/Library/Application Support/com.operasoftware.Opera"
        paths.append("\(operaBase)/Cache")

        // Safari WebKit caches (separate from main cache)
        paths.append("\(home)/Library/WebKit/com.apple.Safari")

        return paths.filter { fileManager.fileExists(atPath: $0) }
    }

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for path in browserCachePaths {
            let scannedItems = await scanRecursive(at: path)
            items.append(contentsOf: scannedItems)
            if items.count >= maxItems { break }
        }

        return ScanResult(category: .browserCache, items: items)
    }

    private func scanRecursive(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                print("[TrashCat] BrowserCache error at \(url.path): \(error)")
                return true
            }
        ) else {
            return items
        }

        for case let url as URL in enumerator {
            guard items.count < maxItems else { break }

            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let isDir = resourceValues.isDirectory,
                  !isDir,
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                continue
            }

            let relative = url.path.replacingOccurrences(of: path + "/", with: "")
            items.append(CleanItem(
                path: url.path,
                name: relative,
                size: Int64(fileSize),
                category: .browserCache
            ))
        }

        return items
    }
}
