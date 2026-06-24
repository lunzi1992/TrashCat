import Foundation

/// Central registry of all cleanup rules. Each rule defines a specific cleanup target
/// with metadata for display, risk assessment, and deletion strategy.
enum RuleRegistry {

    static let all: [CleanRule] = [
        // ── Recommendation Tier ──

        CleanRule(
            id: "user-cache",
            title: "用户缓存",
            description: "应用运行时产生的缓存文件，删除后应用会在下次启动时自动重建",
            paths: ["~/Library/Caches"],
            category: .cache,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "删除后应用下次启动可能略慢"
        ),

        CleanRule(
            id: "user-logs",
            title: "用户日志",
            description: "应用记录的运行日志，通常为诊断用途",
            paths: ["~/Library/Logs"],
            category: .logs,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "无影响"
        ),

        CleanRule(
            id: "crash-reports-user",
            title: "用户崩溃报告",
            description: "应用崩溃产生的 .ips/.crash 诊断文件，可用于排查问题但通常不需要保留",
            paths: ["~/Library/Logs/DiagnosticReports"],
            category: .logs,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "无影响"
        ),

        CleanRule(
            id: "system-logs",
            title: "系统日志",
            description: "macOS 系统级日志文件",
            paths: ["/Library/Logs"],
            category: .logs,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "无影响"
        ),

        CleanRule(
            id: "crash-reports-system",
            title: "系统崩溃报告",
            description: "系统级崩溃诊断文件",
            paths: ["/Library/Logs/DiagnosticReports"],
            category: .logs,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "无影响"
        ),

        CleanRule(
            id: "temp-files",
            title: "临时文件",
            description: "系统和应用的临时文件，超过 7 天未修改",
            paths: ["/tmp", "/private/tmp", "/private/var/tmp"],
            category: .temp,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: 7,
            deleteStrategy: .trashItem,
            impactSummary: "无影响"
        ),

        CleanRule(
            id: "shell-sessions",
            title: "终端会话历史",
            description: "Shell 保存的会话恢复文件，每次打开终端时自动重建",
            paths: ["~/.bash_sessions", "~/.zsh_sessions"],
            category: .temp,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次打开终端时自动重建"
        ),

        CleanRule(
            id: "trash",
            title: "废纸篓",
            description: "废纸篓中尚未清空的项目",
            paths: ["~/.Trash"],
            category: .trash,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "将永久删除废纸篓内容"
        ),

        CleanRule(
            id: "browser-cache",
            title: "浏览器缓存",
            description: "浏览器缓存文件（Cache、Code Cache、Service Worker），不含书签、密码和浏览历史",
            paths: [],  // handled by BrowserCacheScanner dynamically
            category: .browserCache,
            riskLevel: .safe,
            defaultSelected: true,
            deletionUnit: .perApp,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次访问网页时重新下载"
        ),

        // ── Caution Tier ──

        CleanRule(
            id: "system-cache",
            title: "系统级缓存",
            description: "系统共享的缓存文件",
            paths: ["/Library/Caches"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "部分系统服务可能短暂变慢"
        ),

        CleanRule(
            id: "system-temp-folders",
            title: "系统用户临时文件",
            description: "macOS 为用户进程分配的临时存储",
            paths: ["NSTemporaryDirectory_UP_ONE"],  // resolved at scan time
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: 7,
            deleteStrategy: .trashItem,
            impactSummary: "某些运行中的应用可能短暂异常"
        ),

        CleanRule(
            id: "xcode-derived",
            title: "Xcode 编译缓存",
            description: "Xcode 编译生成的中间文件，可安全删除但会减慢下次编译",
            paths: ["~/Library/Developer/Xcode/DerivedData"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次编译需要重新生成，耗时较长"
        ),

        CleanRule(
            id: "xcode-device-support",
            title: "iOS 设备符号文件",
            description: "用于调试和崩溃符号化的设备符号表，删除后 Xcode 可重新下载",
            paths: ["~/Library/Developer/Xcode/iOS DeviceSupport"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次连接设备需要重新下载 (~1-5GB)"
        ),

        CleanRule(
            id: "xcode-simulator",
            title: "iOS 模拟器",
            description: "iOS 模拟器镜像和数据",
            paths: ["~/Library/Developer/CoreSimulator/Devices"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "模拟器需要重新创建和安装，建议使用 simctl delete unavailable"
        ),

        CleanRule(
            id: "npm-cache",
            title: "npm 缓存",
            description: "Node.js 包管理器缓存，删除后下次安装需重新下载",
            paths: ["~/.npm/_cacache"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次 npm install 需要重新下载包"
        ),

        CleanRule(
            id: "gradle-cache",
            title: "Gradle 缓存",
            description: "Android / Gradle 构建缓存，删除后需要重新下载依赖",
            paths: ["~/.gradle/caches"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次构建需重新下载所有依赖，耗时较长"
        ),

        CleanRule(
            id: "cargo-registry",
            title: "Cargo 注册表",
            description: "Rust 包注册表缓存",
            paths: ["~/.cargo/registry"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次 cargo build 需重新下载"
        ),

        CleanRule(
            id: "pub-cache",
            title: "Dart/Flutter 缓存",
            description: "Dart 和 Flutter 的 pub 包缓存",
            paths: ["~/.pub-cache"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "下次 flutter pub get 需重新下载"
        ),

        CleanRule(
            id: "vscode-cache",
            title: "VS Code 缓存",
            description: "Visual Studio Code 缓存数据、扩展安装包和日志",
            paths: [
                "~/Library/Application Support/Code/Cache",
                "~/Library/Application Support/Code/CachedData",
                "~/Library/Application Support/Code/CachedExtensionVSIXs",
                "~/Library/Application Support/Code/logs",
                "~/Library/Application Support/Code/User/workspaceStorage",
            ],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "清除编辑器缓存和已缓存的扩展安装包，workspaceStorage 会丢失未保存的编辑器状态"
        ),

        CleanRule(
            id: "system-updates",
            title: "系统更新下载",
            description: "macOS 下载的更新安装包，安装完成后通常不再需要",
            paths: ["/Library/Updates"],
            category: .cache,
            riskLevel: .caution,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: 30,
            deleteStrategy: .trashItem,
            impactSummary: "如果系统更新尚未安装，删除后需要重新下载"
        ),

        // ── Danger / Diagnosis Tier ──

        CleanRule(
            id: "xcode-archives",
            title: "Xcode 归档文件",
            description: "已打包的 App 归档，可能用于重新导出或符号化崩溃日志",
            paths: [],  // handled by SpaceDiagnosticScanner as top-level archives
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "删除后无法重新导出该版本 App，崩溃日志可能无法符号化"
        ),

        CleanRule(
            id: "ios-backup",
            title: "iOS 设备备份",
            description: "iPhone/iPad 的本地备份数据，可能包含照片、消息、应用数据",
            paths: [],  // handled by SpaceDiagnosticScanner as individual backups
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含用户数据，删除后无法恢复该备份。建议通过访达或 Apple 设备管理备份"
        ),

        CleanRule(
            id: "orphan-files",
            title: "可能的应用残留",
            description: "未匹配到已安装应用的残留文件，可能属于已卸载应用",
            paths: [],  // handled by OrphanScanner
            category: .orphan,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perFile,
            minAgeDays: nil,
            deleteStrategy: .trashItem,
            impactSummary: "如果属于仍在使用但未通过 bundle ID 匹配的应用，删除后可能导致配置丢失"
        ),

        // ── Space Diagnosis Tier ──

        CleanRule(
            id: "time-machine-snapshots",
            title: "Time Machine 本地快照",
            description: "macOS 自动创建的 APFS 本地快照。可释放空间但不建议在此清理——请在系统设置 > 通用 > 存储空间中管理",
            paths: [],  // handled by SpaceDiagnosticScanner via tmutil
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含用户文件的历史版本。建议使用系统设置管理而非手动清理"
        ),

        CleanRule(
            id: "mail-downloads",
            title: "邮件下载与附件",
            description: "Mail.app 下载的邮件内容和附件",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含邮件附件和下载内容。建议在 Mail.app 中管理，不要直接删除"
        ),

        CleanRule(
            id: "messages-attachments",
            title: "信息附件",
            description: "iMessage 中的图片、视频等附件文件",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含聊天附件。建议在信息.app 中管理，不要直接删除"
        ),

        CleanRule(
            id: "docker-data",
            title: "Docker 数据",
            description: "Docker Desktop 的镜像、容器、卷和构建缓存",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "可能包含数据库卷、开发环境和镜像。建议使用 Docker Desktop 或 docker system df/prune 判断"
        ),

        CleanRule(
            id: "wechat-data",
            title: "微信数据",
            description: "微信聊天文件、缓存和接收的媒体内容",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含聊天文件和媒体。建议在微信内清理，不要直接删除数据库或账号数据"
        ),

        CleanRule(
            id: "qq-data",
            title: "QQ 数据",
            description: "QQ 聊天文件、缓存和接收的媒体内容",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含聊天文件和媒体。建议在 QQ 内清理，不要直接删除账号数据"
        ),

        CleanRule(
            id: "telegram-data",
            title: "Telegram 数据",
            description: "Telegram 下载、媒体缓存和本地数据",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "包含下载文件和媒体缓存。建议在 Telegram 设置中管理存储空间"
        ),

        CleanRule(
            id: "virtual-machines",
            title: "虚拟机镜像",
            description: "Parallels、VMware、UTM、VirtualBox 等虚拟机文件",
            paths: [],  // handled by SpaceDiagnosticScanner
            category: .diagnostic,
            riskLevel: .danger,
            defaultSelected: false,
            deletionUnit: .perDirectory,
            minAgeDays: nil,
            deleteStrategy: .manualOnly,
            impactSummary: "通常包含完整系统磁盘镜像。删除前必须确认虚拟机已不再需要"
        ),
    ]

    /// O(1) lookup by rule ID
    static let byId: [String: CleanRule] = {
        var dict: [String: CleanRule] = [:]
        for rule in all { dict[rule.id] = rule }
        return dict
    }()

    // MARK: - Helpers

    /// Resolve home-relative paths (prefixed with ~) to absolute paths
    static func resolve(path: String) -> String {
        if path.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser.path
                + String(path.dropFirst(1))
        }
        if path == "NSTemporaryDirectory_UP_ONE" {
            let tmp = NSTemporaryDirectory()
            return (tmp as NSString).deletingLastPathComponent
        }
        return path
    }
}
