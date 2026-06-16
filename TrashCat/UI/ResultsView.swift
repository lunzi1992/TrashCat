import SwiftUI
import AppKit

private enum ViewMode: String, CaseIterable {
    case byCategory = "按分类"
    case byApp = "按应用"
}

struct ResultsView: View {
    let summary: ScanSummary
    @ObservedObject var coordinator: ScanCoordinator

    @State private var showConfirmClean = false
    @State private var cleanResult: CleanResult?
    @State private var isCleaning = false
    @State private var expandedCategories: Set<String> = []
    @State private var expandedApps: Set<String> = []
    @State private var selectedItems: Set<UUID> = []
    @State private var viewMode: ViewMode = .byCategory

    private let maxPreview = 30

    // MARK: - Derived

    private var allItemIDs: Set<UUID> {
        Set(summary.results.flatMap { $0.items }.map { $0.id })
    }

    private var selectedSize: Int64 {
        summary.results.flatMap { $0.items }
            .filter { selectedItems.contains($0.id) }
            .reduce(0) { $0 + $1.size }
    }

    private var selectedCount: Int {
        selectedItems.count
    }

    var body: some View {
        if let result = cleanResult {
            CleanReportView(result: result) {
                coordinator.state = .idle
            }
        } else {
            mainResultsView
                .onAppear { selectedItems = allItemIDs }
        }
    }

    // MARK: - Main

    private var mainResultsView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            // View mode picker
            if !summary.isEmpty {
                Picker("", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider()

            ScrollView {
                switch viewMode {
                case .byCategory:
                    categoryListView
                case .byApp:
                    appListView
                }
            }

            footerView
        }
        .frame(minHeight: 460)
        .sheet(isPresented: $showConfirmClean) {
            confirmCleanSheet
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("扫描完成")
                        .font(.title3).fontWeight(.bold)
                    Text("用时 \(String(format: "%.1f", summary.scanDuration)) 秒")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(selectedItems == allItemIDs ? "取消全选" : "全选") {
                        if selectedItems == allItemIDs { selectedItems = [] }
                        else { selectedItems = allItemIDs }
                    }
                    .font(.caption)

                    Button("重新扫描") {
                        Task { await coordinator.startScan() }
                    }
                    .font(.caption)
                }
            }

            if summary.isEmpty {
                emptyStateView
            } else {
                HStack(spacing: 24) {
                    VStack {
                        Text(selectedSize.formattedSize)
                            .font(.title).fontWeight(.bold).foregroundColor(.orange)
                        Text("已选 \(selectedCount)/\(summary.totalFileCount) 项")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
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
        .padding(.vertical, 32)
    }

    // MARK: - Category View

    private var categoryListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(summary.results, id: \.category.rawValue) { result in
                if !result.items.isEmpty {
                    categoryRow(result)
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    private func categoryRow(_ result: ScanResult) -> some View {
        let isExpanded = expandedCategories.contains(result.category.rawValue)
        let catIDs = Set(result.items.map { $0.id })
        let allSelected = catIDs.isSubset(of: selectedItems)
        let someSelected = !catIDs.isDisjoint(with: selectedItems)

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: {
                    if allSelected { selectedItems.subtract(catIDs) }
                    else { selectedItems.formUnion(catIDs) }
                }) {
                    Image(systemName: allSelected ? "checkmark.square.fill" :
                                        someSelected ? "minus.square" : "square")
                        .font(.title3)
                        .foregroundColor(allSelected ? .accentColor : .secondary)
                        .frame(width: 24)
                }
                .buttonStyle(.plain)

                // Category info button
                Button(action: {
                    withAnimation {
                        if isExpanded { expandedCategories.remove(result.category.rawValue) }
                        else { expandedCategories.insert(result.category.rawValue) }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: result.category.iconName)
                            .font(.title3).foregroundColor(.accentColor).frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.category.displayName).font(.body)
                            Text(result.category.description)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(result.totalSize.formattedSize).font(.body).fontWeight(.medium)
                            Text("\(result.fileCount) 个文件").font(.caption).foregroundColor(.secondary)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())

            if isExpanded {
                itemList(result.items)
            }
        }
    }

    // MARK: - App View

    private var appListView: some View {
        let grouped = Dictionary(grouping: summary.results.flatMap { $0.items }, by: { $0.appName })
            .sorted(by: { $0.key < $1.key })

        return LazyVStack(spacing: 0) {
            ForEach(grouped, id: \.key) { appName, items in
                let isExpanded = expandedApps.contains(appName)
                let appIDs = Set(items.map { $0.id })
                let allSelected = appIDs.isSubset(of: selectedItems)
                let someSelected = !appIDs.isDisjoint(with: selectedItems)
                let appSize = items.reduce(0) { $0 + $1.size }

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: {
                            if allSelected { selectedItems.subtract(appIDs) }
                            else { selectedItems.formUnion(appIDs) }
                        }) {
                            Image(systemName: allSelected ? "checkmark.square.fill" :
                                                someSelected ? "minus.square" : "square")
                                .font(.title3)
                                .foregroundColor(allSelected ? .accentColor : .secondary)
                                .frame(width: 24)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation {
                                if isExpanded { expandedApps.remove(appName) }
                                else { expandedApps.insert(appName) }
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "app.fill")
                                    .font(.title3).foregroundColor(.accentColor).frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appName).font(.body)
                                    // Show top categories for this app
                                    let cats = Set(items.map { $0.category.displayName }).sorted().prefix(3).joined(separator: "、")
                                    Text(cats).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(appSize.formattedSize).font(.body).fontWeight(.medium)
                                    Text("\(items.count) 项").font(.caption).foregroundColor(.secondary)
                                }
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())

                    if isExpanded {
                        itemList(items)
                    }
                }
                Divider().padding(.leading, 52)
            }
        }
    }

    // MARK: - Item List (shared)

    @ViewBuilder
    private func itemList(_ items: [CleanItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(items.prefix(maxPreview)) { item in
                HStack(spacing: 8) {
                    Button(action: {
                        if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                        else { selectedItems.insert(item.id) }
                    }) {
                        Image(systemName: selectedItems.contains(item.id)
                              ? "checkmark.square.fill" : "square")
                            .font(.system(size: 14))
                            .foregroundColor(selectedItems.contains(item.id) ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1).truncationMode(.middle)

                        HStack(spacing: 6) {
                            Text(item.fileType).font(.caption2).foregroundColor(.accentColor)
                            if viewMode == .byCategory {
                                Text("·").foregroundColor(.secondary)
                                Text(item.appName).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text(item.size.formattedSize)
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 4)
                .contextMenu {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                    }) {
                        Label("在访达中显示", systemImage: "folder")
                    }
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(item.path, forType: .string)
                    }) {
                        Label("拷贝路径", systemImage: "doc.on.doc")
                    }
                }
            }

            if items.count > maxPreview {
                Text("...还有 \(items.count - maxPreview) 个文件")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button(action: { showConfirmClean = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("清理所选 (\(selectedSize.formattedSize))")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedItems.isEmpty || isCleaning)
                .keyboardShortcut(.return, modifiers: [])
                .padding(16)
                Spacer()
            }
        }
    }

    // MARK: - Confirm Sheet

    private var confirmCleanSheet: some View {
        VStack(spacing: 20) {
            Image(systemName: "trash.fill")
                .font(.system(size: 48)).foregroundColor(.orange)
            Text("确认清理？").font(.title2).fontWeight(.bold)
            VStack(spacing: 4) {
                Text("将移动 \(selectedCount) 个文件到废纸篓")
                Text("共释放 \(selectedSize.formattedSize) 空间")
                    .foregroundColor(.orange).fontWeight(.medium)
            }
            .font(.body).multilineTextAlignment(.center)
            Text("文件会先移入废纸篓，后悔了还能从废纸篓恢复。")
                .font(.caption).foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("再想想") { showConfirmClean = false }
                Button("清理！") {
                    showConfirmClean = false
                    performClean()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top, 8)
        }
        .padding(40).frame(width: 400, height: 320)
    }

    // MARK: - Clean

    private func performClean() {
        isCleaning = true
        let items = summary.results.flatMap { $0.items }.filter { selectedItems.contains($0.id) }
        let manager = CleanManager()

        Task {
            let result = await manager.clean(items: items)
            await MainActor.run {
                isCleaning = false
                cleanResult = result
            }
        }
    }
}
