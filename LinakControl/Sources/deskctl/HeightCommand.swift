// HeightCommand.swift
// deskctl height [--json]

import ArgumentParser
import Foundation
import LinakControlKit

struct HeightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "height",
        abstract: "Print the current desk height."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() throws {
        let status = try runIPC(json: json) { try $0.getStatus() }
        if json {
            printJSON(status)
        } else {
            printPlain(status)
        }
    }

    // MARK: - Formatters

    private func printPlain(_ status: StatusResult) {
        let display = status.heightDisplay ?? "unknown"
        print("\(display) \(status.unit)")
    }

    private struct HeightJSON: Encodable {
        let height_mm: Int
        let height_display: String
        let unit: String
    }

    private func printJSON(_ status: StatusResult) {
        let payload = HeightJSON(
            height_mm: status.heightMM ?? 0,
            height_display: status.heightDisplay ?? "0.0",
            unit: status.unit
        )
        guard let data = try? JSONEncoder().encode(payload),
              let line = String(data: data, encoding: .utf8) else {
            print(#"{"height_mm": 0, "height_display": "unknown", "unit": ""}"#)
            return
        }
        print(line)
    }
}
