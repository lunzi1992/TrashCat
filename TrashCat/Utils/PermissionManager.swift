import Foundation
import AppKit

final class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    /// Check if the app has Full Disk Access
    var hasFullDiskAccess: Bool {
        // Try to read a protected path — if it works, FDA is granted
        let testPath = "\(NSHomeDirectory())/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    /// Open System Settings → Privacy → Full Disk Access
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
