import Foundation

/// A local AI CLI the app drives as a subprocess — no API key, no token cost.
/// It reuses whatever the user already has authenticated on their machine, so
/// "if you can run `claude` in Terminal, this works."
public enum AICLI: String, Codable, CaseIterable, Sendable, Identifiable {
    case claude
    case codex

    public var id: String { rawValue }

    /// The binary name (also the `PATH` lookup key).
    public var binary: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "OpenAI Codex"
        }
    }

    /// Shown when the CLI is missing, so the UI can tell the user how to get it.
    public var installHint: String {
        switch self {
        case .claude: return "npm i -g @anthropic-ai/claude-code"
        case .codex: return "npm i -g @openai/codex"
        }
    }

    /// argv to run a one-shot, non-interactive prompt and read the answer from
    /// stdout. `codex` gets `-q` so it stays quiet and machine-parseable.
    public func arguments(for prompt: String) -> [String] {
        switch self {
        case .claude: return ["-p", prompt]
        case .codex: return ["exec", "-q", prompt]
        }
    }
}

public enum AIError: LocalizedError {
    case noProvider
    case notFound(AICLI)
    case emptyInput
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .noProvider: return "No AI provider configured."
        case .notFound(let cli): return "\(cli.displayName) not found on your PATH."
        case .emptyInput: return "Nothing to send to the AI."
        case .failed(let m):
            let snippet = m.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines)
            return "AI CLI failed: \(snippet.isEmpty ? "no output" : snippet)"
        }
    }
}
