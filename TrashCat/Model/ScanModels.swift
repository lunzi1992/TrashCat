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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cache:        return "缓存文件"
        case .browserCache: return "浏览器缓存"
        case .logs:         return "日志文件"
        case .temp:         return "临时文件"
        case .trash:        return "废纸篓"
        case .orphan:       return "可能的应用残留"
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

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var fileCount: Int {
        items.count
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

// MARK: - Formatting Helpers

extension Int64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
