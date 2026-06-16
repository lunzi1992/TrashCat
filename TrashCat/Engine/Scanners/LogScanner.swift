import Foundation

final class LogScanner: Scannable {
    let category: CleanCategory = .logs
    let progressLabel = "扫描日志文件..."

    private let fileManager = FileManager.default

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
            let scannedItems = await scanDirectory(at: path)
            items.append(contentsOf: scannedItems)
        }

        return ScanResult(category: .logs, items: items)
    }

    private func scanDirectory(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }

        for case let url as URL in enumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                continue
            }

            items.append(CleanItem(
                path: url.path,
                name: url.lastPathComponent,
                size: Int64(fileSize),
                category: .logs
            ))
        }

        return items
    }
}
