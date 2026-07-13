import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator: ScanCoordinator
    @State private var showPermissionGuide = false
    @State private var userDismissedGuide = false

    init(coordinator: ScanCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        Group {
            switch coordinator.state {
            case .idle:
                idleView
            case .scanning(let category, let progress, _, _, let filesFound):
                ScanningView(category: category, progress: progress,
                             filesFound: filesFound,
                             onCancel: { coordinator.cancelScan() })
            case .completed(let summary):
                ResultsView(summary: summary, coordinator: coordinator)
            case .error(let message):
                errorView(message)
            }
        }
        .frame(minWidth: 680, idealWidth: 720, minHeight: 500, idealHeight: 540)
        .onAppear {
            // 首次启动：检测 FDA，未授权则弹出引导
            let granted = PermissionManager.shared.hasFullDiskAccess
            showPermissionGuide = !granted
            userDismissedGuide = false
        }
        // 用户从「系统设置」返回 app 时重新检测。
        // 关键：只自动关闭引导（FDA 已授权），不自动弹出（防止无限循环）。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            handlePermissionChange()
        }
        // PermissionManager.recheck() 广播的变化通知。
        .onReceive(NotificationCenter.default.publisher(for: PermissionManager.didChangeNotification)) { _ in
            handlePermissionChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppDelegate.requestPermissionGuideNotification)) { _ in
            userDismissedGuide = false
            showPermissionGuide = true
        }
        .sheet(isPresented: $showPermissionGuide) {
            PermissionGuideView(
                isPresented: $showPermissionGuide,
                onDefer: { userDismissedGuide = true }
            )
        }
    }

    /// FDA 状态变化处理：已授权 → 关闭引导；未授权 → 仅当用户未主动关闭过引导时才弹出。
    private func handlePermissionChange() {
        let granted = PermissionManager.shared.hasFullDiskAccess
        if granted {
            // 权限已获取，关闭引导并重置"已关闭"标记
            showPermissionGuide = false
            userDismissedGuide = false
        } else if !userDismissedGuide {
            // 仅在用户未曾主动关闭引导时才弹出——避免无限循环
            showPermissionGuide = true
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
                requestScan()
            }) {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 44))
                    Text("开始扫描")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("让我闻一闻你的 Mac 里藏了什么")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(width: 320, height: 140)
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

            // Scan history stats (only if we have a history)
            let thisMonth = ScanHistory.thisMonth()
            if thisMonth > 0 || ScanHistory.totalSessions() > 0 {
                VStack(spacing: 2) {
                    if thisMonth > 0 {
                        Text("本月已释放 \(thisMonth.formattedSize)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    Text("累计处理 \(ScanHistory.totalSessions()) 次")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
            }

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

    private func requestScan() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.requestScan()
        } else {
            coordinator.startScan()
        }
    }
}
