import SwiftUI

struct CleanReportView: View {
    let result: CleanResult
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            if result.isSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("清理完成！")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("释放了")
                        Text(result.freedSize.formattedSize)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("空间")
                    }

                    Text("共 \(result.freedFileCount) 个文件被移入废纸篓")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .font(.body)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)

                Text("部分完成")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 6) {
                    Text("释放了 \(result.freedSize.formattedSize)")
                        .fontWeight(.bold)

                    Text("\(result.errors.count) 个文件未能移除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Error details
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.errors.prefix(5), id: \.self) { error in
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.05))
                )
            }

            Text("文件在废纸篓里，随时可以恢复。")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("好的") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])

            Spacer()
        }
        .padding(40)
    }
}
