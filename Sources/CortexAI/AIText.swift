import Foundation

/// Pure text helpers for taming CLI output. LLMs wrap answers in code fences,
/// add preamble, or run long — these clean that up. Kept free of any process or
/// UI dependency so they're trivially testable.
public enum AIText {

    /// Strips a leading/trailing ```` ``` ```` fence (with optional language tag)
    /// that the CLI sometimes wraps around output. Returns the inner text,
    /// trimmed.
    public static func stripFences(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("```") else { return t }
        if let nl = t.firstIndex(of: "\n") { t = String(t[t.index(after: nl)...]) }
        if let r = t.range(of: "```", options: .backwards) { t = String(t[..<r.lowerBound]) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first non-empty, non-fence line — used for single-line answers like
    /// commit subjects, where the CLI may add blank lines or a code fence around
    /// the real content. Surrounding quotes/backticks are stripped.
    public static func firstMeaningfulLine(_ raw: String) -> String {
        let line = raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("```") } ?? raw
        return line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
    }

    /// Truncates `text` to `limit` characters, appending a marker when cut —
    /// used to keep diffs/contexts under a prompt budget.
    public static func truncated(_ text: String, to limit: Int) -> String {
        text.count <= limit ? text : "\(text.prefix(limit))\n…(truncated)…"
    }
}
