import SwiftUI
import AppKit

private extension Set {
    mutating func toggleMember(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}

private enum GroupMode: String, CaseIterable {
    case byApp = "按应用"
    case byCategory = "按类型"
    case byRule = "按规则"
}

struct ResultsView: View {
    let summary: ScanSummary
    @ObservedObject var coordinator: ScanCoordinator

    @State private var showConfirmClean = false
    @State private var cleanResult: CleanResult?
    @State private var isCleaning = false
    @State private var expandedTiers: Set<String> = []
    @State private var expandedGroups: Set<String> = []
    @State private var selectedItems: Set<UUID> = []
    @State private var selectedSize: Int64 = 0
    @State private var selectedCount: Int = 0
    @State private var groupMode: GroupMode = .byApp

    private let maxPreview = 20

    // Cache — computed once on init
    private let allItems: [CleanItem]
    private let tieredGroups: [(RiskLevel, [CleanItem])]
    private let sizeOf: [UUID: Int64]     // O(1) size lookup

    init(summary: ScanSummary, coordinator: ScanCoordinator) {
        self.summary = summary
        self.coordinator = coordinator
        let items = summary.results.flatMap { $0.items }
        self.allItems = items

        // Pre-build tier groups
        var map: [RiskLevel: [CleanItem]] = [:]
        for item in items { map[item.riskLevel, default: []].append(item) }
        let trashItems = items.filter { $0.category == .trash }
        var tiers: [(RiskLevel, [CleanItem])] = []
        for level: RiskLevel in [.safe, .caution, .danger] {
            let its = (map[level] ?? []).filter { $0.category != .trash }
            if !its.isEmpty { tiers.append((level, its)) }
        }
        if !trashItems.isEmpty { tiers.append((.safe, trashItems)) }
        self.tieredGroups = tiers

        // Size lookup
        var sizeDict: [UUID: Int64] = [:]
        for item in items { sizeDict[item.id] = item.size }
        self.sizeOf = sizeDict
    }

    /// Risk breakdown of currently selected items
    private var selectedByRisk: [(RiskLevel, Int)] {
        var map: [RiskLevel: Int] = [:]
        for item in allItems where selectedItems.contains(item.id) {
            map[item.riskLevel, default: 0] += 1
        }
        let levels: [RiskLevel] = [.safe, .caution, .danger]
        return levels.compactMap { level in
            let count = map[level] ?? 0
            return count > 0 ? (level, count) : nil
        }
    }

    /// All safe items (minus trash)
    private var safeNonTrashIDs: Set<UUID> {
        Set(allItems.filter { $0.riskLevel == .safe && $0.category != .trash }.map { $0.id })
    }

    // MARK: - Incremental Selection Helpers

    private func selectAllIDs(_ ids: Set<UUID>) {
        let toAdd = ids.subtracting(selectedItems)
        selectedItems.formUnion(ids)
        for id in toAdd {
            selectedSize += sizeOf[id] ?? 0
            selectedCount += 1
        }
    }

    private func deselectIDs(_ ids: Set<UUID>) {
        let toRemove = ids.intersection(selectedItems)
        selectedItems.subtract(ids)
        for id in toRemove {
            selectedSize -= sizeOf[id] ?? 0
            selectedCount -= 1
        }
    }

    private func toggleItem(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
            selectedSize -= sizeOf[id] ?? 0
            selectedCount -= 1
        } else {
            selectedItems.insert(id)
            selectedSize += sizeOf[id] ?? 0
            selectedCount += 1
        }
    }

    var body: some View {
        if let result = cleanResult {
            CleanReportView(result: result) { coordinator.state = .idle }
        } else {
            mainResultsView
                .onAppear {
                    let defaults = Set(allItems.filter { $0.defaultSelected }.map { $0.id })
                    selectAllIDs(defaults)
                }
        }
    }

    // MARK: - Main

    private var mainResultsView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            if !summary.isEmpty {
                Picker("", selection: $groupMode) {
                    ForEach(GroupMode.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 6)
            }

            Divider()

            ScrollView {
                if summary.isEmpty {
                    emptyStateView.padding(40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(tieredGroups, id: \.0.rawValue) { tier, items in
                            tierSection(tier: tier, items: items)
                        }
                    }
                    .padding(12)
                }
            }

            footerView
        }
        .frame(minHeight: 500)
        .sheet(isPresented: $showConfirmClean) { confirmCleanSheet }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("扫描完成").font(.title3).fontWeight(.bold)
                    Text("用时 \(String(format: "%.1f", summary.scanDuration)) 秒")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("重新扫描") { Task { await coordinator.startScan() } }.font(.caption)
                }
            }

            if !summary.isEmpty {
                HStack(spacing: 24) {
                    VStack {
                        Text(selectedSize.formattedSize)
                            .font(.title).fontWeight(.bold).foregroundColor(.orange)
                        Text("已选 \(selectedCount)/\(summary.totalFileCount) 项")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundColor(.green)
            Text("你的 Mac 很干净！").font(.headline)
            Text("没找到任何垃圾文件，好猫表示很满意。").font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Tier Section

    private func tierSection(tier: RiskLevel, items: [CleanItem]) -> some View {
        let tierKey = tier.rawValue
        let isExpanded = expandedTiers.contains(tierKey)
        let tierIDs = Set(items.map { $0.id })
        let allSelected = tierIDs.isSubset(of: selectedItems)
        let someSelected = !tierIDs.isDisjoint(with: selectedItems)
        let tierSize = items.reduce(0) { $0 + $1.size }

        // color
        let tintColor: Color = {
            switch tier {
            case .safe:    return .green
            case .caution: return .orange
            case .danger:  return .red
            }
        }()

        return VStack(spacing: 0) {
            // Tier header
            Button(action: {
                expandedTiers.toggleMember(tierKey)
            }) {
                HStack(spacing: 10) {
                    // Checkbox
                    Button(action: {
                        if allSelected { deselectIDs(tierIDs) }
                        else { selectAllIDs(tierIDs) }
                    }) {
                        Image(systemName: allSelected ? "checkmark.square.fill" :
                                            someSelected ? "minus.square" : "square")
                            .font(.title3)
                            .foregroundColor(allSelected ? .accentColor : .secondary)
                            .frame(width: 22)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: tier.iconName)
                        .foregroundColor(tintColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tier.displayName).font(.headline)
                            Text("\(items.count) 项").font(.caption).foregroundColor(.secondary)
                        }
                        if !isExpanded {
                            Text(tier.explanation)
                                .font(.caption).foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Text(tierSize.formattedSize)
                        .font(.body).fontWeight(.medium)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .background(tintColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Expanded content
            if isExpanded {
                VStack(spacing: 4) {
                    Text(tier.explanation)
                        .font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.top, 6)

                    groupedContent(items: items, tier: tier)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Grouped Content

    // MARK: - Grouping

    private func groupItems(_ items: [CleanItem]) -> [(String, [CleanItem])] {
        let dict: [String: [CleanItem]]
        switch groupMode {
        case .byApp:
            dict = Dictionary(grouping: items, by: { $0.appName })
        case .byCategory:
            dict = Dictionary(grouping: items, by: { $0.category.displayName })
        case .byRule:
            dict = Dictionary(grouping: items, by: { item in
                if let rid = item.ruleId, let rule = RuleRegistry.all.first(where: { $0.id == rid }) {
                    return "\(item.category.displayName) → \(rule.title)"
                }
                return item.category.displayName
            })
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    @ViewBuilder
    private func groupedContent(items: [CleanItem], tier: RiskLevel) -> some View {
        let groups = groupItems(items)

        ForEach(Array(groups.enumerated()), id: \.offset) { _, entry in
            let groupName = entry.0
            let groupItems = entry.1
            let groupKey = "\(tier.rawValue)-\(groupName)"
            let isExpanded = expandedGroups.contains(groupKey)
            let groupIDs = Set(groupItems.map { $0.id })
            let allSel = groupIDs.isSubset(of: selectedItems)
            let someSel = !groupIDs.isDisjoint(with: selectedItems)
            let groupSize = groupItems.reduce(0) { $0 + $1.size }

            VStack(spacing: 0) {
                Button(action: {
                    expandedGroups.toggleMember(groupKey)
                }) {
                    HStack(spacing: 8) {
                        Button(action: {
                            if allSel { deselectIDs(groupIDs) }
                            else { selectAllIDs(groupIDs) }
                        }) {
                            Image(systemName: allSel ? "checkmark.square.fill" :
                                                someSel ? "minus.square" : "square")
                                .font(.system(size: 13))
                                .foregroundColor(allSel ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(groupName).font(.callout).fontWeight(.medium)
                        Spacer()
                        Text(groupSize.formattedSize).font(.callout).foregroundColor(.secondary)
                        Text("\(groupItems.count)").font(.caption).foregroundColor(.secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    itemList(groupItems, tier: tier, prefix: groupName)
                }

                Divider().padding(.leading, 40)
            }
        }
    }

    // MARK: - Item List

    @ViewBuilder
    private func itemList(_ items: [CleanItem], tier: RiskLevel, prefix: String) -> some View {
        VStack(spacing: 0) {
            ForEach(items.prefix(maxPreview)) { item in
                HStack(spacing: 6) {
                    Button(action: {
                        toggleItem(item.id)
                    }) {
                        Image(systemName: selectedItems.contains(item.id)
                              ? "checkmark.square.fill" : "square")
                            .font(.system(size: 12))
                            .foregroundColor(selectedItems.contains(item.id) ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).font(.caption).lineLimit(1).truncationMode(.middle)
                        HStack(spacing: 4) {
                            Text(item.fileType).font(.caption2).foregroundColor(.accentColor)
                            if groupMode == .byCategory {
                                Text("·").foregroundColor(.secondary)
                                Text(item.appName).font(.caption2).foregroundColor(.secondary)
                            }
                            if item.category == .orphan {
                                Text("·").foregroundColor(.secondary)
                                Text(RiskAssessor.orphanReason(for: item.path))
                                    .font(.caption2).foregroundColor(.orange)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                    Text(item.size.formattedSize).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 28).padding(.vertical, 3)
                .contextMenu {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                    }) { Label("在访达中显示", systemImage: "folder") }
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.path, forType: .string)
                    }) { Label("拷贝路径", systemImage: "doc.on.doc") }
                }
            }

            if items.count > maxPreview {
                Text("...还有 \(items.count - maxPreview) 个文件")
                    .font(.caption).foregroundColor(.secondary).padding(.vertical, 4)
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if selectedItems != safeNonTrashIDs {
                    Button("选择推荐项") {
                        deselectIDs(selectedItems)
                        selectAllIDs(safeNonTrashIDs)
                    }
                        .font(.caption).padding(.leading, 16)
                } else if selectedItems.isEmpty {
                    // nothing selected
                    EmptyView()
                } else {
                    Button("取消全选") { deselectIDs(selectedItems) }
                        .font(.caption).padding(.leading, 16)
                }
                Spacer()
                Button(action: { showConfirmClean = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清理所选 (\(selectedSize.formattedSize))")
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

    // MARK: - Confirm Sheet

    private var confirmCleanSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.fill").font(.system(size: 40)).foregroundColor(.orange)
            Text("确认清理？").font(.title2).fontWeight(.bold)

            VStack(spacing: 2) {
                Text("将移动 \(selectedCount) 个文件到废纸篓")
                Text("共释放 \(selectedSize.formattedSize) 空间")
                    .foregroundColor(.orange).fontWeight(.medium)
            }.font(.body).multilineTextAlignment(.center)

            // Risk breakdown
            VStack(alignment: .leading, spacing: 4) {
                ForEach(selectedByRisk, id: \.0.rawValue) { level, count in
                    HStack(spacing: 6) {
                        Circle().fill(level.tint).frame(width: 8, height: 8)
                        Text(level.displayName).font(.caption).fontWeight(.medium)
                        Spacer()
                        Text("\(count) 项").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            VStack(spacing: 2) {
                if selectedByRisk.contains(where: { $0.0 == .danger }) {
                    Text("⚠️ 选中的文件包含谨慎处理项，请确认后继续。")
                        .font(.caption).foregroundColor(.red)
                }
                Text("文件会先移入废纸篓，后悔了还能恢复。")
                    .font(.caption).foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                Button("再想想") { showConfirmClean = false }
                Button("清理！") { showConfirmClean = false; performClean() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: [])
            }.padding(.top, 4)
        }.padding(32).frame(width: 380)
    }

    private func performClean() {
        isCleaning = true
        let items = allItems.filter { selectedItems.contains($0.id) }
        Task {
            let result = await CleanManager().clean(items: items)
            await MainActor.run { isCleaning = false; cleanResult = result }
        }
    }
}

extension RiskLevel {
    var tint: Color {
        switch self {
        case .safe:    return .green
        case .caution: return .orange
        case .danger:  return .red
        }
    }
}
