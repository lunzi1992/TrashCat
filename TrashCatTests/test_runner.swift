#!/usr/bin/env swift

import Foundation

// ────────────────────────────────────────────────────────────
// Standalone test runner for TrashCat pure-logic modules.
// Run:  swift TrashCatTests/test_runner.swift
// ────────────────────────────────────────────────────────────

var passed = 0
var failed = 0
var tests: [(String, () -> Bool)] = []

func test(_ name: String, _ body: @escaping () -> Bool) {
    tests.append((name, body))
}

func assertTrue(_ condition: Bool, _ msg: String = "") -> Bool {
    if !condition { print("  ❌ FAIL: \(msg)") }
    return condition
}

func assertFalse(_ condition: Bool, _ msg: String = "") -> Bool {
    if condition { print("  ❌ FAIL: \(msg)") }
    return !condition
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") -> Bool {
    if a != b { print("  ❌ FAIL: \(msg) — got \(a), expected \(b)") }
    return a == b
}

// ────────────────────────────────────────────────────────────
// Replicate ScanPolicy (pure logic, no AppKit dependency)
// ────────────────────────────────────────────────────────────

let blockedPaths = [
    "/System", "/bin", "/sbin", "/usr",
    "/private/var/db", "/Library/Keychains", "Keychains",
]

func isBlocked(_ path: String) -> Bool {
    for blocked in blockedPaths {
        if path.hasPrefix(blocked) { return true }
    }
    return false
}

// ────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────

// MARK: - ScanPolicy

test("System path is blocked") {
    assertTrue(isBlocked("/System/Library/SomeFile"))
    && assertTrue(isBlocked("/System/Applications"))
}

test("Bin paths are blocked") {
    assertTrue(isBlocked("/bin/bash"))
    && assertTrue(isBlocked("/bin/sh"))
}

test("Sbin is blocked") {
    assertTrue(isBlocked("/sbin/mount"))
}

test("Usr is blocked") {
    assertTrue(isBlocked("/usr/lib/libSystem.dylib"))
    && assertTrue(isBlocked("/usr/local/bin/brew"))
}

test("/private/var/db is blocked") {
    assertTrue(isBlocked("/private/var/db/SomeDB"))
}

test("Keychains paths are blocked") {
    assertTrue(isBlocked("/Library/Keychains/login.keychain-db"))
    && assertTrue(isBlocked("/Users/test/Library/Keychains/some.keychain"))
}

test("User paths are not blocked") {
    assertFalse(isBlocked("/Users/test/Library/Caches/com.apple.Safari"))
    && assertFalse(isBlocked("/Users/test/Library/Logs/app.log"))
    && assertFalse(isBlocked("/tmp/some-file"))
    && assertFalse(isBlocked("/Library/Caches/service"))
}

// MARK: - File Age

let fileManager = FileManager.default

test("meetsAgeRequirement: existing old file passes (7 day rule)") {
    // Create a temp file with old modification date
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("trashcat_test_old.txt")
    try? "test".write(to: tmp, atomically: true, encoding: .utf8)

    // Set mod date to 30 days ago
    let past = Date().addingTimeInterval(-30 * 86400)
    try? fileManager.setAttributes([.modificationDate: past], ofItemAtPath: tmp.path)

    // Check: minAgeDays=7 should pass (file is 30 days old)
    let cal = Calendar.current
    let attrs = try? fileManager.attributesOfItem(atPath: tmp.path)
    let modDate = attrs?[.modificationDate] as? Date
    let age = cal.dateComponents([.day], from: modDate ?? Date(), to: Date()).day ?? 0
    let result = age >= 7

    try? fileManager.removeItem(at: tmp)
    return assertTrue(result, "30-day-old file should pass 7-day age check (age=\(age))")
}

test("meetsAgeRequirement: brand new file fails age check") {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("trashcat_test_new.txt")
    try? "test".write(to: tmp, atomically: true, encoding: .utf8)

    let attrs = try? fileManager.attributesOfItem(atPath: tmp.path)
    let modDate = attrs?[.modificationDate] as? Date
    let age = Calendar.current.dateComponents([.day], from: modDate ?? Date(), to: Date()).day ?? 0
    let result = age < 7

    try? fileManager.removeItem(at: tmp)
    return assertTrue(result, "Brand new file should fail 7-day age check (age=\(age))")
}

test("meetsAgeRequirement: nonexistent file fails") {
    let url = URL(fileURLWithPath: "/tmp/definitely-does-not-exist-xyz-123-456")
    let attrs = try? fileManager.attributesOfItem(atPath: url.path)
    // No attributes -> can't determine age -> should fail (safe default)
    return assertTrue(attrs == nil, "Non-existent file should return nil attributes")
}

// MARK: - Risk paths

// Simulate RiskAssessor logic (pure string matching)
let dangerPaths = ["MobileSync/Backup", "Xcode/Archives"]
let cautionPaths = [
    "Xcode/DerivedData", "Xcode/iOS DeviceSupport", "CoreSimulator/Devices",
    "/private/var/folders", "/Library/Caches", "/Library/Updates",
    "workspaceStorage",
]
let safePaths = [
    "/Caches/", "/Cache/", "/Code Cache/", "/Service Worker/",
    "/cache2/", "/tmp/", "/private/tmp/", "/private/var/tmp/",
    "WebKit/", "/logs/", "/Logs/",
]

func simulateAssess(path: String, category: String) -> String {
    if category == "trash" { return "safe" }
    if category == "orphan" || category == "diagnostic" { return "danger" }
    for dp in dangerPaths { if path.contains(dp) { return "danger" } }
    if category == "browserCache" {
        for sp in safePaths { if path.contains(sp) { return "safe" } }
        return "caution"
    }
    if category == "cache" || category == "temp" {
        for sp in safePaths { if path.contains(sp) { return "safe" } }
        for cp in cautionPaths { if path.contains(cp) { return "caution" } }
        return "safe"
    }
    if category == "logs" { return "safe" }
    return "safe"
}

test("Risk: trash is always safe") {
    assertEqual(simulateAssess(path: "/Users/test/.Trash/file.txt", category: "trash"), "safe")
}

test("Risk: orphan is always danger") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Preferences/com.unknown.plist", category: "orphan"), "danger")
}

test("Risk: diagnostic is always danger") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Mail", category: "diagnostic"), "danger")
}

test("Risk: iOS backup is danger") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Application Support/MobileSync/Backup/abc", category: "cache"), "danger")
}

test("Risk: Xcode archives is danger") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Developer/Xcode/Archives/app.xcarchive", category: "cache"), "danger")
}

test("Risk: Xcode DerivedData is caution") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Developer/Xcode/DerivedData/MyApp-abc", category: "cache"), "caution")
}

test("Risk: system /Library/Caches is caution") {
    assertEqual(simulateAssess(path: "/Library/Caches/com.apple.service", category: "cache"), "caution")
}

test("Risk: /Library/Updates is caution") {
    assertEqual(simulateAssess(path: "/Library/Updates/ProductMetadata.plist", category: "cache"), "caution")
}

test("Risk: user cache is safe") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Caches/Safari/Cache.db", category: "cache"), "safe")
}

test("Risk: browser cache subdir is safe") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Application Support/Google/Chrome/Default/Cache/abc", category: "browserCache"), "safe")
}

test("Risk: browser non-cache path is caution") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Application Support/Google/Chrome/Default/Preferences", category: "browserCache"), "caution")
}

test("Risk: logs are safe") {
    assertEqual(simulateAssess(path: "/Users/test/Library/Logs/App/app.log", category: "logs"), "safe")
}

test("Risk: temp files are safe") {
    assertEqual(simulateAssess(path: "/tmp/some-file.log", category: "temp"), "safe")
}

// ────────────────────────────────────────────────────────────
// Run
// ────────────────────────────────────────────────────────────

print("")
print("═══ TrashCat Test Suite ═══")
print("")

for (name, body) in tests {
    if body() {
        print("  ✅ \(name)")
        passed += 1
    } else {
        print("  ❌ \(name)")
        failed += 1
    }
}

print("")
print("──────────────")
print("\(passed) passed, \(failed) failed, \(tests.count) total")
print("──────────────")

if failed > 0 {
    exit(1)
}
