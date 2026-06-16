import SwiftUI

struct PermissionGuideView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("需要「全磁盘访问」权限")
                .font(.title2)
                .fontWeight(.bold)

            Text("""
                为了让 TrashCat 能扫描系统缓存、日志和应用残留，\
                需要你授予「全磁盘访问」权限。

                我们不会上传任何数据，一切都在本地完成。
                """)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            VStack(alignment: .leading, spacing: 8) {
                StepRow(number: 1, text: "点击下方「打开设置」按钮")
                StepRow(number: 2, text: "在隐私与安全性中找到「全磁盘访问」")
                StepRow(number: 3, text: "打开 TrashCat 旁边的开关")
                StepRow(number: 4, text: "返回 TrashCat，开始扫描")
            }
            .padding(.vertical, 8)

            HStack(spacing: 16) {
                Button("稍后设置") {
                    isPresented = false
                }

                Button("打开设置") {
                    PermissionManager.shared.openFullDiskAccessSettings()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 420)
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
