// BLEControllerTests.swift
// LinakControlTests — Verifies MockBLEController behavior and BLEControllerProtocol contract.

import XCTest
import CoreBluetooth
@testable import LinakControlKit

// MARK: - Helpers

private func makeMockDesk(
    name: String = "LINAK Desk",
    rssi: Int = -60
) -> DiscoveredDesk {
    DiscoveredDesk(peripheralId: UUID(), name: name, rssi: rssi)
}

// MARK: - BLEState cases

final class BLEStateTests: XCTestCase {

    func testAllCasesExist() {
        // Each case must be expressible — verifies the enum hasn't silently dropped a case.
        let cases: [BLEState] = [.unknown, .resetting, .unsupported, .unauthorized, .poweredOff, .poweredOn]
        XCTAssertEqual(cases.count, 6)
    }

    func testStateStreamReceivesEmittedValues() async {
        let mock = MockBLEController()
        var received: [BLEState] = []

        let task = Task {
            for await state in mock.stateStream {
                received.append(state)
                if received.count == 2 { break }
            }
        }

        mock.emitState(.poweredOn)
        mock.emitState(.poweredOff)
        await task.value

        XCTAssertEqual(received, [.poweredOn, .poweredOff])
    }
}

// MARK: - Scan behavior

final class MockBLEControllerScanTests: XCTestCase {

    func testScanYieldsAllMockDesks() async {
        let mock = MockBLEController()
        mock.mockDesks = [
            makeMockDesk(name: "Desk A"),
            makeMockDesk(name: "Desk B"),
        ]

        var discovered: [DiscoveredDesk] = []
        for await desk in mock.scanForPeripherals() {
            discovered.append(desk)
        }

        XCTAssertEqual(discovered.count, 2)
        XCTAssertEqual(discovered[0].name, "Desk A")
        XCTAssertEqual(discovered[1].name, "Desk B")
    }

    func testScanTerminatesAfterYieldingAllDesks() async {
        let mock = MockBLEController()
        mock.mockDesks = [makeMockDesk()]

        var count = 0
        for await _ in mock.scanForPeripherals() {
            count += 1
        }
        // Stream must finish — test will hang (and timeout) if it doesn't.
        XCTAssertEqual(count, 1)
    }

    func testScanWithNoMockDesksTerminatesImmediately() async {
        let mock = MockBLEController()
        mock.mockDesks = []

        var count = 0
        for await _ in mock.scanForPeripherals() {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }

    func testDiscoveredDeskPreservesRSSI() async {
        let mock = MockBLEController()
        mock.mockDesks = [makeMockDesk(rssi: -45)]

        var desks: [DiscoveredDesk] = []
        for await desk in mock.scanForPeripherals() {
            desks.append(desk)
        }

        XCTAssertEqual(desks.first?.rssi, -45)
    }
}

// MARK: - Connect behavior

final class MockBLEControllerConnectTests: XCTestCase {

    func testConnectSucceedsWhenNotConfiguredToFail() async throws {
        let mock = MockBLEController()
        // Must not throw
        try await mock.connect(peripheralId: UUID())
    }

    func testConnectThrowsWhenShouldFailConnectIsTrue() async {
        let mock = MockBLEController()
        mock.shouldFailConnect = true

        do {
            try await mock.connect(peripheralId: UUID())
            XCTFail("Expected connect to throw BLEError.connectionFailed")
        } catch BLEError.connectionFailed {
            // Expected path
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testConnectRespectsConnectDelay() async throws {
        let mock = MockBLEController()
        mock.connectDelay = .milliseconds(50)

        let start = ContinuousClock().now
        try await mock.connect(peripheralId: UUID())
        let elapsed = ContinuousClock().now - start

        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(50))
    }
}

// MARK: - Write capture

final class MockBLEControllerWriteTests: XCTestCase {

    func testWriteCapturesDataAndCharacteristic() async throws {
        let mock = MockBLEController()
        let data = DeskCommand.wakeUp
        let uuid = DeskUUID.command

        try await mock.write(data: data, to: uuid, type: .withoutResponse)

        XCTAssertEqual(mock.writtenData.count, 1)
        XCTAssertEqual(mock.writtenData[0].data, data)
        XCTAssertEqual(mock.writtenData[0].characteristic, uuid)
    }

    func testMultipleWritesAreAppendedInOrder() async throws {
        let mock = MockBLEController()

        try await mock.write(data: DeskCommand.wakeUp, to: DeskUUID.command, type: .withoutResponse)
        try await mock.write(data: DeskCommand.moveUp, to: DeskUUID.command, type: .withoutResponse)
        try await mock.write(data: DeskCommand.stop, to: DeskUUID.command, type: .withoutResponse)

        XCTAssertEqual(mock.writtenData.count, 3)
        XCTAssertEqual(mock.writtenData[0].data, DeskCommand.wakeUp)
        XCTAssertEqual(mock.writtenData[1].data, DeskCommand.moveUp)
        XCTAssertEqual(mock.writtenData[2].data, DeskCommand.stop)
    }

    func testWriteToTargetHeartbeatCapturesCorrectUUID() async throws {
        let mock = MockBLEController()
        let data = DeskCommand.heartbeat

        try await mock.write(data: data, to: DeskUUID.targetHeartbeat, type: .withoutResponse)

        XCTAssertEqual(mock.writtenData.first?.characteristic, DeskUUID.targetHeartbeat)
    }
}

// MARK: - Read behavior

final class MockBLEControllerReadTests: XCTestCase {

    func testReadReturnsMockResponse() async throws {
        let mock = MockBLEController()
        let expected = Data([0x7F, 0x80, 0x1C])
        mock.mockReadResponses[DeskUUID.dpg] = expected

        let result = try await mock.read(DeskUUID.dpg)

        XCTAssertEqual(result, expected)
    }

    func testReadThrowsWhenNoMockResponseConfigured() async {
        let mock = MockBLEController()

        do {
            _ = try await mock.read(DeskUUID.status)
            XCTFail("Expected read to throw BLEError.characteristicNotFound")
        } catch BLEError.characteristicNotFound(let uuid) {
            XCTAssertEqual(uuid, DeskUUID.status)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testReadReturnsDifferentResponsesForDifferentCharacteristics() async throws {
        let mock = MockBLEController()
        let statusData = Data([0x01])
        let dpgData = Data([0x7F, 0x80, 0x04])
        mock.mockReadResponses[DeskUUID.status] = statusData
        mock.mockReadResponses[DeskUUID.dpg] = dpgData

        let statusResult = try await mock.read(DeskUUID.status)
        let dpgResult = try await mock.read(DeskUUID.dpg)

        XCTAssertEqual(statusResult, statusData)
        XCTAssertEqual(dpgResult, dpgData)
    }
}

// MARK: - Notification stream behavior

final class MockBLEControllerNotificationTests: XCTestCase {

    func testNotificationsReturnsConfiguredStream() async {
        let mock = MockBLEController()
        let values: [Data] = [Data([0x01]), Data([0x02]), Data([0x03])]

        let (stream, continuation) = AsyncStream<Data>.makeStream()
        mock.mockNotificationStreams[DeskUUID.height] = stream

        for value in values {
            continuation.yield(value)
        }
        continuation.finish()

        var received: [Data] = []
        for await data in mock.notifications(for: DeskUUID.height) {
            received.append(data)
        }

        XCTAssertEqual(received, values)
    }

    func testNotificationsForUnknownCharacteristicTerminatesImmediately() async {
        let mock = MockBLEController()

        var count = 0
        for await _ in mock.notifications(for: DeskUUID.status) {
            count += 1
        }
        XCTAssertEqual(count, 0)
    }
}

// MARK: - DiscoveredDesk value type

final class DiscoveredDeskTests: XCTestCase {

    func testDiscoveredDeskStoresAllProperties() {
        let id = UUID()
        let desk = DiscoveredDesk(peripheralId: id, name: "Standing Desk", rssi: -72)

        XCTAssertEqual(desk.peripheralId, id)
        XCTAssertEqual(desk.name, "Standing Desk")
        XCTAssertEqual(desk.rssi, -72)
    }
}

// MARK: - Operation deadlines

final class BLEControllerDeadlineTests: XCTestCase {

    /// An unknown UUID lands in the scan-fallback path whose parked
    /// continuation used to be unbounded. With a short connect timeout the
    /// overall deadline must fire (and beat the built-in 6s scan fallback).
    func testConnect_unknownPeripheral_timesOutBeforeScanFallback() async {
        let controller = BLEController(connectTimeout: 0.3)

        let started = ContinuousClock.now
        do {
            try await controller.connect(peripheralId: UUID())
            XCTFail("connect must not succeed for an unknown peripheral")
        } catch {
            guard case BLEError.timeout = error else {
                XCTFail("expected BLEError.timeout, got \(error)")
                return
            }
        }
        let elapsed = ContinuousClock.now - started
        XCTAssertLessThan(
            elapsed, .seconds(4),
            "deadline must fire well before the 6s scan-fallback timer"
        )
    }

    /// A second connect while one is parked must still be rejected fast —
    /// deadlines must not change the concurrency guard.
    func testConnect_concurrentAttempt_stillRejected() async throws {
        let controller = BLEController(connectTimeout: 2)

        async let first: Void = controller.connect(peripheralId: UUID())
        // Let the first call's bleQueue block land and park its continuation
        // before the second connect is enqueued — dispatch ordering across
        // tasks is not guaranteed.
        try await Task.sleep(for: .milliseconds(150))
        do {
            try await controller.connect(peripheralId: UUID())
            XCTFail("concurrent connect must be rejected")
        } catch {
            guard case BLEError.connectionFailed = error else {
                XCTFail("expected BLEError.connectionFailed, got \(error)")
                return
            }
        }
        _ = try? await first
    }
}
