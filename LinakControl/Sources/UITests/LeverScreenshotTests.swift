// LeverScreenshotTests.swift
// LeverUITests — captures documentation screenshots via XCUITest.
//
// Assumes ~/Library/Application Support/LinakControl/config.json has a valid
// paired_desk_uuid and that the desk is powered on and reachable. No demo BLE
// mocking — see commit history for the rationale.

import AppKit
import XCTest

final class LeverScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Target the installed app at LINAK_APP_PATH (default /Applications/Lever.app)
        // rather than the freshly built Debug binary. The installed app has stable
        // TCC permissions for Bluetooth; a fresh ad-hoc-signed Debug build does not.
        let envPath = ProcessInfo.processInfo.environment["LINAK_APP_PATH"]
        let appPath = envPath?.isEmpty == false ? envPath! : "/Applications/Lever.app"
        let appURL = URL(fileURLWithPath: appPath)
        app = XCUIApplication(url: appURL)

        // activate() reuses an already-running instance if present (preserving its
        // BLE connection state) and only cold-launches as a fallback.
        app.activate()

        // Settle: give the menu bar time to draw and any cold-connect time to run.
        Thread.sleep(forTimeInterval: 5)

        dumpStatusItems()
    }

    override func tearDownWithError() throws {
        // Intentionally do not terminate — preserve the user's running app
        // instance (and its BLE connection) between tests and across runs.
    }

    func test_screenshot_menubar() throws {
        let item = resolveStatusItem()
        XCTAssertTrue(item.waitForExistence(timeout: 10), "status item not findable")

        // Make sure nothing from a prior test is still on screen.
        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        let itemFrame = item.frame

        let crop = CGRect(
            x: max(0, itemFrame.minX - 10),
            y: 0,
            width: itemFrame.width + 20,
            height: max(itemFrame.maxY, 30)
        )
        attach(name: "menubar",
               image: cropFullScreen(to: crop) ?? XCUIScreen.main.screenshot().image)
    }

    func test_screenshot_menubar_popover() throws {
        let item = resolveStatusItem()
        XCTAssertTrue(item.waitForExistence(timeout: 10), "status item not findable")
        let itemFrame = item.frame

        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        // Right-click opens the control popover (left-click drops the preset menu).
        item.rightClick()
        Thread.sleep(forTimeInterval: 0.6)

        let crop = CGRect(
            x: itemFrame.midX - 150,
            y: itemFrame.minY,
            width: 340,
            height: 380
        )
        attach(name: "menubar-popover",
               image: cropFullScreen(to: crop) ?? XCUIScreen.main.screenshot().image)

        app.typeKey(.escape, modifierFlags: [])
    }

    func test_screenshot_preset_menu() throws {
        let item = resolveStatusItem()
        XCTAssertTrue(
            item.waitForExistence(timeout: 10),
            "status item not findable"
        )
        let itemFrame = item.frame

        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        item.click()
        Thread.sleep(forTimeInterval: 0.4)

        // app.menuItems unions NSApp menu-bar items (huge bounds), so we crop
        // from the status item directly. The dropdown hangs straight below it.
        let crop = CGRect(
            x: max(0, itemFrame.midX - 80),
            y: itemFrame.maxY,
            width: 160,
            height: 150
        )
        attach(name: "menubar-preset-menu",
               image: cropFullScreen(to: crop) ?? XCUIScreen.main.screenshot().image)

        app.typeKey(.escape, modifierFlags: [])
    }

    func test_screenshot_settings() throws {
        let item = resolveStatusItem()
        XCTAssertTrue(item.waitForExistence(timeout: 10), "status item not findable")
        let itemFrame = item.frame

        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        item.rightClick()
        Thread.sleep(forTimeInterval: 0.6)

        let gear = app.buttons["linak.popover.settings.gear"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5), "gear button not findable")
        gear.click()
        Thread.sleep(forTimeInterval: 0.5)

        // Slightly narrower than the popover test to keep adjacent menu-bar
        // icons (Dropbox, language flag) and the desktop wallpaper sliver out
        // of the upper-right corner.
        let crop = CGRect(
            x: itemFrame.midX - 150,
            y: itemFrame.minY,
            width: 300,
            height: 380
        )
        attach(name: "settings",
               image: cropFullScreen(to: crop) ?? XCUIScreen.main.screenshot().image)

        dismissPopoverFromSettings()
    }

    func test_screenshot_settings_scrolled() throws {
        let item = resolveStatusItem()
        XCTAssertTrue(item.waitForExistence(timeout: 10), "status item not findable")
        let itemFrame = item.frame

        app.typeKey(.escape, modifierFlags: [])
        Thread.sleep(forTimeInterval: 0.3)

        item.rightClick()
        Thread.sleep(forTimeInterval: 0.6)

        let gear = app.buttons["linak.popover.settings.gear"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5), "gear button not findable")
        gear.click()
        Thread.sleep(forTimeInterval: 0.5)

        // Scroll the settings content to expose the Presets / login / hotkeys
        // section. Try the scroll view first, then fall back to swiping an
        // element inside the popover.
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.scroll(byDeltaX: 0, deltaY: -300)
        } else {
            app.windows.firstMatch.swipeUp()
        }
        Thread.sleep(forTimeInterval: 0.4)

        let crop = CGRect(
            x: itemFrame.midX - 150,
            y: itemFrame.minY,
            width: 300,
            height: 380
        )
        attach(name: "settings-scrolled",
               image: cropFullScreen(to: crop) ?? XCUIScreen.main.screenshot().image)

        dismissPopoverFromSettings()
    }

    /// Settings view persists `viewModel.showSettings = true` even after the
    /// popover is dismissed, which would make the next right-click open the
    /// popover directly on the settings screen. Press Back first, then escape.
    private func dismissPopoverFromSettings() {
        let back = app.buttons["linak.settings.back"]
        if back.exists {
            back.click()
            Thread.sleep(forTimeInterval: 0.2)
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Screenshot cropping

    /// Capture the whole screen and crop to `rect` (in points/screen-coordinates,
    /// top-left origin). Returns nil if anything along the pipeline fails so the
    /// caller can fall back to an uncropped attachment.
    private func cropFullScreen(to rect: CGRect) -> NSImage? {
        let full = XCUIScreen.main.screenshot().image
        guard let cg = full.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        // The CGImage may be at native pixel scale while rect is in points.
        let scaleX = CGFloat(cg.width) / full.size.width
        let scaleY = CGFloat(cg.height) / full.size.height
        let bounded = rect.intersection(CGRect(origin: .zero, size: full.size))
        guard !bounded.isEmpty else { return nil }
        let pixelRect = CGRect(
            x: bounded.minX * scaleX,
            y: bounded.minY * scaleY,
            width: bounded.width * scaleX,
            height: bounded.height * scaleY
        )
        guard let cropped = cg.cropping(to: pixelRect) else { return nil }
        return NSImage(cgImage: cropped, size: bounded.size)
    }

    // MARK: - Element lookup

    /// Prefer the a11y identifier; if absent (e.g. older installed build), fall
    /// back to the legacy two-zone identifiers, then to scanning for a status
    /// item whose title looks like our height readout or desk icon.
    private func resolveStatusItem() -> XCUIElement {
        let byIdentifier = app.statusItems["linak.menubar.item"]
        if byIdentifier.exists { return byIdentifier }
        // Legacy identifiers from the two-zone era.
        for legacyId in ["linak.menubar.zone2.text", "linak.menubar.zone1.icon"] {
            let legacy = app.statusItems[legacyId]
            if legacy.exists { return legacy }
        }
        // Fallback: pick a status item whose title contains a digit (the
        // height readout) or is image-only (icon fallback mode).
        for i in 0..<app.statusItems.count {
            let item = app.statusItems.element(boundBy: i)
            let title = (item.value as? String) ?? item.label
            if title.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) {
                return item
            }
            if item.label.isEmpty && (item.value as? String ?? "").isEmpty {
                return item
            }
        }
        return byIdentifier
    }

    // MARK: - Diagnostics

    /// Print the a11y identifier, label, and value of every visible status
    /// item. Run output shows up in the xcresult log — invaluable when the
    /// expected identifier mysteriously doesn't resolve.
    private func dumpStatusItems() {
        let count = app.statusItems.count
        print("=== status items visible to XCUITest (\(count)) ===")
        for i in 0..<count {
            let item = app.statusItems.element(boundBy: i)
            let id = item.identifier
            let label = item.label
            let value = (item.value as? String) ?? "<nil>"
            print("  [\(i)] id='\(id)' label='\(label)' value='\(value)'")
        }
        print("===============================================")
    }

    private func attach(name: String, image: NSImage) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
