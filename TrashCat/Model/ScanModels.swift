import Foundation

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
        case .orphan:       return "应用残留"
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
