import Foundation

final class TrashScanner: Scannable {
    let category: CleanCategory = .trash
    let progressLabel = "检查废纸篓..."

    private let fileManager = FileManager.default
    private let maxItems = 5000

    private var trashPath: String {
        "\(fileManager.homeDirectoryForCurrentUser.path)/.Trash"
    }

    func scan() async throws -> ScanResult {
        let items = await scanRecursive(at: trashPath)
        return ScanResult(category: .trash, items: items)
    }

    private func scanRecursive(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],  // Don't skip hidden — trash items could be dot-files
            errorHandler: { url, error in
                print("[TrashCat] TrashScanner error at \(url.path): \(error)")
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
                category: .trash
            ))
        }

        return items
    }
}
