import Foundation

final class TempScanner: Scannable {
    let category: CleanCategory = .temp
    let progressLabel = "扫描临时文件..."

    private let fileManager = FileManager.default

    private let scanPaths = [
        "/tmp",
        "/private/tmp",
        "/private/var/tmp",
    ]

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for path in scanPaths {
            let scannedItems = await scanDirectory(at: path, depth: 1)
            items.append(contentsOf: scannedItems)
        }

        return ScanResult(category: .temp, items: items)
    }

    private func scanDirectory(at path: String, depth: Int) async -> [CleanItem] {
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

            items.append(CleanItem(
                path: url.path,
                name: url.lastPathComponent,
                size: Int64(fileSize),
                category: .temp
            ))
        }

        return items
    }
}
