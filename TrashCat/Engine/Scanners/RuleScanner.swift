import Foundation

/// A scanner that executes a single CleanRule — enumerates its paths, filters by
/// age/type, and produces items tagged with the rule ID.
final class RuleScanner: Scannable {
    let rule: CleanRule
    let category: CleanCategory
    let progressLabel: String

    private let fileManager = FileManager.default
    private let maxItems = 10000

    init(rule: CleanRule) {
        self.rule = rule
        self.category = rule.category
        self.progressLabel = "扫描 \(rule.title)..."
    }

    func scan() async throws -> ScanResult {
        var items: [CleanItem] = []

        for rawPath in rule.paths {
            let path = RuleRegistry.resolve(path: rawPath)
            guard fileManager.fileExists(atPath: path) else { continue }

            let scannedItems = await scanRecursive(at: path)
            items.append(contentsOf: scannedItems)
            if items.count >= maxItems { break }
        }

        return ScanResult(category: rule.category, items: items, ruleId: rule.id)
    }

    private func scanRecursive(at path: String) async -> [CleanItem] {
        var items: [CleanItem] = []

        let skipHidden = rule.category != .trash && rule.category != .temp

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: skipHidden ? [.skipsHiddenFiles] : [],
            errorHandler: { [weak self] url, error in
                print("[TrashCat] RuleScanner(\(self?.rule.id ?? "?")) error at \(url.path): \(error)")
                return true
            }
        ) else {
            return items
        }

        for case let url as URL in enumerator {
            guard items.count < maxItems else { break }

            guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]),
                  let isDir = resourceValues.isDirectory,
                  !isDir,
                  let fileSize = resourceValues.fileSize,
                  fileSize > 0 else {
                continue
            }

            // Age filter
            if let minDays = rule.minAgeDays, minDays > 0,
               let modDate = resourceValues.contentModificationDate {
                let age = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0
                if age < minDays { continue }
            }

            let relative = url.path.replacingOccurrences(of: path + "/", with: "")
            items.append(CleanItem(
                path: url.path,
                name: relative,
                size: Int64(fileSize),
                category: rule.category,
                ruleId: rule.id
            ))
        }

        return items
    }
}
