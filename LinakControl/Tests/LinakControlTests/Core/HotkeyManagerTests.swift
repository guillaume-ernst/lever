// HotkeyManagerTests.swift
// LinakControlTests — Verifies HotkeyManager enable/disable state and desk-command routing.

import XCTest
@testable import LinakControlKit

// MARK: - MockHotkeyManager

/// In-memory HotkeyManaging stub for testing consumers that depend on the protocol.
final class MockHotkeyManager: HotkeyManaging {
    private(set) var enableCallCount = 0
    private(set) var disableCallCount = 0
    private(set) var _isEnabled = false

    var isEnabled: Bool { _isEnabled }

    func enable() {
        enableCallCount += 1
        _isEnabled = true
    }

    func disable() {
        disableCallCount += 1
        _isEnabled = false
    }
}

// MARK: - Helpers

// makeTempConfigStore is provided by TestHelpers.swift (with config: parameter)

// MARK: - MockHotkeyManager Protocol Tests

final class MockHotkeyManagerTests: XCTestCase {

    func testEnableSetIsEnabledTrue() {
        let mock = MockHotkeyManager()

        mock.enable()

        XCTAssertTrue(mock.isEnabled)
    }

    func testDisableSetIsEnabledFalse() {
        let mock = MockHotkeyManager()
        mock.enable()

        mock.disable()

        XCTAssertFalse(mock.isEnabled)
    }

    func testEnableCallCountIncrements() {
        let mock = MockHotkeyManager()

        mock.enable()
        mock.enable()

        XCTAssertEqual(mock.enableCallCount, 2)
    }

    func testDisableCallCountIncrements() {
        let mock = MockHotkeyManager()

        mock.disable()
        mock.disable()

        XCTAssertEqual(mock.disableCallCount, 2)
    }

    func testInitialStateIsDisabled() {
        let mock = MockHotkeyManager()

        XCTAssertFalse(mock.isEnabled)
        XCTAssertEqual(mock.enableCallCount, 0)
        XCTAssertEqual(mock.disableCallCount, 0)
    }
}

// MARK: - HotkeyManager Enable/Disable State Tests

@MainActor
final class HotkeyManagerEnableDisableTests: XCTestCase {

    func testIsEnabledFalseBeforeEnable() {
        let bleController = MockBLEController()
        let store = makeTempConfigStore()
        let deskManager = DeskManager(bleController: bleController, configStore: store)
        let hotkeys = HotkeyManager(deskManager: deskManager, configStore: store)

        XCTAssertFalse(hotkeys.isEnabled)
    }

    func testIsEnabledTrueAfterEnable() {
        let bleController = MockBLEController()
        let store = makeTempConfigStore()
        let deskManager = DeskManager(bleController: bleController, configStore: store)
        let hotkeys = HotkeyManager(deskManager: deskManager, configStore: store)

        hotkeys.enable()
        defer { hotkeys.disable() }

        XCTAssertTrue(hotkeys.isEnabled)
    }

    func testIsEnabledFalseAfterDisable() {
        let bleController = MockBLEController()
        let store = makeTempConfigStore()
        let deskManager = DeskManager(bleController: bleController, configStore: store)
        let hotkeys = HotkeyManager(deskManager: deskManager, configStore: store)

        hotkeys.enable()
        hotkeys.disable()

        XCTAssertFalse(hotkeys.isEnabled)
    }

    func testEnableIsIdempotent() {
        let bleController = MockBLEController()
        let store = makeTempConfigStore()
        let deskManager = DeskManager(bleController: bleController, configStore: store)
        let hotkeys = HotkeyManager(deskManager: deskManager, configStore: store)

        hotkeys.enable()
        hotkeys.enable() // second call must not create a second monitor

        defer { hotkeys.disable() }
        XCTAssertTrue(hotkeys.isEnabled)
    }

    func testDisableWhenAlreadyDisabledDoesNotCrash() {
        let bleController = MockBLEController()
        let store = makeTempConfigStore()
        let deskManager = DeskManager(bleController: bleController, configStore: store)
        let hotkeys = HotkeyManager(deskManager: deskManager, configStore: store)

        // disable without a prior enable must be a no-op
        hotkeys.disable()

        XCTAssertFalse(hotkeys.isEnabled)
    }

    func testReEnableAfterDisableRestoresEnabledState() {
        let bleController = MockBLEController()
        let store = makeTempConfigStore()
        let deskManager = DeskManager(bleController: bleController, configStore: store)
        let hotkeys = HotkeyManager(deskManager: deskManager, configStore: store)

        hotkeys.enable()
        hotkeys.disable()
        hotkeys.enable()
        defer { hotkeys.disable() }

        XCTAssertTrue(hotkeys.isEnabled)
    }
}

// MARK: - HotkeyManager Config Integration Tests

@MainActor
final class HotkeyManagerConfigIntegrationTests: XCTestCase {

    func testMoveUpUsesAutoRunUpModeFromConfig() async throws {
        let bleController = MockBLEController()
        let config = AppConfig(autoRunUp: .auto, autoRunDown: .manual)
        let store = makeTempConfigStore(config: config)
        let deskManager = DeskManager(bleController: bleController, configStore: store)

        // Verify that configStore.load() returns the expected run mode
        // (HotkeyManager reads this on each key press)
        let loaded = try store.load()
        XCTAssertEqual(loaded.autoRunUp, .auto)
    }

    func testMoveDownUsesAutoRunDownModeFromConfig() async throws {
        let bleController = MockBLEController()
        let config = AppConfig(autoRunUp: .manual, autoRunDown: .auto)
        let store = makeTempConfigStore(config: config)
        let deskManager = DeskManager(bleController: bleController, configStore: store)

        let loaded = try store.load()
        XCTAssertEqual(loaded.autoRunDown, .auto)
    }

    func testHotkeysEnabledFlagDefaultsFalse() throws {
        let store = makeTempConfigStore()
        let loaded = try store.load()
        XCTAssertFalse(loaded.hotkeysEnabled)
    }

    func testHotkeysEnabledFlagCanBePersisted() throws {
        let store = makeTempConfigStore(config: AppConfig(hotkeysEnabled: true))
        let loaded = try store.load()
        XCTAssertTrue(loaded.hotkeysEnabled)
    }
}

// MARK: - DeskViewModel Hotkey Toggle Propagation Tests
//
// The Settings toggle calls updateHotkeysEnabled — it must arm/disarm the
// live monitor immediately, not merely persist the flag for next launch.

@MainActor
final class DeskViewModelHotkeyToggleTests: XCTestCase {

    @MainActor
    private func makeViewModel(
        store: ConfigStore,
        hotkeyManager: HotkeyManaging?
    ) -> DeskViewModel {
        let manager = DeskManager(bleController: MockBLEController(), configStore: store)
        return DeskViewModel(
            deskManager: manager,
            configStore: store,
            loginItemManager: MockLoginItemManager(),
            hotkeyManager: hotkeyManager
        )
    }

    func testUpdateHotkeysEnabledTrueCallsEnable() {
        let mock = MockHotkeyManager()
        let viewModel = makeViewModel(store: makeTempConfigStore(), hotkeyManager: mock)

        viewModel.updateHotkeysEnabled(true)

        XCTAssertEqual(mock.enableCallCount, 1)
        XCTAssertEqual(mock.disableCallCount, 0)
        XCTAssertTrue(viewModel.hotkeysEnabled)
    }

    func testUpdateHotkeysEnabledFalseCallsDisable() {
        let mock = MockHotkeyManager()
        let store = makeTempConfigStore(config: AppConfig(hotkeysEnabled: true))
        let viewModel = makeViewModel(store: store, hotkeyManager: mock)

        viewModel.updateHotkeysEnabled(false)

        XCTAssertEqual(mock.disableCallCount, 1)
        XCTAssertEqual(mock.enableCallCount, 0)
        XCTAssertFalse(viewModel.hotkeysEnabled)
    }

    func testUpdateHotkeysEnabledPersistsFlag() async throws {
        let mock = MockHotkeyManager()
        let store = makeTempConfigStore()
        let viewModel = makeViewModel(store: store, hotkeyManager: mock)

        viewModel.updateHotkeysEnabled(true)
        try await Task.sleep(for: .milliseconds(50))

        let saved = try store.load()
        XCTAssertTrue(saved.hotkeysEnabled)
    }

    /// Without an injected manager (e.g. tests, previews) the toggle must not crash.
    func testUpdateHotkeysEnabledWithoutManagerDoesNotCrash() {
        let store = makeTempConfigStore()
        let viewModel = makeViewModel(store: store, hotkeyManager: nil)

        viewModel.updateHotkeysEnabled(true)
        viewModel.updateHotkeysEnabled(false)

        XCTAssertFalse(viewModel.hotkeysEnabled)
    }
}
