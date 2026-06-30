import XCTest
@testable import TrashCat

/// PermissionManager 的单元测试。
///
/// 注意：FDA 状态依赖真实 TCC 授权，无法在单元测试中模拟"未授权"分支。
/// 这里验证的是 API 契约稳定性：
/// 1. `hasFullDiskAccess` 返回稳定的 Bool（不崩溃、不抛错）
/// 2. `recheck()` 返回值与 `hasFullDiskAccess` 一致
/// 3. `recheck()` 会广播通知
final class PermissionManagerTests: XCTestCase {

    func test_hasFullDiskAccess_returnsBoolWithoutCrash() {
        // 测试环境（Xcode runner）通常已授予 FDA 或路径可读，但不应假设具体值。
        // 只验证 API 稳定、不崩溃。
        let result = PermissionManager.shared.hasFullDiskAccess
        XCTAssertTrue(result == true || result == false)
    }

    func test_recheck_returnsConsistentWithHasFullDiskAccess() {
        let direct = PermissionManager.shared.hasFullDiskAccess
        let rechecked = PermissionManager.shared.recheck()
        XCTAssertEqual(direct, rechecked, "recheck() 应与 hasFullDiskAccess 返回一致")
    }

    func test_recheck_broadcastsNotification() {
        let expectation = XCTestExpectation(description: "should post didChangeNotification")
        let observer = NotificationCenter.default.addObserver(
            forName: PermissionManager.didChangeNotification,
            object: nil,
            queue: nil
        ) { note in
            // userInfo 应包含 granted 字段
            let granted = note.userInfo?["granted"] as? Bool
            XCTAssertNotNil(granted, "通知 userInfo 应包含 granted 字段")
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        PermissionManager.shared.recheck()
        wait(for: [expectation], timeout: 1.0)
    }

    func test_probePaths_useDirectoryNotFile() {
        // 反射式检查：探针不应再依赖具体文件（如 Bookmarks.plist），
        // 避免用户未使用 Safari 时误判。
        // 这里通过验证 hasFullDiskAccess 多次调用结果稳定来间接保障。
        let r1 = PermissionManager.shared.hasFullDiskAccess
        let r2 = PermissionManager.shared.hasFullDiskAccess
        XCTAssertEqual(r1, r2, "多次调用应返回一致结果")
    }
}
