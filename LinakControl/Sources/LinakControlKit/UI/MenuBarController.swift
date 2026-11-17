// MenuBarController.swift
// LinakControlKit — Single NSStatusItem: height readout + dual-click gestures.

import AppKit
import Combine
import SwiftUI

// MARK: - MenuBarController

/// Owns the single NSStatusItem in the macOS menu bar.
///
/// The item shows the current desk height (bare number, unit implied).
/// Left-click drops the preset `NSMenu`; right-click opens the `NSPopover`
/// containing `PopoverView`.
///
/// Observes `DeskViewModel` to update the readout reactively.
@MainActor
public final class MenuBarController: NSObject {

    // MARK: - Private state

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let viewModel: DeskViewModel
    private var lastTitle: String = ""
    private var cancellable: AnyCancellable?

    // MARK: - Init

    public init(viewModel: DeskViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    // MARK: - Public API

    /// Creates the status item and connects it to the view model.
    ///
    /// When `autoOpen` is true the popover opens immediately after setup,
    /// which is useful for first-run pairing so the user sees the scanning UI
    /// without having to find and right-click the menu-bar item first.
    public func setup(autoOpen: Bool = false) {
        FileLog.debug("setup(autoOpen: \(autoOpen)) isFirstRun=\(viewModel.isFirstRun)", category: "ui")
        setupStatusItem()
        setupPopover()
        startObservingViewModel()

        if autoOpen {
            // Slight delay so the status item is laid out in the menu bar first.
            DispatchQueue.main.async { [weak self] in
                self?.togglePopover()
            }
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Both buttons land in the same action; NSApp.currentEvent discriminates.
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.action = #selector(statusItemClicked)
        item.button?.target = self
        item.button?.setAccessibilityIdentifier("linak.menubar.item")
        statusItem = item
        updateStatusItem()
    }

    /// Left-click shows the preset menu; right-click toggles the control popover.
    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            togglePopover()
        } else {
            showPresetMenu()
        }
    }

    private func setupPopover() {
        let hosting = NSPopover()
        hosting.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )
        hosting.contentSize = NSSize(width: 280, height: 400)
        // During first-run the popover must stay open so the user can complete
        // the pairing flow without it dismissing on focus loss.
        hosting.behavior = viewModel.isFirstRun ? .applicationDefined : .transient
        popover = hosting
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover's window key so clicks register immediately
            // without needing an extra activation click first.
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    private func showPresetMenu() {
        guard let item = statusItem else { return }
        // Assigning .menu then simulating a click pops the menu anchored to
        // the item; clearing it right after keeps right-click free for the
        // popover and left-clicks routed through statusItemClicked().
        item.menu = buildPresetMenu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: - View model observation

    private func startObservingViewModel() {
        // objectWillChange fires before the mutation, so we schedule the
        // refresh on the next main-queue cycle to read updated values.
        cancellable = viewModel.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.refreshStatusItem()
            }
        }
    }

    private func refreshStatusItem() {
        updateStatusItem()
        updatePopoverBehavior()
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.alphaValue = 1.0

        if viewModel.needsReference {
            // Persistent fault indicator — visible without opening the popover
            // or catching the one-shot notification. Self-coloured (non-template)
            // orange so it renders regardless of the status-bar tint.
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            let warning = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: String(localized: "Desk fault")
            )?.withSymbolConfiguration(config)
            warning?.isTemplate = false
            button.image = warning
            button.toolTip = viewModel.faultMessage
        } else if viewModel.showZone2 {
            button.image = nil
            button.toolTip = String(localized: "Left-click: presets · Right-click: desk controls")
        } else {
            // Readout hidden by preference — fall back to the bare desk icon.
            button.image = NSImage(
                systemSymbolName: "table.furniture",
                accessibilityDescription: String(localized: "Desk")
            )
            button.image?.isTemplate = true
            button.alphaValue = viewModel.connectionState == .connected ? 1.0 : 0.7
            button.toolTip = String(localized: "Left-click: presets · Right-click: desk controls")
        }

        button.imagePosition = viewModel.showZone2 ? .imageLeft : .imageOnly
        let title = viewModel.showZone2 ? titleText() : ""
        guard title != lastTitle else { return }
        lastTitle = title
        button.title = title
    }

    private func updatePopoverBehavior() {
        // Switch from applicationDefined → transient once first-run completes
        // so the popover dismisses normally on focus loss.
        if !viewModel.isFirstRun, popover?.behavior == .applicationDefined {
            popover?.behavior = .transient
        }
    }

    // MARK: - Readout

    /// The bare height number (no unit) — "114.4". Shows "…" while a state
    /// transition is in flight and "—" when no height is known.
    private func titleText() -> String {
        switch viewModel.connectionState {
        case .connected:
            guard let mm = viewModel.heightMM else { return "—" }
            return HeightConverter.value(mm: mm + viewModel.deskOffsetMM, unit: viewModel.unit)
        case .connecting, .scanning:
            return "…"
        case .disconnected:
            return "—"
        }
    }

    // MARK: - Preset menu

    private func buildPresetMenu() -> NSMenu {
        let menu = NSMenu()
        for preset in viewModel.presets {
            menu.addItem(presetMenuItem(for: preset))
        }
        if !viewModel.softwarePresets.isEmpty {
            menu.addItem(.separator())
            for preset in viewModel.softwarePresets {
                menu.addItem(softwarePresetMenuItem(for: preset))
            }
        }
        menu.addItem(.separator())
        let addTitle = viewModel.heightDisplay == "—"
            ? String(localized: "Add Preset")
            : String(localized: "Add Preset at \(viewModel.heightDisplay)")
        let add = NSMenuItem(
            title: addTitle,
            action: #selector(addSoftwarePresetSelected),
            keyEquivalent: ""
        )
        add.target = self
        add.isEnabled = viewModel.heightMM != nil
        menu.addItem(add)
        menu.addItem(.separator())
        let settings = NSMenuItem(
            title: String(localized: "Settings…"),
            action: #selector(settingsMenuItemSelected),
            keyEquivalent: ""
        )
        settings.target = self
        menu.addItem(settings)
        return menu
    }

    private func presetMenuItem(for preset: PresetPosition) -> NSMenuItem {
        let heightText = preset.heightMM.map { HeightConverter.display(mm: $0, unit: viewModel.unit) }
            ?? String(localized: "+ Add")
        let title = "\(preset.index)  \(heightText)"

        let item = NSMenuItem(title: title, action: #selector(presetMenuItemSelected(_:)), keyEquivalent: "")
        item.tag = preset.index
        item.target = self
        item.state = (preset.index == viewModel.activePreset) ? .on : .off
        markIfMoving(item, targeted: preset.index == viewModel.targetPreset)
        return item
    }

    private func softwarePresetMenuItem(for preset: SoftwarePreset) -> NSMenuItem {
        let heightText = HeightConverter.display(mm: preset.heightMM, unit: viewModel.unit)

        let item = NSMenuItem(
            title: "\(preset.name)  \(heightText)",
            action: #selector(softwarePresetMenuItemSelected(_:)),
            keyEquivalent: ""
        )
        item.representedObject = preset.id.uuidString
        item.target = self
        item.state = (preset.id == viewModel.activeSoftwarePresetID) ? .on : .off
        markIfMoving(item, targeted: preset.id == viewModel.targetSoftwarePresetID)
        return item
    }

    /// In-motion marker: an SF Symbol in the item's image gutter rather than
    /// an ASCII prefix hacked into the title (the checkmark column stays free
    /// for the active state).
    private func markIfMoving(_ item: NSMenuItem, targeted: Bool) {
        guard targeted else { return }
        item.image = NSImage(
            systemSymbolName: "arrow.right",
            accessibilityDescription: String(localized: "Moving")
        )
    }

    @objc private func presetMenuItemSelected(_ sender: NSMenuItem) {
        // Empty slot → "+ Add" means save the current height into it.
        if viewModel.presets.first(where: { $0.index == sender.tag })?.heightMM == nil {
            viewModel.savePreset(index: sender.tag)
        } else {
            viewModel.goToPreset(index: sender.tag)
        }
    }

    @objc private func softwarePresetMenuItemSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        viewModel.goToSoftwarePreset(id: id)
    }

    @objc private func addSoftwarePresetSelected() {
        viewModel.addSoftwarePresetAtCurrentHeight()
    }

    @objc private func settingsMenuItemSelected() {
        // Open the popover straight onto the settings panel — the user asked
        // for Settings, not for the instrument view.
        viewModel.showSettings = true
        if popover?.isShown == false {
            togglePopover()
        }
    }
}
