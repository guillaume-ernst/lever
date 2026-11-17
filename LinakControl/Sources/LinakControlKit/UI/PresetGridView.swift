// PresetGridView.swift
// LinakControlKit — 2x2 grid of preset buttons in the popover.

import SwiftUI

// MARK: - PresetGridView

/// A two-column grid showing all four preset slots, followed by a compact
/// list of the user's named software presets.
///
/// Each cell displays the preset index and its stored height.
/// The active preset is highlighted with an accent border.
/// The target preset pulses during movement.
/// Double-tapping an unset cell saves the current height into that slot.
/// Software rows reuse the same state language: accent ring when active,
/// pulse while targeted, dimmed when disconnected, double-tap to move.
public struct PresetGridView: View {

    @ObservedObject public var viewModel: DeskViewModel

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    public init(viewModel: DeskViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(viewModel.presets, id: \.index) { preset in
                    PresetCell(
                        preset: preset,
                        isActive: preset.index == viewModel.activePreset,
                        isTarget: preset.index == viewModel.targetPreset,
                        unit: viewModel.unit,
                        isConnected: viewModel.connectionState == .connected,
                        onTap: {
                            if preset.heightMM == nil {
                                viewModel.savePreset(index: preset.index)
                            } else {
                                viewModel.goToPreset(index: preset.index)
                            }
                        }
                    )
                }
            }

            if !viewModel.softwarePresets.isEmpty {
                SoftwarePresetListView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - SoftwarePresetListView

/// Compact named rows under the hardware grid — the same preset world the
/// left-click menu shows, so the popover never hides software presets.
/// Capped at ~3.5 rows; longer lists scroll inside the popover.
private struct SoftwarePresetListView: View {
    @ObservedObject var viewModel: DeskViewModel

    var body: some View {
        VStack(spacing: 4) {
            Divider()
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(viewModel.softwarePresets) { preset in
                        SoftwarePresetRow(
                            preset: preset,
                            isActive: preset.id == viewModel.activeSoftwarePresetID,
                            isTarget: preset.id == viewModel.targetSoftwarePresetID,
                            unit: viewModel.unit,
                            isConnected: viewModel.connectionState == .connected,
                            onTap: { viewModel.goToSoftwarePreset(id: preset.id) }
                        )
                    }
                }
            }
            .frame(maxHeight: 104)
        }
    }
}

// MARK: - SoftwarePresetRow

/// One named software preset in the popover list. Same visual grammar as
/// `PresetCell` flattened into a line: name left, height right, accent ring
/// when active, pulse while targeted.
private struct SoftwarePresetRow: View {

    let preset: SoftwarePreset
    let isActive: Bool
    let isTarget: Bool
    let unit: HeightUnit
    let isConnected: Bool
    let onTap: () -> Void

    @State private var isPulsing: Bool = false

    private var heightText: String {
        HeightConverter.display(mm: preset.heightMM, unit: unit)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(preset.name)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if isTarget {
                Text("Moving...")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
            Text(heightText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isPulsing ? 0.97 : 1.0)
        .opacity(isConnected ? 1.0 : 0.4)
        .contentShape(Rectangle())
        .help("Double-click to move to \(heightText)")
        .onTapGesture(count: 2) {
            guard isConnected else { return }
            onTap()
        }
        .onChange(of: isTarget) { newValue in
            withAnimation(newValue ? pulseAnimation : .default) {
                isPulsing = newValue
            }
        }
    }

    private var pulseAnimation: Animation {
        Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    }
}

// MARK: - PresetCell

private struct PresetCell: View {

    let preset: PresetPosition
    let isActive: Bool
    let isTarget: Bool
    let unit: HeightUnit
    let isConnected: Bool
    let onTap: () -> Void

    @State private var isPulsing: Bool = false

    private var heightText: String {
        preset.heightMM.map { HeightConverter.display(mm: $0, unit: unit) } ?? "—"
    }

    private var hasHeight: Bool { preset.heightMM != nil }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(preset.index)")
                .font(.headline)
            if hasHeight {
                Text(heightText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("+ Add")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            if isTarget {
                Text("Moving...")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isPulsing ? 0.96 : 1.0)
        .opacity(cellOpacity)
        .contentShape(Rectangle())
        .help(hasHeight
            ? "Double-click to move to \(heightText)"
            : "Double-click to save the current height as preset \(preset.index)")
        .onTapGesture(count: 2) {
            guard isConnected else { return }
            onTap()
        }
        .onChange(of: isTarget) { newValue in
            withAnimation(newValue ? pulseAnimation : .default) {
                isPulsing = newValue
            }
        }
    }

    private var cellOpacity: Double {
        if !isConnected { return 0.4 }
        if !hasHeight { return 0.65 }
        return 1.0
    }

    private var cellBackground: Color {
        if isActive { return Color.accentColor.opacity(0.15) }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var pulseAnimation: Animation {
        Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    }
}
