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
        let order = RiskLevel.allCases
        guard let lhsIdx = order.firstIndex(of: lhs),
              let rhsIdx = order.firstIndex(of: rhs) else { return false }
        return lhsIdx < rhsIdx
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

    /// Whether this item can be cleaned at all through TrashCat.
    /// Returns false for diagnostic items and rules with `manualOnly` delete strategy.
    var isCleanable: Bool {
        if category == .diagnostic { return false }
        if let ruleId = ruleId, let rule = RuleRegistry.byId[ruleId] {
            return rule.deleteStrategy != .manualOnly
        }
        return true
    }

    var rule: CleanRule? {
        guard let ruleId else { return nil }
        return RuleRegistry.byId[ruleId]
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
        return RuleRegistry.byId[id]?.title
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
    var categoryBreakdown: [(CleanCategory, Int64, Int)] = []

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
    let id: String
    let appName: String
    let items: [CleanItem]

    init(appName: String, items: [CleanItem]) {
        let groupKey = items.first?.ruleId ?? items.first.map { "category:\($0.category.rawValue)" } ?? "unknown"
        self.id = "\(groupKey)|\(appName)"
        self.appName = appName
        self.items = items
        self.totalSize = items.reduce(0) { $0 + $1.size }
        self.fileCount = items.count
        self.ids = Set(items.map { $0.id })
    }

    let totalSize: Int64
    let fileCount: Int
    let ids: Set<UUID>
}

/// Aggregate of rules (or categories) containing app-level groups.
struct RuleGroup: Identifiable {
    let id: String
    let ruleId: String?
    let title: String
    let apps: [AppGroup]
    let totalSize: Int64
    let fileCount: Int
    let allIds: Set<UUID>
    var rule: CleanRule? {
        guard let ruleId else { return nil }
        return RuleRegistry.byId[ruleId]
    }
}

/// Top-level tier grouping: risk level → rules → apps
struct TierGroup: Identifiable {
    let id: String
    let riskLevel: RiskLevel
    let rules: [RuleGroup]
    let totalSize: Int64
    let fileCount: Int
    let allIds: Set<UUID>
}

extension ScanSummary {
    /// Build the 3-level aggregation: Tier → Rule → App
    func buildTierGroups() -> [TierGroup] {
        let allItems = results.flatMap { $0.items }.filter {
            $0.category != .trash && $0.category != .diagnostic
        }
        let trashItems = results.flatMap { $0.items }.filter { $0.category == .trash }
        let diagnosticItems = results.flatMap { $0.items }.filter { $0.category == .diagnostic }

        var tierMap: [RiskLevel: [CleanItem]] = [:]
        for item in allItems {
            tierMap[item.riskLevel, default: []].append(item)
        }

        let levels: [RiskLevel] = [.safe, .caution, .danger]
        var groups: [TierGroup] = []

        for level in levels {
            guard let items = tierMap[level], !items.isEmpty else { continue }
            let rules = buildRuleGroups(from: items)
            let tSize = rules.reduce(0) { $0 + $1.totalSize }
            let tCount = rules.reduce(0) { $0 + $1.fileCount }
            let tIds = rules.reduce(into: Set<UUID>()) { $0.formUnion($1.allIds) }
            groups.append(TierGroup(id: level.rawValue, riskLevel: level, rules: rules,
                                    totalSize: tSize, fileCount: tCount, allIds: tIds))
        }

        // Append trash as a separate tier
        if !trashItems.isEmpty {
            let trashApps = buildAppGroups(from: trashItems)
            let aSize = trashApps.reduce(0) { $0 + $1.totalSize }
            let aCount = trashApps.reduce(0) { $0 + $1.fileCount }
            let aIds = trashApps.reduce(into: Set<UUID>()) { $0.formUnion($1.ids) }
            let trashRule = RuleGroup(id: "trash", ruleId: "trash", title: "废纸篓", apps: trashApps,
                                      totalSize: aSize, fileCount: aCount, allIds: aIds)
            groups.append(TierGroup(id: "trash", riskLevel: .safe, rules: [trashRule],
                                    totalSize: aSize, fileCount: aCount, allIds: aIds))
        }

        if !diagnosticItems.isEmpty {
            let rules = buildRuleGroups(from: diagnosticItems)
            let dSize = rules.reduce(0) { $0 + $1.totalSize }
            let dCount = rules.reduce(0) { $0 + $1.fileCount }
            let dIds = rules.reduce(into: Set<UUID>()) { $0.formUnion($1.allIds) }
            groups.append(TierGroup(id: "diagnostic", riskLevel: .danger, rules: rules,
                                    totalSize: dSize, fileCount: dCount, allIds: dIds))
        }

        return groups
    }

    private func buildRuleGroups(from items: [CleanItem]) -> [RuleGroup] {
        // Group by stable rule id, fallback to category.
        let dict = Dictionary(grouping: items) { item in
            item.ruleId ?? "category:\(item.category.rawValue)"
        }

        return dict.map { (key, ruleItems) in
            let apps = buildAppGroups(from: ruleItems)
            let rule = RuleRegistry.byId[key]
            let title = rule?.title ?? ruleItems.first?.category.displayName ?? key
            let rSize = apps.reduce(0) { $0 + $1.totalSize }
            let rCount = apps.reduce(0) { $0 + $1.fileCount }
            let rIds = apps.reduce(into: Set<UUID>()) { $0.formUnion($1.ids) }
            return RuleGroup(id: key, ruleId: rule?.id, title: title, apps: apps,
                             totalSize: rSize, fileCount: rCount, allIds: rIds)
        }.sorted { $0.totalSize > $1.totalSize }
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
