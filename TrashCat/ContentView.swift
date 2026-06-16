import SwiftUI

struct ContentView: View {
    @State private var isScanning = false
    @State private var scanComplete = false

    var body: some View {
        VStack(spacing: 24) {
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
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            // Scan Button
            Button(action: {
                startScan()
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
                .frame(width: 200, height: 120)
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
            .disabled(isScanning)

            if isScanning {
                ProgressView("正在嗅探...")
                    .padding(.top, 16)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 400)
    }

    private func startScan() {
        isScanning = true
        // TODO: Trigger ScanCoordinator
        // Simulate scanning for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isScanning = false
            scanComplete = true
        }
    }
}

#Preview {
    ContentView()
}
