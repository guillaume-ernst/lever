// IPCProtocol.swift
// LinakControl — IPC message types, framing helpers, and socket path constants.

import Foundation

// MARK: - IPCConstants

public enum IPCConstants {
    public static var socketPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("LinakControl/linakcontrol.sock").path
    }
}

// MARK: - IPCMethod

public enum IPCMethod: String, Codable, Sendable {
    case getStatus
    case move
    case stop
    case goPreset
    case savePreset
    case goSoftwarePreset
    case addSoftwarePreset
    case removeSoftwarePreset
    case renameSoftwarePreset
    case repointSoftwarePreset
}

// MARK: - IPCParams

/// Parameters for an IPC request. Enum cases map to specific methods.
public enum IPCParams: Codable, Sendable {
    case move(direction: String, mode: String?)
    case preset(index: Int)
    /// Software-preset operations. `id` is a UUID string; `name` selects the
    /// preset by name (case-insensitive); `newName` is the rename target.
    /// Which fields a method requires is validated server-side.
    case software(id: String?, name: String?, newName: String?)

    // MARK: CodingKeys

    private enum CodingKeys: String, CodingKey {
        case direction
        case mode
        case index
        case id
        case name
        case newName = "new_name"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let index = try container.decodeIfPresent(Int.self, forKey: .index) {
            self = .preset(index: index)
        } else if container.contains(.id)
                    || container.contains(.name)
                    || container.contains(.newName) {
            self = .software(
                id: try container.decodeIfPresent(String.self, forKey: .id),
                name: try container.decodeIfPresent(String.self, forKey: .name),
                newName: try container.decodeIfPresent(String.self, forKey: .newName)
            )
        } else {
            let direction = try container.decode(String.self, forKey: .direction)
            let mode = try container.decodeIfPresent(String.self, forKey: .mode)
            self = .move(direction: direction, mode: mode)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .move(let direction, let mode):
            try container.encode(direction, forKey: .direction)
            try container.encodeIfPresent(mode, forKey: .mode)
        case .preset(let index):
            try container.encode(index, forKey: .index)
        case .software(let id, let name, let newName):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(newName, forKey: .newName)
        }
    }
}

// MARK: - IPCRequest

public struct IPCRequest: Codable, Sendable {
    public let id: String
    public let method: IPCMethod
    public let params: IPCParams?

    public init(id: String, method: IPCMethod, params: IPCParams? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

// MARK: - StatusResult

public struct StatusResult: Codable, Sendable {
    public let connected: Bool
    public let deskName: String?
    public let heightMM: Int?
    public let heightDisplay: String?
    public let unit: String
    public let presets: [PresetInfo]
    public let activePreset: Int?
    /// App-side named presets beyond the hardware slots.
    public let softwarePresets: [SoftwarePresetInfo]
    /// Id of the software preset matching the current height, if any.
    public let activeSoftwarePreset: String?
    /// True when a movement stalled and the desk may need a manual reset (E16).
    public let needsReference: Bool
    /// Raw desk fault code behind `needsReference` when the desk pushed one, else nil.
    public let faultCode: Int?

    public init(
        connected: Bool,
        deskName: String? = nil,
        heightMM: Int? = nil,
        heightDisplay: String? = nil,
        unit: String,
        presets: [PresetInfo] = [],
        activePreset: Int? = nil,
        softwarePresets: [SoftwarePresetInfo] = [],
        activeSoftwarePreset: String? = nil,
        needsReference: Bool = false,
        faultCode: Int? = nil
    ) {
        self.connected = connected
        self.deskName = deskName
        self.heightMM = heightMM
        self.heightDisplay = heightDisplay
        self.unit = unit
        self.presets = presets
        self.activePreset = activePreset
        self.softwarePresets = softwarePresets
        self.activeSoftwarePreset = activeSoftwarePreset
        self.needsReference = needsReference
        self.faultCode = faultCode
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        connected = try c.decode(Bool.self, forKey: .connected)
        deskName = try c.decodeIfPresent(String.self, forKey: .deskName)
        heightMM = try c.decodeIfPresent(Int.self, forKey: .heightMM)
        heightDisplay = try c.decodeIfPresent(String.self, forKey: .heightDisplay)
        unit = try c.decode(String.self, forKey: .unit)
        presets = try c.decodeIfPresent([PresetInfo].self, forKey: .presets) ?? []
        activePreset = try c.decodeIfPresent(Int.self, forKey: .activePreset)
        // Tolerant of daemons predating these fields (rolling upgrade).
        softwarePresets = try c.decodeIfPresent([SoftwarePresetInfo].self, forKey: .softwarePresets) ?? []
        activeSoftwarePreset = try c.decodeIfPresent(String.self, forKey: .activeSoftwarePreset)
        needsReference = try c.decodeIfPresent(Bool.self, forKey: .needsReference) ?? false
        faultCode = try c.decodeIfPresent(Int.self, forKey: .faultCode)
    }

    private enum CodingKeys: String, CodingKey {
        case connected
        case deskName = "desk_name"
        case heightMM = "height_mm"
        case heightDisplay = "height_display"
        case unit
        case presets
        case activePreset = "active_preset"
        case softwarePresets = "software_presets"
        case activeSoftwarePreset = "active_software_preset"
        case needsReference = "needs_reference"
        case faultCode = "fault_code"
    }
}

// MARK: - PresetInfo

public struct PresetInfo: Codable, Sendable {
    public let index: Int
    public let heightMM: Int?
    public let label: String?

    public init(index: Int, heightMM: Int? = nil, label: String? = nil) {
        self.index = index
        self.heightMM = heightMM
        self.label = label
    }

    private enum CodingKeys: String, CodingKey {
        case index
        case heightMM = "height_mm"
        case label
    }
}

// MARK: - SoftwarePresetInfo

/// IPC-facing view of a software preset. Heights are absolute
/// (deskOffsetMM already applied), matching `PresetInfo`'s convention.
public struct SoftwarePresetInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let heightMM: Int

    public init(id: String, name: String, heightMM: Int) {
        self.id = id
        self.name = name
        self.heightMM = heightMM
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case heightMM = "height_mm"
    }
}

// MARK: - IPCResult

public enum IPCResult: Codable, Sendable {
    case status(StatusResult)
    case ok(targetMM: Int?)

    // MARK: CodingKeys

    private enum CodingKeys: String, CodingKey {
        case ok
        case targetMM = "target_mm"
        // StatusResult keys (flat encoding)
        case connected
        case deskName = "desk_name"
        case heightMM = "height_mm"
        case heightDisplay = "height_display"
        case unit
        case presets
        case activePreset = "active_preset"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try container.decodeIfPresent(Bool.self, forKey: .ok)) != nil {
            let targetMM = try container.decodeIfPresent(Int.self, forKey: .targetMM)
            self = .ok(targetMM: targetMM)
        } else {
            let status = try StatusResult(from: decoder)
            self = .status(status)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .status(let result):
            try result.encode(to: encoder)
        case .ok(let targetMM):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(true, forKey: .ok)
            try container.encodeIfPresent(targetMM, forKey: .targetMM)
        }
    }
}

// MARK: - IPCErrorPayload

public struct IPCErrorPayload: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

// MARK: - IPCResponse

public struct IPCResponse: Codable, Sendable {
    public let id: String
    public let result: IPCResult?
    public let error: IPCErrorPayload?

    public init(id: String, result: IPCResult? = nil, error: IPCErrorPayload? = nil) {
        self.id = id
        self.result = result
        self.error = error
    }
}

// MARK: - IPCErrorCode

public enum IPCErrorCode: Int, Sendable {
    case general = 1
    case daemonNotRunning = 2
    case notConnected = 3
    case timeout = 5
    case invalidRequest = 10
}

// MARK: - IPCFraming

public enum IPCFraming {
    /// Maximum payload size (64 KB).
    public static let maxPayloadSize: UInt32 = 65536

    /// Prepends a 4-byte big-endian length prefix to `payload`.
    public static func frame(_ payload: Data) -> Data {
        let length = UInt32(payload.count)
        var bigEndian = length.bigEndian
        var framed = Data(bytes: &bigEndian, count: 4)
        framed.append(payload)
        return framed
    }

    /// Extracts one complete message from `buffer`.
    ///
    /// Returns `(message, remaining)` when a complete message is available,
    /// or `nil` when the buffer is too short, the payload is incomplete,
    /// or the declared length exceeds `maxPayloadSize`.
    public static func deframe(_ buffer: Data) -> (message: Data, remaining: Data)? {
        guard buffer.count >= 4 else { return nil }
        let lengthBytes = buffer.prefix(4)
        let length = lengthBytes.withUnsafeBytes { ptr in
            ptr.loadUnaligned(as: UInt32.self).bigEndian
        }
        guard length <= maxPayloadSize else { return nil }
        let total = 4 + Int(length)
        guard buffer.count >= total else { return nil }
        let message = buffer[4..<total]
        let remaining = buffer[total...]
        return (Data(message), Data(remaining))
    }
}
