import Foundation

final class OrphanScanner: Scannable {
    let category: CleanCategory = .orphan
    let progressLabel = "搜寻残留老鼠窝..."

    private let fileManager = FileManager.default

    // Bundle IDs to always skip (Apple system apps)
    private let systemBundlePrefixes = [
        "com.apple.",
        "com.apple",
    ]

    /// Directories where orphaned files hide
    private var searchRoots: [String] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Preferences",
            "\(home)/Library/Application Support",
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
            "\(home)/Library/Saved Application State",
        ]
    }

    func scan() async throws -> ScanResult {
        // Step 1: Get list of currently installed app bundle IDs
        let installedIDs = await getInstalledBundleIDs()

        // Step 2: Scan each root directory for orphans
        var items: [CleanItem] = []

        for root in searchRoots {
            let orphans = await findOrphans(in: root, installedIDs: installedIDs)
            items.append(contentsOf: orphans)
        }

        return ScanResult(category: .orphan, items: items)
    }

    // MARK: - Get Installed Apps

    private func getInstalledBundleIDs() async -> Set<String> {
        var bundleIDs = Set<String>()

        // Scan /Applications
        let appDirs = ["/Applications", "\(fileManager.homeDirectoryForCurrentUser.path)/Applications"]

        for appDir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: appDir),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else {
                continue
            }

            for url in contents where url.pathExtension == "app" {
                if let bundle = Bundle(url: url),
                   let id = bundle.bundleIdentifier {
                    bundleIDs.insert(id)
                }
            }
        }

        // Also use system_profiler for deeper scan of Launchpad-registered apps
        bundleIDs.formUnion(await getLaunchpadBundleIDs())

        return bundleIDs
    }

    private func getLaunchpadBundleIDs() async -> Set<String> {
        // Use mdfind to find all apps registered in Launch Services
        let task = Process()
        task.launchPath = "/usr/bin/mdfind"
        task.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            var ids = Set<String>()
            let paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }

            // Limit to avoid scanning thousands of apps
            for path in paths.prefix(500) {
                if let bundle = Bundle(url: URL(fileURLWithPath: path)),
                   let id = bundle.bundleIdentifier {
                    ids.insert(id)
                }
            }

            return ids
        } catch {
            print("[TrashCat] mdfind failed: \(error)")
            return []
        }
    }

    // MARK: - Find Orphans

    private func findOrphans(in directory: String, installedIDs: Set<String>) async -> [CleanItem] {
        var items: [CleanItem] = []

        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return items
        }

        for url in contents {
            let name = url.lastPathComponent
            let stem = (name as NSString).deletingPathExtension.lowercased()

            // Skip if this file likely belongs to a system app
            if systemBundlePrefixes.contains(where: { stem.hasPrefix($0) }) {
                continue
            }

            // Check if any installed app's bundle ID matches this file/dir name
            let matched = installedIDs.contains { installedID in
                let lowered = installedID.lowercased()
                return lowered == stem
                    || lowered.hasPrefix(stem)
                    || stem.hasPrefix(lowered)
            }

            if !matched {
                guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                      let fileSize = resourceValues.fileSize else {
                    continue
                }

                items.append(CleanItem(
                    path: url.path,
                    name: name,
                    size: Int64(fileSize),
                    category: .orphan
                ))
            }
        }

        return items
    }
}
