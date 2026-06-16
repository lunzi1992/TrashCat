import SwiftUI

struct ResultsView: View {
    let summary: ScanSummary
    @ObservedObject var coordinator: ScanCoordinator

    @State private var showConfirmClean = false
    @State private var cleanResult: CleanResult?
    @State private var isCleaning = false
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        if let result = cleanResult {
            CleanReportView(result: result) {
                coordinator.state = .idle
            }
        } else {
            mainResultsView
        }
    }

    // MARK: - Main Results

    private var mainResultsView: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Category list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(summary.results, id: \.category.rawValue) { result in
                        if !result.items.isEmpty {
                            categoryRow(result)
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }

            // Footer: clean button
            footerView
        }
        .frame(minHeight: 400)
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
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("用时 \(String(format: "%.1f", summary.scanDuration)) 秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !summary.isEmpty {
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
                        Text(summary.totalSize.formattedSize)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("可释放空间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(summary.totalFileCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("个文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("你的 Mac 很干净！")
                .font(.headline)

            Text("没找到任何垃圾文件，好猫表示很满意。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Category Row

    private func categoryRow(_ result: ScanResult) -> some View {
        let isExpanded = expandedCategories.contains(result.category.rawValue)

        return VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    if isExpanded {
                        expandedCategories.remove(result.category.rawValue)
                    } else {
                        expandedCategories.insert(result.category.rawValue)
                    }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: result.category.iconName)
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.category.displayName)
                            .font(.body)

                        Text(result.category.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(result.totalSize.formattedSize)
                            .font(.body)
                            .fontWeight(.medium)

                        Text("\(result.fileCount) 个文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(result.items.prefix(30)) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Text(item.size.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 3)
                    }

                    if result.items.count > 30 {
                        Text("...还有 \(result.items.count - 30) 个文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 8)
            }
        }
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
                        Text("一键清理 (\(summary.totalSize.formattedSize))")
                    }
                    .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(summary.isEmpty || isCleaning)
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
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("确认清理？")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 4) {
                Text("将移动 \(summary.totalFileCount) 个文件到废纸篓")
                Text("共释放 \(summary.totalSize.formattedSize) 空间")
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
            .font(.body)
            .multilineTextAlignment(.center)

            Text("文件会先移入废纸篓，后悔了还能从废纸篓恢复。")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("再想想") {
                    showConfirmClean = false
                }

                Button("清理！") {
                    showConfirmClean = false
                    performClean()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(width: 400, height: 320)
    }

    // MARK: - Clean Action

    private func performClean() {
        isCleaning = true

        let allItems = summary.results.flatMap { $0.items }
        let manager = CleanManager()

        Task {
            let result = await manager.clean(items: allItems)
            await MainActor.run {
                isCleaning = false
                cleanResult = result
            }
        }
    }
}
