import Foundation

// MARK: - Scannable Protocol

protocol Scannable: AnyObject {
    var category: CleanCategory { get }

    /// Scan for cleanable files and return the result.
    /// Should check `Task.isCancelled` periodically and throw `CancellationError` if so.
    func scan() async throws -> ScanResult

    /// The display name shown during scan progress
    var progressLabel: String { get }
}

// MARK: - Scan Progress

enum ScanState: Equatable {
    case idle
    case scanning(currentCategory: String, progress: Double, filesScanned: Int, filesFound: Int)
    case completed(ScanSummary)
    case error(String)

    // Backward-compatible accessors
    var categoryText: String {
        if case .scanning(let cat, _, _, _) = self { return cat }
        return ""
    }
    var progressValue: Double {
        if case .scanning(_, let p, _, _) = self { return p }
        return 0
    }
    var filesScanned: Int {
        if case .scanning(_, _, let s, _) = self { return s }
        return 0
    }
    var filesFound: Int {
        if case .scanning(_, _, _, let f) = self { return f }
        return 0
    }
}

// MARK: - Scan Coordinator

@MainActor
final class ScanCoordinator: ObservableObject {
    @Published var state: ScanState = .idle

    private var scanners: [Scannable] = []
    private var scanTask: Task<Void, Never>?
    var didRegister = false

    var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }

    func register(_ scanner: Scannable) {
        scanners.append(scanner)
    }

    func registerAll(_ newScanners: [Scannable]) {
        scanners.append(contentsOf: newScanners)
    }

    func startScan() {
        scanTask?.cancel()

        state = .scanning(currentCategory: "准备扫描...", progress: 0, filesScanned: 0, filesFound: 0)

        scanTask = Task { [scanners] in
            let total = Double(scanners.count)
            let startTime = Date()

            // Update progress as each scanner completes
            let results = await withTaskGroup(
                of: (Int, ScanResult?).self
            ) { group in
                for (index, scanner) in scanners.enumerated() {
                    group.addTask {
                        guard !Task.isCancelled else { return (index, nil) }
                        do {
                            let result = try await scanner.scan()
                            return (index, result)
                        } catch is CancellationError {
                            return (index, nil)
                        } catch {
                            print("[TrashCat] Scanner '\(scanner.category.rawValue)' failed: \(error.localizedDescription)")
                            return (index, ScanResult(category: scanner.category, items: []))
                        }
                    }
                }

                var collected: [(Int, ScanResult)] = []
                var completedCount = 0
                var totalFilesFound = 0

                for await (index, maybeResult) in group {
                    completedCount += 1
                    let prog = Double(completedCount) / total
                    if let result = maybeResult {
                        totalFilesFound += result.items.count
                        collected.append((index, result))
                    }

                    // Live progress update
                    let label = completedCount < scanners.count
                        ? scanners[min(completedCount, scanners.count - 1)].progressLabel
                        : "收尾中..."
                    await MainActor.run {
                        self.state = .scanning(
                            currentCategory: label,
                            progress: prog,
                            filesScanned: completedCount,
                            filesFound: totalFilesFound
                        )
                    }

                    if Task.isCancelled { break }
                }

                collected.sort { $0.0 < $1.0 }
                return collected.map { $0.1 }
            }

            guard !Task.isCancelled else {
                await MainActor.run { self.state = .idle }
                return
            }

            let duration = Date().timeIntervalSince(startTime)
            let summary = ScanSummary(results: results, scanDuration: duration)
            await MainActor.run { self.state = .completed(summary) }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        state = .idle
    }
}
