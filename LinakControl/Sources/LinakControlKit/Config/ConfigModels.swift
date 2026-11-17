// ConfigModels.swift
// LinakControlKit

import Foundation

// MARK: - Config Models

/// Persisted application settings. Stored as config.json in
/// ~/Library/Application Support/LinakControl/.
public struct AppConfig: Codable, Equatable, Sendable {

    // MARK: Pairing

    /// CoreBluetooth peripheral identifier for the paired desk.
    public var pairedDeskUUID: String?

    /// Human-readable desk name shown in the UI.
    public var pairedDeskName: String?

    // MARK: Display

    /// Height display unit. Defaults to .cm.
    public var unit: HeightUnit

    /// Desk base offset in mm. Raw heights from the desk are relative to its internal
    /// zero point; adding this offset gives the absolute height from floor.
    public var deskOffsetMM: Int

    // MARK: Movement

    /// Up button behaviour. Defaults to .manual (hold to move).
    public var autoRunUp: RunMode

    /// Down button behaviour. Defaults to .manual (hold to move).
    public var autoRunDown: RunMode

    // MARK: System

    /// Register the app as a login item. Defaults to false.
    public var startAtLogin: Bool

    /// Enable global keyboard shortcuts. Defaults to false.
    public var hotkeysEnabled: Bool

    /// Show the height readout in the menu bar status item. Defaults to true.
    public var showZone2: Bool

    // MARK: Preset Labels

    /// Optional labels for preset slots 1–4, e.g. ["Sitting", "Standing", nil, nil].
    public var presetLabels: [String?]

    // MARK: Software Presets

    /// App-side named presets beyond the desk's four hardware slots.
    /// Ordered — the list order is the menu order.
    public var softwarePresets: [SoftwarePreset]

    // MARK: Init

    public init(
        pairedDeskUUID: String? = nil,
        pairedDeskName: String? = nil,
        unit: HeightUnit = .cm,
        deskOffsetMM: Int = 0,
        autoRunUp: RunMode = .manual,
        autoRunDown: RunMode = .manual,
        startAtLogin: Bool = false,
        hotkeysEnabled: Bool = false,
        showZone2: Bool = true,
        presetLabels: [String?] = [nil, nil, nil, nil],
        softwarePresets: [SoftwarePreset] = []
    ) {
        self.pairedDeskUUID = pairedDeskUUID
        self.pairedDeskName = pairedDeskName
        self.unit = unit
        self.deskOffsetMM = deskOffsetMM
        self.autoRunUp = autoRunUp
        self.autoRunDown = autoRunDown
        self.startAtLogin = startAtLogin
        self.hotkeysEnabled = hotkeysEnabled
        self.showZone2 = showZone2
        self.presetLabels = presetLabels
        self.softwarePresets = softwarePresets
    }

    // MARK: CodingKeys — snake_case JSON per SDD schema

    enum CodingKeys: String, CodingKey {
        case pairedDeskUUID   = "paired_desk_uuid"
        case pairedDeskName   = "paired_desk_name"
        case unit
        case deskOffsetMM     = "desk_offset_mm"
        case autoRunUp        = "auto_run_up"
        case autoRunDown      = "auto_run_down"
        case startAtLogin     = "start_at_login"
        case hotkeysEnabled   = "hotkeys_enabled"
        case showZone2        = "show_zone_2"
        case presetLabels     = "preset_labels"
        case softwarePresets  = "software_presets"

        // Legacy keys for backward-compatible reading of old config files.
        case preset1Label     = "preset_1_label"
        case preset2Label     = "preset_2_label"
        case preset3Label     = "preset_3_label"
        case preset4Label     = "preset_4_label"
    }

    // MARK: Decodable — tolerant of missing keys

    /// Custom decoder that provides defaults for any missing keys.
    /// Reads the new `preset_labels` array when present, otherwise falls back
    /// to the legacy `preset_1_label`…`preset_4_label` individual keys for
    /// backward compatibility with old config files.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pairedDeskUUID = try c.decodeIfPresent(String.self, forKey: .pairedDeskUUID)
        pairedDeskName = try c.decodeIfPresent(String.self, forKey: .pairedDeskName)
        unit           = try c.decodeIfPresent(HeightUnit.self, forKey: .unit) ?? .cm
        deskOffsetMM   = try c.decodeIfPresent(Int.self, forKey: .deskOffsetMM) ?? 0
        autoRunUp      = try c.decodeIfPresent(RunMode.self, forKey: .autoRunUp) ?? .manual
        autoRunDown    = try c.decodeIfPresent(RunMode.self, forKey: .autoRunDown) ?? .manual
        startAtLogin   = try c.decodeIfPresent(Bool.self, forKey: .startAtLogin) ?? false
        hotkeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeysEnabled) ?? false
        showZone2      = try c.decodeIfPresent(Bool.self, forKey: .showZone2) ?? true

        if let labels = try c.decodeIfPresent([String?].self, forKey: .presetLabels) {
            presetLabels = labels
            // Guarantee at least one entry per preset slot — a hand-edited or
            // truncated config must not crash `deskctl config label` or any
            // other consumer indexing slots 1-4.
            while presetLabels.count < 4 { presetLabels.append(nil) }
        } else {
            presetLabels = [
                try c.decodeIfPresent(String.self, forKey: .preset1Label),
                try c.decodeIfPresent(String.self, forKey: .preset2Label),
                try c.decodeIfPresent(String.self, forKey: .preset3Label),
                try c.decodeIfPresent(String.self, forKey: .preset4Label),
            ]
        }

        softwarePresets = try c.decodeIfPresent([SoftwarePreset].self, forKey: .softwarePresets) ?? []
    }

    // MARK: Encodable — write only the new format

    /// Encodes using the new `preset_labels` array key only. Legacy individual
    /// keys are not written — they are read-only for migration.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(pairedDeskUUID, forKey: .pairedDeskUUID)
        try c.encodeIfPresent(pairedDeskName, forKey: .pairedDeskName)
        try c.encode(unit, forKey: .unit)
        try c.encode(deskOffsetMM, forKey: .deskOffsetMM)
        try c.encode(autoRunUp, forKey: .autoRunUp)
        try c.encode(autoRunDown, forKey: .autoRunDown)
        try c.encode(startAtLogin, forKey: .startAtLogin)
        try c.encode(hotkeysEnabled, forKey: .hotkeysEnabled)
        try c.encode(showZone2, forKey: .showZone2)
        try c.encode(presetLabels, forKey: .presetLabels)
        try c.encode(softwarePresets, forKey: .softwarePresets)
    }

    // MARK: Defaults

    /// Factory default — matches SDD initial values.
    public static let `default` = AppConfig()
}

// MARK: - SoftwarePreset

/// A named, app-side preset position stored in config — independent of the
/// desk's four hardware memory slots. Identified by `id`, ordered by the
/// containing array (the config order is the menu order).
public struct SoftwarePreset: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String

    /// Raw desk-relative height in mm — same convention as hardware presets:
    /// the display offset is applied at presentation, never stored.
    public var heightMM: Int

    public init(id: UUID = UUID(), name: String, heightMM: Int) {
        self.id = id
        self.name = name
        self.heightMM = heightMM
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case heightMM = "height_mm"
    }

    /// Tolerant decode: a hand-edited entry missing `id` gets a fresh one
    /// rather than failing the whole config load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        heightMM = try c.decode(Int.self, forKey: .heightMM)
    }
}

// MARK: - HeightUnit

/// Height display unit.
public enum HeightUnit: String, Codable, Sendable {
    case cm
    case inch
}

// MARK: - RunMode

/// Movement button behaviour.
public enum RunMode: String, Codable, Sendable {
    /// Hold the button to keep moving (release to stop).
    case manual

    /// Tap once to start; the desk runs automatically to the target.
    case auto
}
