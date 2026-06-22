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
            guard !ScanPolicy.isBlocked(url.path) else { continue }

            // Use NSURL.getResourceValue to read from enumerator's pre-fetched cache
            // (avoids a fresh stat() call per file — significant I/O savings)
            let nsurl = url as NSURL

            var isDir: AnyObject?
            guard let _ = try? nsurl.getResourceValue(&isDir, forKey: .isDirectoryKey),
                  let dirNum = isDir as? NSNumber, !dirNum.boolValue else { continue }

            var fileSize: AnyObject?
            guard let _ = try? nsurl.getResourceValue(&fileSize, forKey: .fileSizeKey),
                  let sizeNum = fileSize as? NSNumber, sizeNum.intValue > 0 else { continue }

            // Age filter
            if let minDays = rule.minAgeDays, minDays > 0 {
                var modDate: AnyObject?
                if let _ = try? nsurl.getResourceValue(&modDate, forKey: .contentModificationDateKey),
                   let date = modDate as? Date {
                    let age = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
                    if age < minDays { continue }
                }
            }

            let relative = url.path.replacingOccurrences(of: path + "/", with: "")
            items.append(CleanItem(
                path: url.path,
                name: relative,
                size: Int64(sizeNum.intValue),
                category: rule.category,
                ruleId: rule.id
            ))
        }

        return items
    }
}

// MARK: - Space Diagnostic Scanner

/// Scans for large space consumers that should NOT be cleaned automatically.
/// These are user-data-heavy areas presented as "space diagnosis" —
/// users decide what to do outside of TrashCat.
///
/// Targets: Time Machine local APFS snapshots, Mail, Messages attachments.
/// All items are marked `.danger` — no default selection, no one-click cleanup.
final class SpaceDiagnosticScanner: Scannable {
    let category: CleanCategory = .diagnostic
    let progressLabel = "空间诊断..."

    private let fileManager = FileManager.default

    func scan() async throws -> ScanResult {
        // Offload blocking calls (Process, FileManager) to a background queue
        // to avoid starving the cooperative thread pool.
        async let tm = Task.detached { await self.checkTMSnapshots() }.value
        async let mail = Task.detached { await self.checkMailSize() }.value
        async let messages = Task.detached { await self.checkMessagesSize() }.value

        var items: [CleanItem] = []
        items.append(contentsOf: await tm)
        items.append(contentsOf: await mail)
        items.append(contentsOf: await messages)

        return ScanResult(category: .diagnostic, items: items)
    }

    // MARK: - Time Machine Local Snapshots

    private func checkTMSnapshots() async -> [CleanItem] {
        var items: [CleanItem] = []

        let task = Process()
        task.launchPath = "/usr/bin/tmutil"
        task.arguments = ["listlocalsnapshots", "/"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else { return items }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return items }

            let lines = output.components(separatedBy: "\n")
                .filter { $0.hasPrefix("com.apple.TimeMachine") }

            if !lines.isEmpty {
                let estimatedBytes: Int64 = Int64(lines.count) * 500_000_000
                items.append(CleanItem(
                    path: "/",
                    name: "Time Machine 本地快照（\(lines.count) 个）",
                    size: estimatedBytes,
                    category: .diagnostic,
                    ruleId: "time-machine-snapshots"
                ))
            }
        } catch {
            print("[TrashCat] SpaceDiagnostic: tmutil failed: \(error)")
        }

        return items
    }

    // MARK: - Mail

    private func checkMailSize() async -> [CleanItem] {
        var items: [CleanItem] = []
        let home = fileManager.homeDirectoryForCurrentUser.path
        let mailPath = "\(home)/Library/Mail"

        guard fileManager.fileExists(atPath: mailPath) else { return items }

        if let size = directorySize(at: mailPath), size > 0 {
            items.append(CleanItem(
                path: mailPath,
                name: "邮件下载与附件",
                size: size,
                category: .diagnostic,
                ruleId: "mail-downloads"
            ))
        }

        return items
    }

    // MARK: - Messages

    private func checkMessagesSize() async -> [CleanItem] {
        var items: [CleanItem] = []
        let home = fileManager.homeDirectoryForCurrentUser.path
        let messagesPath = "\(home)/Library/Messages"

        guard fileManager.fileExists(atPath: messagesPath) else { return items }

        let attPath = "\(messagesPath)/Attachments"
        if fileManager.fileExists(atPath: attPath),
           let size = directorySize(at: attPath), size > 0 {
            items.append(CleanItem(
                path: attPath,
                name: "信息附件（图片、视频等）",
                size: size,
                category: .diagnostic,
                ruleId: "messages-attachments"
            ))
        }

        let dbPath = "\(messagesPath)/chat.db"
        if fileManager.fileExists(atPath: dbPath),
           let dbSize = fileSize(at: dbPath), dbSize > 0 {
            items.append(CleanItem(
                path: dbPath,
                name: "信息聊天记录数据库",
                size: dbSize,
                category: .diagnostic,
                ruleId: "messages-attachments"
            ))
        }

        return items
    }

    // MARK: - Helpers

    private func directorySize(at path: String) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in return true }
        ) else { return nil }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard !ScanPolicy.isBlocked(url.path) else { continue }
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  let isDir = values.isDirectory, !isDir,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total > 0 ? total : nil
    }

    private func fileSize(at path: String) -> Int64? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return nil }
        return size > 0 ? size : nil
    }
}
