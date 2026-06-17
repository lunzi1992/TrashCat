import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = ScanCoordinator()
    @State private var showPermissionGuide = false

    var body: some View {
        Group {
            switch coordinator.state {
            case .idle:
                idleView
            case .scanning(let category, let progress):
                ScanningView(category: category, progress: progress)
            case .completed(let summary):
                ResultsView(summary: summary, coordinator: coordinator)
            case .error(let message):
                errorView(message)
            }
        }
        .frame(minWidth: 560, minHeight: 500)
        .onAppear {
            // Register rule-based scanners for all path-defined rules
            let ruleScanners: [Scannable] = RuleRegistry.all
                .filter { !$0.paths.isEmpty }
                .map { RuleScanner(rule: $0) }
            coordinator.registerAll(ruleScanners)

            // Special scanners (dynamic paths — browser cache, orphan detection)
            coordinator.register(BrowserCacheScanner())
            coordinator.register(OrphanScanner())
            showPermissionGuide = !PermissionManager.shared.hasFullDiskAccess
        }
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGuideView(isPresented: $showPermissionGuide)
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .cornerRadius(16)

            Text("TrashCat")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("垃圾就像老鼠。我是那只抓老鼠的猫。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer().frame(height: 8)

            // Scan Button
            Button(action: {
                Task {
                    await coordinator.startScan()
                }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 40))
                    Text("开始扫描")
                        .font(.headline)
                    Text("让我闻一闻你的 Mac 里藏了什么")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 220, height: 120)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .keyboardShortcut(.return, modifiers: [])

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("出问题了")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button("重试") {
                coordinator.state = .idle
            }
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(40)
    }
}
