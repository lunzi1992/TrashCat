import SwiftUI

struct ScanningView: View {
    let category: String
    let progress: Double

    @State private var catFrame = 0
    @State private var dots = ""

    private let catFrames = ["🐱", "😺", "😼", "😾"]
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    private let dotsTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Animated cat
            Text(catFrames[catFrame])
                .font(.system(size: 64))
                .onReceive(timer) { _ in
                    catFrame = (catFrame + 1) % catFrames.count
                }

            // Progress bar
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 260)

            // Current task
            VStack(spacing: 6) {
                Text("正在嗅探...")
                    .font(.headline)

                Text(category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    + Text(dots)
                    .foregroundColor(.secondary)
            }
            .onReceive(dotsTimer) { _ in
                dots = dots.count >= 3 ? "" : dots + "."
            }

            Spacer()

            Text("TrashCat 正在翻你 Mac 的角落...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}
