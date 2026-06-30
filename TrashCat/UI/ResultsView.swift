import SwiftUI
import AppKit
import Combine

// MARK: - Selection Store

private enum SelectionVisualState: Equatable {
    case locked
    case empty
    case partial
    case full
}

@MainActor
private final class SelectionStore: ObservableObject {
    private let sizeOf: [UUID: Int64]
    private let riskOf: [UUID: RiskLevel]
    private let cleanableIDs: Set<UUID>
    private let recommendedIDs: Set<UUID>
    private let groupIDs: [String: Set<UUID>]
    private let groupTotals: [String: Int]
    private let itemGroups: [UUID: [String]]

    private var unsafeCount = 0
    private var groupSelectedCounts: [String: Int] = [:]

    private(set) var selectedIDs: Set<UUID> = []
    private(set) var selectedSize: Int64 = 0
    private(set) var selectedCount = 0
    private(set) var riskCounts: [RiskLevel: Int] = [:]
    @Published private(set) var epoch = 0

    init(items: [CleanItem], tierGroups: [TierGroup], nonCleanableIDs: Set<UUID>) {
        var sizes: [UUID: Int64] = [:]
        var risks: [UUID: RiskLevel] = [:]
        var cleanable = Set<UUID>()
        var recommended = Set<UUID>()

        for item in items {
            sizes[item.id] = item.size
            let risk = item.riskLevel
            risks[item.id] = risk

            if item.isCleanable {
                cleanable.insert(item.id)
                if risk == .safe && item.category != .trash {
                    recommended.insert(item.id)
                }
            }
        }

        var groups: [String: Set<UUID>] = [:]
        var totals: [String: Int] = [:]
        var memberships: [UUID: [String]] = [:]

        func registerGroup(_ key: String, ids rawIDs: Set<UUID>) {
            let ids = rawIDs.subtracting(nonCleanableIDs).filter { cleanable.contains($0) }
            groups[key] = Set(ids)
            totals[key] = ids.count
            for id in ids {
                memberships[id, default: []].append(key)
            }
        }

        for tier in tierGroups {
            registerGroup(Self.tierKey(tier.id), ids: tier.allIds)
            for rule in tier.rules {
                registerGroup(Self.ruleKey(rule.id), ids: rule.allIds)
                for app in rule.apps {
                    registerGroup(Self.appKey(app.id), ids: app.ids)
                }
            }
        }

        self.sizeOf = sizes
        self.riskOf = risks
        self.cleanableIDs = cleanable
        self.recommendedIDs = recommended
        self.groupIDs = groups
        self.groupTotals = totals
        self.itemGroups = memberships

        let defaultIDs = items.compactMap { item -> UUID? in
            guard cleanable.contains(item.id),
                  risks[item.id]?.defaultSelected == true else { return nil }
            return item.id
        }
        applyInitialSelection(Set(defaultIDs))
    }

    static func tierKey(_ id: String) -> String { "tier:\(id)" }
    static func ruleKey(_ id: String) -> String { "rule:\(id)" }
    static func appKey(_ id: String) -> String { "app:\(id)" }

    var hasSelection: Bool { selectedCount > 0 }
    var hasUnsafeSelection: Bool { unsafeCount > 0 }
    var hasRecommendedSelection: Bool { !recommendedIDs.isEmpty }
    var isRecommendedSelection: Bool { selectedIDs == recommendedIDs }

    var selectedByRisk: [(RiskLevel, Int)] {
        [RiskLevel.safe, .caution, .danger].compactMap { level in
            guard let count = riskCounts[level], count > 0 else { return nil }
            return (level, count)
        }
    }

    func contains(_ id: UUID) -> Bool {
        selectedIDs.contains(id)
    }

    func state(forGroup key: String) -> SelectionVisualState {
        let total = groupTotals[key] ?? 0
        guard total > 0 else { return .locked }

        let count = groupSelectedCounts[key] ?? 0
        if count == 0 { return .empty }
        if count == total { return .full }
        return .partial
    }

    func state(forItem id: UUID) -> SelectionVisualState {
        guard cleanableIDs.contains(id) else { return .locked }
        return selectedIDs.contains(id) ? .full : .empty
    }

    @discardableResult
    func toggleGroup(_ key: String) -> SelectionVisualState {
        let ids = groupIDs[key] ?? []
        guard !ids.isEmpty else { return .locked }

        if state(forGroup: key) == .full {
            mutate { ids.forEach { set($0, selected: false) } }
        } else {
            mutate { ids.forEach { set($0, selected: true) } }
        }
        return state(forGroup: key)
    }

    @discardableResult
    func toggleItem(_ id: UUID) -> SelectionVisualState {
        guard cleanableIDs.contains(id) else { return .locked }

        mutate {
            set(id, selected: !selectedIDs.contains(id))
        }
        return state(forItem: id)
    }

    func selectRecommended() {
        replaceSelection(with: recommendedIDs)
    }

    func clear() {
        replaceSelection(with: [])
    }

    private func replaceSelection(with ids: Set<UUID>) {
        mutate {
            let target = ids.intersection(cleanableIDs)
            for id in selectedIDs.subtracting(target) {
                set(id, selected: false)
            }
            for id in target.subtracting(selectedIDs) {
                set(id, selected: true)
            }
        }
    }

    private func applyInitialSelection(_ ids: Set<UUID>) {
        for id in ids {
            set(id, selected: true)
        }
    }

    private func mutate(_ changes: () -> Void) {
        changes()
        epoch += 1
    }

    private func set(_ id: UUID, selected: Bool) {
        if selected {
            guard cleanableIDs.contains(id), selectedIDs.insert(id).inserted else { return }
            selectedSize += sizeOf[id] ?? 0
            selectedCount += 1

            let risk = riskOf[id] ?? .safe
            riskCounts[risk, default: 0] += 1
            if risk != .safe { unsafeCount += 1 }

            for key in itemGroups[id] ?? [] {
                groupSelectedCounts[key, default: 0] += 1
            }
        } else {
            guard selectedIDs.remove(id) != nil else { return }
            selectedSize -= sizeOf[id] ?? 0
            selectedCount -= 1

            let risk = riskOf[id] ?? .safe
            riskCounts[risk, default: 0] -= 1
            if riskCounts[risk] == 0 { riskCounts.removeValue(forKey: risk) }
            if risk != .safe { unsafeCount -= 1 }

            for key in itemGroups[id] ?? [] {
                groupSelectedCounts[key, default: 0] -= 1
                if groupSelectedCounts[key] == 0 {
                    groupSelectedCounts.removeValue(forKey: key)
                }
            }
        }
    }
}

// MARK: - Selection Icons

private struct GroupSelectionIcon: View {
    let groupKey: String
    let selection: SelectionStore
    let epoch: Int
    let size: CGFloat

    @State private var visual: SelectionVisualState = .empty

    var body: some View {
        selectionButton(visual: visual, size: size) {
            visual = selection.toggleGroup(groupKey)
        }
        .onAppear { sync() }
        .onChange(of: epoch) { _ in sync() }
    }

    private func sync() {
        visual = selection.state(forGroup: groupKey)
    }
}

private struct ItemSelectionIcon: View {
    let itemID: UUID
    let selection: SelectionStore
    let epoch: Int

    @State private var visual: SelectionVisualState = .empty

    var body: some View {
        selectionButton(visual: visual, size: 10) {
            visual = selection.toggleItem(itemID)
        }
        .onAppear { sync() }
        .onChange(of: epoch) { _ in sync() }
    }

    private func sync() {
        visual = selection.state(forItem: itemID)
    }
}

@ViewBuilder
private func selectionButton(
    visual: SelectionVisualState,
    size: CGFloat,
    action: @escaping () -> Void
) -> some View {
    switch visual {
    case .locked:
        Image(systemName: "lock")
            .font(.system(size: size))
            .foregroundColor(.secondary.opacity(0.7))
            .frame(width: 18)
    case .empty, .partial, .full:
        Button(action: action) {
            Image(systemName: iconName(for: visual))
                .font(.system(size: size))
                .foregroundColor(visual == .full ? .accentColor : .secondary)
                .frame(width: 18)
        }
        .buttonStyle(.plain)
    }
}

private func iconName(for visual: SelectionVisualState) -> String {
    switch visual {
    case .locked: return "lock"
    case .empty: return "square"
    case .partial: return "minus.square"
    case .full: return "checkmark.square.fill"
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: TierGroup
    let selection: SelectionStore
    let epoch: Int

    @State private var isExpanded = false

    private let tint: Color
    private let title: String
    private let icon: String
    private let explanation: String
    private let groupKey: String

    init(tier: TierGroup, selection: SelectionStore, epoch: Int) {
        self.tier = tier
        self.selection = selection
        self.epoch = epoch
        self.groupKey = SelectionStore.tierKey(tier.id)

        switch tier.id {
        case "diagnostic":
            tint = .blue
            icon = "magnifyingglass.circle"
            title = "空间诊断"
            explanation = "这些是占用空间较大的用户数据或开发数据，只用于定位来源，不会被 TrashCat 自动清理。"
        case "trash":
            tint = .green
            icon = "trash"
            title = "废纸篓"
            explanation = "这些项目已经在废纸篓中，清理后会进入系统废纸篓处理流程。"
        default:
            tint = tier.riskLevel.tint
            icon = tier.riskLevel.iconName
            title = tier.riskLevel.displayName
            explanation = tier.riskLevel.explanation
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 10) {
                    GroupSelectionIcon(groupKey: groupKey, selection: selection, epoch: epoch, size: 18)
                    Image(systemName: icon).foregroundColor(tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.headline)
                        if !isExpanded {
                            Text(explanation).font(.caption)
                                .foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("\(tier.rules.count) 类").font(.caption).foregroundColor(.secondary)
                    Text(tier.totalSize.formattedSize).font(.body).fontWeight(.medium)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }.padding(12)
            }
            .buttonStyle(.plain)
            .background(tint.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isExpanded {
                VStack(spacing: 4) {
                    Text(explanation).font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.top, 4)

                    ForEach(tier.rules) { rule in
                        RuleRow(rule: rule, selection: selection, epoch: epoch, tint: tint)
                    }
                }.padding(.bottom, 8)
            }
        }.padding(.horizontal, 4)
    }
}

// MARK: - Rule Row

private struct RuleRow: View {
    let rule: RuleGroup
    let selection: SelectionStore
    let epoch: Int
    let tint: Color

    @State private var isExpanded = false

    private var groupKey: String { SelectionStore.ruleKey(rule.id) }
    private var isDiagnosticOnly: Bool { selection.state(forGroup: groupKey) == .locked }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    GroupSelectionIcon(groupKey: groupKey, selection: selection, epoch: epoch, size: 13)
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(rule.title).font(.callout).fontWeight(.medium)
                    Spacer()
                    if isDiagnosticOnly {
                        Text("仅诊断").font(.caption2).foregroundColor(.orange).padding(.horizontal, 4)
                    }
                    Text("\(rule.apps.count) 个应用").font(.caption).foregroundColor(.secondary)
                    Text(rule.totalSize.formattedSize).font(.callout).foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }.padding(.horizontal, 16).padding(.vertical, 6)
            }.buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ruleGuidance
                    ForEach(rule.apps) { app in
                        AppRow(app: app, selection: selection, epoch: epoch)
                    }
                }.padding(.bottom, 4)
            }
            Divider().padding(.leading, 32)
        }
    }

    @ViewBuilder
    private var ruleGuidance: some View {
        if let r = rule.rule {
            VStack(alignment: .leading, spacing: 4) {
                Label(r.description, systemImage: "info.circle")
                Label("影响：\(r.impactSummary)", systemImage: "exclamationmark.circle")
                Label("建议：\(actionText(r))", systemImage: "arrow.right.circle")
            }
            .font(.caption2).foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 34).padding(.vertical, 6)
            .background(Color.primary.opacity(0.025))
        }
    }

    private func actionText(_ r: CleanRule) -> String {
        switch r.deleteStrategy {
        case .manualOnly: return "只做空间诊断，建议在系统设置或对应 App 中处理"
        case .officialTool: return "优先使用官方工具处理"
        case .trashItem:
            switch r.riskLevel {
            case .safe: return "可安全清理"
            case .caution: return "确认影响后再清理"
            case .danger: return "逐项确认后再清理"
            }
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: AppGroup
    let selection: SelectionStore
    let epoch: Int

    @State private var showFiles = false

    private let maxPreview = 15
    private var groupKey: String { SelectionStore.appKey(app.id) }
    private var isDiagnosticOnly: Bool { selection.state(forGroup: groupKey) == .locked }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                GroupSelectionIcon(groupKey: groupKey, selection: selection, epoch: epoch, size: 12)
                Text(app.appName).font(.caption).fontWeight(.medium).lineLimit(1)
                Spacer()
                if isDiagnosticOnly {
                    Text("仅诊断").font(.caption2).foregroundColor(.orange)
                }
                Text("\(app.fileCount) 个文件").font(.caption2).foregroundColor(.secondary)
                Text(app.totalSize.formattedSize).font(.caption).foregroundColor(.secondary)
                Button(action: { showFiles.toggle() }) {
                    Image(systemName: showFiles ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 32).padding(.vertical, 3)
            .contextMenu {
                if let first = app.items.first {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first.path)])
                    }) { Label("在访达中显示", systemImage: "folder") }
                }
            }

            if showFiles {
                VStack(spacing: 0) {
                    ForEach(app.items.prefix(maxPreview)) { item in
                        FileRow(item: item, selection: selection, epoch: epoch)
                    }
                    if app.items.count > maxPreview {
                        Text("...还有 \(app.items.count - maxPreview) 个文件")
                            .font(.caption2).foregroundColor(.secondary)
                            .padding(.horizontal, 44).padding(.vertical, 2)
                    }
                }.padding(.bottom, 4)
            }
            Divider().padding(.leading, 44)
        }
    }
}

private struct FileRow: View {
    let item: CleanItem
    let selection: SelectionStore
    let epoch: Int

    var body: some View {
        HStack(spacing: 4) {
            ItemSelectionIcon(itemID: item.id, selection: selection, epoch: epoch)
            Text(item.name).font(.caption2).foregroundColor(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            if !item.isCleanable {
                Text("仅诊断").font(.caption2).foregroundColor(.orange).padding(.horizontal, 2)
            }
            Text(item.size.formattedSize).font(.caption2).foregroundColor(.secondary)
        }.padding(.horizontal, 44).padding(.vertical, 2)
    }
}

// MARK: - ResultsView

struct ResultsView: View {
    let summary: ScanSummary
    @ObservedObject var coordinator: ScanCoordinator

    @StateObject private var selection: SelectionStore
    @State private var showConfirmClean = false
    @State private var cleanResult: CleanResult?
    @State private var isCleaning = false

    private let allItems: [CleanItem]
    private let tierGroups: [TierGroup]
    private let nonCleanableIDs: Set<UUID>

    init(summary: ScanSummary, coordinator: ScanCoordinator) {
        self.summary = summary
        self.coordinator = coordinator

        let items = summary.results.flatMap { $0.items }
        let groups = summary.buildTierGroups()
        let nonCleanable = Set(items.filter { !$0.isCleanable }.map { $0.id })

        self.allItems = items
        self.tierGroups = groups
        self.nonCleanableIDs = nonCleanable
        self._selection = StateObject(
            wrappedValue: SelectionStore(
                items: items,
                tierGroups: groups,
                nonCleanableIDs: nonCleanable
            )
        )
    }

    var body: some View {
        if let result = cleanResult {
            CleanReportView(result: result) { coordinator.state = .idle }
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                if tierGroups.isEmpty {
                    emptyStateView.padding(40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(tierGroups) { tier in
                            TierCard(tier: tier, selection: selection, epoch: selection.epoch)
                        }
                    }.padding(12)
                }
            }
            footerView
        }
        .frame(minHeight: 500)
        .sheet(isPresented: $showConfirmClean) { confirmSheet }
    }

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("扫描完成").font(.title3).fontWeight(.bold)
                    Text("用时 \(String(format: "%.1f", summary.scanDuration)) 秒")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("重新扫描") { coordinator.startScan() }.font(.caption)
            }
            if !summary.isEmpty {
                HStack(spacing: 24) {
                    VStack {
                        Text(selection.selectedSize.formattedSize)
                            .font(.title).fontWeight(.bold).foregroundColor(.orange)
                        Text("已选 \(selection.selectedCount)/\(summary.totalFileCount) 项")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }.padding(.vertical, 2)
            }
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundColor(.green)
            Text("你的 Mac 很干净！").font(.headline)
            Text("没找到任何垃圾文件，好猫表示很满意。").font(.caption).foregroundColor(.secondary)
        }
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if selection.hasRecommendedSelection && !selection.isRecommendedSelection {
                    Button("选择推荐项") { selection.selectRecommended() }
                        .font(.caption).padding(.leading, 16)
                } else if selection.hasSelection {
                    Button("取消全选") { selection.clear() }
                        .font(.caption).padding(.leading, 16)
                } else {
                    EmptyView()
                }
                Spacer()
                Button(action: { showConfirmClean = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("\(cleanupLabel) (\(selection.selectedSize.formattedSize))")
                    }.frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!selection.hasSelection || isCleaning)
                .keyboardShortcut(.return, modifiers: [])
                .padding(16)
                Spacer()
            }
        }
    }

    private var cleanupLabel: String {
        selection.hasUnsafeSelection ? "确认后清理" : "安全清理"
    }

    private var confirmSheet: some View {
        let byRisk = selection.selectedByRisk

        return VStack(spacing: 16) {
            Image(systemName: "trash.fill").font(.system(size: 40)).foregroundColor(.orange)
            Text("确认清理？").font(.title2).fontWeight(.bold)
            VStack(spacing: 2) {
                Text("将移动 \(selection.selectedCount) 个文件到废纸篓")
                Text("共释放 \(selection.selectedSize.formattedSize) 空间")
                    .foregroundColor(.orange).fontWeight(.medium)
            }.font(.body).multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(byRisk, id: \.0.rawValue) { level, count in
                    HStack(spacing: 6) {
                        Circle().fill(level.tint).frame(width: 8, height: 8)
                        Text(level.displayName).font(.caption).fontWeight(.medium)
                        Spacer()
                        Text("\(count) 项").font(.caption).foregroundColor(.secondary)
                    }
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            if byRisk.contains(where: { $0.0 == .danger }) {
                Text("⚠️ 选中的文件包含谨慎处理项，请确认后继续。")
                    .font(.caption).foregroundColor(.red)
            }
            Text("仅会处理 TrashCat 支持安全清理的项目；空间诊断项不会被清理。")
                .font(.caption).foregroundColor(.secondary)
            Text("文件会先移入废纸篓，后悔了还能恢复。").font(.caption).foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("再想想") { showConfirmClean = false }
                Button("清理！") { showConfirmClean = false; performClean() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: [])
            }.padding(.top, 4)
        }.padding(32).frame(width: 400)
    }

    private func performClean() {
        isCleaning = true
        let selectedIDs = selection.selectedIDs
        let cleanable = allItems.filter { selectedIDs.contains($0.id) && $0.isCleanable }
        Task {
            let result = await CleanManager().clean(items: cleanable)
            await MainActor.run { isCleaning = false; cleanResult = result }
        }
    }
}

extension RiskLevel {
    var tint: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .danger: return .red
        }
    }
}
