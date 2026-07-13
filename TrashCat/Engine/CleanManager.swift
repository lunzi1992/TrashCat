import Foundation

final class CleanManager {
    private let fileManager = FileManager.default

    /// Move items to Trash (safe, recoverable).
    /// Returns the result with count of successfully moved items and any errors.
    func clean(items: [CleanItem]) async -> CleanResult {
        let startTime = Date()
        var freedSize: Int64 = 0
        var freedCount = 0
        var movedToTrashSize: Int64 = 0
        var movedToTrashCount = 0
        var errors: [String] = []
        var catSizes: [CleanCategory: Int64] = [:]
        var catCounts: [CleanCategory: Int] = [:]

        for item in items {
            guard item.isCleanable else {
                errors.append("\(item.name): 此项不支持自动清理，已跳过")
                continue
            }
            do {
                try validateImmediatelyBeforeCleaning(item)
                if item.category == .trash {
                    try deleteTrashItem(path: item.path)
                    freedSize += item.size
                    freedCount += 1
                } else {
                    try await moveToTrash(path: item.path)
                    movedToTrashSize += item.size
                    movedToTrashCount += 1
                }
                catSizes[item.category, default: 0] += item.size
                catCounts[item.category, default: 0] += 1
            } catch {
                errors.append("\(item.name): \(error.localizedDescription)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let breakdown = catSizes.map { (cat, size) in
            (cat, size, catCounts[cat] ?? 0)
        }.sorted { $0.1 > $1.1 }

        return CleanResult(
            freedSize: freedSize,
            freedFileCount: freedCount,
            movedToTrashSize: movedToTrashSize,
            movedToTrashFileCount: movedToTrashCount,
            duration: duration,
            errors: errors,
            categoryBreakdown: breakdown
        )
    }

    private func validateImmediatelyBeforeCleaning(_ item: CleanItem) throws {
        let resolvedPath = URL(fileURLWithPath: item.path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        guard fileManager.fileExists(atPath: item.path) else {
            throw NSError(
                domain: "TrashCat.CleanManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "文件已发生变化，请重新扫描"]
            )
        }
        guard !ScanPolicy.isBlocked(resolvedPath) else {
            throw NSError(
                domain: "TrashCat.CleanManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "路径受到系统保护，已跳过"]
            )
        }
        if item.category == .browserCache && RiskAssessor.isRunningAppPath(resolvedPath) {
            throw NSError(
                domain: "TrashCat.CleanManager",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "对应浏览器正在运行，请退出浏览器后重新扫描"]
            )
        }
    }

    /// Move a single file/directory to Trash
    private func moveToTrash(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        var resultingURL: NSURL?

        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
    }

    /// Permanently remove an item that is already inside the user's Trash.
    private func deleteTrashItem(path: String) throws {
        let homeTrash = "\(fileManager.homeDirectoryForCurrentUser.path)/.Trash"
        guard path == homeTrash || path.hasPrefix(homeTrash + "/") else {
            throw NSError(
                domain: "TrashCat.CleanManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "只允许清空废纸篓中的项目"]
            )
        }
        try fileManager.removeItem(atPath: path)
    }

    /// Permanently delete (use with caution — not used in MVP default path)
    func permanentDelete(items: [CleanItem]) async -> CleanResult {
        let startTime = Date()
        var freedSize: Int64 = 0
        var freedCount = 0
        var errors: [String] = []

        for item in items {
            guard item.isCleanable else {
                errors.append("\(item.name): 此项不支持自动清理，已跳过")
                continue
            }
            do {
                try fileManager.removeItem(atPath: item.path)
                freedSize += item.size
                freedCount += 1
            } catch {
                errors.append("\(item.name): \(error.localizedDescription)")
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return CleanResult(
            freedSize: freedSize,
            freedFileCount: freedCount,
            duration: duration,
            errors: errors
        )
    }
}
