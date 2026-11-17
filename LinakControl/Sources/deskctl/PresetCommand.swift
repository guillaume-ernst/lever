// PresetCommand.swift
// deskctl preset <index|name> [--save]
// deskctl preset add|remove|rename ...

import ArgumentParser
import Foundation
import LinakControlKit

struct PresetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preset",
        abstract: "Move to or manage presets — hardware slots 1-4 or named software presets."
    )

    @Argument(
        parsing: .remaining,
        help: "Preset index (1-4), software preset name, or action: add <name> | remove <name> | rename <name> <new>."
    )
    var args: [String]

    @Flag(name: .long, help: "Save the current height to the given preset.")
    var save = false

    func run() throws {
        guard let first = args.first else {
            throw ValidationError("Missing preset index, name, or action.")
        }

        switch first.lowercased() {
        case "add":
            let name = try joinedName(drop: 1, usage: "deskctl preset add <name>")
            try runIPC { try $0.addSoftwarePreset(name: name) }
            print("Added preset \"\(name)\" at current height.")

        case "remove", "rm", "delete":
            let name = try joinedName(drop: 1, usage: "deskctl preset remove <name>")
            try runIPC { try $0.removeSoftwarePreset(name: name) }
            print("Removed preset \"\(name)\".")

        case "rename":
            guard args.count == 3 else {
                throw ValidationError("Usage: deskctl preset rename <name> <new name> (quote multi-word names)")
            }
            try runIPC { try $0.renameSoftwarePreset(name: args[1], newName: args[2]) }
            print("Renamed preset \"\(args[1])\" to \"\(args[2])\".")

        default:
            if let index = Int(first) {
                guard (1...4).contains(index) else {
                    throw ValidationError("Preset index must be 1, 2, 3, or 4.")
                }
                if save {
                    _ = try runIPC { try $0.savePreset(index: index) }
                    print("Saved current height to preset \(index).")
                } else {
                    let targetMM = try runIPC { try $0.goPreset(index: index) }
                    print("Moving to preset \(index) (\(formatTarget(targetMM)))...")
                }
            } else {
                let name = args.joined(separator: " ")
                if save {
                    try runIPC { try $0.repointSoftwarePreset(name: name) }
                    print("Saved current height to preset \"\(name)\".")
                } else {
                    let targetMM = try runIPC { try $0.goSoftwarePreset(name: name) }
                    print("Moving to preset \"\(name)\" (\(formatTarget(targetMM)))...")
                }
            }
        }
    }

    private func joinedName(drop: Int, usage: String) throws -> String {
        let name = args.dropFirst(drop).joined(separator: " ")
        guard !name.isEmpty else { throw ValidationError("Usage: \(usage)") }
        return name
    }

    private func formatTarget(_ targetMM: Int?) -> String {
        targetMM.map { String(format: "%.1f cm", Double($0) / 10) } ?? "unknown"
    }
}
