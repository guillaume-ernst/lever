// PeripheralName.swift
// LinakControlKit — Sanitizes untrusted BLE-advertised peripheral names.

import Foundation

// MARK: - PeripheralName

/// Utilities for handling untrusted peripheral names delivered by CoreBluetooth.
public enum PeripheralName {

    /// Maximum name length kept after sanitization.
    public static let maxLength = 64

    /// Returns a display- and log-safe version of a raw BLE device name.
    ///
    /// Any advertiser in radio range fully controls this string. Strips C0
    /// controls (newlines can forge log lines), DEL, and C1 controls (ESC/CSI
    /// introducers reach the user's terminal via `deskctl status`), then
    /// truncates to `maxLength`. Falls back when nothing printable remains.
    public static func sanitize(_ raw: String?, fallback: String = "Unknown") -> String {
        guard let raw, !raw.isEmpty else { return fallback }
        let cleaned = String(raw.unicodeScalars.filter { scalar in
            scalar.value >= 0x20 && scalar.value != 0x7F && !(0x80...0x9F).contains(scalar.value)
        })
        guard !cleaned.isEmpty else { return fallback }
        return String(cleaned.prefix(maxLength))
    }
}
