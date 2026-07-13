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
    case scanning(currentCategory: String, progress: Double, filesScanned: Int, totalScanUnits: Int, filesFound: Int)
    case completed(ScanSummary)
    case error(String)

    // Backward-compatible accessors
    var categoryText: String {
        if case .scanning(let cat, _, _, _, _) = self { return cat }
        return ""
    }
    var progressValue: Double {
        if case .scanning(_, let p, _, _, _) = self { return p }
        return 0
    }
    var filesScanned: Int {
        if case .scanning(_, _, let s, _, _) = self { return s }
        return 0
    }
    var totalScanUnits: Int {
        if case .scanning(_, _, _, let total, _) = self { return total }
        return 0
    }
    var filesFound: Int {
        if case .scanning(_, _, _, _, let f) = self { return f }
        return 0
    }
}

// MARK: - Scan Coordinator

@MainActor
final class ScanCoordinator: ObservableObject {
    @Published var state: ScanState = .idle

    private var scanners: [Scannable] = []
    private var scanTask: Task<Void, Never>?
    private var scanGeneration = 0
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
        guard !isScanning else { return }

        scanTask?.cancel()
        scanGeneration += 1
        let generation = scanGeneration

        let scannerCount = scanners.count
        state = .scanning(currentCategory: "准备扫描...", progress: 0, filesScanned: 0, totalScanUnits: scannerCount, filesFound: 0)

        scanTask = Task { [scanners] in
            let totalScanUnits = scanners.count
            let total = Double(max(totalScanUnits, 1))
            let startTime = Date()

            // Update progress as each scanner completes
            let outcomes = await withTaskGroup(
                of: (Int, ScanResult?, ScanIssue?).self
            ) { group in
                for (index, scanner) in scanners.enumerated() {
                    group.addTask {
                        guard !Task.isCancelled else { return (index, nil, nil) }
                        do {
                            let result = try await scanner.scan()
                            return (index, result, nil)
                        } catch is CancellationError {
                            return (index, nil, nil)
                        } catch {
                            print("[TrashCat] Scanner '\(scanner.category.rawValue)' failed: \(error.localizedDescription)")
                            return (index, nil, ScanIssue(
                                scannerName: scanner.progressLabel,
                                message: error.localizedDescription
                            ))
                        }
                    }
                }

                var collected: [(Int, ScanResult, ScanIssue?)] = []
                var completedCount = 0
                var totalFilesFound = 0

                for await (index, maybeResult, issue) in group {
                    completedCount += 1
                    let prog = Double(completedCount) / total
                    if let result = maybeResult {
                        totalFilesFound += result.items.count
                        collected.append((index, result, issue))
                    } else if let issue {
                        collected.append((index, ScanResult(category: scanners[index].category, items: []), issue))
                    }

                    // Live progress update
                    let label = completedCount < scanners.count
                        ? scanners[min(completedCount, scanners.count - 1)].progressLabel
                        : "收尾中..."
                    await MainActor.run {
                        guard self.scanGeneration == generation else { return }
                        self.state = .scanning(
                            currentCategory: label,
                            progress: prog,
                            filesScanned: completedCount,
                            totalScanUnits: totalScanUnits,
                            filesFound: totalFilesFound
                        )
                    }

                    if Task.isCancelled { break }
                }

                collected.sort { $0.0 < $1.0 }
                return collected
            }

            guard !Task.isCancelled else {
                await MainActor.run {
                    guard self.scanGeneration == generation else { return }
                    self.state = .idle
                }
                return
            }

            let duration = Date().timeIntervalSince(startTime)
            let summary = ScanSummary(
                results: outcomes.map { $0.1 },
                scanDuration: duration,
                issues: outcomes.compactMap { $0.2 }
            )
            await MainActor.run {
                guard self.scanGeneration == generation else { return }
                self.state = .completed(summary)
            }
        }
    }

    /// Run a fresh scan without replacing the current screen. Used after
    /// cleanup to verify that handled paths no longer appear in scan results.
    func verificationScan() async -> ScanSummary {
        let scanners = self.scanners
        let startTime = Date()
        let outcomes = await withTaskGroup(of: (Int, ScanResult?, ScanIssue?).self) { group in
            for (index, scanner) in scanners.enumerated() {
                group.addTask {
                    do {
                        return (index, try await scanner.scan(), nil)
                    } catch {
                        return (index, nil, ScanIssue(scannerName: scanner.progressLabel, message: error.localizedDescription))
                    }
                }
            }
            var values: [(Int, ScanResult?, ScanIssue?)] = []
            for await value in group { values.append(value) }
            return values.sorted { $0.0 < $1.0 }
        }
        return ScanSummary(
            results: outcomes.compactMap { $0.1 },
            scanDuration: Date().timeIntervalSince(startTime),
            issues: outcomes.compactMap { $0.2 }
        )
    }

    func cancelScan() {
        scanGeneration += 1
        scanTask?.cancel()
        scanTask = nil
        state = .idle
    }
}
