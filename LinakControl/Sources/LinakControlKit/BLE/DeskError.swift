// DeskError.swift
// LinakControlKit — Errors surfaced by desk-level operations.

import Foundation

// MARK: - DeskError

/// Errors thrown by desk protocol operations including handshake, movement, and preset recall.
public enum DeskError: Error, Sendable {

    /// The output mask response did not match the expected value `Data([0x01])`.
    case unexpectedMaskValue(Data)

    /// A DPG query did not receive a notification response within the timeout window.
    case handshakeTimeout

    /// The operation requires an active BLE connection, but none exists.
    case notConnected

    /// The requested preset slot has no height stored.
    case presetNotSet(index: Int)

    /// No software preset exists for the requested identifier.
    case softwarePresetNotFound

    /// Another software preset already carries this name (case-insensitive).
    case softwarePresetNameTaken(String)

    /// The target height in mm is outside the safe command range (600...1350 mm).
    case targetOutOfRange(Int)

    /// A DPG response could not be parsed into the expected format.
    case invalidResponse

    /// The desk did not respond to wake-up commands after the maximum number of retries.
    case wakeUpFailed
}

// MARK: - LocalizedError

extension DeskError: LocalizedError {
    /// CLI-facing English messages — IPC forwards `localizedDescription` to
    /// deskctl's stderr, so these stay English on purpose (scripting surface).
    public var errorDescription: String? {
        switch self {
        case .unexpectedMaskValue(let data):
            return "unexpected output mask value: \(data.map { String(format: "%02x", $0) }.joined())"
        case .handshakeTimeout:
            return "desk handshake timed out"
        case .notConnected:
            return "desk is not connected"
        case .presetNotSet(let index):
            return "preset \(index) has no height stored"
        case .softwarePresetNotFound:
            return "software preset not found"
        case .softwarePresetNameTaken(let name):
            return "a preset named \"\(name)\" already exists"
        case .targetOutOfRange(let mm):
            return "target height \(mm)mm is outside the safe range (600–1350mm)"
        case .invalidResponse:
            return "the desk sent an unparseable response"
        case .wakeUpFailed:
            return "the desk did not wake up"
        }
    }
}
