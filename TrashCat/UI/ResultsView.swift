import SwiftUI
import AppKit

// MARK: - Tier Card (own @State for expansion — isolates re-rendering)

private struct TierCard: View {
    let tier: TierGroup
    let nonCleanableIDs: Set<UUID>
    let cleanableIDs: Set<UUID>
    @Binding var selectedItems: Set<UUID>
    let addIDs: (Set<UUID>) -> Void
    let removeIDs: (Set<UUID>) -> Void

    @State private var isExpanded = false

    private let tint: Color
    private let title: String
    private let icon: String
    private let explanation: String

    init(tier: TierGroup, nonCleanableIDs: Set<UUID>, selectedItems: Binding<Set<UUID>>,
         addIDs: @escaping (Set<UUID>) -> Void, removeIDs: @escaping (Set<UUID>) -> Void) {
        self.tier = tier
        self.nonCleanableIDs = nonCleanableIDs
        self.cleanableIDs = tier.allIds.subtracting(nonCleanableIDs)
        self._selectedItems = selectedItems
        self.addIDs = addIDs
        self.removeIDs = removeIDs

        switch tier.id {
        case "diagnostic":
            tint = .blue; icon = "magnifyingglass.circle"; title = "空间诊断"
            explanation = "这些是占用空间较大的用户数据或开发数据，只用于定位来源，不会被 TrashCat 自动清理。"
        case "trash":
            tint = .green; icon = "trash"; title = "废纸篓"
            explanation = "这些项目已经在废纸篓中，清理后会进入系统废纸篓处理流程。"
        default:
            tint = tier.riskLevel.tint; icon = tier.riskLevel.iconName
            title = tier.riskLevel.displayName; explanation = tier.riskLevel.explanation
        }
    }

    var body: some View {
        let hasCleanable = !cleanableIDs.isEmpty
        let allSel = hasCleanable && cleanableIDs.isSubset(of: selectedItems)
        let someSel = !cleanableIDs.isDisjoint(with: selectedItems)

        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 10) {
                    SelIcon(ids: cleanableIDs, allSel: allSel, someSel: someSel,
                            addIDs: addIDs, removeIDs: removeIDs, size: 18)
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
                        RuleRow(rule: rule, nonCleanableIDs: nonCleanableIDs,
                                selectedItems: $selectedItems, tint: tint,
                                addIDs: addIDs, removeIDs: removeIDs)
                    }
                }.padding(.bottom, 8)
            }
        }.padding(.horizontal, 4)
    }
}

// MARK: - Rule Row

private struct RuleRow: View {
    let rule: RuleGroup
    let cleanableIDs: Set<UUID>
    let nonCleanableIDs: Set<UUID>
    @Binding var selectedItems: Set<UUID>
    let addIDs: (Set<UUID>) -> Void
    let removeIDs: (Set<UUID>) -> Void
    let tint: Color

    @State private var isExpanded = false

    init(rule: RuleGroup, nonCleanableIDs: Set<UUID>, selectedItems: Binding<Set<UUID>>,
         tint: Color, addIDs: @escaping (Set<UUID>) -> Void, removeIDs: @escaping (Set<UUID>) -> Void) {
        self.rule = rule
        self.cleanableIDs = rule.allIds.subtracting(nonCleanableIDs)
        self.nonCleanableIDs = nonCleanableIDs
        self._selectedItems = selectedItems
        self.tint = tint
        self.addIDs = addIDs
        self.removeIDs = removeIDs
    }

    var body: some View {
        let hasCleanable = !cleanableIDs.isEmpty
        let allSel = hasCleanable && cleanableIDs.isSubset(of: selectedItems)
        let someSel = !cleanableIDs.isDisjoint(with: selectedItems)

        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    SelIcon(ids: cleanableIDs, allSel: allSel, someSel: someSel,
                            addIDs: addIDs, removeIDs: removeIDs, size: 13)
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(rule.title).font(.callout).fontWeight(.medium)
                    Spacer()
                    if cleanableIDs.isEmpty {
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
                        AppRow(app: app, nonCleanableIDs: nonCleanableIDs,
                               selectedItems: $selectedItems, tint: tint,
                               addIDs: addIDs, removeIDs: removeIDs)
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
    let cleanableIDs: Set<UUID>
    let nonCleanableIDs: Set<UUID>
    @Binding var selectedItems: Set<UUID>
    let addIDs: (Set<UUID>) -> Void
    let removeIDs: (Set<UUID>) -> Void
    let tint: Color

    @State private var showFiles = false

    private let maxPreview = 15

    init(app: AppGroup, nonCleanableIDs: Set<UUID>, selectedItems: Binding<Set<UUID>>,
         tint: Color, addIDs: @escaping (Set<UUID>) -> Void, removeIDs: @escaping (Set<UUID>) -> Void) {
        self.app = app
        self.cleanableIDs = app.ids.subtracting(nonCleanableIDs)
        self.nonCleanableIDs = nonCleanableIDs
        self._selectedItems = selectedItems
        self.tint = tint
        self.addIDs = addIDs
        self.removeIDs = removeIDs
    }

    var body: some View {
        let hasCleanable = !cleanableIDs.isEmpty
        let allSel = hasCleanable && cleanableIDs.isSubset(of: selectedItems)
        let someSel = !cleanableIDs.isDisjoint(with: selectedItems)

        VStack(spacing: 0) {
            HStack(spacing: 6) {
                SelIcon(ids: cleanableIDs, allSel: allSel, someSel: someSel,
                        addIDs: addIDs, removeIDs: removeIDs, size: 12)
                Text(app.appName).font(.caption).fontWeight(.medium).lineLimit(1)
                Spacer()
                if cleanableIDs.isEmpty {
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
                        HStack(spacing: 4) {
                            Button(action: {
                                if item.isCleanable {
                                    if selectedItems.contains(item.id) { removeIDs([item.id]) }
                                    else { addIDs([item.id]) }
                                }
                            }) {
                                Image(systemName: selectedItems.contains(item.id)
                                      ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedItems.contains(item.id) ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.isCleanable)
                            Text(item.name).font(.caption2).foregroundColor(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            if !item.isCleanable {
                                Text("仅诊断").font(.caption2).foregroundColor(.orange).padding(.horizontal, 2)
                            }
                            Text(item.size.formattedSize).font(.caption2).foregroundColor(.secondary)
                        }.padding(.horizontal, 44).padding(.vertical, 2)
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

// MARK: - Selection Icon (incremental — no O(n) recomputation)

private struct SelIcon: View {
    let ids: Set<UUID>
    let allSel: Bool
    let someSel: Bool
    let addIDs: (Set<UUID>) -> Void
    let removeIDs: (Set<UUID>) -> Void
    let size: CGFloat

    var body: some View {
        if ids.isEmpty {
            Image(systemName: "lock")
                .font(.system(size: size))
                .foregroundColor(.secondary.opacity(0.7))
                .frame(width: 18)
        } else {
            Button(action: {
                if allSel { removeIDs(ids) } else { addIDs(ids) }
            }) {
                Image(systemName: allSel ? "checkmark.square.fill" :
                                    someSel ? "minus.square" : "square")
                    .font(.system(size: size))
                    .foregroundColor(allSel ? .accentColor : .secondary)
                    .frame(width: 18)
            }.buttonStyle(.plain)
        }
    }
}

// MARK: - ResultsView

struct ResultsView: View {
    let summary: ScanSummary
    @ObservedObject var coordinator: ScanCoordinator

    @State private var showConfirmClean = false
    @State private var cleanResult: CleanResult?
    @State private var isCleaning = false
    @State private var selectedItems: Set<UUID> = []
    @State private var selectedSize: Int64 = 0
    @State private var selectedCount: Int = 0

    // Immutable caches
    private let allItems: [CleanItem]
    private let sizeOf: [UUID: Int64]
    private let tierGroups: [TierGroup]
    private let nonCleanableIDs: Set<UUID>
    private let safeNonTrashIDs: Set<UUID>

    init(summary: ScanSummary, coordinator: ScanCoordinator) {
        self.summary = summary
        self.coordinator = coordinator
        let items = summary.results.flatMap { $0.items }
        self.allItems = items
        self.tierGroups = summary.buildTierGroups()

        var sizeMap: [UUID: Int64] = [:]
        for item in items { sizeMap[item.id] = item.size }
        self.sizeOf = sizeMap

        self.nonCleanableIDs = Set(items.filter { !$0.isCleanable }.map { $0.id })
        self.safeNonTrashIDs = Set(items.filter {
            $0.riskLevel == .safe && $0.category != .trash && $0.isCleanable
        }.map { $0.id })
    }

    var body: some View {
        if let result = cleanResult {
            CleanReportView(result: result) { coordinator.state = .idle }
        } else {
            mainView
                .onAppear {
                    let defaults = allItems.filter { $0.defaultSelected && $0.isCleanable }
                    for item in defaults { addItem(item.id) }
                }
        }
    }

    // MARK: - Incremental Selection

    private func addItem(_ id: UUID) {
        guard !selectedItems.contains(id) else { return }
        selectedItems.insert(id)
        selectedSize += sizeOf[id] ?? 0
        selectedCount += 1
    }

    private func removeItem(_ id: UUID) {
        guard selectedItems.contains(id) else { return }
        selectedItems.remove(id)
        selectedSize -= sizeOf[id] ?? 0
        selectedCount -= 1
    }

    private func addIDs(_ ids: Set<UUID>) { for id in ids { addItem(id) } }
    private func removeIDs(_ ids: Set<UUID>) { for id in ids { removeItem(id) } }

    // MARK: - Main

    private var mainView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                if tierGroups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles").font(.system(size: 40)).foregroundColor(.green)
                        Text("你的 Mac 很干净！").font(.headline)
                        Text("没找到任何垃圾文件，好猫表示很满意。").font(.caption).foregroundColor(.secondary)
                    }.padding(40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(tierGroups) { tier in
                            TierCard(tier: tier, nonCleanableIDs: nonCleanableIDs,
                                     selectedItems: $selectedItems,
                                     addIDs: addIDs, removeIDs: removeIDs)
                        }
                    }.padding(12)
                }
            }
            footerView
        }
        .frame(minHeight: 500)
        .sheet(isPresented: $showConfirmClean) { confirmSheet }
    }

    // MARK: - Header

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
                        Text(selectedSize.formattedSize)
                            .font(.title).fontWeight(.bold).foregroundColor(.orange)
                        Text("已选 \(selectedCount)/\(summary.totalFileCount) 项")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }.padding(.vertical, 2)
            }
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if selectedItems != safeNonTrashIDs && !safeNonTrashIDs.isEmpty {
                    Button("选择推荐项") { removeIDs(selectedItems); addIDs(safeNonTrashIDs) }
                        .font(.caption).padding(.leading, 16)
                } else if !selectedItems.isEmpty {
                    Button("取消全选") { removeIDs(selectedItems) }.font(.caption).padding(.leading, 16)
                } else { EmptyView() }
                Spacer()
                Button(action: { showConfirmClean = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("\(cleanupLabel) (\(selectedSize.formattedSize))")
                    }.frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(selectedItems.isEmpty || isCleaning)
                .keyboardShortcut(.return, modifiers: [])
                .padding(16)
                Spacer()
            }
        }
    }

    private var cleanupLabel: String {
        // Check if any selected item is caution/danger by just checking a few items
        for item in allItems where selectedItems.contains(item.id) {
            if item.riskLevel == .danger || item.riskLevel == .caution {
                return "确认后清理"
            }
        }
        return "安全清理"
    }

    // MARK: - Confirm

    private var confirmSheet: some View {
        let byRisk: [(RiskLevel, Int)] = {
            var map: [RiskLevel: Int] = [:]
            for item in allItems where selectedItems.contains(item.id) {
                map[item.riskLevel, default: 0] += 1
            }
            return [RiskLevel.safe, .caution, .danger].compactMap { level in
                map[level].map { (level, $0) }
            }
        }()

        return VStack(spacing: 16) {
            Image(systemName: "trash.fill").font(.system(size: 40)).foregroundColor(.orange)
            Text("确认清理？").font(.title2).fontWeight(.bold)
            VStack(spacing: 2) {
                Text("将移动 \(selectedCount) 个文件到废纸篓")
                Text("共释放 \(selectedSize.formattedSize) 空间")
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
        let cleanable = allItems.filter { selectedItems.contains($0.id) && $0.isCleanable }
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
