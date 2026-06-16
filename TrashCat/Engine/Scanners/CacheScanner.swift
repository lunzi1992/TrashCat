import Foundation

final class CacheScanner: Scannable {
    let category: CleanCategory = .cache
    let progressLabel = "扫描缓存文件..."

    private let fileManager = FileManager.default
    private let maxItems = 10000  // Safety limit

    private var scanPaths: [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var paths: [String] = [
            "\(home)/Library/Caches",
            "/Library/Caches",
        ]

        // System per-user temp/cache directory (a.k.a. /private/var/folders/xx/yyyyy/)
        // NSTemporaryDirectory() returns .../T/ — go up one level to get C/ + T/
        let tempDir = NSTemporaryDirectory()
        let userVarFolder = (tempDir as NSString).deletingLastPathComponent  // remove "T/"
        paths.append(userVarFolder)

        // Developer tool caches (append if exist)
        let devPaths = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
            "\(home)/Library/Developer/CoreSimulator/Devices",
            "\(home)/Library/Developer/Xcode/Archives",
            // iOS backups
            "\(home)/Library/Application Support/MobileSync/Backup",
        ]
        paths.append(contentsOf: devPaths.filter { fileManager.fileExists(atPath: $0) })

        return paths
    }

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for path in scanPaths {
            let scannedItems = await scanRecursive(at: path)
            items.append(contentsOf: scannedItems)
            if items.count >= maxItems { break }
        }

        return ScanResult(category: .cache, items: items)
    }

    /// Recursively enumerate all files under path, adding each file's size.
    /// Uses FileManager.enumerator which performs a depth-first walk.
    private func scanRecursive(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                print("[TrashCat] Enumerator error at \(url.path): \(error)")
                return true  // continue on error
            }
        ) else {
            print("[TrashCat] CacheScanner: cannot access \(path)")
            return items
        }

        for case let url as URL in enumerator {
            guard items.count < maxItems else { break }

            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let isDir = resourceValues.isDirectory,
                  !isDir,  // skip directories themselves, only count files
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                continue
            }

            let relative = url.path.replacingOccurrences(of: path + "/", with: "")
            items.append(CleanItem(
                path: url.path,
                name: relative,
                size: Int64(fileSize),
                category: .cache
            ))
        }

        return items
    }
}
