import SwiftUI
import AppKit

struct CleanReportView: View {
    let result: CleanResult
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // ── Status icon ──
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(result.isSuccess ? .green : .orange)

            Text(result.isSuccess ? "清理完成！" : "部分完成")
                .font(.title2).fontWeight(.bold)

            // ── Summary numbers ──
            VStack(spacing: 4) {
                if result.movedToTrashFileCount > 0 {
                    HStack(spacing: 4) {
                        Text("已移入废纸篓")
                        Text(result.movedToTrashSize.formattedSize)
                            .fontWeight(.bold).foregroundColor(.green)
                    }
                    Text("清空废纸篓后才会真正释放这部分空间")
                        .font(.caption).foregroundColor(.secondary)
                }
                if result.freedFileCount > 0 {
                    HStack(spacing: 4) {
                        Text("已释放")
                        Text(result.freedSize.formattedSize)
                            .fontWeight(.bold).foregroundColor(.green)
                        Text("空间")
                    }
                }
                if result.movedToTrashFileCount == 0 && result.freedFileCount == 0 {
                    Text("没有成功清理任何文件")
                        .foregroundColor(.secondary)
                }
                Text(summaryCountText)
                    .font(.caption).foregroundColor(.secondary)
                Text("用时 \(String(format: "%.1f", result.duration)) 秒")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .font(.body)

            if let verification = result.verification {
                HStack(spacing: 8) {
                    Image(systemName: verification.isVerified ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(verification.isVerified ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verification.isVerified
                             ? "复扫验证通过"
                             : (verification.scanIssueCount > 0 ? "复扫验证不完整" : "复扫发现部分内容仍存在"))
                            .font(.caption).fontWeight(.semibold)
                        Text(verificationText(verification))
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill((verification.isVerified ? Color.green : Color.orange).opacity(0.07)))
                .frame(maxWidth: 340)
            }

            // ── Category breakdown ──
            if !result.categoryBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("清理明细")
                        .font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                    ForEach(result.categoryBreakdown, id: \.0.rawValue) { cat, size, count in
                        HStack(spacing: 8) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                                .frame(width: 16)
                            Text(cat.displayName)
                                .font(.caption)
                            Spacer()
                            Text("\(count) 个文件")
                                .font(.caption2).foregroundColor(.secondary)
                            Text(size.formattedSize)
                                .font(.caption).fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                .frame(maxWidth: 320)
            }

            // ── Errors ──
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(result.errors.prefix(5), id: \.self) { error in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption).foregroundColor(.red)
                            Text(error)
                                .font(.caption).foregroundColor(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    if result.errors.count > 5 {
                        Text("...还有 \(result.errors.count - 5) 个错误")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.05)))
                .frame(maxWidth: 320)
            }

            // ── Recovery hint ──
            if result.movedToTrashFileCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.caption)
                    Text("新清理的文件在废纸篓里，随时可以恢复")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // ── Actions ──
            HStack(spacing: 12) {
                if result.movedToTrashFileCount > 0 {
                    Button("打开废纸篓") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")]
                        )
                    }
                    .font(.caption)
                }

                Button("好的") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
            }

            Spacer()
        }
        .padding(40)
    }

    private var summaryCountText: String {
        var parts: [String] = []
        if result.movedToTrashFileCount > 0 {
            parts.append("\(result.movedToTrashFileCount) 个文件已移入废纸篓")
        }
        if result.freedFileCount > 0 {
            parts.append("\(result.freedFileCount) 个废纸篓项目已清空")
        }
        return parts.isEmpty ? "请查看下方错误信息" : parts.joined(separator: "，")
    }

    private func verificationText(_ verification: CleanVerification) -> String {
        if verification.scanIssueCount > 0 {
            return "有 \(verification.scanIssueCount) 个扫描项未完成，不能确认本次结果"
        }
        if verification.isVerified {
            return "已处理的 \(verification.checkedCount) 个路径未再次出现在扫描结果中"
        }
        return "仍有 \(verification.remainingCount) 项，共 \(verification.remainingSize.formattedSize)，可能已被应用重新生成"
    }
}
