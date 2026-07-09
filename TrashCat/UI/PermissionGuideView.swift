import SwiftUI

struct PermissionGuideView: View {
    @Binding var isPresented: Bool
    /// 用户点击"稍后设置"时回调，通知父视图不要再自动弹出。
    var onDefer: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("需要「全磁盘访问」权限")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                Text("TrashCat 需要扫描系统缓存、日志和应用残留，macOS 要求此类操作必须获得你的明确授权。")
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        Text("不会上传任何数据——TrashCat 不出门，断网照常工作")
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        Text("不会删除你的照片、文档、聊天记录或工作文件")
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                        Text("代码全部开源，随时可以审计每一行逻辑")
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: 400)

            // App Translocation 警告
            if PermissionManager.shared.isTranslocated {
                VStack(alignment: .leading, spacing: 4) {
                    Label("检测到 App 移花接木（Translocation）", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("""
                        由于 macOS 安全策略，从 DMG 首次启动的 app 被移到了临时路径，\
                        这会导致即使你授权了全磁盘访问，TrashCat 也无法检测到。

                        解决方法：退出 TrashCat，然后打开「终端」运行：
                        xattr -d com.apple.quarantine /Applications/TrashCat.app
                        再重新启动 TrashCat 即可。
                        """)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
                .frame(maxWidth: 380)
            }

            VStack(alignment: .leading, spacing: 8) {
                StepRow(number: 1, text: "点击下方「打开设置」按钮")
                StepRow(number: 2, text: "在隐私与安全性中找到「全磁盘访问」")
                StepRow(number: 3, text: "打开 TrashCat 旁边的开关")
                StepRow(number: 4, text: "返回 TrashCat——会自动检测，或点下方按钮手动刷新")
            }
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Button("稍后设置") {
                    onDefer?()
                    isPresented = false
                }

                Button("打开设置") {
                    PermissionManager.shared.openFullDiskAccessSettings()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }

            // 用户在系统设置授权后返回 app，主动触发重检。
            // 配合 ContentView 的 didBecomeActive 监听，确保授权后立即关闭引导。
            Button("我已授权，重新检测") {
                if PermissionManager.shared.recheck() {
                    isPresented = false
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(40)
        .frame(width: 540, height: 520)
    }
}

private struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.callout)
        }
    }
}
