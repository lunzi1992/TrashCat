import SwiftUI
import AppKit

private extension Set {
    mutating func toggleMember(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}

struct ResultsView: View {
    let summary: ScanSummary
    @ObservedObject var coordinator: ScanCoordinator

    @State private var showConfirmClean = false
    @State private var cleanResult: CleanResult?
    @State private var isCleaning = false
    @State private var expandedTiers: Set<String> = []
    @State private var expandedRules: Set<UUID> = []
    @State private var showFiles: Set<UUID> = []
    @State private var selectedItems: Set<UUID> = []

    // MARK: - Derived

    private var tierGroups: [TierGroup] { summary.buildTierGroups() }

    private var selectedSize: Int64 {
        let all = summary.results.flatMap { $0.items }
        return all.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
    }
    private var selectedCount: Int { selectedItems.count }

    private var selectedByRisk: [(RiskLevel, Int)] {
        let all = summary.results.flatMap { $0.items }
        let sel = all.filter { selectedItems.contains($0.id) }
        let map = Dictionary(grouping: sel, by: { $0.riskLevel })
        return [RiskLevel.safe, .caution, .danger].compactMap { level in
            let c = map[level]?.count ?? 0
            return c > 0 ? (level, c) : nil
        }
    }

    private var safeNonTrashIDs: Set<UUID> {
        let all = summary.results.flatMap { $0.items }
        return Set(all.filter { $0.riskLevel == .safe && $0.category != .trash }.map { $0.id })
    }

    /// Items that cannot be cleaned through TrashCat (diagnostic / manualOnly rules).
    private var nonCleanableIDs: Set<UUID> {
        let all = summary.results.flatMap { $0.items }
        return Set(all.filter { !$0.isCleanable }.map { $0.id })
    }

    var body: some View {
        if let result = cleanResult {
            CleanReportView(result: result) { coordinator.state = .idle }
        } else {
            mainView
                .onAppear {
                    let all = summary.results.flatMap { $0.items }
                    selectedItems = Set(all.filter { $0.defaultSelected && $0.isCleanable }.map { $0.id })
                    expandedTiers = Set(tierGroups.map { $0.id })
                }
        }
    }

    // MARK: - Main

    private var mainView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                if tierGroups.isEmpty {
                    emptyStateView.padding(40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(tierGroups) { tier in tierSection(tier) }
                    }.padding(12)
                }
            }
            footerView
        }
        .frame(minHeight: 500)
        .sheet(isPresented: $showConfirmClean) { confirmCleanSheet }
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
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 40)).foregroundColor(.green)
            Text("你的 Mac 很干净！").font(.headline)
            Text("没找到任何垃圾文件，好猫表示很满意。").font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Tier

    private func tierSection(_ tier: TierGroup) -> some View {
        let isExpanded = expandedTiers.contains(tier.id)
        let cleanableIds = tier.allIds.subtracting(nonCleanableIDs)
        let allSel = cleanableIds.isSubset(of: selectedItems)
        let someSel = !cleanableIds.isDisjoint(with: selectedItems)
        let color = tier.riskLevel.tint

        return VStack(spacing: 0) {
            Button(action: { expandedTiers.toggleMember(tier.id) }) {
                HStack(spacing: 10) {
                    Button(action: {
                        if allSel { selectedItems.subtract(cleanableIds) }
                        else { selectedItems.formUnion(cleanableIds) }
                    }) {
                        Image(systemName: allSel ? "checkmark.square.fill"
                                            : someSel ? "minus.square" : "square")
                            .font(.title3).foregroundColor(allSel ? .accentColor : .secondary)
                    }.buttonStyle(.plain)

                    Image(systemName: tier.riskLevel.iconName).foregroundColor(color)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tier.riskLevel.displayName).font(.headline)
                        if !isExpanded {
                            Text(tier.riskLevel.explanation).font(.caption)
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
            .background(color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isExpanded {
                VStack(spacing: 4) {
                    Text(tier.riskLevel.explanation)
                        .font(.caption).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.top, 4)

                    ForEach(tier.rules) { rule in ruleRow(rule, color: color) }
                }.padding(.bottom, 8)
            }
        }.padding(.horizontal, 4)
    }

    // MARK: - Rule

    private func ruleRow(_ rule: RuleGroup, color: Color) -> some View {
        let isExpanded = expandedRules.contains(rule.id)
        let cleanableIds = rule.allIds.subtracting(nonCleanableIDs)
        let allSel = cleanableIds.isSubset(of: selectedItems)
        let someSel = !cleanableIds.isDisjoint(with: selectedItems)

        return VStack(spacing: 0) {
            Button(action: { expandedRules.toggleMember(rule.id) }) {
                HStack(spacing: 8) {
                    Button(action: {
                        if allSel { selectedItems.subtract(cleanableIds) }
                        else { selectedItems.formUnion(cleanableIds) }
                    }) {
                        Image(systemName: allSel ? "checkmark.square.fill"
                                            : someSel ? "minus.square" : "square")
                            .font(.system(size: 13))
                            .foregroundColor(allSel ? .accentColor : .secondary)
                    }.buttonStyle(.plain)

                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(rule.title).font(.callout).fontWeight(.medium)
                    Spacer()
                    Text("\(rule.apps.count) 个应用").font(.caption).foregroundColor(.secondary)
                    Text(rule.totalSize.formattedSize).font(.callout).foregroundColor(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }.padding(.horizontal, 16).padding(.vertical, 6)
            }.buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(rule.apps) { app in appRow(app, color: color) }
                }.padding(.bottom, 4)
            }
            Divider().padding(.leading, 32)
        }
    }

    // MARK: - App

    private func appRow(_ app: AppGroup, color: Color) -> some View {
        let filesShown = showFiles.contains(app.id)
        let cleanableIds = app.ids.subtracting(nonCleanableIDs)
        let allSel = cleanableIds.isSubset(of: selectedItems)
        let someSel = !cleanableIds.isDisjoint(with: selectedItems)

        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button(action: {
                    if allSel { selectedItems.subtract(cleanableIds) }
                    else { selectedItems.formUnion(cleanableIds) }
                }) {
                    Image(systemName: allSel ? "checkmark.square.fill"
                                        : someSel ? "minus.square" : "square")
                        .font(.system(size: 12))
                        .foregroundColor(allSel ? .accentColor : .secondary)
                }.buttonStyle(.plain)

                Text(app.appName).font(.caption).fontWeight(.medium).lineLimit(1)
                Spacer()
                Text("\(app.fileCount) 个文件").font(.caption2).foregroundColor(.secondary)
                Text(app.totalSize.formattedSize).font(.caption).foregroundColor(.secondary)
                Button(action: { showFiles.toggleMember(app.id) }) {
                    Image(systemName: filesShown ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 32).padding(.vertical, 3)
            .contextMenu {
                if let first = app.items.first {
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first.path)]) }
                    ) { Label("在访达中显示", systemImage: "folder") }
                }
            }

            // Files (collapsed by default)
            if filesShown {
                VStack(spacing: 0) {
                    ForEach(app.items.prefix(15)) { item in
                        HStack(spacing: 4) {
                            Button(action: {
                                if item.isCleanable { selectedItems.toggleMember(item.id) }
                            }) {
                                Image(systemName: selectedItems.contains(item.id)
                                      ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedItems.contains(item.id) ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!item.isCleanable)
                            Text(item.name).font(.caption2).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            if !item.isCleanable {
                                Text("仅诊断").font(.caption2).foregroundColor(.orange).padding(.horizontal, 2)
                            }
                            Text(item.size.formattedSize).font(.caption2).foregroundColor(.secondary)
                        }.padding(.horizontal, 44).padding(.vertical, 2)
                    }
                    if app.items.count > 15 {
                        Text("...还有 \(app.items.count - 15) 个文件")
                            .font(.caption2).foregroundColor(.secondary)
                            .padding(.horizontal, 44).padding(.vertical, 2)
                    }
                }.padding(.bottom, 4)
            }
            Divider().padding(.leading, 44)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                if selectedItems != safeNonTrashIDs && !safeNonTrashIDs.isEmpty {
                    Button("选择推荐项") { selectedItems = safeNonTrashIDs }.font(.caption).padding(.leading, 16)
                } else if !selectedItems.isEmpty {
                    Button("取消全选") { selectedItems = [] }.font(.caption).padding(.leading, 16)
                } else { EmptyView() }
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

    // MARK: - Confirm

    private var confirmCleanSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.fill").font(.system(size: 40)).foregroundColor(.orange)
            Text("确认清理？").font(.title2).fontWeight(.bold)
            VStack(spacing: 2) {
                Text("将移动 \(selectedCount) 个文件到废纸篓")
                Text("共释放 \(selectedSize.formattedSize) 空间")
                    .foregroundColor(.orange).fontWeight(.medium)
            }.font(.body).multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(selectedByRisk, id: \.0.rawValue) { level, count in
                    HStack(spacing: 6) {
                        Circle().fill(level.tint).frame(width: 8, height: 8)
                        Text(level.displayName).font(.caption).fontWeight(.medium)
                        Spacer()
                        Text("\(count) 项").font(.caption).foregroundColor(.secondary)
                    }
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            if selectedByRisk.contains(where: { $0.0 == .danger }) {
                Text("⚠️ 选中的文件包含谨慎处理项，请确认后继续。")
                    .font(.caption).foregroundColor(.red)
            }
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
        let items = summary.results.flatMap { $0.items }.filter {
            selectedItems.contains($0.id) && $0.isCleanable
        }
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
