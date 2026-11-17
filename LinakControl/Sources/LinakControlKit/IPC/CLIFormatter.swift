// CLIFormatter.swift
// LinakControlKit — CLI error formatting and exit code mapping shared by deskctl commands.

import Foundation

// MARK: - CLIExitCode

public enum CLIExitCode: Int32, Sendable {
    case success = 0
    case general = 1
    case daemonNotRunning = 2
    case notConnected = 3
    case timeout = 5
}

// MARK: - CLIFormatter

public enum CLIFormatter {

    /// Format an IPCClientError into a user-facing message and exit code.
    public static func formatError(_ error: IPCClientError, json: Bool) -> (message: String, exitCode: CLIExitCode) {
        switch error {
        case .daemonNotRunning:
            let msg = json
                ? jsonError(code: 2, message: "daemon not running")
                : "error: daemon not running — start LinakControl.app first"
            return (msg, .daemonNotRunning)

        case .connectionFailed(let detail):
            let msg = json
                ? jsonError(code: 1, message: "connection failed: \(detail)")
                : "error: connection failed: \(detail)"
            return (msg, .general)

        case .invalidResponse:
            let msg = json
                ? jsonError(code: 1, message: "invalid response from daemon")
                : "error: invalid response from daemon"
            return (msg, .general)

        case .serverError(let code, let message):
            let msg = json
                ? jsonError(code: code, message: message)
                : "error: \(message)"
            return (msg, mapServerCode(code))

        case .timeout:
            let msg = json
                ? jsonError(code: 5, message: "request timed out")
                : "error: request timed out — daemon not responding"
            return (msg, .timeout)
        }
    }

    /// Write a message to stderr followed by a newline.
    public static func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    // MARK: - Private

    private struct ErrorJSON: Encodable {
        let error: Int
        let message: String
    }

    /// Encodes an error object as guaranteed-valid JSON (message escaped by the encoder).
    private static func jsonError(code: Int, message: String) -> String {
        guard let data = try? JSONEncoder().encode(ErrorJSON(error: code, message: message)),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"error": 1, "message": "failed to encode error"}"#
        }
        return string
    }

    private static func mapServerCode(_ code: Int) -> CLIExitCode {
        switch code {
        case 2: return .daemonNotRunning
        case 3: return .notConnected
        case 5: return .timeout
        default: return .general
        }
    }
}
