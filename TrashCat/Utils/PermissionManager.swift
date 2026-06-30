import Foundation
import AppKit
import os

/// 全磁盘访问（Full Disk Access, FDA）权限检测与引导。
///
/// 设计要点：
/// 1. **多探针组合**：单一探针（如旧版的 `~/Library/Safari/Bookmarks.plist`）过窄——
///    用户从未在 Safari 添加书签时该文件不存在，导致即使已授权也返回 false → 永远弹窗。
///    改用目录级探针（Safari / Mail / Messages / CoreTime），任一可读即认为有 FDA。
/// 2. **避免 NSHomeDirectory 沙盒歧义**：用 `homeDirectoryForCurrentUser` 显式获取用户真实 home，
///    在非沙盒应用下返回 `/Users/<name>`；当前 TrashCat 未启用沙盒，行为与 NSHomeDirectory 一致，
///    但意图更清晰，且对未来沙盒启用更友好。
/// 3. **可重检**：TCC 授权需要 app 重启才生效，但 `isReadableFile` 在 app 重新前台时即可反映新权限。
///    暴露 `recheck()` 供 UI 主动触发，并通过 `Notification` 让 ContentView 监听变化。
/// 4. **诊断日志**：每次检测都通过 os.Logger 输出每个探针的状态，便于在 Console.app 排查。
final class PermissionManager {
    static let shared = PermissionManager()

    /// 权限状态变化通知，UI 监听后重检。
    static let didChangeNotification = Notification.Name("TrashCatPermissionDidChange")

    private static let logger = Logger(subsystem: "com.lunzi.trashcat", category: "Permission")

    private init() {}

    // MARK: - Translocation Detection

    /// 检测当前 app 是否被 Gatekeeper 移花接木（App Translocation）。
    ///
    /// 当用户从 DMG 安装 app、且 app 带有 quarantine 标记时，macOS 首次启动会
    /// 将 app 移到 `/private/var/folders/.../AppTranslocation/.../` 随机路径运行。
    /// 在这种状态下，TCC 权限检查会因为运行时路径与真实路径不一致而全部失败——
    /// 即使用户已在系统设置中打开 FDA 开关，`hasFullDiskAccess` 依然返回 false。
    ///
    /// 参考：`man 1 translocation` / Apple TN2432
    var isTranslocated: Bool {
        Bundle.main.bundlePath.contains("AppTranslocation")
    }

    // MARK: - FDA Check

    /// 检查是否已授予全磁盘访问权限。
    ///
    /// 使用多个受 FDA 保护的目录作为探针，任一可读即认为已授权。
    /// 采用两步检测：
    /// 1. `isReadableFile` 快速检测（POSIX access）
    /// 2. 对存在的目录尝试 `contentsOfDirectory`（实际 syscall，更可靠触发 TCC 判定）
    var hasFullDiskAccess: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // 用户级探针：受 FDA 保护的 ~/Library 子目录
        // 按可靠性排序：Keychains 在几乎所有 macOS 系统上都存在；
        // Safari/Mail/Messages 仅当用户使用过对应 app 时才存在
        let userProbes = [
            "\(home)/Library/Keychains",         // ✅ 几乎总存在
            "\(home)/Library/Safari",
            "\(home)/Library/Mail",
            "\(home)/Library/Messages",
            "\(home)/Library/Calendars",
            "\(home)/Library/Metadata/CoreTime",
        ]

        Self.logger.info("=== FDA check start ===")
        Self.logger.info("home: \(home, privacy: .public)")
        Self.logger.info("bundle id: \(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public)")
        Self.logger.info("app path: \(Bundle.main.bundlePath, privacy: .public)")

        // 诊断：是否 translocated（关键——translocation 会让 TCC 授权完全失效）
        if isTranslocated {
            Self.logger.warning("⚠️ App is TRANSLOCATED — TCC permissions may not apply")
            Self.logger.warning("   translocated path: \(Bundle.main.bundlePath, privacy: .public)")
        }

        // 诊断：是否在 sandbox 里（关键——sandbox 会让探针失效）
        if let container = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] {
            Self.logger.warning("SANDBOX detected: \(container, privacy: .public)")
            Self.logger.warning("App in Sandbox — ~/Library paths redirect to container, FDA probe invalid")
        } else {
            Self.logger.info("no sandbox env (normal)")
        }

        var anyReadable = false
        for probe in userProbes {
            let exists = FileManager.default.fileExists(atPath: probe)
            // 第一步：POSIX access() 检测
            let readable = FileManager.default.isReadableFile(atPath: probe)
            // 第二步：对存在的目录尝试实际读取（触发完整的 TCC 检查链路）
            var listable = false
            if exists && readable {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: probe)
                listable = contents != nil
            }
            Self.logger.info("probe \(probe, privacy: .public): exists=\(exists) readable=\(readable) listable=\(listable)")
            if readable && listable { anyReadable = true }
        }

        Self.logger.info("=== FDA result: \(anyReadable) translocated=\(self.isTranslocated) ===")
        return anyReadable
    }

    /// 重新检测权限，并广播变化通知。
    /// 调用时机：app 重新前台、用户在权限引导中点击"我已授权"。
    @discardableResult
    func recheck() -> Bool {
        let granted = hasFullDiskAccess
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self, userInfo: ["granted": granted])
        return granted
    }

    /// 打开「系统设置 → 隐私与安全性 → 全磁盘访问」。
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
