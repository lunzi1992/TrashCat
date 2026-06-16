import Foundation

final class TrashScanner: Scannable {
    let category: CleanCategory = .trash
    let progressLabel = "检查废纸篓..."

    private let fileManager = FileManager.default

    private var trashPath: String {
        "\(fileManager.homeDirectoryForCurrentUser.path)/.Trash"
    }

    func scan() async throws -> ScanResult {
        let items = await scanDirectory(at: trashPath)
        return ScanResult(category: .trash, items: items)
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
                category: .trash
            ))
        }

        return items
    }
}
