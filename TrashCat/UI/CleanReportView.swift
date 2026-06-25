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
                HStack(spacing: 4) {
                    Text("释放了")
                    Text(result.freedSize.formattedSize)
                        .fontWeight(.bold).foregroundColor(.green)
                    Text("空间")
                }
                Text("共 \(result.freedFileCount) 个文件被移入废纸篓")
                    .font(.caption).foregroundColor(.secondary)
                Text("用时 \(String(format: "%.1f", result.duration)) 秒")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .font(.body)

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
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.caption)
                Text("文件在废纸篓里，随时可以恢复")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            // ── Actions ──
            HStack(spacing: 12) {
                Button("打开废纸篓") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: NSHomeDirectory() + "/.Trash")]
                    )
                }
                .font(.caption)

                Button("好的") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [])
            }

            Spacer()
        }
        .padding(40)
    }
}
