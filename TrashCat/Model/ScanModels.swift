import Foundation

// MARK: - Risk Level

enum RiskLevel: String, Comparable, CaseIterable {
    case safe    = "recommended"  // 推荐清理
    case caution = "review"       // 需要确认
    case danger  = "warning"      // 谨慎处理

    var displayName: String {
        switch self {
        case .safe:    return "推荐清理"
        case .caution: return "需要确认"
        case .danger:  return "谨慎处理"
        }
    }

    var iconName: String {
        switch self {
        case .safe:    return "checkmark.shield"
        case .caution: return "exclamationmark.shield"
        case .danger:  return "xmark.shield"
        }
    }

    var headerColor: String {
        switch self {
        case .safe:    return "green"
        case .caution: return "orange"
        case .danger:  return "red"
        }
    }

    /// Should items at this level be selected by default?
    var defaultSelected: Bool {
        switch self {
        case .safe:    return true
        case .caution: return false
        case .danger:  return false
        }
    }

    var explanation: String {
        switch self {
        case .safe:
            return "这些是系统或应用的临时缓存、过期日志文件，删除不会影响任何应用正常运行。"
        case .caution:
            return "这些文件删除后应用会在下次启动时重建，但可能短暂影响启动速度或需要重新登录。建议确认后再清理。"
        case .danger:
            return "这些包含用户数据、开发产物或配置残留。删除后可能无法恢复，且相关应用可能立即出现异常。请逐项确认。"
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        let order: [RiskLevel] = [.safe, .caution, .danger]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Clean Category

enum CleanCategory: String, CaseIterable, Identifiable {
    case cache         = "缓存"
    case browserCache  = "浏览器缓存"
    case logs          = "日志"
    case temp          = "临时文件"
    case trash         = "废纸篓"
    case orphan        = "应用残留"
    case diagnostic    = "空间诊断"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cache:        return "缓存文件"
        case .browserCache: return "浏览器缓存"
        case .logs:         return "日志文件"
        case .temp:         return "临时文件"
        case .trash:        return "废纸篓"
        case .orphan:       return "可能的应用残留"
        case .diagnostic:   return "空间诊断"
        }
    }

    var iconName: String {
        switch self {
        case .cache:        return "archivebox"
        case .browserCache: return "globe"
        case .logs:         return "doc.text"
        case .temp:         return "clock"
        case .trash:        return "trash"
        case .orphan:       return "app.dashed"
        case .diagnostic:   return "magnifyingglass.circle"
        }
    }

    var description: String {
        switch self {
        case .cache:        return "系统和应用的缓存数据"
        case .browserCache: return "浏览器缓存，不含书签和密码"
        case .logs:         return "应用产生的日志文件"
        case .temp:         return "系统临时文件夹中的残留"
        case .trash:        return "废纸篓中尚未清空的项目"
        case .orphan:       return "已卸载应用的配置文件残留"
        case .diagnostic:   return "大空间占用诊断（仅展示，不自动清理）"
        }
    }
}

// MARK: - Clean Item

struct CleanItem: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let category: CleanCategory
    var ruleId: String? = nil

    /// Which app this file likely belongs to (derived from path)
    var appName: String {
        FileCategorizer.appName(for: path, category: category)
    }

    /// What kind of file this is (缓存 / 日志 / 配置 / etc.)
    var fileType: String {
        FileCategorizer.fileType(for: path, name: name)
    }

    /// How risky this item is to delete
    var riskLevel: RiskLevel {
        RiskAssessor.assess(path: path, category: category, name: name)
    }

    /// Should this item be selected for cleanup by default?
    var defaultSelected: Bool {
        riskLevel.defaultSelected
    }
}

// MARK: - Scan Result

struct ScanResult: Equatable {
    let category: CleanCategory
    let items: [CleanItem]
    var ruleId: String? = nil

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var fileCount: Int {
        items.count
    }

    /// Human-readable rule title, looked up from the registry
    var ruleTitle: String? {
        guard let id = ruleId else { return nil }
        return RuleRegistry.all.first { $0.id == id }?.title
    }
}

// MARK: - Scan Summary

struct ScanSummary: Equatable {
    let results: [ScanResult]
    let scanDuration: TimeInterval

    var totalSize: Int64 {
        results.reduce(0) { $0 + $1.totalSize }
    }

    var totalFileCount: Int {
        results.reduce(0) { $0 + $1.fileCount }
    }

    var isEmpty: Bool {
        results.allSatisfy { $0.items.isEmpty }
    }
}

// MARK: - Clean Result

struct CleanResult {
    let freedSize: Int64
    let freedFileCount: Int
    let duration: TimeInterval
    let errors: [String]

    var isSuccess: Bool {
        errors.isEmpty
    }
}

// MARK: - Deletion Strategy

enum DeletionUnit: String {
    case perFile         = "逐文件"
    case perDirectory    = "按目录"
    case perApp          = "按应用"
}

enum DeleteStrategy: String {
    case trashItem       = "移入废纸篓"
    case officialTool    = "使用官方工具"
    case manualOnly      = "仅手动清理"
}

// MARK: - Clean Rule

struct CleanRule: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let paths: [String]
    let category: CleanCategory
    let riskLevel: RiskLevel
    let defaultSelected: Bool
    let deletionUnit: DeletionUnit
    let minAgeDays: Int?
    let deleteStrategy: DeleteStrategy
    let impactSummary: String

    static func == (lhs: CleanRule, rhs: CleanRule) -> Bool { lhs.id == rhs.id }
}

// MARK: - Grouped Result (for UX aggregation)

/// Aggregate of items belonging to one app, within one rule.
struct AppGroup: Identifiable {
    let id = UUID()
    let appName: String
    let items: [CleanItem]
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var fileCount: Int { items.count }
    var ids: Set<UUID> { Set(items.map { $0.id }) }
}

/// Aggregate of rules (or categories) containing app-level groups.
struct RuleGroup: Identifiable {
    let id = UUID()
    let title: String
    let apps: [AppGroup]
    var totalSize: Int64 { apps.reduce(0) { $0 + $1.totalSize } }
    var fileCount: Int { apps.reduce(0) { $0 + $1.fileCount } }
    var allIds: Set<UUID> { apps.reduce(into: Set()) { $0.formUnion($1.ids) } }
}

/// Top-level tier grouping: risk level → rules → apps
struct TierGroup: Identifiable {
    let id: String  // uses riskLevel.rawValue
    let riskLevel: RiskLevel
    let rules: [RuleGroup]
    var totalSize: Int64 { rules.reduce(0) { $0 + $1.totalSize } }
    var fileCount: Int { rules.reduce(0) { $0 + $1.fileCount } }
    var allIds: Set<UUID> { rules.reduce(into: Set()) { $0.formUnion($1.allIds) } }
}

extension ScanSummary {
    /// Build the 3-level aggregation: Tier → Rule → App
    func buildTierGroups() -> [TierGroup] {
        let allItems = results.flatMap { $0.items }.filter { $0.category != .trash }
        let trashItems = results.flatMap { $0.items }.filter { $0.category == .trash }

        var tierMap: [RiskLevel: [CleanItem]] = [:]
        for item in allItems {
            tierMap[item.riskLevel, default: []].append(item)
        }

        let levels: [RiskLevel] = [.safe, .caution, .danger]
        var groups: [TierGroup] = []

        for level in levels {
            guard let items = tierMap[level], !items.isEmpty else { continue }
            let rules = buildRuleGroups(from: items)
            groups.append(TierGroup(id: level.rawValue, riskLevel: level, rules: rules))
        }

        // Append trash as a separate tier (always safe)
        if !trashItems.isEmpty {
            let trashApps = buildAppGroups(from: trashItems)
            let trashRule = RuleGroup(title: "废纸篓", apps: trashApps)
            groups.append(TierGroup(id: "trash", riskLevel: .safe, rules: [trashRule]))
        }

        return groups
    }

    private func buildRuleGroups(from items: [CleanItem]) -> [RuleGroup] {
        // Group by rule title (from ruleId → RuleRegistry lookup), fallback to category
        var dict: [String: [CleanItem]] = [:]
        for item in items {
            let key = item.ruleId.flatMap { id in RuleRegistry.all.first(where: { $0.id == id })?.title }
                ?? item.category.displayName
            dict[key, default: []].append(item)
        }
        return dict.map { (title, ruleItems) in
            RuleGroup(title: title, apps: buildAppGroups(from: ruleItems))
        }.sorted { $0.title < $1.title }
    }

    private func buildAppGroups(from items: [CleanItem]) -> [AppGroup] {
        let dict = Dictionary(grouping: items, by: { $0.appName })
        return dict.map { AppGroup(appName: $0.key, items: $0.value) }
            .sorted { $0.totalSize > $1.totalSize }  // largest first
    }
}

// MARK: - Formatting Helpers

extension Int64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
