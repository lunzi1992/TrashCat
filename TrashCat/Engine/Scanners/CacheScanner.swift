import Foundation

final class CacheScanner: Scannable {
    let category: CleanCategory = .cache
    let progressLabel = "扫描缓存文件..."

    private let fileManager = FileManager.default

    // Directories to scan for caches
    private var scanPaths: [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches",
            "/Library/Caches",
        ]
    }

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for path in scanPaths {
            let scannedItems = await scanDirectory(at: path)
            items.append(contentsOf: scannedItems)
        }

        return ScanResult(category: .cache, items: items)
    }

    private func scanDirectory(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }

        for url in contents {
            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }

            let item = CleanItem(
                path: url.path,
                name: url.lastPathComponent,
                size: Int64(fileSize),
                category: .cache
            )
            items.append(item)
        }

        return items
    }
}
