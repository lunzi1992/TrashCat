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
            guard !Task.isCancelled else { break }
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
    private let minimumReportSize: Int64 = 100 * 1024 * 1024

    func scan() async throws -> ScanResult {
        // Offload blocking calls (Process, FileManager) to a background queue
        // to avoid starving the cooperative thread pool.
        async let tm = Task.detached { await self.checkTMSnapshots() }.value
        async let iosBackups = Task.detached { self.checkIOSBackups() }.value
        async let xcodeArchives = Task.detached { self.checkXcodeArchives() }.value
        async let mail = Task.detached { await self.checkMailSize() }.value
        async let messages = Task.detached { await self.checkMessagesSize() }.value
        async let docker = Task.detached { self.checkDockerData() }.value
        async let chats = Task.detached { self.checkChatApps() }.value
        async let virtualMachines = Task.detached { self.checkVirtualMachines() }.value
        async let userFiles = Task.detached { self.checkUserFiles() }.value

        var items: [CleanItem] = []
        items.append(contentsOf: await tm)
        items.append(contentsOf: await iosBackups)
        items.append(contentsOf: await xcodeArchives)
        items.append(contentsOf: await mail)
        items.append(contentsOf: await messages)
        items.append(contentsOf: await docker)
        items.append(contentsOf: await chats)
        items.append(contentsOf: await virtualMachines)
        items.append(contentsOf: await userFiles)

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

    // MARK: - iOS Backups

    private func checkIOSBackups() -> [CleanItem] {
        let backupRoot = resolve("~/Library/Application Support/MobileSync/Backup")
        return childDirectoryItems(
            under: backupRoot,
            fallbackName: "iOS 设备备份",
            ruleId: "ios-backup"
        )
    }

    // MARK: - Xcode Archives

    private func checkXcodeArchives() -> [CleanItem] {
        let archiveRoot = resolve("~/Library/Developer/Xcode/Archives")
        return childDirectoryItems(
            under: archiveRoot,
            fallbackName: "Xcode 归档文件",
            ruleId: "xcode-archives",
            allowedExtensions: ["xcarchive"]
        )
    }

    // MARK: - Mail

    private func checkMailSize() async -> [CleanItem] {
        var items: [CleanItem] = []
        let mailPath = resolve("~/Library/Mail")

        guard fileManager.fileExists(atPath: mailPath) else { return items }

        if let size = directorySize(at: mailPath), size >= minimumReportSize {
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
        let messagesPath = resolve("~/Library/Messages")

        guard fileManager.fileExists(atPath: messagesPath) else { return items }

        let attPath = "\(messagesPath)/Attachments"
        if fileManager.fileExists(atPath: attPath),
           let size = directorySize(at: attPath), size >= minimumReportSize {
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
           let dbSize = fileSize(at: dbPath), dbSize >= minimumReportSize {
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

    // MARK: - Docker

    private func checkDockerData() -> [CleanItem] {
        directoryItems(
            [
                DiagnosticPath(
                    path: "~/Library/Containers/com.docker.docker/Data",
                    name: "Docker Desktop 数据"
                ),
                DiagnosticPath(
                    path: "~/.docker",
                    name: "Docker 用户配置与缓存"
                ),
            ],
            ruleId: "docker-data"
        )
    }

    // MARK: - Chat Apps

    private func checkChatApps() -> [CleanItem] {
        var items: [CleanItem] = []
        items.append(contentsOf: directoryItems(
            [
                DiagnosticPath(
                    path: "~/Library/Containers/com.tencent.xinWeChat/Data/Library/Application Support/com.tencent.xinWeChat",
                    name: "微信聊天数据"
                ),
                DiagnosticPath(
                    path: "~/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files",
                    name: "微信接收文件"
                ),
                DiagnosticPath(
                    path: "~/Library/Application Support/com.tencent.xinWeChat",
                    name: "微信旧版数据"
                ),
            ],
            ruleId: "wechat-data"
        ))
        items.append(contentsOf: directoryItems(
            [
                DiagnosticPath(
                    path: "~/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ",
                    name: "QQ 聊天数据"
                ),
                DiagnosticPath(
                    path: "~/Library/Application Support/QQ",
                    name: "QQ 旧版数据"
                ),
            ],
            ruleId: "qq-data"
        ))
        items.append(contentsOf: directoryItems(
            [
                DiagnosticPath(
                    path: "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram",
                    name: "Telegram 媒体与缓存"
                ),
                DiagnosticPath(
                    path: "~/Library/Application Support/Telegram Desktop",
                    name: "Telegram Desktop 数据"
                ),
            ],
            ruleId: "telegram-data"
        ))
        return items
    }

    // MARK: - Virtual Machines

    private func checkVirtualMachines() -> [CleanItem] {
        var items: [CleanItem] = []
        let roots = [
            "~/Parallels",
            "~/Virtual Machines.localized",
            "~/Documents/Virtual Machines.localized",
            "~/VirtualBox VMs",
            "~/Library/Containers/com.utmapp.UTM/Data/Documents",
        ]
        let extensions = ["pvm", "vmwarevm", "utm", "vbox", "vdi", "qcow2", "img"]

        for root in roots.map(resolve) {
            items.append(contentsOf: childDirectoryItems(
                under: root,
                fallbackName: "虚拟机镜像",
                ruleId: "virtual-machines",
                allowedExtensions: extensions
            ))
        }
        return items
    }

    // MARK: - Downloads and Large User Files

    private func checkUserFiles() -> [CleanItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let roots = ["Downloads", "Desktop", "Documents", "Movies"]
            .map { "\(home)/\($0)" }
        let downloadsRoot = "\(home)/Downloads/"
        let now = Date()
        let oldDMGCutoff = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let staleDownloadCutoff = Calendar.current.date(byAdding: .day, value: -180, to: now) ?? now
        let staleMinimumSize: Int64 = 10 * 1024 * 1024
        let largeFileMinimumSize: Int64 = 1024 * 1024 * 1024
        let maxItems = 200
        var items: [CleanItem] = []

        for root in roots where items.count < maxItems {
            guard fileManager.fileExists(atPath: root),
                  let enumerator = fileManager.enumerator(
                    at: URL(fileURLWithPath: root),
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, _ in true }
                  ) else { continue }

            for case let url as URL in enumerator {
                guard items.count < maxItems else { break }
                guard !Task.isCancelled, !ScanPolicy.isBlocked(url.path),
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                      values.isRegularFile == true,
                      let rawSize = values.fileSize,
                      rawSize > 0 else { continue }

                let size = Int64(rawSize)
                let modified = values.contentModificationDate ?? now
                let ageDays = max(0, Calendar.current.dateComponents([.day], from: modified, to: now).day ?? 0)
                let isInDownloads = url.path.hasPrefix(downloadsRoot)

                let ruleID: String?
                let prefix: String
                if isInDownloads && url.pathExtension.lowercased() == "dmg" && modified < oldDMGCutoff {
                    ruleID = "old-dmg-files"
                    prefix = "长期未使用的 DMG"
                } else if isInDownloads && modified < staleDownloadCutoff && size >= staleMinimumSize {
                    ruleID = "stale-downloads"
                    prefix = "陈旧下载"
                } else if size >= largeFileMinimumSize {
                    ruleID = "large-user-files"
                    prefix = "大文件"
                } else {
                    ruleID = nil
                    prefix = ""
                }

                guard let ruleID else { continue }
                items.append(CleanItem(
                    path: url.path,
                    name: "\(prefix)：\(url.lastPathComponent)（约 \(ageDays) 天未修改）",
                    size: size,
                    category: .diagnostic,
                    ruleId: ruleID
                ))
            }
        }

        return items
    }

    // MARK: - Helpers

    private struct DiagnosticPath {
        let path: String
        let name: String
    }

    private func resolve(_ path: String) -> String {
        RuleRegistry.resolve(path: path)
    }

    private func directoryItems(_ targets: [DiagnosticPath], ruleId: String) -> [CleanItem] {
        targets.compactMap { target in
            let path = resolve(target.path)
            guard !ScanPolicy.isBlocked(path),
                  fileManager.fileExists(atPath: path),
                  let size = directorySize(at: path),
                  size >= minimumReportSize else { return nil }
            return CleanItem(
                path: path,
                name: target.name,
                size: size,
                category: .diagnostic,
                ruleId: ruleId
            )
        }
    }

    private func childDirectoryItems(
        under root: String,
        fallbackName: String,
        ruleId: String,
        allowedExtensions: [String]? = nil
    ) -> [CleanItem] {
        guard !ScanPolicy.isBlocked(root),
              fileManager.fileExists(atPath: root),
              let children = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return children.compactMap { url in
            if let allowedExtensions,
               !allowedExtensions.contains(url.pathExtension.lowercased()) {
                return nil
            }
            guard !ScanPolicy.isBlocked(url.path),
                  let size = itemSize(at: url.path),
                  size >= minimumReportSize else { return nil }

            let displayName = url.lastPathComponent.isEmpty ? fallbackName : url.lastPathComponent
            return CleanItem(
                path: url.path,
                name: "\(fallbackName)：\(displayName)",
                size: size,
                category: .diagnostic,
                ruleId: ruleId
            )
        }
    }

    private func itemSize(at path: String) -> Int64? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue ? directorySize(at: path) : fileSize(at: path)
    }

    private func directorySize(at path: String) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [],
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
