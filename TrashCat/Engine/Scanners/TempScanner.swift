import Foundation

final class TempScanner: Scannable {
    let category: CleanCategory = .temp
    let progressLabel = "扫描临时文件..."

    private let fileManager = FileManager.default
    private let maxItems = 10000

    private var scanPaths: [String] {
        var paths = [
            "/tmp",
            "/private/tmp",
            "/private/var/tmp",
        ]
        // Also add the user's T/ folder inside /private/var/folders
        paths.append(NSTemporaryDirectory())
        return paths
    }

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for path in scanPaths {
            let scannedItems = await scanRecursive(at: path)
            items.append(contentsOf: scannedItems)
            if items.count >= maxItems { break }
        }

        return ScanResult(category: .temp, items: items)
    }

    private func scanRecursive(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],  // Don't skip hidden — /tmp has dot-files
            errorHandler: { url, error in
                print("[TrashCat] TempScanner error at \(url.path): \(error)")
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
                category: .temp
            ))
        }

        return items
    }
}
