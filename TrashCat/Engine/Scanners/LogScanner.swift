import Foundation

final class LogScanner: Scannable {
    let category: CleanCategory = .logs
    let progressLabel = "扫描日志文件..."

    private let fileManager = FileManager.default
    private let maxItems = 5000

    private var scanPaths: [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Logs",
            "/Library/Logs",
        ]
    }

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for path in scanPaths {
            let scannedItems = await scanRecursive(at: path)
            items.append(contentsOf: scannedItems)
            if items.count >= maxItems { break }
        }

        return ScanResult(category: .logs, items: items)
    }

    private func scanRecursive(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                print("[TrashCat] LogScanner error at \(url.path): \(error)")
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
                category: .logs
            ))
        }

        return items
    }
}
