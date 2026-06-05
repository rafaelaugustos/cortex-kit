import SwiftUI
import Foundation
import CortexUI

/// Highlights case-insensitive matches of a query inside a string — used to
/// surface ⌘F hits inside grid cells, lists, etc. Also carries a small elapsed-
/// time formatter, since the two travel together in the result UIs.
public enum SearchHighlight {
    /// Paints case-insensitive matches of `query` in `value` with an accent
    /// background. Returns plain text when `query` is empty.
    public static func attributed(_ value: String, query: String) -> AttributedString {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return AttributedString(value) }
        let ns = value as NSString
        var out = AttributedString()
        var cursor = 0
        var search = NSRange(location: 0, length: ns.length)
        while true {
            let r = ns.range(of: trimmed, options: .caseInsensitive, range: search)
            if r.location == NSNotFound { break }
            if r.location > cursor {
                out += AttributedString(ns.substring(with: NSRange(location: cursor, length: r.location - cursor)))
            }
            var hit = AttributedString(ns.substring(with: r))
            hit.backgroundColor = Brand.accent.opacity(0.45)
            hit.foregroundColor = .white
            out += hit
            cursor = r.location + r.length
            search = NSRange(location: cursor, length: ns.length - cursor)
        }
        if cursor < ns.length {
            out += AttributedString(ns.substring(from: cursor))
        }
        return out
    }

    /// Short-form elapsed duration: `<1ms`, `1.4ms`, `234ms`, `1.2s`.
    public static func elapsed(_ seconds: TimeInterval) -> String {
        let ms = seconds * 1000
        if ms < 1 { return "<1ms" }
        if ms < 10 { return String(format: "%.1fms", ms) }
        if ms < 1000 { return String(format: "%.0fms", ms) }
        return String(format: "%.2fs", ms / 1000)
    }
}
