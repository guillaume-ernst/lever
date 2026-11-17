// SettingsView.swift
// LinakControlKit — Settings panel pushed within the popover.
//
// Renders inside the popover when `DeskViewModel.showSettings` is true.
// Sections: display unit, movement mode, presets, connection, system, about.

import SwiftUI

// MARK: - SettingsView

/// Full settings panel displayed inside the menu bar popover.
///
/// Navigation is simulated: a Back button sets `viewModel.showSettings = false`,
/// returning to the normal popover content.
public struct SettingsView: View {

    @ObservedObject public var viewModel: DeskViewModel

    public init(viewModel: DeskViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderView(viewModel: viewModel)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DisplayUnitSection(viewModel: viewModel)
                    SettingsDivider()
                    DeskOffsetSection(viewModel: viewModel)
                    SettingsDivider()
                    MovementModeSection(viewModel: viewModel)
                    SettingsDivider()
                    PresetsSection(viewModel: viewModel)
                    SettingsDivider()
                    ConnectionSection(viewModel: viewModel)
                    SettingsDivider()
                    SystemSection(viewModel: viewModel)
                    SettingsDivider()
                    AboutSection()
                }
                .padding()
            }
        }
        .frame(width: 280)
    }
}

// MARK: - SettingsHeaderView

private struct SettingsHeaderView: View {
    @ObservedObject var viewModel: DeskViewModel

    var body: some View {
        HStack {
            Button {
                viewModel.showSettings = false
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .accessibilityIdentifier("linak.settings.back")

            Spacer()

            Text("Settings")
                .font(.headline)

            Spacer()

            // Invisible spacer to balance the Back button and center the title
            Text("Back")
                .opacity(0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - SettingsDivider

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - SectionHeader

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 6)
    }
}

// MARK: - DisplayUnitSection

private struct DisplayUnitSection: View {
    @ObservedObject var viewModel: DeskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Display Unit")

            Picker("Unit", selection: Binding(
                get: { viewModel.unit },
                set: { viewModel.updateUnit($0) }
            )) {
                Text("cm").tag(HeightUnit.cm)
                Text("inch").tag(HeightUnit.inch)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

// MARK: - DeskOffsetSection

private struct DeskOffsetSection: View {
    @ObservedObject var viewModel: DeskViewModel
    @State private var offsetText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Desk Offset")

            HStack {
                Text("Offset:")
                    .foregroundColor(.secondary)
                TextField("cm", text: $offsetText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onAppear { offsetText = formatCM(viewModel.deskOffsetMM) }
                    .onSubmit { applyOffset() }
                    .onChange(of: viewModel.deskOffsetMM) { _ in
                        offsetText = formatCM(viewModel.deskOffsetMM)
                    }
                Text("cm")
                    .foregroundColor(.secondary)
                Button("Apply") { applyOffset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Text("Height at lowest desk position")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func formatCM(_ mm: Int) -> String {
        let cm = Double(mm) / 10.0
        let fractional = cm.truncatingRemainder(dividingBy: 1)
        if abs(fractional) < 0.05 {
            return "\(Int(cm.rounded()))"
        }
        return String(format: "%.1f", cm)
    }

    private func applyOffset() {
        let cleaned = offsetText.replacingOccurrences(of: ",", with: ".")
        guard let cm = Double(cleaned) else { return }
        let mm = Int((cm * 10).rounded())
        let clamped = max(0, min(mm, 15000))
        viewModel.updateDeskOffset(clamped)
    }
}

// MARK: - MovementModeSection

private struct MovementModeSection: View {
    @ObservedObject var viewModel: DeskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Movement Mode")

            HStack {
                Text("Up:")
                    .frame(width: 46, alignment: .leading)
                Picker("Up mode", selection: Binding(
                    get: { viewModel.autoRunUp },
                    set: { viewModel.updateAutoRunUp($0) }
                )) {
                    Text("hold").tag(RunMode.manual)
                    Text("auto").tag(RunMode.auto)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Text("Down:")
                    .frame(width: 46, alignment: .leading)
                Picker("Down mode", selection: Binding(
                    get: { viewModel.autoRunDown },
                    set: { viewModel.updateAutoRunDown($0) }
                )) {
                    Text("hold").tag(RunMode.manual)
                    Text("auto").tag(RunMode.auto)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}

// MARK: - PresetsSection

private struct PresetsSection: View {
    @ObservedObject var viewModel: DeskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Presets")

            ForEach(viewModel.presets, id: \.index) { preset in
                PresetRowView(preset: preset, unit: viewModel.unit) {
                    viewModel.savePreset(index: preset.index)
                }
            }

            Text("Software")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.top, 6)

            ForEach(Array(viewModel.softwarePresets.enumerated()), id: \.element.id) { index, preset in
                SoftwarePresetRow(
                    preset: preset,
                    unit: viewModel.unit,
                    canMoveUp: index > 0,
                    canMoveDown: index < viewModel.softwarePresets.count - 1,
                    onRename: { viewModel.renameSoftwarePreset(id: preset.id, name: $0) },
                    onSetHeight: { viewModel.setSoftwarePresetToCurrentHeight(id: preset.id) },
                    onDelete: { viewModel.removeSoftwarePreset(id: preset.id) },
                    onMove: { direction in
                        // move(fromOffsets:toOffset:) counts toOffset in the
                        // array *before* removal — one row down is index+2.
                        let destination = direction < 0 ? index - 1 : index + 2
                        viewModel.moveSoftwarePreset(fromOffsets: [index], toOffset: destination)
                    }
                )
            }

            Button(addTitle) {
                viewModel.addSoftwarePresetAtCurrentHeight()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.heightMM == nil)
        }
    }

    private var addTitle: String {
        viewModel.heightDisplay == "—"
            ? "Add preset"
            : "Add preset at \(viewModel.heightDisplay)"
    }
}

// MARK: - SoftwarePresetRow

/// One row of the software preset list: reorder chevrons, inline-editable
/// name, stored height, re-point and delete actions.
private struct SoftwarePresetRow: View {
    let preset: SoftwarePreset
    let unit: HeightUnit
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onRename: (String) -> Void
    let onSetHeight: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void

    @State private var name: String
    @State private var confirmDelete = false

    init(
        preset: SoftwarePreset,
        unit: HeightUnit,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onRename: @escaping (String) -> Void,
        onSetHeight: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onMove: @escaping (Int) -> Void
    ) {
        self.preset = preset
        self.unit = unit
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onRename = onRename
        self.onSetHeight = onSetHeight
        self.onDelete = onDelete
        self.onMove = onMove
        _name = State(initialValue: preset.name)
    }

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 0) {
                Button { onMove(-1) } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveUp)
                Button { onMove(1) } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDown)
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .font(.caption2)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commitRename)

            Text(HeightConverter.display(mm: preset.heightMM, unit: unit))
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onSetHeight) {
                Image(systemName: "arrow.down.to.line")
            }
            .buttonStyle(.borderless)
            .help("Set to the desk's current height")

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this preset")
            .confirmationDialog(
                "Delete preset \"\(preset.name)\"?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: onDelete)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func commitRename() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != preset.name else {
            name = preset.name
            return
        }
        name = trimmed
        onRename(trimmed)
    }
}

// MARK: - PresetRowView

private struct PresetRowView: View {
    let preset: PresetPosition
    let unit: HeightUnit
    let onSave: () -> Void

    @State private var confirmOverwrite = false

    var body: some View {
        HStack {
            Text("\(preset.index):")
                .frame(width: 16, alignment: .leading)

            if let heightMM = preset.heightMM {
                Text(HeightConverter.display(mm: heightMM, unit: unit))
                    .font(.body)
            } else {
                Text("—")
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Save current") {
                // Writing into an empty slot loses nothing — confirm only on overwrite.
                if preset.heightMM == nil {
                    onSave()
                } else {
                    confirmOverwrite = true
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .confirmationDialog(
                overwriteTitle,
                isPresented: $confirmOverwrite,
                titleVisibility: .visible
            ) {
                Button("Replace", action: onSave)
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var overwriteTitle: String {
        guard let heightMM = preset.heightMM else { return "" }
        return "Replace preset \(preset.index) (\(HeightConverter.display(mm: heightMM, unit: unit))) with the current height?"
    }
}

// MARK: - ConnectionSection

private struct ConnectionSection: View {
    @ObservedObject var viewModel: DeskViewModel
    @State private var confirmForget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Connection")

            HStack {
                Text("Desk:")
                    .foregroundColor(.secondary)
                Text(viewModel.deskName ?? "Unknown")
                    .lineLimit(1)
                Spacer()
                if viewModel.connectionState == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Button("Forget & Re-scan") {
                confirmForget = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            .confirmationDialog(
                "Forget \(viewModel.deskName ?? "this desk") and scan again?",
                isPresented: $confirmForget,
                titleVisibility: .visible
            ) {
                Button("Forget", role: .destructive) { viewModel.forgetAndRescan() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pairing is lost — the controller must be in pairing mode (blue LED) to connect again.")
            }
        }
    }
}

// MARK: - SystemSection

private struct SystemSection: View {
    @ObservedObject var viewModel: DeskViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Start at login", isOn: Binding(
                get: { viewModel.startAtLogin },
                set: { viewModel.updateStartAtLogin($0) }
            ))

            Toggle("Global hotkeys", isOn: Binding(
                get: { viewModel.hotkeysEnabled },
                set: { viewModel.updateHotkeysEnabled($0) }
            ))

            Toggle("Show height in menu bar", isOn: Binding(
                get: { viewModel.showZone2 },
                set: { viewModel.updateShowZone2($0) }
            ))
        }
    }
}

// MARK: - AboutSection

private struct AboutSection: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About Lever v\(appVersion)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
    }
}
