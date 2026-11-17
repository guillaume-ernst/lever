// PeripheralNameTests.swift
// LinakControlTests — Verifies sanitization of untrusted BLE device names.

import XCTest
@testable import LinakControlKit

final class PeripheralNameTests: XCTestCase {

    func testSanitizeReturnsCleanNameUnchanged() {
        XCTAssertEqual(PeripheralName.sanitize("Desk 8965"), "Desk 8965")
    }

    func testSanitizeNilReturnsFallback() {
        XCTAssertEqual(PeripheralName.sanitize(nil), "Unknown")
    }

    func testSanitizeEmptyReturnsFallback() {
        XCTAssertEqual(PeripheralName.sanitize(""), "Unknown")
    }

    func testSanitizeCustomFallback() {
        XCTAssertEqual(PeripheralName.sanitize(nil, fallback: "unknown"), "unknown")
    }

    func testSanitizeStripsNewlines() {
        XCTAssertEqual(
            PeripheralName.sanitize("Desk\n[00:00] [ble] forged entry"),
            "Desk[00:00] [ble] forged entry"
        )
    }

    func testSanitizeStripsCarriageReturnAndTab() {
        XCTAssertEqual(PeripheralName.sanitize("De\tsk\r1"), "Desk1")
    }

    func testSanitizeStripsESCAndCSISequences() {
        // ESC[31m ... ESC[0m — introducer stripped, printable bytes kept.
        XCTAssertEqual(PeripheralName.sanitize("\u{1B}[31mFAKE\u{1B}[0m"), "[31mFAKE[0m")
    }

    func testSanitizeStripsOSCSequences() {
        // OSC 52 clipboard payload — ESC]52;c;...BEL terminator.
        XCTAssertEqual(
            PeripheralName.sanitize("\u{1B}]52;c;aGVsbG8=\u{7}"),
            "]52;c;aGVsbG8="
        )
    }

    func testSanitizeStripsDELAndC1Controls() {
        XCTAssertEqual(PeripheralName.sanitize("A\u{7F}B\u{85}C\u{9B}"), "ABC")
    }

    func testSanitizeKeepsUnicodeLetters() {
        XCTAssertEqual(PeripheralName.sanitize("Bureau Réglé — é"), "Bureau Réglé — é")
    }

    func testSanitizeTruncatesToMaxLength() {
        let long = String(repeating: "a", count: 100)
        let result = PeripheralName.sanitize(long)
        XCTAssertEqual(result.count, PeripheralName.maxLength)
    }

    func testSanitizeTruncatesAfterStripping() {
        // 63 'a' + newline + 10 'b' → 73 chars, truncated to 64.
        let result = PeripheralName.sanitize(String(repeating: "a", count: 63) + "\n" + String(repeating: "b", count: 10))
        XCTAssertEqual(result.count, PeripheralName.maxLength)
        XCTAssertFalse(result.contains("\n"))
    }

    func testSanitizeAllControlsReturnsFallback() {
        XCTAssertEqual(PeripheralName.sanitize("\n\u{1B}\u{7F}"), "Unknown")
    }

    func testDiscoveredDeskSanitizesName() {
        let desk = DiscoveredDesk(peripheralId: UUID(), name: "Desk\nForged", rssi: -50)
        XCTAssertEqual(desk.name, "DeskForged")
    }
}
