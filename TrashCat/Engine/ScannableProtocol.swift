import Foundation

// MARK: - Scannable Protocol

protocol Scannable: AnyObject {
    var category: CleanCategory { get }

    /// Scan for cleanable files and return the result
    func scan() async throws -> ScanResult

    /// The display name shown during scan progress
    var progressLabel: String { get }
}

// MARK: - Scan Progress

enum ScanState: Equatable {
    case idle
    case scanning(currentCategory: String, progress: Double) // 0.0~1.0
    case completed(ScanSummary)
    case error(String)
}

// MARK: - Scan Coordinator

@MainActor
final class ScanCoordinator: ObservableObject {
    @Published var state: ScanState = .idle

    private var scanners: [Scannable] = []

    func register(_ scanner: Scannable) {
        scanners.append(scanner)
    }

    func registerAll(_ newScanners: [Scannable]) {
        scanners.append(contentsOf: newScanners)
    }

    func startScan() async {
        state = .scanning(currentCategory: "准备扫描...", progress: 0)

        var results: [ScanResult] = []
        let total = Double(scanners.count)
        let startTime = Date()

        for (index, scanner) in scanners.enumerated() {
            let progress = Double(index) / total
            state = .scanning(currentCategory: scanner.progressLabel, progress: progress)

            do {
                let result = try await scanner.scan()
                results.append(result)
            } catch {
                // Log error but continue scanning other categories
                print("[TrashCat] Scanner '\(scanner.category.rawValue)' failed: \(error.localizedDescription)")
                results.append(ScanResult(category: scanner.category, items: []))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let summary = ScanSummary(results: results, scanDuration: duration)
        state = .completed(summary)
    }
}
