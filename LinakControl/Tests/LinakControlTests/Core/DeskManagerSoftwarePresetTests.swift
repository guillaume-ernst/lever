// DeskManagerSoftwarePresetTests.swift
// LinakControlTests — Verifies software preset CRUD, recall, and active detection.

import XCTest
import CoreBluetooth
@testable import LinakControlKit

// MARK: - Test Helpers

/// Result of `makeSoftwarePresetSetup` — a connected manager whose config
/// carries the given software presets, plus a controllable height stream.
private struct SoftwarePresetSetup {
    let manager: DeskManager
    let mock: MockBLEController
    let store: ConfigStore
    let heightCont: AsyncStream<Data>.Continuation
    let presets: [SoftwarePreset]
}

/// Builds a DeskManager connected to a MockBLEController with `presets`
/// pre-seeded in config. The height stream stays open; call
/// `heightCont.yield(makeHeightPacket(mm:))` to inject notifications.
private func makeSoftwarePresetSetup(
    presets: [SoftwarePreset]
) async throws -> SoftwarePresetSetup {
    var heightCont: AsyncStream<Data>.Continuation!
    let heightStream = AsyncStream<Data> { cont in heightCont = cont }

    let mock = MockBLEController()
    mock.mockReadResponses[DeskUUID.outputMask] = HandshakeFixtures.validOutputMask
    mock.mockReadResponses[DeskUUID.height] = HandshakeFixtures.heightNotification730mm
    mock.mockNotificationStreams[DeskUUID.dpg] = makeDPGStream(
        responses: HandshakeFixtures.happyPathDPGResponses
    )
    mock.mockNotificationStreams[DeskUUID.height] = heightStream

    var config = AppConfig.default
    config.softwarePresets = presets
    let store = makeTempConfigStore(tag: "SoftwarePreset", config: config)
    let manager = DeskManager(bleController: mock, configStore: store)

    // Run connect in a task so we can emit the initial height to unblock the handshake.
    let connectTask = Task { try await manager.connect(peripheralId: UUID()) }
    heightCont.yield(makeHeightPacket(mm: 730))
    try await connectTask.value

    return SoftwarePresetSetup(
        manager: manager, mock: mock, store: store,
        heightCont: heightCont, presets: presets
    )
}

private func makeSoftwarePreset(
    name: String = "Test",
    heightMM: Int = 1000
) -> SoftwarePreset {
    SoftwarePreset(name: name, heightMM: heightMM)
}

// MARK: - CRUD Tests

final class DeskManagerSoftwarePresetCRUDTests: XCTestCase {

    func testAddSoftwarePresetPersistsAndUpdatesState() async throws {
        let store = makeTempConfigStore(tag: "AddSW")
        let manager = DeskManager(bleController: MockBLEController(), configStore: store)

        let preset = try await manager.addSoftwarePreset(name: "Stand", heightMM: 1105)

        let state = await manager.currentState
        XCTAssertEqual(state.softwarePresets.count, 1)
        XCTAssertEqual(state.softwarePresets.first?.id, preset.id)
        XCTAssertEqual(state.softwarePresets.first?.name, "Stand")
        XCTAssertEqual(state.softwarePresets.first?.heightMM, 1105)

        let persisted = try store.load()
        XCTAssertEqual(persisted.softwarePresets.count, 1)
        XCTAssertEqual(persisted.softwarePresets.first?.id, preset.id)
    }

    func testUpdateSoftwarePresetRenamesAndRepoints() async throws {
        let existing = makeSoftwarePreset(name: "Sit", heightMM: 700)
        let setup = try await makeSoftwarePresetSetup(presets: [existing])

        try await setup.manager.updateSoftwarePreset(id: existing.id, name: "Desk Low", heightMM: 690)

        let state = await setup.manager.currentState
        XCTAssertEqual(state.softwarePresets.first?.name, "Desk Low")
        XCTAssertEqual(state.softwarePresets.first?.heightMM, 690)

        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.first?.name, "Desk Low")
        XCTAssertEqual(persisted.softwarePresets.first?.heightMM, 690)
    }

    func testUpdateSoftwarePresetPartialFieldsOnly() async throws {
        let existing = makeSoftwarePreset(name: "Sit", heightMM: 700)
        let setup = try await makeSoftwarePresetSetup(presets: [existing])

        // Rename only — height must survive.
        try await setup.manager.updateSoftwarePreset(id: existing.id, name: "Renamed")

        let state = await setup.manager.currentState
        XCTAssertEqual(state.softwarePresets.first?.name, "Renamed")
        XCTAssertEqual(state.softwarePresets.first?.heightMM, 700)
    }

    func testUpdateSoftwarePresetUnknownIdIsNoOp() async throws {
        let setup = try await makeSoftwarePresetSetup(presets: [makeSoftwarePreset()])

        try await setup.manager.updateSoftwarePreset(id: UUID(), name: "Ghost")

        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.count, 1)
        XCTAssertEqual(persisted.softwarePresets.first?.name, "Test")
    }

    func testRemoveSoftwarePresetPersistsAndClearsState() async throws {
        let keep = makeSoftwarePreset(name: "Keep", heightMM: 1000)
        let drop = makeSoftwarePreset(name: "Drop", heightMM: 730)
        let setup = try await makeSoftwarePresetSetup(presets: [keep, drop])

        // The desk sits at 730mm — `drop` matches within tolerance, so it is active.
        await waitFor { await setup.manager.currentState.activeSoftwarePresetID == drop.id }

        try await setup.manager.removeSoftwarePreset(id: drop.id)

        let state = await setup.manager.currentState
        XCTAssertEqual(state.softwarePresets.map(\.id), [keep.id])
        XCTAssertNil(state.activeSoftwarePresetID, "Active marker must clear when its preset is removed")

        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.map(\.id), [keep.id])
    }

    func testMoveSoftwarePresetReordersAndPersists() async throws {
        let a = makeSoftwarePreset(name: "A", heightMM: 700)
        let b = makeSoftwarePreset(name: "B", heightMM: 900)
        let c = makeSoftwarePreset(name: "C", heightMM: 1100)
        let setup = try await makeSoftwarePresetSetup(presets: [a, b, c])

        // Move A below B — destination counts pre-removal indices, so toOffset 2.
        try await setup.manager.moveSoftwarePreset(fromOffsets: [0], toOffset: 2)

        let state = await setup.manager.currentState
        XCTAssertEqual(state.softwarePresets.map(\.name), ["B", "A", "C"])

        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.map(\.name), ["B", "A", "C"])
    }

    func testAddSoftwarePresetRejectsDuplicateName() async throws {
        let setup = try await makeSoftwarePresetSetup(
            presets: [makeSoftwarePreset(name: "Focus")]
        )

        do {
            try await setup.manager.addSoftwarePreset(name: "focus", heightMM: 800)
            XCTFail("Expected DeskError.softwarePresetNameTaken")
        } catch DeskError.softwarePresetNameTaken(let name) {
            XCTAssertEqual(name, "focus")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Nothing was persisted for the rejected add.
        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.count, 1)
    }

    func testUpdateSoftwarePresetRejectsCollidingRename() async throws {
        let a = makeSoftwarePreset(name: "Focus", heightMM: 700)
        let b = makeSoftwarePreset(name: "Stand", heightMM: 1100)
        let setup = try await makeSoftwarePresetSetup(presets: [a, b])

        do {
            try await setup.manager.updateSoftwarePreset(id: b.id, name: "FOCUS")
            XCTFail("Expected DeskError.softwarePresetNameTaken")
        } catch DeskError.softwarePresetNameTaken {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.map(\.name), ["Focus", "Stand"])
    }

    func testUpdateSoftwarePresetAllowsRenameToSameName() async throws {
        let preset = makeSoftwarePreset(name: "Focus", heightMM: 700)
        let setup = try await makeSoftwarePresetSetup(presets: [preset])

        // Renaming a preset to its own (case-variant) name must not collide
        // with itself.
        try await setup.manager.updateSoftwarePreset(id: preset.id, name: "focus")

        let persisted = try setup.store.load()
        XCTAssertEqual(persisted.softwarePresets.first?.name, "focus")
    }
}

// MARK: - Recall Tests

final class DeskManagerSoftwarePresetRecallTests: XCTestCase {

    func testGoToSoftwarePresetSendsMoveToTarget() async throws {
        let preset = makeSoftwarePreset(name: "Stand", heightMM: 1105)
        let setup = try await makeSoftwarePresetSetup(presets: [preset])
        let priorCount = setup.mock.writtenData.count

        let goToTask = Task { try await setup.manager.goToSoftwarePreset(id: preset.id) }

        // Let the loop run a few iterations before arriving.
        try await Task.sleep(for: .milliseconds(350))
        setup.heightCont.yield(makeHeightPacket(mm: 1105))
        setup.heightCont.finish()

        try await goToTask.value

        let expectedTarget = DeskCommand.moveTo(tenthsOfMm: UInt16(1105 * 10))
        let heartbeatWrites = setup.mock.writtenData.dropFirst(priorCount).filter {
            $0.characteristic == DeskUUID.targetHeartbeat && $0.data == expectedTarget
        }
        XCTAssertGreaterThanOrEqual(
            heartbeatWrites.count, 2,
            "goToSoftwarePreset must send move-to 1105mm to targetHeartbeat repeatedly"
        )
    }

    func testGoToSoftwarePresetSetsAndClearsTarget() async throws {
        let preset = makeSoftwarePreset(name: "Stand", heightMM: 1105)
        let setup = try await makeSoftwarePresetSetup(presets: [preset])

        let goToTask = Task { try await setup.manager.goToSoftwarePreset(id: preset.id) }

        await waitFor { await setup.manager.currentState.targetSoftwarePresetID == preset.id }
        let movingTarget = await setup.manager.currentState.targetSoftwarePresetID
        XCTAssertEqual(
            movingTarget, preset.id,
            "targetSoftwarePresetID must mark the software preset during movement"
        )
        let hardwareTarget = await setup.manager.currentState.targetPreset
        XCTAssertNil(hardwareTarget)

        setup.heightCont.yield(makeHeightPacket(mm: 1105))
        setup.heightCont.finish()
        try await goToTask.value

        // The recall loop clears state after goTo returns; give it time.
        await waitFor { await setup.manager.currentState.targetSoftwarePresetID == nil }
        let clearedTarget = await setup.manager.currentState.targetSoftwarePresetID
        XCTAssertNil(clearedTarget)
    }

    func testGoToSoftwarePresetUnknownIdThrows() async throws {
        let setup = try await makeSoftwarePresetSetup(presets: [])

        do {
            try await setup.manager.goToSoftwarePreset(id: UUID())
            XCTFail("Expected DeskError.softwarePresetNotFound")
        } catch DeskError.softwarePresetNotFound {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGoToSoftwarePresetThrowsNotConnectedWhenNoPairing() async {
        let manager = DeskManager(
            bleController: MockBLEController(),
            configStore: makeTempConfigStore(tag: "SWNotConnected")
        )

        do {
            try await manager.goToSoftwarePreset(id: UUID())
            XCTFail("Expected DeskError.notConnected")
        } catch DeskError.notConnected {
            // expected — ensureConnectedForAction runs before the id lookup
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Active Detection Tests

final class ActiveSoftwarePresetDetectionTests: XCTestCase {

    private let a = SoftwarePreset(name: "A", heightMM: 700)
    private let b = SoftwarePreset(name: "B", heightMM: 1105)

    func testMatchesPresetWithinTolerance() {
        let id = activeSoftwarePreset(height: 1103, presets: [a, b], isMoving: false)
        XCTAssertEqual(id, b.id)
    }

    func testClosestMatchWinsOnOverlap() {
        // Two presets within tolerance of 702mm — A (700) is closer than a
        // hypothetical 706mm entry.
        let near = SoftwarePreset(name: "Near", heightMM: 706)
        let id = activeSoftwarePreset(height: 702, presets: [a, near], isMoving: false)
        XCTAssertEqual(id, a.id)
    }

    func testNilWhileMoving() {
        XCTAssertNil(activeSoftwarePreset(height: 700, presets: [a], isMoving: true))
    }

    func testNilWhenNoneInRange() {
        XCTAssertNil(activeSoftwarePreset(height: 900, presets: [a, b], isMoving: false))
    }
}

// MARK: - Config Persistence Tests

final class SoftwarePresetConfigTests: XCTestCase {

    func testConfigRoundTripsSoftwarePresets() throws {
        var config = AppConfig.default
        config.softwarePresets = [
            SoftwarePreset(name: "Sit", heightMM: 700),
            SoftwarePreset(name: "Stand", heightMM: 1105),
        ]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.softwarePresets.count, 2)
        XCTAssertEqual(decoded.softwarePresets[0].name, "Sit")
        XCTAssertEqual(decoded.softwarePresets[0].heightMM, 700)
        XCTAssertEqual(decoded.softwarePresets[1].name, "Stand")
    }

    func testConfigWithoutSoftwarePresetsDecodesEmpty() throws {
        // A config written before the feature existed carries no key at all.
        let json = """
        {"unit": "cm", "preset_labels": [null, null, null, null]}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppConfig.self, from: json)
        XCTAssertEqual(decoded.softwarePresets, [])
    }

    func testSoftwarePresetMissingIdGetsFreshOne() throws {
        let json = """
        {"name": "Stand", "height_mm": 1105}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SoftwarePreset.self, from: json)
        XCTAssertNotNil(decoded.id)
        XCTAssertEqual(decoded.name, "Stand")
        XCTAssertEqual(decoded.heightMM, 1105)
    }
}

// MARK: - Generated Name Tests

final class SoftwarePresetNamingTests: XCTestCase {

    func testUniquePresetNameStartsAtFive() {
        XCTAssertEqual(DeskViewModel.uniquePresetName(existing: []), "Preset 5")
    }

    func testUniquePresetNameSkipsTaken() {
        XCTAssertEqual(
            DeskViewModel.uniquePresetName(existing: ["Preset 5", "Preset 6"]),
            "Preset 7"
        )
    }

    func testUniquePresetNameCaseInsensitive() {
        XCTAssertEqual(DeskViewModel.uniquePresetName(existing: ["preset 5"]), "Preset 6")
    }

    func testUniquePresetNameIgnoresUnrelatedNames() {
        XCTAssertEqual(DeskViewModel.uniquePresetName(existing: ["Focus", "Stand"]), "Preset 5")
    }

    func testUniquePresetNameFillsGaps() {
        // User deleted Preset 5 — the name is free again even with 6+ taken.
        XCTAssertEqual(
            DeskViewModel.uniquePresetName(existing: ["Preset 6", "Preset 7"]),
            "Preset 5"
        )
    }
}
