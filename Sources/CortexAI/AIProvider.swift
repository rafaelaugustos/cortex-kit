import Foundation
import CortexInfra

/// Drives the user's local AI CLI (`claude` / `codex`) to generate text.
///
/// Robust PATH resolution (login shell + directory scan, via ``ShellRunner``)
/// plus preference-aware backend selection, so it finds the CLI even from a
/// Finder-launched `.app` and honours a user-pinned backend.
///
/// ```swift
/// let provider = AIProvider(prefs: PrefsStore(namespace: "cortexdb"))
/// if let cli = await provider.resolveBackend() {
///     let answer = try await provider.run(prompt: "Explain this query…", cli: cli)
/// }
/// ```
///
/// It is stateless apart from an optional ``PrefsStore`` used to honour a
/// user-pinned backend, so it is cheap to create and `Sendable`.
public struct AIProvider: Sendable {

    /// Preference suffix (under the store's namespace) holding the pinned
    /// backend: an `AICLI.rawValue`, or ``autoValue`` for "whatever is on PATH".
    public static let backendPrefKey = "aiProvider"

    /// Sentinel preference value meaning "auto-detect".
    public static let autoValue = "auto"

    private let prefs: PrefsStore?

    /// - Parameter prefs: optional namespaced store. When provided,
    ///   ``resolveBackend()`` honours the user's pinned backend; without it,
    ///   selection is pure auto-detection.
    public init(prefs: PrefsStore? = nil) {
        self.prefs = prefs
    }

    // MARK: - Detection

    /// Every CLI that resolves on the user's `PATH`, mapped to its absolute path.
    public func detect() async -> [AICLI: String] {
        var found: [AICLI: String] = [:]
        for cli in AICLI.allCases {
            if let path = await ShellRunner.resolve(cli.binary) { found[cli] = path }
        }
        return found
    }

    /// The first available CLI, preferring `claude` (most users are already
    /// authenticated there). `nil` if neither is installed.
    public func detectBackend() async -> AICLI? {
        for cli in AICLI.allCases where await ShellRunner.resolve(cli.binary) != nil {
            return cli
        }
        return nil
    }

    /// Resolves the backend to use: if the user pinned one in preferences and
    /// it's installed, use it; otherwise fall back to auto-detection.
    public func resolveBackend() async -> AICLI? {
        if let prefs {
            let pref = prefs.string(for: Self.backendPrefKey, default: Self.autoValue)
            if pref != Self.autoValue, let pinned = AICLI(rawValue: pref),
               await ShellRunner.resolve(pinned.binary) != nil {
                return pinned
            }
        }
        return await detectBackend()
    }

    // MARK: - Running

    /// Runs `prompt` through `cli` and returns its trimmed stdout.
    /// - Throws: ``AIError/notFound(_:)`` if the binary can't be resolved, or
    ///   ``AIError/failed(_:)`` on a non-zero exit.
    public func run(prompt: String, cli: AICLI) async throws -> String {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.emptyInput
        }
        guard let path = await ShellRunner.resolve(cli.binary) else {
            throw AIError.notFound(cli)
        }
        let out = try await ShellRunner.run(executable: path, arguments: cli.arguments(for: prompt))
        guard out.ok else {
            let msg = out.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AIError.failed(msg.isEmpty ? "Exited with code \(out.exitCode)" : msg)
        }
        return out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves the backend and runs `prompt` in one call.
    /// - Throws: ``AIError/noProvider`` if no CLI is available.
    public func run(prompt: String) async throws -> String {
        guard let cli = await resolveBackend() else { throw AIError.noProvider }
        return try await run(prompt: prompt, cli: cli)
    }
}
