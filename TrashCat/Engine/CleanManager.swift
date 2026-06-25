import Foundation

final class CleanManager {
    private let fileManager = FileManager.default

    /// Move items to Trash (safe, recoverable).
    /// Returns the result with count of successfully moved items and any errors.
    func clean(items: [CleanItem]) async -> CleanResult {
        let startTime = Date()
        var freedSize: Int64 = 0
        var freedCount = 0
        var errors: [String] = []
        var catSizes: [CleanCategory: Int64] = [:]
        var catCounts: [CleanCategory: Int] = [:]

        for item in items {
            guard item.isCleanable else {
                errors.append("\(item.name): 此项不支持自动清理，已跳过")
                continue
            }
            do {
                try await moveToTrash(path: item.path)
                freedSize += item.size
                freedCount += 1
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
            duration: duration,
            errors: errors,
            categoryBreakdown: breakdown
        )
    }

    /// Move a single file/directory to Trash
    private func moveToTrash(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        var resultingURL: NSURL?

        try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
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
