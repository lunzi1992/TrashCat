import Foundation

final class TempScanner: Scannable {
    let category: CleanCategory = .temp
    let progressLabel = "扫描临时文件..."

    private let fileManager = FileManager.default
    private let maxItems = 10000

    private var scanPaths: [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var paths = [
            "/tmp",
            "/private/tmp",
            "/private/var/tmp",
        ]
        // Also add the user's T/ folder inside /private/var/folders
        paths.append(NSTemporaryDirectory())

        // Shell session histories (safe to clean, auto-recreated)
        let shellPaths = [
            "\(home)/.bash_sessions",
            "\(home)/.zsh_sessions",
        ]
        paths.append(contentsOf: shellPaths.filter { fileManager.fileExists(atPath: $0) })

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
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
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
            guard !ScanPolicy.isBlocked(url.path) else { continue }

            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]),
                  let isDir = resourceValues.isDirectory,
                  !isDir,
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                continue
            }

            // Age filter: only include files ≥ N days old
            if let modDate = resourceValues.contentModificationDate {
                let age = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
                if age < ScanPolicy.tempMinAgeDays { continue }
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
