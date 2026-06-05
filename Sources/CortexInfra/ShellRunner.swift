import Foundation

/// Runs short-lived subprocesses and resolves executables on the user's real
/// `PATH` — the plumbing under `CortexAI`, factored out because launching a CLI
/// from a Finder-launched `.app` (which inherits a bare environment) is fiddly
/// enough to deserve one tested implementation.
///
/// This merges the two divergent approaches the apps had grown:
/// - an **interactive login shell** (`zsh -ilc`) to source `~/.zshrc`, where
///   users add Homebrew / nvm / `~/.local/bin` to PATH, and
/// - a **direct scan** of the common install directories as a fallback.
///
/// All methods are `async` and run off the main thread.
public enum ShellRunner {

    /// A tiny thread-safe byte accumulator for draining a pipe off the reader
    /// queue — sidesteps `NSMutableData`'s non-`Sendable`ness in the `@Sendable`
    /// readability handler.
    private final class DataSink: @unchecked Sendable {
        private let lock = NSLock()
        private var buffer = Data()
        func append(_ chunk: Data) {
            lock.lock(); buffer.append(chunk); lock.unlock()
        }
        var data: Data {
            lock.lock(); defer { lock.unlock() }; return buffer
        }
    }

    /// Result of a finished process.
    public struct Output: Sendable {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32
        public var ok: Bool { exitCode == 0 }
    }

    public enum ShellError: LocalizedError {
        case launchFailed(String)
        public var errorDescription: String? {
            switch self {
            case .launchFailed(let m): return "Failed to launch process: \(m)"
            }
        }
    }

    // MARK: - PATH resolution

    /// Directories the Cortex CLIs (and their Node runtimes) are commonly found
    /// in. Used both to scan for a binary and to augment a child's `PATH`.
    public static var commonBinDirs: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.bun/bin",
            "\(home)/.deno/bin",
            "\(home)/.volta/bin",
            "\(home)/.npm-global/bin",
            "\(home)/n/bin",
            "/usr/bin",
        ]
    }

    /// Resolves `binary` to an absolute path, trying the user's interactive
    /// login shell first, then scanning `commonBinDirs`. Returns `nil` if not
    /// found anywhere.
    public static func resolve(_ binary: String) async -> String? {
        if let p = await viaLoginShell(binary) { return p }
        return scanCommonDirs(binary)
    }

    /// `command -v <binary>` through an interactive login shell, so `~/.zshrc`
    /// (where PATH is usually extended) is sourced. `nil` if the lookup fails.
    private static func viaLoginShell(_ binary: String) async -> String? {
        let out = try? await run(
            executable: "/bin/zsh",
            arguments: ["-ilc", "command -v \(binary)"]
        )
        guard let out, out.ok else { return nil }
        let trimmed = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.components(separatedBy: "\n").last { !$0.isEmpty }
    }

    /// Direct scan of the usual install locations.
    private static func scanCommonDirs(_ binary: String) -> String? {
        for dir in commonBinDirs where FileManager.default.isExecutableFile(atPath: "\(dir)/\(binary)") {
            return "\(dir)/\(binary)"
        }
        return nil
    }

    /// The process environment with `commonBinDirs` prepended to `PATH` (and a
    /// `HOME` fallback), so a spawned CLI can find its own runtime even when the
    /// app launched from Finder with a minimal environment.
    public static func augmentedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let existing = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = commonBinDirs.joined(separator: ":") + ":" + existing
        if env["HOME"] == nil {
            env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        }
        return env
    }

    // MARK: - Running

    /// Runs `executable` with `arguments`, draining stdout and stderr
    /// concurrently (so a full pipe buffer can never deadlock the child), and
    /// returns when it exits.
    ///
    /// - Parameters:
    ///   - executable: absolute path to the binary to run.
    ///   - arguments: argv (without the executable itself).
    ///   - environment: child environment; defaults to `augmentedEnvironment()`.
    public static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) async throws -> Output {
        let env = environment ?? augmentedEnvironment()
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: executable)
                proc.arguments = arguments
                proc.environment = env
                proc.standardInput = FileHandle.nullDevice  // never block on input

                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe

                // Drain stderr concurrently so a large error stream can't fill
                // the pipe buffer and stall the child while we block on stdout.
                let errSink = DataSink()
                errPipe.fileHandleForReading.readabilityHandler = { h in
                    errSink.append(h.availableData)
                }

                do {
                    try proc.run()
                } catch {
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    cont.resume(throwing: ShellError.launchFailed(error.localizedDescription))
                    return
                }

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                errPipe.fileHandleForReading.readabilityHandler = nil

                cont.resume(returning: Output(
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errSink.data, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                ))
            }
        }
    }
}
